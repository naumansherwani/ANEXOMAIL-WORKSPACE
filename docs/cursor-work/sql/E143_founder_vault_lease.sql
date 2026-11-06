-- E143 v2 — Founder J8: DEAD-MAN VAULT LEASE, built as a tamper-evident, race-safe, self-auditing SQL core (founder 6 Nov 2026 21:51 PKT: "super advance sql, duniya ka super advance sql").
-- Idea: a device's local vault key works only while the device holds a SHORT server-signed lease (default 15 min, 60 s..60 min). The server renews it ONLY while the device is approved and not revoked.
--   Revoke a device (or lose it) = the lease is never renewed = the vault locks itself when the lease ends, even if the thief keeps the phone offline. No operator, no NIDD (research: CELLULAR-CORE-J7-J9-RESEARCH-03NOV.md, J8).
-- What this file builds (Rust signer J8b, kernel verify J8c and UI J8d come after):
--   1) founder_vault_lease        one row per device. CHECK ties expires = issued + ttl while live; a revoked lease is cut to <= revoked_ms. Guard trigger: serial only goes up, a revoked lease can NEVER be extended or renewed, no delete, no truncate.
--                                 The random nonce is returned ONCE to the signer; SQL keeps only sha256(nonce) (replay token for the signature, never readable).
--   2) founder_vault_lease_event  append-only ledger with TWO hash chains in one row: a GLOBAL chain (all devices) and a PER-DEVICE chain (one device's history can be exported and verified alone).
--                                 Kinds: issued / refused / revoked / expired / panic. Unique index (device, serial) per `issued` and per `expired` = a serial is issued once and expires once. Gapless: issued serial n needs issued n-1 first.
--   3) founder_vault_lease_issue  the only way to get a lease. Per-device advisory lock; checks owner, approved, not revoked; CLOCK-BACKWARDS guard (never issues if the clock is behind the last lease);
--                                 RATE LIMITS (min gap between renewals, max per rolling hour; both tunable with GUCs anexo.vl_min_gap_ms / anexo.vl_max_per_hour); refusals are de-duplicated (one per device per 60 s) so a flood cannot bloat the ledger.
--   4) revoke trigger on founder_devices: the moment revoked_at is set the lease is cut to NOW, a `revoked` event is chained AND the same fact goes into the main founder audit chain (best effort, flagged if it fails; the cut itself never fails).
--   5) founder_vault_lease_panic  panic lock: revoke every other approved device in one transaction (keep one), one `panic` event, one audit entry.
--   6) founder_vault_lease_sweep  logs each lease that ran out by itself ONCE (`expired`): "this phone locked itself at ...". Meant for the Rust tick.
--   7) founder_vault_lease_status / _verify / _device_verify  per-device live|expired|revoked|none, seconds left, chain heads; global chain + per-device chains + serial gaps re-check; one device's portable chain proof.
--   8) view founder_vault_lease_live (security_invoker), CHECK_E143.sql, selftest (rolls back).
-- Needs E102 (founder_devices, founder_audit_append) and E140 (_fh_now_ms). Safe to run again; the old v1 shape is upgraded in place.

do $$ begin
  if to_regclass('public.founder_devices') is null or to_regprocedure('public._fh_now_ms()') is null then raise exception 'E143 needs E102 and E140 first'; end if;
end $$;

