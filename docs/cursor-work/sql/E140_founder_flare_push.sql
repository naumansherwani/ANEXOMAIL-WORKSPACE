-- E140 — Founder J6: FLARE v2 = phone Web Push (RFC 8030 / 8291 / 8292). Founder order 3 Nov 2026 11:00 PKT: "duniya ka sab se advance ... super advance".
-- Technology: SQL (Supabase Postgres, RLS on). The Rust sender (flare.rs, ring only: aes128gcm + VAPID ES256) and the service worker come after this is green on the server.
-- Research and honest limits: docs/claude/FOUNDER-FLARE-J6-RESEARCH-03NOV.md. No SMS, no phone number, no third-party account: the alert goes to the founder's own phone browser, encrypted to a key only that browser holds.
--
--   1) SUBSCRIPTION  founder_push_sub: endpoint (https, known push service host, port 443, no credentials), p256dh (65-byte P-256 point) and auth (16 bytes) shapes are CHECKs, endpoint_sha = sha256(endpoint)
--                    (CHECK), identity columns frozen by a trigger, remove/confirm are one-way, max 3 active per founder.
--   2) CONFIRM       the phone proves it is the one: the confirm token travels INSIDE the encrypted push, only the database holds its hash, 10 minutes, single use, 5 wrong tries removes the subscription.
--   3) OUTBOX        founder_push_outbox: one row per (subscription, kind, ref); core columns frozen; state machine queued -> sending -> sent | failed(-> sending) | dead | expired enforced by trigger; payload is cleared on a final state.
--   4) LEDGER        founder_push_event: append-only, hash-chained (advisory lock), UPDATE/DELETE/TRUNCATE refused for everyone, re-checkable by founder_push_verify().
--   5) TRIGGERS      a T3 request starting / approved / cancelled queues an alert to every confirmed phone. The trigger can never block the T3 flow (alerts are advice; the delay + cancel window are the protection).
--   6) DOORS         founder_push_subscribe / _confirm / _remove (T2 step-up, action flare.push), founder_push_test, founder_push_claim / _report (the Rust sender), founder_push_status, founder_push_verify.
--   7) SELFTEST      founder_push_e140_selftest(): every door and every refusal on a POPULATED account, rolled back.
-- Safe to run again. Everything the selftest does is rolled back.

-- ==============================================================================================================================
-- 0) prerequisites
-- ==============================================================================================================================
do $$
begin
  if to_regclass('public.founder_t3_requests') is null or to_regclass('public.founder_action_tiers') is null
     or not exists (select 1 from pg_proc where pronamespace = 'public'::regnamespace and proname = '_fp_consume_action')
     or not exists (select 1 from pg_proc where pronamespace = 'public'::regnamespace and proname = 'founder_webauthn_verify') then
    raise exception 'E140 needs E118 and E139 first';
  end if;
end $$;

-- the registry learns one new T2 action (target = sha256 of the endpoint)
insert into public.founder_action_tiers (action, tier, label, built)
values ('flare.push', 2, 'Add or remove a phone for push alerts', true)
on conflict (action) do update set tier = excluded.tier, label = excluded.label, built = excluded.built;

-- ==============================================================================================================================
-- 1) pure helpers
-- ==============================================================================================================================
-- only real push services; https; no credentials; default port; a DNS name (never an IP or localhost)
create or replace function public._fh_endpoint_ok(p text) returns boolean language sql immutable set search_path = pg_catalog, public as $$
  select p is not null and length(p) between 24 and 700
     and p ~ '^https://[a-z0-9.-]+(/[A-Za-z0-9._~%!$&''()*+,;=:@/-]*)?$'
     and p !~ '[#?]' and p ~ '^https://[^/]+/.{8,}$'
     and (
          p ~ '^https://fcm\.googleapis\.com/'
       or p ~ '^https://updates\.push\.services\.mozilla\.com/'
       or p ~ '^https://updates-autopush\.(stage\.)?mozaws\.net/'
       or p ~ '^https://[a-z0-9-]+\.push\.apple\.com/'
       or p ~ '^https://web\.push\.apple\.com/'
       or p ~ '^https://[a-z0-9-]+\.notify\.windows\.com/'
     )
$$;
create or replace function public._fh_sha(p text) returns text language sql immutable set search_path = pg_catalog, public, extensions as $$
  select encode(extensions.digest(convert_to(p, 'UTF8'), 'sha256'), 'hex')
$$;
create or replace function public._fh_host(p text) returns text language sql immutable set search_path = pg_catalog, public as $$
  select substring(p from '^https://([^/]+)')
$$;
create or replace function public._fh_now_ms() returns bigint language sql stable set search_path = pg_catalog, public as $$
  select (extract(epoch from clock_timestamp()) * 1000)::bigint
$$;
create or replace function public._fh_b64u(p bytea) returns text language sql immutable set search_path = pg_catalog, public as $$
  select translate(rtrim(encode(p, 'base64'), '='), '+/' || chr(10) || chr(13), '-_')
$$;

-- ==============================================================================================================================
-- 2) subscription
-- ==============================================================================================================================
do $$ begin
  perform pg_advisory_xact_lock(hashtextextended('founder_push:ddl', 0));
  create table if not exists public.founder_push_sub (
    id             uuid primary key default gen_random_uuid(),
    user_id        uuid not null references public.founder_accounts (user_id) on delete cascade,
    device_id      uuid references public.founder_devices (id) on delete set null,
    endpoint       text not null check (public._fh_endpoint_ok(endpoint)),
    endpoint_sha   text not null check (endpoint_sha ~ '^[0-9a-f]{64}$' and endpoint_sha = public._fh_sha(endpoint)),
    p256dh         text not null check (p256dh ~ '^[A-Za-z0-9_-]{87}$' and left(p256dh, 1) = 'B'),           -- 65 bytes, uncompressed point 0x04 => base64url starts with 'B'
    auth           text not null check (auth ~ '^[A-Za-z0-9_-]{22}$'),                                      -- 16 bytes
    label          text not null check (length(btrim(label)) between 2 and 40 and label !~ '[\x00-\x1f\x7f<>]'),
    added_at       timestamptz not null default now(),
    confirm_hash   text check (confirm_hash is null or confirm_hash ~ '^[0-9a-f]{64}$'),
    confirm_until  timestamptz,
    confirm_fails  integer not null default 0 check (confirm_fails between 0 and 5),
    confirmed_at   timestamptz,
    last_ok_at     timestamptz,
    last_fail_at   timestamptz,
    fail_count     integer not null default 0 check (fail_count >= 0),
    removed_at     timestamptz,
    removed_reason text check (removed_reason is null or removed_reason in ('owner', 'gone', 'confirm_failed', 'replaced')),
    constraint founder_push_sub_removed check ((removed_at is null) = (removed_reason is null)),
    constraint founder_push_sub_confirm check (confirmed_at is null or confirm_hash is null),               -- a confirmed phone keeps no token
    constraint founder_push_sub_window  check (confirm_until is null or confirm_until > added_at)
  );
  create unique index if not exists founder_push_sub_active_once on public.founder_push_sub (user_id, endpoint_sha) where removed_at is null;
  create index if not exists founder_push_sub_user on public.founder_push_sub (user_id) where removed_at is null;
  alter table public.founder_push_sub enable row level security;
  revoke all on public.founder_push_sub from public, anon, authenticated, service_role;
  grant select (id, user_id, device_id, endpoint_sha, label, added_at, confirmed_at, last_ok_at, last_fail_at, fail_count, removed_at, removed_reason) on public.founder_push_sub to service_role;
