-- E143 — Founder J8: DEAD-MAN VAULT LEASE (founder "go" 6 Nov 2026 21:46 PKT; research: docs/claude/CELLULAR-CORE-J7-J9-RESEARCH-03NOV.md, J8).
-- Idea: a device's local vault key works only while it holds a SHORT server-signed lease (default 15 min, never over 60). The server renews it ONLY while the device is approved and not revoked.
--   Revoke a device (or lose it) = the lease is never renewed = the vault locks itself when the lease ends, even if the thief keeps the phone offline. No operator, no NIDD.
-- This file is the SQL brain (E-number order, Rust signer + kernel verify + UI follow in J8b/J8c/J8d):
--   1) founder_vault_lease        one row per device: monotonic serial, issued/expires in ms, revoked_ms. A guard trigger: serial only goes up, expiry NEVER extends once revoked, ttl 60..3600 s, no delete.
--   2) founder_vault_lease_event  append-only, SHA-256 HASH-CHAINED ledger (issued / refused / revoked), same pattern as E140; update, delete and truncate are blocked.
--   3) founder_vault_lease_issue  the only way to get a lease: device must be the caller's, approved, not revoked; row-locked per device; returns serial + issued/expires ms for the Rust signer.
--   4) revoke trigger on founder_devices: the moment revoked_at is set, the lease is cut to NOW (can never run to its old end) and a `revoked` event is chained.
--   5) founder_vault_lease_status / _verify  per-device live|expired|revoked|none with seconds left; chain re-check.  6) selftest (rolled back).
-- Needs E102 (founder_devices) and E140 (_fh_now_ms). Safe to run again.

do $$ begin
  if to_regclass('public.founder_devices') is null or to_regprocedure('public._fh_now_ms()') is null then raise exception 'E143 needs E102 and E140 first'; end if;
end $$;

-- 1) tables ----------------------------------------------------------------------------------------------------------------------------------------
do $$ begin
  perform pg_advisory_xact_lock(hashtextextended('founder_vault_lease:ddl', 0));
  create table if not exists public.founder_vault_lease (
    device_id   uuid primary key references public.founder_devices(id),
    user_id     uuid   not null,
    serial      bigint not null check (serial >= 1),
    issued_ms   bigint not null check (issued_ms > 0),
    expires_ms  bigint not null,
    ttl_s       integer not null check (ttl_s between 60 and 3600),
    revoked_ms  bigint,
    check (expires_ms > issued_ms or revoked_ms is not null),
    check (revoked_ms is null or expires_ms <= revoked_ms)
  );
  create table if not exists public.founder_vault_lease_event (
    id        bigint generated always as identity primary key,
    ts_ms     bigint not null check (ts_ms > 0),
    user_id   uuid   not null,
    device_id uuid   not null,
    kind      text   not null check (kind in ('issued', 'refused', 'revoked')),
    facts     jsonb  not null default '{}'::jsonb check (jsonb_typeof(facts) = 'object' and octet_length(facts::text) <= 1000),
    prev_hash text   not null check (prev_hash ~ '^[0-9a-f]{64}$'),
    hash      text   not null unique check (hash ~ '^[0-9a-f]{64}$')
  );
  create index if not exists founder_vault_lease_event_dev on public.founder_vault_lease_event (device_id, id desc);
  alter table public.founder_vault_lease enable row level security;
  alter table public.founder_vault_lease_event enable row level security;
  revoke all on public.founder_vault_lease, public.founder_vault_lease_event from public, anon, authenticated, service_role;
  grant select on public.founder_vault_lease, public.founder_vault_lease_event to service_role;
end $$;

-- 2) guards ----------------------------------------------------------------------------------------------------------------------------------------
create or replace function public._fh_vl_stop() returns trigger language plpgsql as $$ begin raise exception 'E143: the lease ledger is append-only / never deleted' using errcode = '42501'; end $$;
create or replace function public._fh_vl_guard() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if tg_op = 'DELETE' then raise exception 'E143: a lease row is never deleted' using errcode = '42501'; end if;
  if new.device_id <> old.device_id or new.user_id <> old.user_id then raise exception 'E143: a lease belongs to one device for ever' using errcode = '42501'; end if;
  if new.serial < old.serial then raise exception 'E143: the lease serial only goes up' using errcode = '42501'; end if;
  if old.revoked_ms is not null then
    if new.revoked_ms is distinct from old.revoked_ms or new.expires_ms > old.expires_ms or new.serial <> old.serial then
      raise exception 'E143: a revoked device can never get its lease back' using errcode = '42501'; end if;
  end if;
  return new;