-- 1) tables ----------------------------------------------------------------------------------------------------------------------------------------
do $$ begin
  perform pg_advisory_xact_lock(hashtextextended('founder_vault_lease:ddl', 0));
  create table if not exists public.founder_vault_lease (
    device_id   uuid primary key references public.founder_devices(id),
    user_id     uuid    not null,
    serial      bigint  not null check (serial >= 1),
    issued_ms   bigint  not null check (issued_ms > 0),
    expires_ms  bigint  not null,
    ttl_s       integer not null check (ttl_s between 60 and 3600),
    nonce_hash  text    check (nonce_hash ~ '^[0-9a-f]{64}$'),
    revoked_ms  bigint,
    constraint founder_vault_lease_live_shape  check (revoked_ms is not null or expires_ms = issued_ms + ttl_s * 1000::bigint),
    constraint founder_vault_lease_cut_shape   check (revoked_ms is null or expires_ms <= revoked_ms)
  );
  alter table public.founder_vault_lease add column if not exists nonce_hash text;
  if not exists (select 1 from pg_constraint where conname = 'founder_vault_lease_nonce_shape') then
    alter table public.founder_vault_lease add constraint founder_vault_lease_nonce_shape check (nonce_hash is null or nonce_hash ~ '^[0-9a-f]{64}$');
  end if;
  -- upgrade from v1 (table already there, so CREATE TABLE skipped its named shape rules): add them now
  if not exists (select 1 from pg_constraint where conrelid = 'public.founder_vault_lease'::regclass and conname = 'founder_vault_lease_live_shape') then
    alter table public.founder_vault_lease add constraint founder_vault_lease_live_shape check (revoked_ms is not null or expires_ms = issued_ms + ttl_s * 1000::bigint);
  end if;
  if not exists (select 1 from pg_constraint where conrelid = 'public.founder_vault_lease'::regclass and conname = 'founder_vault_lease_cut_shape') then
    alter table public.founder_vault_lease add constraint founder_vault_lease_cut_shape check (revoked_ms is null or expires_ms <= revoked_ms);
  end if;
  -- the two loose v1 rules (expires > issued, unnamed) are replaced by the exact shape rules above
  alter table public.founder_vault_lease drop constraint if exists founder_vault_lease_check;
  alter table public.founder_vault_lease drop constraint if exists founder_vault_lease_check1;
  create table if not exists public.founder_vault_lease_event (
    id            bigint generated always as identity primary key,
    ts_ms         bigint not null check (ts_ms > 0),
    user_id       uuid   not null,                                          -- no foreign keys: deleting an account or device must never rewrite or block a ledger
    device_id     uuid   not null,
    serial        bigint,
    kind          text   not null check (kind in ('issued', 'refused', 'revoked', 'expired', 'panic')),
    facts         jsonb  not null default '{}'::jsonb check (jsonb_typeof(facts) = 'object' and octet_length(facts::text) <= 1000),
    dev_prev_hash text   not null default repeat('0', 64) check (dev_prev_hash ~ '^[0-9a-f]{64}$'),
    prev_hash     text   not null check (prev_hash ~ '^[0-9a-f]{64}$'),
    hash          text   not null unique check (hash ~ '^[0-9a-f]{64}$')
  );
  alter table public.founder_vault_lease_event add column if not exists serial bigint;
  alter table public.founder_vault_lease_event add column if not exists dev_prev_hash text not null default repeat('0', 64);
  alter table public.founder_vault_lease_event drop constraint if exists founder_vault_lease_event_kind_check;
  alter table public.founder_vault_lease_event add constraint founder_vault_lease_event_kind_check check (kind in ('issued', 'refused', 'revoked', 'expired', 'panic'));
  create index if not exists founder_vault_lease_event_dev on public.founder_vault_lease_event (device_id, id desc);
  create unique index if not exists founder_vault_lease_event_once on public.founder_vault_lease_event (device_id, serial, kind) where kind in ('issued', 'expired');
  create index if not exists founder_vault_lease_event_ts on public.founder_vault_lease_event using brin (ts_ms);
  alter table public.founder_vault_lease enable row level security;
  alter table public.founder_vault_lease_event enable row level security;
  revoke all on public.founder_vault_lease, public.founder_vault_lease_event from public, anon, authenticated, service_role;
  grant select on public.founder_vault_lease_event to service_role;
  -- E144 narrows the lease table to named columns (the shred nonce is never readable); a re-run of E143 must not undo that
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'founder_vault_lease' and column_name = 'shred_nonce') then
    grant select on public.founder_vault_lease to service_role;
  end if;
end $$;

-- 2) guards ----------------------------------------------------------------------------------------------------------------------------------------
create or replace function public._fh_vl_stop() returns trigger language plpgsql as $$ begin raise exception 'E143: the lease ledger is append-only / never deleted' using errcode = '42501'; end $$;
create or replace function public._fh_vl_guard() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if tg_op = 'DELETE' then raise exception 'E143: a lease row is never deleted' using errcode = '42501'; end if;
  if new.device_id <> old.device_id or new.user_id <> old.user_id then raise exception 'E143: a lease belongs to one device for ever' using errcode = '42501'; end if;
  if new.serial < old.serial then raise exception 'E143: the lease serial only goes up' using errcode = '42501'; end if;
  if old.revoked_ms is not null and (new.revoked_ms is distinct from old.revoked_ms or new.expires_ms > old.expires_ms or new.serial <> old.serial or new.issued_ms <> old.issued_ms) then
    raise exception 'E143: a revoked device can never get its lease back' using errcode = '42501'; end if;
  -- E144 rules, written with to_jsonb so they are no-ops until the E144 columns exist (a re-run of E143 must never weaken the guard)
  if to_jsonb(old) ->> 'key_thumb' is not null and to_jsonb(new) ->> 'key_thumb' is distinct from to_jsonb(old) ->> 'key_thumb' then raise exception 'E144: the device key is bound once and never changes' using errcode = '42501'; end if;
  if to_jsonb(old) ->> 'shred_nonce' is null and to_jsonb(new) ->> 'shred_nonce' is not null and to_jsonb(old) ->> 'shredded_ms' is not null then raise exception 'E144: a shredded nonce never comes back' using errcode = '42501'; end if;
  if to_jsonb(old) ->> 'shred_nonce' is not null and to_jsonb(new) ->> 'shred_nonce' is not null and to_jsonb(new) ->> 'shred_nonce' <> to_jsonb(old) ->> 'shred_nonce' then raise exception 'E144: the shred nonce never changes (the half must stay derivable)' using errcode = '42501'; end if;
  if to_jsonb(old) ->> 'last_proof_ms' is not null and to_jsonb(new) ->> 'last_proof_ms' is not null and (to_jsonb(new) ->> 'last_proof_ms')::bigint < (to_jsonb(old) ->> 'last_proof_ms')::bigint then raise exception 'E144: proof time only goes up' using errcode = '42501'; end if;
  return new;