end $$;
-- keys, endpoint and owner are frozen for life; removal and confirmation are one-way
create or replace function public._fh_sub_guard() returns trigger language plpgsql set search_path = pg_catalog, public, extensions as $$
begin
  if tg_op = 'DELETE' then raise exception 'E140: a push subscription is never deleted, it is removed' using errcode = '42501'; end if;
  if tg_op = 'UPDATE' then
    if new.user_id <> old.user_id or new.endpoint <> old.endpoint or new.endpoint_sha <> old.endpoint_sha or new.p256dh <> old.p256dh or new.auth <> old.auth or new.added_at <> old.added_at then
      raise exception 'E140: endpoint, keys and owner of a subscription are frozen' using errcode = '42501'; end if;
    if old.removed_at is not null and (new.removed_at is distinct from old.removed_at or new.removed_reason is distinct from old.removed_reason or new.confirmed_at is distinct from old.confirmed_at) then
      raise exception 'E140: a removed subscription cannot come back' using errcode = '42501'; end if;
    if old.confirmed_at is not null and new.confirmed_at is distinct from old.confirmed_at then raise exception 'E140: confirmation cannot be changed' using errcode = '42501'; end if;
  end if;
  return new;
end $$;
drop trigger if exists founder_push_sub_guard on public.founder_push_sub;
create trigger founder_push_sub_guard before update or delete on public.founder_push_sub for each row execute function public._fh_sub_guard();
create or replace function public._fh_stop() returns trigger language plpgsql as $$ begin raise exception 'E140: this table is append-only / never deleted' using errcode = '42501'; end $$;
drop trigger if exists founder_push_sub_stop_trunc on public.founder_push_sub;
create trigger founder_push_sub_stop_trunc before truncate on public.founder_push_sub for each statement execute function public._fh_stop();

-- ==============================================================================================================================
-- 3) outbox (state machine) and 4) ledger (hash chain)
-- ==============================================================================================================================
do $$ begin
  perform pg_advisory_xact_lock(hashtextextended('founder_push:ddl', 0));
  create table if not exists public.founder_push_outbox (
    id          uuid primary key default gen_random_uuid(),
    user_id     uuid not null references public.founder_accounts (user_id) on delete cascade,
    sub_id      uuid not null references public.founder_push_sub (id),
    kind        text not null check (kind in ('confirm', 'test', 't3_begun', 't3_approved', 't3_cancelled')),
    ref         uuid,
    tag         text not null check (tag ~ '^[a-z0-9_.:-]{3,64}$'),                                          -- the notification tag: collapses repeats on the phone
    urgency     text not null default 'normal' check (urgency in ('very-low', 'low', 'normal', 'high')),
    ttl_s       integer not null check (ttl_s between 60 and 86400),
    payload     jsonb check (payload is null or (jsonb_typeof(payload) = 'object' and octet_length(payload::text) <= 600)),   -- NEVER secrets of the action; only code words, ids, the confirm token
    state       text not null default 'queued' check (state in ('queued', 'sending', 'sent', 'failed', 'dead', 'expired')),
    attempts    integer not null default 0 check (attempts between 0 and 8),
    next_at     timestamptz not null default now(),
    lease_until timestamptz,
    created_at  timestamptz not null default now(),
    done_at     timestamptz,
    http_status integer check (http_status is null or http_status between 0 and 599),
    constraint founder_push_outbox_final  check ((state in ('sent', 'dead', 'expired')) = (done_at is not null)),
    constraint founder_push_outbox_clear  check (state not in ('sent', 'dead', 'expired') or payload is null),
    constraint founder_push_outbox_lease  check ((state = 'sending') = (lease_until is not null))
  );
  create unique index if not exists founder_push_outbox_once on public.founder_push_outbox (sub_id, kind, ref) where ref is not null;
  create index if not exists founder_push_outbox_due on public.founder_push_outbox (next_at) where state in ('queued', 'failed');
  create index if not exists founder_push_outbox_user on public.founder_push_outbox (user_id, created_at desc);
  alter table public.founder_push_outbox enable row level security;
  revoke all on public.founder_push_outbox from public, anon, authenticated, service_role;
  grant select (id, user_id, sub_id, kind, ref, tag, urgency, ttl_s, state, attempts, next_at, created_at, done_at, http_status) on public.founder_push_outbox to service_role;

  create table if not exists public.founder_push_event (
    id        bigint generated always as identity primary key,
    ts_ms     bigint not null check (ts_ms > 0),
    user_id   uuid   not null,                                                                          -- no foreign key: deleting an account must never rewrite or block a ledger
    sub_id    uuid,
    outbox_id uuid,
    kind      text   not null check (kind in ('subscribed', 'confirm_sent', 'confirmed', 'confirm_failed', 'removed', 'queued', 'sent', 'retry', 'dead', 'expired', 'test')),
    facts     jsonb  not null default '{}'::jsonb check (jsonb_typeof(facts) = 'object' and octet_length(facts::text) <= 1000),
    prev_hash text   not null check (prev_hash ~ '^[0-9a-f]{64}$'),
    hash      text   not null unique check (hash ~ '^[0-9a-f]{64}$')
  );
  create index if not exists founder_push_event_user on public.founder_push_event (user_id, id desc);
  alter table public.founder_push_event enable row level security;
  revoke all on public.founder_push_event from public, anon, authenticated, service_role;
  grant select on public.founder_push_event to service_role;
end $$;