end $$;
drop trigger if exists founder_vault_lease_guard on public.founder_vault_lease;
create trigger founder_vault_lease_guard before update or delete on public.founder_vault_lease for each row execute function public._fh_vl_guard();
drop trigger if exists founder_vault_lease_trunc on public.founder_vault_lease;
create trigger founder_vault_lease_trunc before truncate on public.founder_vault_lease for each statement execute function public._fh_vl_stop();

create or replace function public._fh_vl_hash(p_prev text, p_ts bigint, p_uid uuid, p_dev uuid, p_kind text, p_facts jsonb) returns text
language sql immutable set search_path = pg_catalog, public, extensions as $$
  select encode(extensions.digest(convert_to(p_prev || '|' || p_ts || '|' || p_uid::text || '|' || p_dev::text || '|' || p_kind || '|' || p_facts::text, 'UTF8'), 'sha256'), 'hex')
$$;
create or replace function public._fh_vl_event_guard() returns trigger language plpgsql set search_path = pg_catalog, public, extensions as $$
declare p public.founder_vault_lease_event%rowtype;
begin
  perform pg_advisory_xact_lock(hashtextextended('founder_vault_lease:chain', 0));
  select * into p from public.founder_vault_lease_event order by id desc limit 1;
  new.ts_ms := public._fh_now_ms();
  new.prev_hash := coalesce(p.hash, repeat('0', 64));
  new.hash := public._fh_vl_hash(new.prev_hash, new.ts_ms, new.user_id, new.device_id, new.kind, new.facts);
  return new;
end $$;
drop trigger if exists founder_vault_lease_event_guard on public.founder_vault_lease_event;
create trigger founder_vault_lease_event_guard before insert on public.founder_vault_lease_event for each row execute function public._fh_vl_event_guard();
drop trigger if exists founder_vault_lease_event_stop on public.founder_vault_lease_event;
create trigger founder_vault_lease_event_stop before update or delete on public.founder_vault_lease_event for each row execute function public._fh_vl_stop();
drop trigger if exists founder_vault_lease_event_trunc on public.founder_vault_lease_event;
create trigger founder_vault_lease_event_trunc before truncate on public.founder_vault_lease_event for each statement execute function public._fh_vl_stop();

create or replace function public._fh_vl_log(p_uid uuid, p_dev uuid, p_kind text, p_facts jsonb) returns void
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
begin
  insert into public.founder_vault_lease_event (ts_ms, user_id, device_id, kind, facts, prev_hash, hash)
  values (1, p_uid, p_dev, p_kind, coalesce(p_facts, '{}'::jsonb), repeat('0', 64), repeat('0', 64));
end $$;

-- 3) issue / renew ---------------------------------------------------------------------------------------------------------------------------------
create or replace function public.founder_vault_lease_issue(p_uid uuid, p_device uuid, p_ttl_s integer default 900) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare d public.founder_devices%rowtype; l public.founder_vault_lease%rowtype; v_now bigint := public._fh_now_ms(); v_ttl integer := least(greatest(coalesce(p_ttl_s, 900), 60), 3600); v_why text;
begin
  perform pg_advisory_xact_lock(hashtextextended('founder_vault_lease:' || p_device::text, 0));
  select * into d from public.founder_devices where id = p_device;
  v_why := case when not found then 'unknown_device'
                when d.user_id <> p_uid then 'not_your_device'
                when d.revoked_at is not null then 'revoked'
                when d.approved_at is null then 'not_approved' end;
  if v_why is not null then
    if d.id is not null and d.user_id = p_uid then perform public._fh_vl_log(p_uid, p_device, 'refused', jsonb_build_object('why', v_why)); end if;
    return jsonb_build_object('ok', false, 'why', v_why);
  end if;
  select * into l from public.founder_vault_lease where device_id = p_device for update;
  if not found then
    insert into public.founder_vault_lease (device_id, user_id, serial, issued_ms, expires_ms, ttl_s) values (p_device, p_uid, 1, v_now, v_now + v_ttl * 1000, v_ttl) returning * into l;
  else
    update public.founder_vault_lease set serial = l.serial + 1, issued_ms = v_now, expires_ms = v_now + v_ttl * 1000, ttl_s = v_ttl where device_id = p_device returning * into l;
  end if;
  perform public._fh_vl_log(p_uid, p_device, 'issued', jsonb_build_object('serial', l.serial, 'ttl_s', v_ttl));
  return jsonb_build_object('ok', true, 'device_id', p_device, 'serial', l.serial, 'issued_ms', l.issued_ms, 'expires_ms', l.expires_ms, 'ttl_s', l.ttl_s);