end $$;
drop trigger if exists founder_vault_lease_guard on public.founder_vault_lease;
create trigger founder_vault_lease_guard before update or delete on public.founder_vault_lease for each row execute function public._fh_vl_guard();
drop trigger if exists founder_vault_lease_trunc on public.founder_vault_lease;
create trigger founder_vault_lease_trunc before truncate on public.founder_vault_lease for each statement execute function public._fh_vl_stop();

create or replace function public._fh_vl_hash(p_prev text, p_dev_prev text, p_ts bigint, p_uid uuid, p_dev uuid, p_serial bigint, p_kind text, p_facts jsonb) returns text
language sql immutable set search_path = pg_catalog, public, extensions as $$
  select encode(extensions.digest(convert_to(p_prev || '|' || p_dev_prev || '|' || p_ts || '|' || p_uid::text || '|' || p_dev::text || '|' || coalesce(p_serial::text, '-') || '|' || p_kind || '|' || p_facts::text, 'UTF8'), 'sha256'), 'hex')
$$;
create or replace function public._fh_vl_event_guard() returns trigger language plpgsql set search_path = pg_catalog, public, extensions as $$
declare p public.founder_vault_lease_event%rowtype; d public.founder_vault_lease_event%rowtype; v_last bigint;
begin
  perform pg_advisory_xact_lock(hashtextextended('founder_vault_lease:chain', 0));
  if new.kind = 'issued' then                                   -- the ledger and the lease row must agree, and serials are gapless
    if new.serial is null or not exists (select 1 from public.founder_vault_lease where device_id = new.device_id and serial = new.serial) then
      raise exception 'E143: an issued event must match the lease row serial' using errcode = '23514'; end if;
    select max(serial) into v_last from public.founder_vault_lease_event where device_id = new.device_id and kind = 'issued';
    if new.serial <> coalesce(v_last, 0) + 1 then raise exception 'E143: lease serials are gapless (expected %, got %)', coalesce(v_last, 0) + 1, new.serial using errcode = '23514'; end if;
  end if;
  select * into p from public.founder_vault_lease_event order by id desc limit 1;
  select * into d from public.founder_vault_lease_event where device_id = new.device_id order by id desc limit 1;
  new.ts_ms         := greatest(public._fh_now_ms(), coalesce(p.ts_ms, 0));      -- the ledger clock never runs backwards
  new.prev_hash     := coalesce(p.hash, repeat('0', 64));
  new.dev_prev_hash := coalesce(d.hash, repeat('0', 64));
  new.hash          := public._fh_vl_hash(new.prev_hash, new.dev_prev_hash, new.ts_ms, new.user_id, new.device_id, new.serial, new.kind, new.facts);
  return new;
end $$;
drop trigger if exists founder_vault_lease_event_guard on public.founder_vault_lease_event;
create trigger founder_vault_lease_event_guard before insert on public.founder_vault_lease_event for each row execute function public._fh_vl_event_guard();
drop trigger if exists founder_vault_lease_event_stop on public.founder_vault_lease_event;
create trigger founder_vault_lease_event_stop before update or delete on public.founder_vault_lease_event for each row execute function public._fh_vl_stop();
drop trigger if exists founder_vault_lease_event_trunc on public.founder_vault_lease_event;
create trigger founder_vault_lease_event_trunc before truncate on public.founder_vault_lease_event for each statement execute function public._fh_vl_stop();

create or replace function public._fh_vl_log(p_uid uuid, p_dev uuid, p_serial bigint, p_kind text, p_facts jsonb) returns void
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
begin
  insert into public.founder_vault_lease_event (ts_ms, user_id, device_id, serial, kind, facts, prev_hash, hash)
  values (1, p_uid, p_dev, p_serial, p_kind, coalesce(p_facts, '{}'::jsonb), repeat('0', 64), repeat('0', 64));
end $$;