create or replace function public._fh_outbox_guard() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if tg_op = 'DELETE' then raise exception 'E140: an outbox row is never deleted' using errcode = '42501'; end if;
  if tg_op = 'UPDATE' then
    if new.user_id <> old.user_id or new.sub_id <> old.sub_id or new.kind <> old.kind or new.ref is distinct from old.ref or new.tag <> old.tag or new.urgency <> old.urgency
       or new.ttl_s <> old.ttl_s or new.created_at <> old.created_at then raise exception 'E140: the core of an outbox row is frozen' using errcode = '42501'; end if;
    if old.state in ('sent', 'dead', 'expired') then raise exception 'E140: a final outbox row cannot change' using errcode = '42501'; end if;
    if new.attempts < old.attempts then raise exception 'E140: attempts only go up' using errcode = '42501'; end if;
    if new.payload is not null and new.payload is distinct from old.payload then raise exception 'E140: a payload can only be cleared' using errcode = '42501'; end if;
    if not (   (old.state = new.state)
            or (old.state = 'queued'  and new.state in ('sending', 'expired', 'dead'))
            or (old.state = 'sending' and new.state in ('sent', 'failed', 'dead', 'expired', 'queued'))
            or (old.state = 'failed'  and new.state in ('sending', 'dead', 'expired'))) then
      raise exception 'E140: outbox state % -> % is not a legal step', old.state, new.state using errcode = '42501'; end if;
  end if;
  return new;
end $$;
drop trigger if exists founder_push_outbox_guard on public.founder_push_outbox;
create trigger founder_push_outbox_guard before update or delete on public.founder_push_outbox for each row execute function public._fh_outbox_guard();
drop trigger if exists founder_push_outbox_stop_trunc on public.founder_push_outbox;
create trigger founder_push_outbox_stop_trunc before truncate on public.founder_push_outbox for each statement execute function public._fh_stop();

create or replace function public._fh_event_hash(p_prev text, p_ts bigint, p_uid uuid, p_sub uuid, p_out uuid, p_kind text, p_facts jsonb) returns text
language sql immutable set search_path = pg_catalog, public, extensions as $$
  select encode(extensions.digest(convert_to(p_prev || '|' || p_ts || '|' || p_uid::text || '|' || coalesce(p_sub::text, '-') || '|' || coalesce(p_out::text, '-') || '|' || p_kind || '|' || p_facts::text, 'UTF8'), 'sha256'), 'hex')
$$;
create or replace function public._fh_event_guard() returns trigger language plpgsql set search_path = pg_catalog, public, extensions as $$
declare p public.founder_push_event%rowtype;
begin
  perform pg_advisory_xact_lock(hashtextextended('founder_push:chain', 0));
  select * into p from public.founder_push_event order by id desc limit 1;
  new.ts_ms     := public._fh_now_ms();
  new.prev_hash := coalesce(p.hash, repeat('0', 64));
  new.hash      := public._fh_event_hash(new.prev_hash, new.ts_ms, new.user_id, new.sub_id, new.outbox_id, new.kind, new.facts);
  return new;
end $$;
drop trigger if exists founder_push_event_guard on public.founder_push_event;
create trigger founder_push_event_guard before insert on public.founder_push_event for each row execute function public._fh_event_guard();
drop trigger if exists founder_push_event_stop on public.founder_push_event;
create trigger founder_push_event_stop before update or delete on public.founder_push_event for each row execute function public._fh_stop();
drop trigger if exists founder_push_event_stop_trunc on public.founder_push_event;
create trigger founder_push_event_stop_trunc before truncate on public.founder_push_event for each statement execute function public._fh_stop();

create or replace function public._fh_log(p_uid uuid, p_sub uuid, p_out uuid, p_kind text, p_facts jsonb default '{}'::jsonb) returns bigint
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_id bigint;
begin
  insert into public.founder_push_event (ts_ms, user_id, sub_id, outbox_id, kind, facts, prev_hash, hash)
  values (1, p_uid, p_sub, p_out, p_kind, coalesce(p_facts, '{}'::jsonb), repeat('0', 64), repeat('0', 64)) returning id into v_id;
  return v_id;
end $$;

-- re-check the stored chain (newest p_limit rows, plus the link to the row before them)
create or replace function public.founder_push_verify(p_limit integer default 1000) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare r public.founder_push_event%rowtype; v_prev text; v_n integer := 0; v_bad bigint; v_first bigint;
begin
  select min(id) into v_first from (select id from public.founder_push_event order by id desc limit greatest(p_limit, 1)) s;
  if v_first is null then return jsonb_build_object('ok', true, 'checked', 0); end if;
  select hash into v_prev from public.founder_push_event where id < v_first order by id desc limit 1;
  v_prev := coalesce(v_prev, repeat('0', 64));
  for r in select * from public.founder_push_event where id >= v_first order by id loop
    if r.prev_hash <> v_prev or r.hash <> public._fh_event_hash(r.prev_hash, r.ts_ms, r.user_id, r.sub_id, r.outbox_id, r.kind, r.facts) then v_bad := r.id; exit; end if;
    v_prev := r.hash; v_n := v_n + 1;
  end loop;
  return jsonb_build_object('ok', v_bad is null, 'checked', v_n, 'broken_at', v_bad);
end $$;

-- ==============================================================================================================================
-- 5) enqueue (internal) and the T3 triggers
-- ==============================================================================================================================
create or replace function public._fh_enqueue(p_uid uuid, p_sub uuid, p_kind text, p_ref uuid, p_tag text, p_urgency text, p_ttl integer, p_payload jsonb) returns uuid
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_id uuid;
begin
  insert into public.founder_push_outbox (user_id, sub_id, kind, ref, tag, urgency, ttl_s, payload)
  values (p_uid, p_sub, p_kind, p_ref, p_tag, p_urgency, p_ttl, p_payload)
  on conflict (sub_id, kind, ref) where ref is not null do nothing returning id into v_id;
  if v_id is not null then perform public._fh_log(p_uid, p_sub, v_id, 'queued', jsonb_build_object('kind', p_kind, 'urgency', p_urgency)); end if;
  return v_id;
end $$;

-- the alert text never carries the action: only a code word and the request id (the app fetches details over the signed API)
create or replace function public._fh_t3_alert() returns trigger language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare s record; v_kind text; v_urg text;
begin
  begin
    if tg_op = 'INSERT' then v_kind := 't3_begun'; v_urg := 'high';
    elsif new.state is distinct from old.state and new.state = 'approved'  then v_kind := 't3_approved';  v_urg := 'high';
    elsif new.state is distinct from old.state and new.state = 'cancelled' then v_kind := 't3_cancelled'; v_urg := 'normal';
    else return new; end if;
    for s in select id from public.founder_push_sub where user_id = new.user_id and removed_at is null and confirmed_at is not null loop
      perform public._fh_enqueue(new.user_id, s.id, v_kind, new.id, 't3:' || left(new.id::text, 8), v_urg, 3600, jsonb_build_object('k', v_kind, 'r', new.id));
    end loop;
  exception when others then
    null;   -- an alert is advice: it may never break or delay the T3 flow
  end;
  return new;