end $$;

-- 4) revoke cuts the lease at once ------------------------------------------------------------------------------------------------------------------
create or replace function public._fh_vl_on_revoke() returns trigger language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_now bigint := public._fh_now_ms(); l public.founder_vault_lease%rowtype;
begin
  if old.revoked_at is null and new.revoked_at is not null then
    update public.founder_vault_lease set revoked_ms = v_now, expires_ms = least(expires_ms, v_now) where device_id = new.id and revoked_ms is null returning * into l;
    perform public._fh_vl_log(new.user_id, new.id, 'revoked', jsonb_build_object('had_lease', l.device_id is not null, 'cut_at_ms', v_now));
  end if;
  return new;
end $$;
drop trigger if exists founder_devices_vault_lease_revoke on public.founder_devices;
create trigger founder_devices_vault_lease_revoke after update of revoked_at on public.founder_devices for each row execute function public._fh_vl_on_revoke();

-- 5) status + chain check ----------------------------------------------------------------------------------------------------------------------------
create or replace function public.founder_vault_lease_status(p_uid uuid) returns jsonb
language sql stable security definer set search_path = pg_catalog, public, extensions as $$
  with n as (select public._fh_now_ms() ms)
  select jsonb_build_object('now_ms', (select ms from n), 'devices', coalesce(jsonb_agg(jsonb_build_object(
    'device_id', d.id, 'label', d.label, 'serial', l.serial, 'expires_ms', l.expires_ms,
    'state', case when d.revoked_at is not null then 'revoked' when l.device_id is null then 'none' when l.expires_ms > (select ms from n) then 'live' else 'expired' end,
    'seconds_left', case when l.device_id is null or d.revoked_at is not null then 0 else greatest(0, (l.expires_ms - (select ms from n)) / 1000) end) order by d.created_at), '[]'::jsonb))
  from public.founder_devices d left join public.founder_vault_lease l on l.device_id = d.id where d.user_id = p_uid and d.approved_at is not null
$$;
create or replace function public.founder_vault_lease_verify(p_limit integer default 1000) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare r public.founder_vault_lease_event%rowtype; v_prev text; v_n integer := 0; v_bad bigint; v_first bigint;
begin
  select min(id) into v_first from (select id from public.founder_vault_lease_event order by id desc limit greatest(p_limit, 1)) s;
  if v_first is null then return jsonb_build_object('ok', true, 'checked', 0); end if;
  select hash into v_prev from public.founder_vault_lease_event where id < v_first order by id desc limit 1;
  v_prev := coalesce(v_prev, repeat('0', 64));
  for r in select * from public.founder_vault_lease_event where id >= v_first order by id loop
    if r.prev_hash <> v_prev or r.hash <> public._fh_vl_hash(r.prev_hash, r.ts_ms, r.user_id, r.device_id, r.kind, r.facts) then v_bad := r.id; exit; end if;
    v_prev := r.hash; v_n := v_n + 1;
  end loop;
  return jsonb_build_object('ok', v_bad is null, 'checked', v_n, 'broken_at', v_bad);
end $$;

revoke all on function public.founder_vault_lease_issue(uuid, uuid, integer), public.founder_vault_lease_status(uuid), public.founder_vault_lease_verify(integer),
  public._fh_vl_log(uuid, uuid, text, jsonb) from public, anon, authenticated;
grant execute on function public.founder_vault_lease_issue(uuid, uuid, integer), public.founder_vault_lease_status(uuid), public.founder_vault_lease_verify(integer) to service_role;