-- the same fact into the MAIN founder audit chain (Merkle-sealed there); best effort: a failure is flagged, never blocks a lock
create or replace function public._fh_vl_audit(p_uid uuid, p_action text, p_target text, p_reason text, p_meta jsonb) returns boolean
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
begin
  if to_regprocedure('public.founder_audit_append(uuid,text,text,text,jsonb)') is null then return false; end if;
  perform public.founder_audit_append(p_uid, p_action, p_target, p_reason, p_meta);
  return true;
exception when others then return false;
end $$;

-- tunables with safe defaults (GUC anexo.vl_*), clamped
create or replace function public._fh_vl_cfg(p_name text, p_default bigint, p_lo bigint, p_hi bigint) returns bigint
language sql stable set search_path = pg_catalog, public as $$
  select least(greatest(coalesce(nullif(current_setting('anexo.' || p_name, true), '')::bigint, p_default), p_lo), p_hi)
$$;

-- 3) issue / renew ---------------------------------------------------------------------------------------------------------------------------------
create or replace function public.founder_vault_lease_issue(p_uid uuid, p_device uuid, p_ttl_s integer default 900) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare d public.founder_devices%rowtype; l public.founder_vault_lease%rowtype; v_now bigint := public._fh_now_ms(); v_ttl integer := least(greatest(coalesce(p_ttl_s, 900), 60), 3600);
        v_why text; v_nonce text; v_gap bigint := public._fh_vl_cfg('vl_min_gap_ms', 5000, 0, 600000); v_max bigint := public._fh_vl_cfg('vl_max_per_hour', 240, 1, 100000);
begin
  perform pg_advisory_xact_lock(hashtextextended('founder_vault_lease:' || p_device::text, 0));
  select * into d from public.founder_devices where id = p_device;
  v_why := case when not found then 'unknown_device' when d.user_id <> p_uid then 'not_your_device' when d.revoked_at is not null then 'revoked' when d.approved_at is null then 'not_approved' end;
  if v_why is null then
    select * into l from public.founder_vault_lease where device_id = p_device for update;
    if found then
      v_why := case when v_now < l.issued_ms then 'clock_back'
                    when v_now - l.issued_ms < v_gap then 'too_fast'
                    when (select count(*) from public.founder_vault_lease_event e where e.device_id = p_device and e.kind = 'issued' and e.ts_ms > v_now - 3600000) >= v_max then 'too_many' end;
    end if;
  end if;
  if v_why is not null then                                          -- one refusal per device per 60 s in the ledger: a flood cannot bloat it
    if d.id is not null and d.user_id = p_uid and not exists (select 1 from public.founder_vault_lease_event e where e.device_id = p_device and e.kind = 'refused' and e.facts ->> 'why' = v_why and e.ts_ms > v_now - 60000) then
      perform public._fh_vl_log(p_uid, p_device, null, 'refused', jsonb_build_object('why', v_why)); end if;
    return jsonb_build_object('ok', false, 'why', v_why);
  end if;
  v_nonce := encode(extensions.gen_random_bytes(16), 'hex');
  if l.device_id is null then
    insert into public.founder_vault_lease (device_id, user_id, serial, issued_ms, expires_ms, ttl_s, nonce_hash) values (p_device, p_uid, 1, v_now, v_now + v_ttl * 1000::bigint, v_ttl, encode(extensions.digest(v_nonce, 'sha256'), 'hex')) returning * into l;
  else
    update public.founder_vault_lease set serial = l.serial + 1, issued_ms = v_now, expires_ms = v_now + v_ttl * 1000::bigint, ttl_s = v_ttl, nonce_hash = encode(extensions.digest(v_nonce, 'sha256'), 'hex') where device_id = p_device returning * into l;
  end if;
  perform public._fh_vl_log(p_uid, p_device, l.serial, 'issued', jsonb_build_object('ttl_s', v_ttl));
  return jsonb_build_object('ok', true, 'device_id', p_device, 'serial', l.serial, 'issued_ms', l.issued_ms, 'expires_ms', l.expires_ms, 'ttl_s', l.ttl_s, 'nonce', v_nonce);
end $$;

-- 4) revoke cuts the lease at once --------------------------------------------------------------------------------------------------------------------
create or replace function public._fh_vl_on_revoke() returns trigger language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_now bigint := public._fh_now_ms(); l public.founder_vault_lease%rowtype; v_ok boolean;
begin
  if old.revoked_at is null and new.revoked_at is not null then
    perform pg_advisory_xact_lock(hashtextextended('founder_vault_lease:' || new.id::text, 0));
    if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'founder_vault_lease' and column_name = 'shred_nonce') then
      -- E144 is installed: revoking also destroys the key-half nonce (one statement, so the E144 shape rule holds)
      execute 'update public.founder_vault_lease set revoked_ms = $1, expires_ms = least(expires_ms, $1), shred_nonce = null, shredded_ms = $1 where device_id = $2 and revoked_ms is null returning *' into l using v_now, new.id;
    else
      update public.founder_vault_lease set revoked_ms = v_now, expires_ms = least(expires_ms, v_now) where device_id = new.id and revoked_ms is null returning * into l;
    end if;
    v_ok := public._fh_vl_audit(new.user_id, 'device.vault_lease_cut', new.id::text, 'Device revoked: its vault lease was cut at once', jsonb_build_object('had_lease', l.device_id is not null, 'serial', l.serial, 'label', new.label));
    perform public._fh_vl_log(new.user_id, new.id, l.serial, 'revoked', jsonb_build_object('had_lease', l.device_id is not null, 'cut_at_ms', v_now, 'audited', v_ok));
  end if;
  return new;