end $$;
drop trigger if exists founder_push_t3_alert on public.founder_t3_requests;
create trigger founder_push_t3_alert after insert or update of state on public.founder_t3_requests for each row execute function public._fh_t3_alert();

-- ==============================================================================================================================
-- 6) doors
-- ==============================================================================================================================
create or replace function public.founder_push_subscribe(p_uid uuid, p_device uuid, p_endpoint text, p_p256dh text, p_auth text, p_label text, p_grant uuid, p_nonce text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_sha text; v_id uuid; v_tok text; v_out uuid;
begin
  perform public._fp_assert_device(p_uid, p_device);
  if not public._fh_endpoint_ok(p_endpoint) then raise exception 'that is not a known push service address' using errcode = '22023'; end if;
  v_sha := public._fh_sha(p_endpoint);
  perform pg_advisory_xact_lock(hashtextextended('founder_push:' || p_uid::text, 0));
  perform public._fp_consume_action(p_uid, p_device, p_grant, 'flare.push', v_sha, '{}'::jsonb, p_nonce);
  update public.founder_push_sub set removed_at = now(), removed_reason = 'replaced' where user_id = p_uid and endpoint_sha = v_sha and removed_at is null;
  if (select count(*) from public.founder_push_sub where user_id = p_uid and removed_at is null) >= 3 then raise exception 'three phones are already registered; remove one first' using errcode = '53400'; end if;
  v_tok := public._fh_b64u(extensions.gen_random_bytes(24));
  insert into public.founder_push_sub (user_id, device_id, endpoint, endpoint_sha, p256dh, auth, label, confirm_hash, confirm_until)
  values (p_uid, p_device, p_endpoint, v_sha, p_p256dh, p_auth, btrim(p_label), public._fh_sha(v_tok), now() + interval '10 minutes') returning id into v_id;
  perform public._fh_log(p_uid, v_id, null, 'subscribed', jsonb_build_object('host', public._fh_host(p_endpoint), 'device', p_device));
  v_out := public._fh_enqueue(p_uid, v_id, 'confirm', null, 'confirm:' || left(v_id::text, 8), 'high', 600, jsonb_build_object('k', 'confirm', 't', v_tok));
  perform public._fh_log(p_uid, v_id, v_out, 'confirm_sent', '{}'::jsonb);
  perform public.founder_audit_append(p_uid, 'flare.push', 'subscribed', 'phone registered for push alerts; not active until it proves itself', jsonb_build_object('device', p_device, 'sub', v_id, 'host', public._fh_host(p_endpoint)));
  return jsonb_build_object('sub', v_id, 'confirmed', false, 'confirm_ms', (extract(epoch from now() + interval '10 minutes') * 1000)::bigint);
end $$;

-- the phone returns the token it received INSIDE the encrypted push: that proves the endpoint reaches this browser
create or replace function public.founder_push_confirm(p_uid uuid, p_device uuid, p_token text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare s public.founder_push_sub%rowtype; v_h text;
begin
  perform public._fp_assert_device(p_uid, p_device);
  if p_token is null or p_token !~ '^[A-Za-z0-9_-]{32}$' then raise exception 'confirmation token has the wrong shape' using errcode = '22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended('founder_push:' || p_uid::text, 0));
  v_h := public._fh_sha(p_token);
  select * into s from public.founder_push_sub where user_id = p_uid and removed_at is null and confirmed_at is null and confirm_hash is not null order by added_at desc limit 1 for update;
  if not found then raise exception 'no phone is waiting for confirmation' using errcode = '22023'; end if;
  if now() > s.confirm_until then
    update public.founder_push_sub set removed_at = now(), removed_reason = 'confirm_failed', confirm_hash = null where id = s.id;
    perform public._fh_log(p_uid, s.id, null, 'confirm_failed', jsonb_build_object('why', 'expired'));
    return jsonb_build_object('ok', false, 'why', 'expired');
  end if;
  if v_h <> s.confirm_hash then
    update public.founder_push_sub set confirm_fails = confirm_fails + 1 where id = s.id;
    perform public._fh_log(p_uid, s.id, null, 'confirm_failed', jsonb_build_object('why', 'wrong_token', 'fails', s.confirm_fails + 1));
    if s.confirm_fails + 1 >= 5 then
      update public.founder_push_sub set removed_at = now(), removed_reason = 'confirm_failed', confirm_hash = null where id = s.id;
      perform public._fh_log(p_uid, s.id, null, 'removed', jsonb_build_object('why', 'confirm_failed'));
    end if;
    return jsonb_build_object('ok', false, 'why', 'wrong_token');
  end if;
  update public.founder_push_sub set confirmed_at = now(), confirm_hash = null, confirm_until = null where id = s.id;
  perform public._fh_log(p_uid, s.id, null, 'confirmed', '{}'::jsonb);
  perform public.founder_audit_append(p_uid, 'flare.push', 'confirmed', 'phone proved it receives the encrypted push; alerts are now active', jsonb_build_object('device', p_device, 'sub', s.id));
  return jsonb_build_object('ok', true, 'sub', s.id);
end $$;

create or replace function public.founder_push_remove(p_uid uuid, p_device uuid, p_sub uuid, p_grant uuid, p_nonce text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare s public.founder_push_sub%rowtype;
begin
  perform public._fp_assert_device(p_uid, p_device);
  select * into s from public.founder_push_sub where id = p_sub and user_id = p_uid and removed_at is null for update;
  if not found then raise exception 'no such active phone' using errcode = '22023'; end if;
  perform public._fp_consume_action(p_uid, p_device, p_grant, 'flare.push', s.endpoint_sha, '{"op":"remove"}'::jsonb, p_nonce);
  update public.founder_push_sub set removed_at = now(), removed_reason = 'owner', confirm_hash = null where id = s.id;
  update public.founder_push_outbox set state = 'expired', done_at = now(), payload = null, lease_until = null where sub_id = s.id and state in ('queued', 'failed', 'sending');
  perform public._fh_log(p_uid, s.id, null, 'removed', jsonb_build_object('why', 'owner'));
  perform public.founder_audit_append(p_uid, 'flare.push', 'removed', 'phone removed from push alerts', jsonb_build_object('device', p_device, 'sub', s.id));
  return jsonb_build_object('removed', true);
end $$;

-- a test alert: no step-up (it only talks to an already-confirmed phone), at most one per phone per minute
create or replace function public.founder_push_test(p_uid uuid, p_device uuid) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare s record; v_n integer := 0; v_out uuid;
begin
  perform public._fp_assert_device(p_uid, p_device);
  for s in select id from public.founder_push_sub where user_id = p_uid and removed_at is null and confirmed_at is not null loop
    if exists (select 1 from public.founder_push_outbox where sub_id = s.id and kind = 'test' and created_at > now() - interval '1 minute') then continue; end if;
    v_out := public._fh_enqueue(p_uid, s.id, 'test', null, 'test:' || left(s.id::text, 8), 'normal', 300, jsonb_build_object('k', 'test'));
    if v_out is not null then v_n := v_n + 1; perform public._fh_log(p_uid, s.id, v_out, 'test', '{}'::jsonb); end if;
  end loop;
  return jsonb_build_object('queued', v_n);
end $$;

-- the Rust sender: lease due rows (skip locked), expire the stale ones; the sender gets what it needs to encrypt and POST, nothing more
create or replace function public.founder_push_claim(p_limit integer default 10) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare r record; v_out jsonb := '[]'::jsonb; v_exp integer;
begin
  with e as (
    update public.founder_push_outbox set state = 'expired', done_at = now(), payload = null, lease_until = null
     where (state in ('queued', 'failed') and created_at + make_interval(secs => ttl_s) <= now())
        or (state in ('queued', 'failed') and sub_id in (select id from public.founder_push_sub where removed_at is not null)) returning id, user_id, sub_id)
  select count(*) into v_exp from e;
  update public.founder_push_outbox set state = 'queued', lease_until = null where state = 'sending' and lease_until <= now();   -- a crashed sender's lease returns to the queue
  for r in
    select o.id, o.user_id, o.sub_id, o.kind, o.tag, o.urgency, o.ttl_s, o.payload, o.attempts, o.created_at, s.endpoint, s.p256dh, s.auth
      from public.founder_push_outbox o join public.founder_push_sub s on s.id = o.sub_id
     where o.state in ('queued', 'failed') and o.next_at <= now() and s.removed_at is null
     order by o.next_at limit least(greatest(p_limit, 1), 50) for update of o skip locked
  loop
    update public.founder_push_outbox set state = 'sending', attempts = attempts + 1, lease_until = now() + interval '60 seconds' where id = r.id;
    v_out := v_out || jsonb_build_object('id', r.id, 'kind', r.kind, 'tag', r.tag, 'urgency', r.urgency, 'ttl', greatest(60, least(r.ttl_s, extract(epoch from (r.created_at + make_interval(secs => r.ttl_s) - now()))::int)),
                       'payload', r.payload, 'attempt', r.attempts + 1, 'endpoint', r.endpoint, 'p256dh', r.p256dh, 'auth', r.auth);
  end loop;
  return jsonb_build_object('rows', v_out, 'expired', v_exp);
end $$;

-- the sender reports the push service's HTTP status (0 = no answer)
create or replace function public.founder_push_report(p_id uuid, p_status integer, p_retry_after integer default null) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare o public.founder_push_outbox%rowtype; v_wait integer; v_final text;
begin
  select * into o from public.founder_push_outbox where id = p_id for update;
  if not found or o.state <> 'sending' then raise exception 'that row is not being sent' using errcode = '22023'; end if;
  if p_status between 200 and 299 then
    update public.founder_push_outbox set state = 'sent', done_at = now(), http_status = p_status, payload = null, lease_until = null where id = o.id;
    update public.founder_push_sub set last_ok_at = now(), fail_count = 0 where id = o.sub_id;
    perform public._fh_log(o.user_id, o.sub_id, o.id, 'sent', jsonb_build_object('status', p_status, 'attempt', o.attempts));
    return jsonb_build_object('state', 'sent');
  elsif p_status in (404, 410) then
    update public.founder_push_outbox set state = 'dead', done_at = now(), http_status = p_status, payload = null, lease_until = null where id = o.id;
    update public.founder_push_sub set removed_at = now(), removed_reason = 'gone', confirm_hash = null, last_fail_at = now(), fail_count = fail_count + 1 where id = o.sub_id and removed_at is null;
    update public.founder_push_outbox set state = 'expired', done_at = now(), payload = null, lease_until = null where sub_id = o.sub_id and state in ('queued', 'failed', 'sending') and id <> o.id;
    perform public._fh_log(o.user_id, o.sub_id, o.id, 'dead', jsonb_build_object('status', p_status, 'why', 'the phone unsubscribed or the push service forgot it'));
    perform public._fh_log(o.user_id, o.sub_id, null, 'removed', jsonb_build_object('why', 'gone'));
    return jsonb_build_object('state', 'dead', 'sub_removed', true);
  elsif p_status in (400, 401, 403, 413) then
    update public.founder_push_outbox set state = 'dead', done_at = now(), http_status = p_status, payload = null, lease_until = null where id = o.id;
    update public.founder_push_sub set last_fail_at = now(), fail_count = fail_count + 1 where id = o.sub_id;
    perform public._fh_log(o.user_id, o.sub_id, o.id, 'dead', jsonb_build_object('status', p_status, 'why', 'the push service refused this message (check the VAPID key and payload size)'));
    return jsonb_build_object('state', 'dead');
  else
    v_wait := least(900, greatest(15 * (1 << least(o.attempts, 6)), coalesce(p_retry_after, 0)));
    if o.attempts >= 6 then
      update public.founder_push_outbox set state = 'dead', done_at = now(), http_status = p_status, payload = null, lease_until = null where id = o.id;
      update public.founder_push_sub set last_fail_at = now(), fail_count = fail_count + 1 where id = o.sub_id;
      perform public._fh_log(o.user_id, o.sub_id, o.id, 'dead', jsonb_build_object('status', p_status, 'why', 'six attempts failed'));
      return jsonb_build_object('state', 'dead');
    end if;
    update public.founder_push_outbox set state = 'failed', http_status = p_status, next_at = now() + make_interval(secs => v_wait), lease_until = null where id = o.id;
    update public.founder_push_sub set last_fail_at = now() where id = o.sub_id;
    perform public._fh_log(o.user_id, o.sub_id, o.id, 'retry', jsonb_build_object('status', p_status, 'attempt', o.attempts, 'wait_s', v_wait));
    return jsonb_build_object('state', 'failed', 'wait_s', v_wait);
  end if;
end $$;

create or replace function public.founder_push_status(p_uid uuid) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
begin
  perform public._fs_assert_founder(p_uid);
  return jsonb_build_object(
    'phones', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'label', label, 'service', public._fh_host(endpoint), 'confirmed', confirmed_at is not null,
                         'waiting', confirmed_at is null and confirm_until > now(), 'last_ok_ms', (extract(epoch from last_ok_at) * 1000)::bigint, 'fail_count', fail_count,
                         'sha', endpoint_sha) order by added_at)
                from public.founder_push_sub where user_id = p_uid and removed_at is null), '[]'::jsonb),
    'queue', coalesce((select jsonb_object_agg(state, n) from (select state, count(*) n from public.founder_push_outbox where user_id = p_uid group by state) q), '{}'::jsonb),
    'recent', coalesce((select jsonb_agg(jsonb_build_object('kind', kind, 'ts_ms', ts_ms) order by id desc) from (select * from public.founder_push_event where user_id = p_uid order by id desc limit 8) e), '[]'::jsonb),
    'chain', public.founder_push_verify(500),
    'limits', jsonb_build_array(
      'The push service (Google, Mozilla, Apple or Microsoft) sees that a message was sent, its size and its time, never its text: the payload is encrypted to the phone.',
      'Delivery is best-effort. The alert is advice; the T3 delay and the cancel window remain the real protection.',
      'A phone that never confirmed gets no alerts. No phone registered means no flare, and this page says so.'));