-- 6) selftest (rolled back) --------------------------------------------------------------------------------------------------------------------------
create or replace function public.founder_vault_lease_selftest() returns text language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_uid uuid; v_dev uuid := gen_random_uuid(); v_dev2 uuid := gen_random_uuid(); r text := ''; a jsonb; b jsonb; v_ok boolean; v_ev bigint;
begin
  select user_id into v_uid from public.founder_accounts limit 1;
  if v_uid is null then return 'E143 selftest SKIP: founder_accounts is empty'; end if;
  select count(*) into v_ev from public.founder_vault_lease_event;
  begin
    insert into public.founder_devices (id, user_id, label, ua_hash, approved_at) values (v_dev, v_uid, 'e143 test', repeat('a', 64), now());
    insert into public.founder_devices (id, user_id, label, ua_hash) values (v_dev2, v_uid, 'e143 waiting', repeat('b', 64));
    a := public.founder_vault_lease_issue(v_uid, v_dev, 900);
    if not (a ->> 'ok')::boolean or (a ->> 'serial')::bigint <> 1 or (a ->> 'expires_ms')::bigint - (a ->> 'issued_ms')::bigint <> 900000 then raise exception 'first lease wrong: %', a; end if;
    b := public.founder_vault_lease_issue(v_uid, v_dev, 99999);
    if (b ->> 'serial')::bigint <> 2 or (b ->> 'ttl_s')::int <> 3600 then raise exception 'renew / ttl cap wrong: %', b; end if;
    b := public.founder_vault_lease_issue(v_uid, v_dev, 1);
    if (b ->> 'ttl_s')::int <> 60 then raise exception 'ttl floor wrong'; end if;
    r := r || 'issue + renew + ttl 60..3600 OK; ';
    if (public.founder_vault_lease_issue(v_uid, v_dev2) ->> 'why') <> 'not_approved' then raise exception 'unapproved device got a lease'; end if;
    if (public.founder_vault_lease_issue(gen_random_uuid(), v_dev) ->> 'why') <> 'not_your_device' then raise exception 'foreign user got a lease'; end if;
    if (public.founder_vault_lease_issue(v_uid, gen_random_uuid()) ->> 'why') <> 'unknown_device' then raise exception 'unknown device got a lease'; end if;
    r := r || 'unapproved / foreign / unknown refused OK; ';
    v_ok := false; begin update public.founder_vault_lease set serial = 1 where device_id = v_dev; exception when others then v_ok := true; end;
    if not v_ok then raise exception 'serial went down'; end if;
    v_ok := false; begin delete from public.founder_vault_lease where device_id = v_dev; exception when others then v_ok := true; end;
    if not v_ok then raise exception 'lease delete allowed'; end if;
    update public.founder_devices set revoked_at = now() where id = v_dev;
    if (select state from jsonb_to_recordset(public.founder_vault_lease_status(v_uid) -> 'devices') as x(device_id uuid, state text) where device_id = v_dev) <> 'revoked' then raise exception 'status not revoked'; end if;
    if (select expires_ms from public.founder_vault_lease where device_id = v_dev) > public._fh_now_ms() then raise exception 'revoke did not cut the lease'; end if;
    if (public.founder_vault_lease_issue(v_uid, v_dev) ->> 'why') <> 'revoked' then raise exception 'revoked device got a lease'; end if;
    v_ok := false; begin update public.founder_vault_lease set expires_ms = expires_ms + 600000, serial = serial where device_id = v_dev; exception when others then v_ok := true; end;
    if not v_ok then raise exception 'a revoked lease was extended'; end if;
    r := r || 'revoke cuts the lease at once, never comes back OK; ';
    if public.founder_vault_lease_verify(100000) ->> 'ok' <> 'true' then raise exception 'clean chain failed verify'; end if;
    v_ok := false; begin update public.founder_vault_lease_event set facts = '{}'::jsonb where id = (select max(id) from public.founder_vault_lease_event); exception when others then v_ok := true; end;
    if not v_ok then raise exception 'ledger update allowed'; end if;
    v_ok := false; begin truncate public.founder_vault_lease_event; exception when others then v_ok := true; end;
    if not v_ok then raise exception 'ledger truncate allowed'; end if;
    alter table public.founder_vault_lease_event disable trigger founder_vault_lease_event_stop;
    update public.founder_vault_lease_event set facts = '{"x":1}'::jsonb where id = (select max(id) from public.founder_vault_lease_event);
    alter table public.founder_vault_lease_event enable trigger founder_vault_lease_event_stop;
    if public.founder_vault_lease_verify(100000) ->> 'ok' <> 'false' then raise exception 'tampered chain not caught'; end if;
    r := r || 'chain verifies, tamper caught, ledger append-only OK';
    raise exception 'E143_ROLLBACK:%', r;
  exception when others then
    if sqlerrm like 'E143_ROLLBACK:%' then return 'E143 selftest PASS: ' || substr(sqlerrm, 15); end if;
    return 'E143 selftest FAIL: ' || sqlerrm;
  end;
end $$;
revoke all on function public.founder_vault_lease_selftest() from public, anon, authenticated;
grant execute on function public.founder_vault_lease_selftest() to service_role;
select public.founder_vault_lease_selftest();