end $$;
drop trigger if exists founder_devices_vault_lease_revoke on public.founder_devices;
create trigger founder_devices_vault_lease_revoke after update of revoked_at on public.founder_devices for each row execute function public._fh_vl_on_revoke();

-- 5) panic lock: every other approved device, one transaction -----------------------------------------------------------------------------------------
create or replace function public.founder_vault_lease_panic(p_uid uuid, p_keep uuid default null) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_n integer; v_ids uuid[];
begin
  if not exists (select 1 from public.founder_accounts where user_id = p_uid) then raise exception 'E143: not a founder' using errcode = '42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended('founder_vault_lease:panic:' || p_uid::text, 0));
  with u as (update public.founder_devices set revoked_at = now() where user_id = p_uid and approved_at is not null and revoked_at is null and id is distinct from p_keep returning id)
  select count(*), coalesce(array_agg(id), '{}') into v_n, v_ids from u;
  perform public._fh_vl_log(p_uid, coalesce(p_keep, p_uid), null, 'panic', jsonb_build_object('locked', v_n, 'kept', p_keep));
  perform public._fh_vl_audit(p_uid, 'vault.panic_lock', coalesce(p_keep::text, 'none'), 'Panic lock: all other devices revoked, their vault leases cut', jsonb_build_object('locked', v_n));
  return jsonb_build_object('ok', true, 'locked', v_n, 'device_ids', to_jsonb(v_ids));
end $$;

-- 6) sweep: leases that ran out on their own are logged once ------------------------------------------------------------------------------------------
create or replace function public.founder_vault_lease_sweep() returns integer
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare r record; v_n integer := 0; v_now bigint := public._fh_now_ms();
begin
  for r in select l.device_id, l.user_id, l.serial, l.expires_ms from public.founder_vault_lease l
           where l.revoked_ms is null and l.expires_ms <= v_now
             and not exists (select 1 from public.founder_vault_lease_event e where e.device_id = l.device_id and e.serial = l.serial and e.kind = 'expired') order by l.expires_ms limit 500 loop
    perform pg_advisory_xact_lock(hashtextextended('founder_vault_lease:' || r.device_id::text, 0));
    begin
      perform public._fh_vl_log(r.user_id, r.device_id, r.serial, 'expired', jsonb_build_object('expired_ms', r.expires_ms, 'noticed_ms', v_now));
      v_n := v_n + 1;
    exception when unique_violation then null; end;
  end loop;
  return v_n;
end $$;

-- 7) status + chain checks ----------------------------------------------------------------------------------------------------------------------------
create or replace function public.founder_vault_lease_status(p_uid uuid) returns jsonb
language sql stable security definer set search_path = pg_catalog, public, extensions as $$
  with n as (select public._fh_now_ms() ms)
  select jsonb_build_object('now_ms', (select ms from n), 'devices', coalesce(jsonb_agg(jsonb_build_object(
    'device_id', d.id, 'label', d.label, 'serial', l.serial, 'expires_ms', l.expires_ms,
    'state', case when d.revoked_at is not null then 'revoked' when l.device_id is null then 'none' when l.expires_ms > (select ms from n) then 'live' else 'expired' end,
    'seconds_left', case when l.device_id is null or d.revoked_at is not null then 0 else greatest(0, (l.expires_ms - (select ms from n)) / 1000) end,
    'issued_last_hour', (select count(*) from public.founder_vault_lease_event e where e.device_id = d.id and e.kind = 'issued' and e.ts_ms > (select ms from n) - 3600000),
    'chain_head', (select e.hash from public.founder_vault_lease_event e where e.device_id = d.id order by e.id desc limit 1)) order by d.created_at), '[]'::jsonb))
  from public.founder_devices d left join public.founder_vault_lease l on l.device_id = d.id where d.user_id = p_uid and d.approved_at is not null
$$;