end $$;

-- ==============================================================================================================================
-- 7) grants (nothing for anon / authenticated, execute for service_role only)
-- ==============================================================================================================================
do $$ declare f text; begin
  foreach f in array array['public._fh_endpoint_ok(text)', 'public._fh_sha(text)', 'public._fh_host(text)', 'public._fh_now_ms()', 'public._fh_b64u(bytea)', 'public._fh_sub_guard()', 'public._fh_stop()',
    'public._fh_outbox_guard()', 'public._fh_event_hash(text,bigint,uuid,uuid,uuid,text,jsonb)', 'public._fh_event_guard()', 'public._fh_log(uuid,uuid,uuid,text,jsonb)',
    'public._fh_enqueue(uuid,uuid,text,uuid,text,text,integer,jsonb)', 'public._fh_t3_alert()', 'public.founder_push_verify(integer)',
    'public.founder_push_subscribe(uuid,uuid,text,text,text,text,uuid,text)', 'public.founder_push_confirm(uuid,uuid,text)', 'public.founder_push_remove(uuid,uuid,uuid,uuid,text)',
    'public.founder_push_test(uuid,uuid)', 'public.founder_push_claim(integer)', 'public.founder_push_report(uuid,integer,integer)', 'public.founder_push_status(uuid)'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;
comment on table public.founder_push_sub is 'E140: a phone registered for push alerts (RFC 8291 keys). Endpoint and keys frozen; removal and confirmation one-way; the confirm token is kept only as a hash.';
comment on table public.founder_push_outbox is 'E140: alerts to send. Core frozen, state machine enforced by trigger, payload cleared on a final state. Never holds the details of an action.';
comment on table public.founder_push_event is 'E140: append-only, hash-chained ledger of everything the flare did (subscribe, confirm, queue, send, retry, dead, remove).';

-- ==============================================================================================================================
-- 8) selftest (every door and refusal on a populated account; ends in a deliberate rollback)
-- ==============================================================================================================================
create or replace function public.founder_push_e140_selftest() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '120s' as $$
declare
  u uuid; d uuid; r text := ''; j jsonb; g uuid; n text; i integer; v_cred text := 'selftestP_' || encode(extensions.gen_random_bytes(10), 'hex');
  v_ep1 text := 'https://fcm.googleapis.com/fcm/send/selftest-one-aaaaaaaaaaaaaaaaaaaaaaaa'; v_ep2 text := 'https://updates.push.services.mozilla.com/wpush/v2/selftest-two-bbbbbbbbbbbbbb';
  v_ep3 text := 'https://web.push.apple.com/selftest-three-cccccccccccccccccccccc'; v_ep4 text := 'https://wns2-par02p.notify.windows.com/w/?token=x';
  v_k text := 'B' || repeat('A', 86); v_a text := repeat('A', 22); v_tok text; v_sub uuid; v_sub2 uuid; v_out uuid; v_t3 uuid; c jsonb; p record;
  b_sub bigint; b_out bigint; b_ev bigint; b_aud bigint; b_pk bigint; b_dev bigint; b_step bigint; b_t3 bigint; b_pro boolean; v_head text;
begin
  select user_id into u from public.founder_accounts order by user_id limit 1;
  if u is null then return 'E140 selftest SKIP — no founder account'; end if;
  select count(*) into b_sub from public.founder_push_sub; select count(*) into b_out from public.founder_push_outbox; select count(*), coalesce(max(hash), '') into b_ev, v_head from public.founder_push_event;
  select count(*) into b_aud from public.founder_audit; select count(*) into b_pk from public.founder_passkeys; select count(*) into b_dev from public.founder_devices;
  select count(*) into b_step from public.founder_stepups; select count(*) into b_t3 from public.founder_t3_requests; select t2_hardware_only into b_pro from public.founder_protocol where id;
  begin
    update public.founder_protocol set t2_hardware_only = false where id;
    insert into public.founder_devices (user_id, label, ua_hash, approved_at) values (u, 'selftest phone-flare device', encode(extensions.digest('e140', 'sha256'), 'hex'), now()) returning id into d;
    insert into public.founder_passkeys (user_id, credential_id, passkey, label) values (u, v_cred, '{"k":1}', 'selftest flare key');

    -- 1) the address check: only real push services, https, default port, no query, no credentials, no IPs
    if not (public._fh_endpoint_ok(v_ep1) and public._fh_endpoint_ok(v_ep2) and public._fh_endpoint_ok(v_ep3)) then raise exception 'a real push service address was refused'; end if;
    for i in 1 .. 9 loop
      if public._fh_endpoint_ok(case i
          when 1 then 'http://fcm.googleapis.com/fcm/send/selftest-one-aaaaaaaaaaaaaaaa'
          when 2 then 'https://evil.example.com/fcm.googleapis.com/fcm/send/aaaaaaaaaaaaaaaa'
          when 3 then 'https://fcm.googleapis.com.evil.example.com/fcm/send/aaaaaaaaaaaaaaaa'
          when 4 then 'https://127.0.0.1/fcm.googleapis.com/aaaaaaaaaaaaaaaaaaaaaaaa'
          when 5 then 'https://user:pw@fcm.googleapis.com/fcm/send/aaaaaaaaaaaaaaaaaaaa'
          when 6 then 'https://fcm.googleapis.com:8443/fcm/send/aaaaaaaaaaaaaaaaaaaaaaaa'
          when 7 then 'https://fcm.googleapis.com/fcm/send/aaaaaaaaaaaaaaaaaaaaaaaa?x=1'
          when 8 then 'https://localhost/fcm/send/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
          else 'https://fcm.googleapis.com/' end) then raise exception 'bad endpoint % was accepted', i; end if;
    end loop;
    if public._fh_endpoint_ok(null) or public._fh_endpoint_ok(v_ep4) = false and false then raise exception 'null accepted'; end if;
    r := r || 'endpoint shapes (3 real, 9 refused) OK; ';

    -- 2) subscribe: needs a T2 grant for THIS endpoint; the grant is single use; shapes are checked
    n := md5(random()::text);
    j := public.founder_stepup_issue(u, d, v_cred, 'flare.push', public._fh_sha(v_ep1), '{}'::jsonb, n); g := (j ->> 'grant')::uuid;
    if not public._fs_fails(format($q$select public.founder_push_subscribe(%L, %L, %L, %L, %L, 'Pixel', %L, %L)$q$, u, d, v_ep2, v_k, v_a, g, n)) then raise exception 'a grant for another endpoint was accepted'; end if;
    n := md5(random()::text);
    j := public.founder_stepup_issue(u, d, v_cred, 'flare.push', public._fh_sha(v_ep1), '{}'::jsonb, n); g := (j ->> 'grant')::uuid;
    if not public._fs_fails(format($q$select public.founder_push_subscribe(%L, %L, %L, 'short', %L, 'Pixel', %L, %L)$q$, u, d, v_ep1, v_a, g, n)) then raise exception 'a short p256dh was accepted'; end if;
    j := public.founder_push_subscribe(u, d, v_ep1, v_k, v_a, 'Pixel', g, n);
    v_sub := (j ->> 'sub')::uuid;
    if (j ->> 'confirmed')::boolean then raise exception 'a phone was active before it proved itself'; end if;
    if not public._fs_fails(format($q$select public.founder_push_subscribe(%L, %L, %L, %L, %L, 'Pixel', %L, %L)$q$, u, d, v_ep1, v_k, v_a, g, n)) then raise exception 'a grant was used twice'; end if;
    select o.id, (o.payload ->> 't') into v_out, v_tok from public.founder_push_outbox o where o.sub_id = v_sub and o.kind = 'confirm';
    if v_out is null or v_tok !~ '^[A-Za-z0-9_-]{32}$' then raise exception 'the confirm push was not queued with a 32-char token'; end if;
    if (select confirm_hash from public.founder_push_sub where id = v_sub) <> public._fh_sha(v_tok) or (select count(*) from public.founder_push_sub where confirm_hash = v_tok) <> 0 then raise exception 'only the hash of the token may be stored'; end if;
    r := r || 'subscribe (T2 bound to the endpoint, single use, shapes, token hash only) OK; ';

    -- 3) an unconfirmed phone gets no alerts; the confirm: wrong tokens count, the right one activates
    if (public.founder_push_test(u, d) ->> 'queued')::int <> 0 then raise exception 'an unconfirmed phone received a test'; end if;
    j := public.founder_push_confirm(u, d, repeat('A', 32));
    if (j ->> 'ok')::boolean or j ->> 'why' <> 'wrong_token' then raise exception 'a wrong token was accepted: %', j; end if;
    if not public._fs_fails(format($q$select public.founder_push_confirm(%L, %L, 'bad token!')$q$, u, d)) then raise exception 'a malformed token was accepted'; end if;
    j := public.founder_push_confirm(u, d, v_tok);
    if not (j ->> 'ok')::boolean then raise exception 'the right token was refused: %', j; end if;
    if (select confirm_hash from public.founder_push_sub where id = v_sub) is not null or (select confirmed_at from public.founder_push_sub where id = v_sub) is null then raise exception 'confirm left a token behind'; end if;
    if not public._fs_fails(format($q$select public.founder_push_confirm(%L, %L, %L)$q$, u, d, v_tok)) then raise exception 'a token worked twice'; end if;
    r := r || 'confirm (wrong token counted, right one single use) OK; ';

    -- 4) five wrong tokens remove an unconfirmed phone
    n := md5(random()::text);
    j := public.founder_stepup_issue(u, d, v_cred, 'flare.push', public._fh_sha(v_ep2), '{}'::jsonb, n); g := (j ->> 'grant')::uuid;
    j := public.founder_push_subscribe(u, d, v_ep2, v_k, v_a, 'Spare', g, n); v_sub2 := (j ->> 'sub')::uuid;
    for i in 1 .. 5 loop perform public.founder_push_confirm(u, d, repeat('B', 32)); end loop;
    if (select removed_reason from public.founder_push_sub where id = v_sub2) <> 'confirm_failed' then raise exception 'five wrong tokens did not remove the phone'; end if;
    r := r || '5 wrong tokens remove the phone OK; ';

    -- 5) the T3 triggers alert the confirmed phone, never carry the action, and cannot break the T3 flow
    insert into public.founder_t3_requests (user_id, device_id, action, action_hash, first_credential, ready_at, expires_at)
      values (u, d, 'key.rotate', repeat('a', 64), v_cred, now() + interval '10 minutes', now() + interval '70 minutes') returning id into v_t3;
    select o.id into v_out from public.founder_push_outbox o where o.sub_id = v_sub and o.kind = 't3_begun' and o.ref = v_t3;
    if v_out is null then raise exception 'a T3 start did not queue an alert'; end if;
    if (select urgency from public.founder_push_outbox where id = v_out) <> 'high' or (select payload::text from public.founder_push_outbox where id = v_out) like '%key.rotate%' then raise exception 'the alert must be high urgency and must not carry the action'; end if;
    update public.founder_t3_requests set state = 'cancelled', cancelled_at = now() where id = v_t3;
    if not exists (select 1 from public.founder_push_outbox where sub_id = v_sub and kind = 't3_cancelled' and ref = v_t3) then raise exception 'a T3 cancel did not queue an alert'; end if;
    r := r || 'T3 begin/cancel alerts (high urgency, no action text) OK; ';

    -- 6) the sender: claim leases, a 503 backs off, a 201 is final, a 410 removes the phone and expires its queue
    c := public.founder_push_claim(50);
    if jsonb_array_length(c -> 'rows') < 2 then raise exception 'the claim returned fewer rows than queued: %', c; end if;
    select x into p from jsonb_array_elements(c -> 'rows') x where x ->> 'id' = v_out::text;
    if p.x is null or p.x ->> 'endpoint' <> v_ep1 or (p.x ->> 'ttl')::int not between 60 and 3600 then raise exception 'the claimed row is wrong: %', p.x; end if;
    if (select state from public.founder_push_outbox where id = v_out) <> 'sending' then raise exception 'a claimed row must be leased'; end if;
    if (public.founder_push_claim(50) -> 'rows') @> jsonb_build_array(jsonb_build_object('id', v_out)) then raise exception 'a leased row was claimed twice'; end if;
    j := public.founder_push_report(v_out, 503, 5);
    if j ->> 'state' <> 'failed' or (j ->> 'wait_s')::int < 30 then raise exception 'a 503 must back off: %', j; end if;
    if (select count(*) from jsonb_array_elements(public.founder_push_claim(50) -> 'rows') x where x ->> 'id' = v_out::text) <> 0 then raise exception 'a backed-off row came back at once'; end if;
    update public.founder_push_outbox set next_at = now() where id = v_out;
    c := public.founder_push_claim(50);
    if (select count(*) from jsonb_array_elements(c -> 'rows') x where x ->> 'id' = v_out::text and (x ->> 'attempt')::int = 2) <> 1 then raise exception 'the retry is not attempt 2'; end if;
    j := public.founder_push_report(v_out, 201);
    if j ->> 'state' <> 'sent' or (select payload from public.founder_push_outbox where id = v_out) is not null or (select last_ok_at from public.founder_push_sub where id = v_sub) is null then raise exception 'a 201 must be final and clear the payload'; end if;
    if not public._fs_fails(format($q$select public.founder_push_report(%L, 201)$q$, v_out)) then raise exception 'a final row was reported again'; end if;
    perform public.founder_push_test(u, d);
    c := public.founder_push_claim(50);
    select o.id into v_out from public.founder_push_outbox o where o.sub_id = v_sub and o.kind = 'test';
    j := public.founder_push_report(v_out, 410);
    if (j ->> 'state') <> 'dead' or not (j ->> 'sub_removed')::boolean or (select removed_reason from public.founder_push_sub where id = v_sub) <> 'gone' then raise exception 'a 410 must remove the phone: %', j; end if;
    if exists (select 1 from public.founder_push_outbox where sub_id = v_sub and state in ('queued', 'failed', 'sending')) then raise exception 'a removed phone kept live alerts'; end if;
    r := r || 'claim lease, 503 backoff, retry, 201 final, 410 removes phone OK; ';

    -- 7) the owner removes a phone (T2 bound to remove); a removed phone can never come back
    n := md5(random()::text);
    j := public.founder_stepup_issue(u, d, v_cred, 'flare.push', public._fh_sha(v_ep3), '{}'::jsonb, n); g := (j ->> 'grant')::uuid;
    j := public.founder_push_subscribe(u, d, v_ep3, v_k, v_a, 'Tablet', g, n); v_sub2 := (j ->> 'sub')::uuid;
    n := md5(random()::text);
    j := public.founder_stepup_issue(u, d, v_cred, 'flare.push', public._fh_sha(v_ep3), '{"op":"remove"}'::jsonb, n); g := (j ->> 'grant')::uuid;
    if not (public.founder_push_remove(u, d, v_sub2, g, n) ->> 'removed')::boolean then raise exception 'remove failed'; end if;
    if not public._fs_fails(format($q$update public.founder_push_sub set removed_at = null, removed_reason = null where id = %L$q$, v_sub2)) then raise exception 'a removed phone came back'; end if;
    if not public._fs_fails(format($q$update public.founder_push_sub set endpoint_sha = repeat('b', 64) where id = %L$q$, v_sub2)) or not public._fs_fails(format($q$delete from public.founder_push_sub where id = %L$q$, v_sub2))
       or not public._fs_fails($q$truncate public.founder_push_sub$q$) then raise exception 'a subscription was changed or deleted'; end if;
    r := r || 'owner remove + frozen/one-way/never-deleted subscription OK; ';

    -- 8) the outbox state machine and the ledger are tamper-proof
    select o.id into v_out from public.founder_push_outbox o where o.sub_id = v_sub and kind = 't3_begun';
    if not public._fs_fails(format($q$update public.founder_push_outbox set state = 'sent', done_at = now(), payload = null where id = %L$q$, v_out)) then raise exception 'a final row was edited'; end if;
    if not public._fs_fails(format($q$delete from public.founder_push_outbox where id = %L$q$, v_out)) or not public._fs_fails($q$truncate public.founder_push_outbox$q$) then raise exception 'an outbox row was deleted'; end if;
    if not public._fs_fails($q$update public.founder_push_event set kind = 'sent'$q$) or not public._fs_fails($q$delete from public.founder_push_event$q$) or not public._fs_fails($q$truncate public.founder_push_event$q$) then raise exception 'the ledger was edited'; end if;
    if (public.founder_push_verify(100000) ->> 'ok')::boolean is not true then raise exception 'the chain must verify'; end if;
    alter table public.founder_push_event disable trigger founder_push_event_stop;
    update public.founder_push_event set facts = '{"edited":true}'::jsonb where id = (select max(id) from public.founder_push_event);
    if (public.founder_push_verify(1000) ->> 'ok')::boolean then raise exception 'verify missed an edited event'; end if;
    alter table public.founder_push_event enable trigger founder_push_event_stop;
    j := public.founder_push_status(u);
    if jsonb_typeof(j -> 'phones') <> 'array' or jsonb_array_length(j -> 'limits') < 3 then raise exception 'status shape: %', j; end if;
    r := r || 'state machine, append-only ledger, tamper detected, status OK; ';
    raise exception 'ROLLBACK_SELFTEST';
  exception when others then
    if sqlerrm <> 'ROLLBACK_SELFTEST' then raise exception 'E140 selftest FAIL: %', sqlerrm; end if;
  end;
  if (select count(*) from public.founder_push_sub) <> b_sub or (select count(*) from public.founder_push_outbox) <> b_out or (select count(*) from public.founder_push_event) <> b_ev
     or coalesce((select max(hash) from public.founder_push_event), '') <> v_head or (select count(*) from public.founder_audit) <> b_aud or (select count(*) from public.founder_passkeys) <> b_pk
     or (select count(*) from public.founder_devices) <> b_dev or (select count(*) from public.founder_stepups) <> b_step or (select count(*) from public.founder_t3_requests) <> b_t3
     or (select t2_hardware_only from public.founder_protocol where id) is distinct from b_pro then raise exception 'E140 selftest left rows behind'; end if;
  if not exists (select 1 from pg_trigger where tgrelid = 'public.founder_push_event'::regclass and tgname = 'founder_push_event_stop' and tgenabled = 'O') then raise exception 'E140 selftest left a trigger disabled'; end if;
  return 'E140 selftest OK — ' || r || 'rollback clean';
end $$;
revoke all on function public.founder_push_e140_selftest() from public, anon, authenticated;
grant execute on function public.founder_push_e140_selftest() to service_role;
do $$ begin raise notice '%', public.founder_push_e140_selftest(); end $$;

-- RUNBOOK: bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E140_founder_flare_push CHECK_E140  (after fetch). Needs E102 + E113 + E117 + E118 + E139.
-- Undo: drop trigger founder_push_t3_alert on founder_t3_requests; drop the founder_push_* tables and _fh_* helpers; delete the registry row 'flare.push' (E118/E139 are untouched).