create or replace function public.founder_vault_lease_verify(p_limit integer default 1000) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare r public.founder_vault_lease_event%rowtype; v_prev text; v_n integer := 0; v_bad bigint; v_first bigint; v_gap record; v_dev_bad bigint;
begin
  select min(id) into v_first from (select id from public.founder_vault_lease_event order by id desc limit greatest(p_limit, 1)) s;
  if v_first is null then return jsonb_build_object('ok', true, 'checked', 0); end if;
  select hash into v_prev from public.founder_vault_lease_event where id < v_first order by id desc limit 1;
  v_prev := coalesce(v_prev, repeat('0', 64));
  for r in select * from public.founder_vault_lease_event where id >= v_first order by id loop
    if r.prev_hash <> v_prev or r.hash <> public._fh_vl_hash(r.prev_hash, r.dev_prev_hash, r.ts_ms, r.user_id, r.device_id, r.serial, r.kind, r.facts) then v_bad := r.id; exit; end if;
    v_prev := r.hash; v_n := v_n + 1;
  end loop;
  select e.id into v_dev_bad from public.founder_vault_lease_event e where e.id >= v_first
    and e.dev_prev_hash is distinct from coalesce((select x.hash from public.founder_vault_lease_event x where x.device_id = e.device_id and x.id < e.id order by x.id desc limit 1), repeat('0', 64)) order by e.id limit 1;
  select e.device_id, e.serial into v_gap from public.founder_vault_lease_event e where e.kind = 'issued' and e.serial > 1
    and not exists (select 1 from public.founder_vault_lease_event p where p.device_id = e.device_id and p.kind = 'issued' and p.serial = e.serial - 1) limit 1;
  return jsonb_build_object('ok', v_bad is null and v_dev_bad is null and v_gap.device_id is null, 'checked', v_n, 'broken_at', v_bad, 'device_chain_broken_at', v_dev_bad, 'serial_gap_device', v_gap.device_id);
end $$;

create or replace function public.founder_vault_lease_device_verify(p_device uuid) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare r public.founder_vault_lease_event%rowtype; v_prev text := repeat('0', 64); v_n integer := 0; v_bad bigint;
begin
  for r in select * from public.founder_vault_lease_event where device_id = p_device order by id loop
    if r.dev_prev_hash <> v_prev or r.hash <> public._fh_vl_hash(r.prev_hash, r.dev_prev_hash, r.ts_ms, r.user_id, r.device_id, r.serial, r.kind, r.facts) then v_bad := r.id; exit; end if;
    v_prev := r.hash; v_n := v_n + 1;
  end loop;
  return jsonb_build_object('ok', v_bad is null, 'events', v_n, 'broken_at', v_bad, 'head', case when v_n > 0 then v_prev end);
end $$;

create or replace view public.founder_vault_lease_live with (security_invoker = true) as
  select l.device_id, l.user_id, l.serial, l.ttl_s, l.issued_ms, l.expires_ms, l.revoked_ms,
         case when l.revoked_ms is not null then 'revoked' when l.expires_ms > public._fh_now_ms() then 'live' else 'expired' end as state
  from public.founder_vault_lease l;
revoke all on public.founder_vault_lease_live from public, anon, authenticated, service_role;
grant select on public.founder_vault_lease_live to service_role;

revoke all on function public.founder_vault_lease_issue(uuid, uuid, integer), public.founder_vault_lease_panic(uuid, uuid), public.founder_vault_lease_sweep(),
  public.founder_vault_lease_status(uuid), public.founder_vault_lease_verify(integer), public.founder_vault_lease_device_verify(uuid),
  public._fh_vl_log(uuid, uuid, bigint, text, jsonb), public._fh_vl_audit(uuid, text, text, text, jsonb) from public, anon, authenticated;
drop function if exists public._fh_vl_log(uuid, uuid, text, jsonb);
grant execute on function public.founder_vault_lease_panic(uuid, uuid), public.founder_vault_lease_sweep(),
  public.founder_vault_lease_status(uuid), public.founder_vault_lease_verify(integer), public.founder_vault_lease_device_verify(uuid) to service_role;
-- the issue core is open to service_role only until E144 exists; after that ONLY founder_vault_lease_grant (device proof) may reach it, so a re-run of E143 never reopens the bypass
do $$ begin
  if to_regprocedure('public.founder_vault_lease_grant(uuid,uuid,text,bigint,integer)') is null then
    grant execute on function public.founder_vault_lease_issue(uuid, uuid, integer) to service_role;
  end if;
end $$;

-- 8) selftest (everything rolls back) ----------------------------------------------------------------------------------------------------------------------
create or replace function public.founder_vault_lease_selftest() returns text language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_uid uuid; v_dev uuid := gen_random_uuid(); v_w uuid := gen_random_uuid(); v_d2 uuid := gen_random_uuid(); v_d3 uuid := gen_random_uuid(); r text := ''; a jsonb; b jsonb; v_ok boolean; v_n integer; v_audit bigint;
begin
  select user_id into v_uid from public.founder_accounts limit 1;
  if v_uid is null then return 'E143 selftest SKIP: founder_accounts is empty'; end if;
  begin
    perform set_config('anexo.vl_min_gap_ms', '0', true);
    insert into public.founder_devices (id, user_id, label, ua_hash, approved_at) values (v_dev, v_uid, 'e143 test', repeat('a', 64), now()), (v_d2, v_uid, 'e143 two', repeat('c', 64), now()), (v_d3, v_uid, 'e143 three', repeat('d', 64), now());
    insert into public.founder_devices (id, user_id, label, ua_hash) values (v_w, v_uid, 'e143 waiting', repeat('b', 64));
    -- issue, renew, ttl clamp, nonce shown once and stored only as a hash
    a := public.founder_vault_lease_issue(v_uid, v_dev, 900);
    if not (a ->> 'ok')::boolean or (a ->> 'serial')::bigint <> 1 or (a ->> 'expires_ms')::bigint - (a ->> 'issued_ms')::bigint <> 900000 or length(a ->> 'nonce') <> 32 then raise exception 'first lease wrong: %', a; end if;
    if (select nonce_hash from public.founder_vault_lease where device_id = v_dev) <> encode(extensions.digest(a ->> 'nonce', 'sha256'), 'hex') then raise exception 'nonce hash not stored'; end if;
    if (select count(*) from public.founder_vault_lease l where l::text like '%' || (a ->> 'nonce') || '%') <> 0 then raise exception 'raw nonce stored'; end if;
    b := public.founder_vault_lease_issue(v_uid, v_dev, 99999); if (b ->> 'serial')::bigint <> 2 or (b ->> 'ttl_s')::int <> 3600 or b ->> 'nonce' = a ->> 'nonce' then raise exception 'renew / ttl cap / fresh nonce wrong: %', b; end if;
    b := public.founder_vault_lease_issue(v_uid, v_dev, 1); if (b ->> 'ttl_s')::int <> 60 then raise exception 'ttl floor wrong'; end if;
    r := r || 'issue + renew + ttl 60..3600 + nonce hash-only OK; ';
    -- refusals
    if (public.founder_vault_lease_issue(v_uid, v_w) ->> 'why') <> 'not_approved' then raise exception 'unapproved device got a lease'; end if;
    if (public.founder_vault_lease_issue(gen_random_uuid(), v_dev) ->> 'why') <> 'not_your_device' then raise exception 'foreign user got a lease'; end if;
    if (public.founder_vault_lease_issue(v_uid, gen_random_uuid()) ->> 'why') <> 'unknown_device' then raise exception 'unknown device got a lease'; end if;
    select count(*) into v_n from public.founder_vault_lease_event where device_id = v_w and kind = 'refused';
    perform public.founder_vault_lease_issue(v_uid, v_w); perform public.founder_vault_lease_issue(v_uid, v_w);
    if (select count(*) from public.founder_vault_lease_event where device_id = v_w and kind = 'refused') <> v_n then raise exception 'refusal flood not de-duplicated'; end if;
    r := r || 'refusals + flood de-duplication OK; ';
    -- rate limits and clock-backwards
    perform set_config('anexo.vl_min_gap_ms', '600000', true);
    if (public.founder_vault_lease_issue(v_uid, v_dev) ->> 'why') <> 'too_fast' then raise exception 'min gap not enforced'; end if;
    perform set_config('anexo.vl_min_gap_ms', '0', true); perform set_config('anexo.vl_max_per_hour', '1', true);
    if (public.founder_vault_lease_issue(v_uid, v_dev) ->> 'why') <> 'too_many' then raise exception 'hourly cap not enforced'; end if;
    perform set_config('anexo.vl_max_per_hour', '240', true);
    update public.founder_vault_lease set issued_ms = issued_ms + 10000000, expires_ms = expires_ms + 10000000 where device_id = v_dev;
    if (public.founder_vault_lease_issue(v_uid, v_dev) ->> 'why') <> 'clock_back' then raise exception 'clock-backwards not caught'; end if;
    update public.founder_vault_lease set issued_ms = issued_ms - 10000000, expires_ms = expires_ms - 10000000 where device_id = v_dev;
    r := r || 'too_fast / too_many / clock_back OK; ';
    -- guards: serial never down, no delete, gapless ledger, ledger matches the lease row
    v_ok := false; begin update public.founder_vault_lease set serial = 1 where device_id = v_dev; exception when others then v_ok := true; end; if not v_ok then raise exception 'serial went down'; end if;
    v_ok := false; begin delete from public.founder_vault_lease where device_id = v_dev; exception when others then v_ok := true; end; if not v_ok then raise exception 'lease delete allowed'; end if;
    v_ok := false; begin perform public._fh_vl_log(v_uid, v_dev, 99, 'issued', '{}'); exception when others then v_ok := true; end; if not v_ok then raise exception 'ledger accepted a serial gap'; end if;
    v_ok := false; begin perform public._fh_vl_log(v_uid, v_dev, 3, 'issued', '{}'); exception when others then v_ok := true; end; if not v_ok then raise exception 'ledger accepted a duplicate serial'; end if;
    r := r || 'serial/ delete/ gapless guards OK; ';
    -- sweep: a lease that ran out is logged once
    update public.founder_vault_lease set issued_ms = issued_ms - 7200000, expires_ms = expires_ms - 7200000 where device_id = v_d2;
    perform public.founder_vault_lease_issue(v_uid, v_d2);
    update public.founder_vault_lease set issued_ms = issued_ms - 7200000, expires_ms = expires_ms - 7200000 where device_id = v_d2;
    if public.founder_vault_lease_sweep() < 1 or public.founder_vault_lease_sweep() <> 0 then raise exception 'sweep not once'; end if;
    if (select count(*) from public.founder_vault_lease_event where device_id = v_d2 and kind = 'expired') <> 1 then raise exception 'expired not logged exactly once'; end if;
    if (select state from public.founder_vault_lease_live where device_id = v_d2) <> 'expired' then raise exception 'live view not expired'; end if;
    r := r || 'sweep once OK; ';
    -- revoke: cut at once, audited, never comes back
    select count(*) into v_audit from public.founder_audit;
    update public.founder_devices set revoked_at = now() where id = v_dev;
    if (select expires_ms from public.founder_vault_lease where device_id = v_dev) > public._fh_now_ms() or (select revoked_ms from public.founder_vault_lease where device_id = v_dev) is null then raise exception 'revoke did not cut the lease'; end if;
    if to_regclass('public.founder_audit') is not null and (select count(*) from public.founder_audit) <= v_audit then raise exception 'revoke not in the main audit chain'; end if;
    if (public.founder_vault_lease_issue(v_uid, v_dev) ->> 'why') <> 'revoked' then raise exception 'revoked device got a lease'; end if;
    v_ok := false; begin update public.founder_vault_lease set expires_ms = expires_ms + 600000 where device_id = v_dev; exception when others then v_ok := true; end; if not v_ok then raise exception 'a revoked lease was extended'; end if;
    r := r || 'revoke cut + audited + never back OK; ';
    -- panic: keep one, lock the rest
    perform public.founder_vault_lease_issue(v_uid, v_d3);
    a := public.founder_vault_lease_panic(v_uid, v_d3);
    if (a ->> 'locked')::int < 1 or (select revoked_at from public.founder_devices where id = v_d2) is null or (select revoked_at from public.founder_devices where id = v_d3) is not null then raise exception 'panic wrong: %', a; end if;
    if (public.founder_vault_lease_issue(v_uid, v_d3) ->> 'ok')::boolean is not true then raise exception 'kept device lost its lease'; end if;
    r := r || 'panic keeps one OK; ';
    -- chains: global + per device + tamper caught + append-only
    if public.founder_vault_lease_verify(100000) ->> 'ok' <> 'true' or public.founder_vault_lease_device_verify(v_dev) ->> 'ok' <> 'true' then raise exception 'clean chains failed verify: %', public.founder_vault_lease_verify(100000); end if;
    v_ok := false; begin update public.founder_vault_lease_event set facts = '{}'::jsonb where device_id = v_dev; exception when others then v_ok := true; end; if not v_ok then raise exception 'ledger update allowed'; end if;
    v_ok := false; begin truncate public.founder_vault_lease_event; exception when others then v_ok := true; end; if not v_ok then raise exception 'ledger truncate allowed'; end if;
    alter table public.founder_vault_lease_event disable trigger founder_vault_lease_event_stop;
    update public.founder_vault_lease_event set facts = '{"x":1}'::jsonb where id = (select max(id) from public.founder_vault_lease_event where device_id = v_dev);
    alter table public.founder_vault_lease_event enable trigger founder_vault_lease_event_stop;
    if public.founder_vault_lease_verify(100000) ->> 'ok' <> 'false' or public.founder_vault_lease_device_verify(v_dev) ->> 'ok' <> 'false' then raise exception 'tampered chain not caught'; end if;
    r := r || 'global + per-device chains, tamper caught, append-only OK';
    raise exception 'E143_ROLLBACK:%', r;
  exception when others then
    if sqlerrm like 'E143_ROLLBACK:%' then return 'E143 selftest PASS: ' || substr(sqlerrm, 15); end if;
    return 'E143 selftest FAIL: ' || sqlerrm;
  end;
end $$;
revoke all on function public.founder_vault_lease_selftest() from public, anon, authenticated;
grant execute on function public.founder_vault_lease_selftest() to service_role;
select public.founder_vault_lease_selftest();
