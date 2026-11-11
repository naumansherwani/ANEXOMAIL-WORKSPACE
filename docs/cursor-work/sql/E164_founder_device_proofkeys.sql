
-- E164 (11 Nov 2026 21:35 PKT, founder order: hybrid ML-DSA + ECDSA device proof, exchange on the kernel) - the HYBRID PROOF KEY, kept BESIDE the DBSC chip key.
-- WHY: E162 put the hybrid key on the DBSC binding, but a device holds ONE binding (chip OR software). His device is chip-bound, so it could never get a hybrid key.
-- WHAT: one active hybrid proof key per (user, device): ES256 P-256 public key + ML-DSA-65 public key, BOTH mandatory. The DBSC chip binding is untouched.
--   * keys never change (trigger); a revoked row never changes; one ACTIVE row per device (unique index); RLS on, no policy, no grants: service_role functions only;
--   * founder_proofkey_get: the key only while the device is approved and not revoked (a revoked device's key is inert at once);
--   * founder_proofkey_register: first key, or a replacement ONLY when the caller says the device's chip is alive (Rust decides from E161 idle_s); nonce single use; hash-chained event;
--   * founder_proofkey_use: consumes the proof nonce once, counts the use; replay refused;
--   * posture164 + selftest164 (rolled back, WITH a live DBSC binding in the test) + CHECK_E164.
-- Idempotent: safe to run twice. Needs E162/E163 first.

do $$ begin
  if to_regprocedure('public.founder_dbsc_register_pq(uuid,text,text,text,text,text,text)') is null then raise exception 'E164 needs E162 first'; end if;
end $$;

create table if not exists public.founder_device_proofkeys (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  device_hash text not null check (device_hash ~ '^[0-9a-f]{64}$'),
  es_pub text not null check (es_pub ~ '^04[0-9a-f]{128}$'),
  pq_pub text not null check (length(pq_pub) = 3904 and pq_pub !~ '[^0-9a-f]'),
  created_at timestamptz not null default now(),
  revoked_at timestamptz,
  revoke_reason text check (revoke_reason is null or revoke_reason in ('replaced', 'device_revoked', 'founder_revoked', 'selftest')),
  last_used_at timestamptz,
  use_count bigint not null default 0,
  check ((revoked_at is null) = (revoke_reason is null))
);
create unique index if not exists founder_device_proofkeys_one_active on public.founder_device_proofkeys (user_id, device_hash) where revoked_at is null;
alter table public.founder_device_proofkeys enable row level security;
revoke all on public.founder_device_proofkeys from public, anon, authenticated;

create or replace function public._proofkey_guard() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if tg_op = 'DELETE' then raise exception 'proof keys are never deleted' using errcode = '42501'; end if;
  if new.id is distinct from old.id or new.user_id is distinct from old.user_id or new.device_hash is distinct from old.device_hash or new.es_pub is distinct from old.es_pub
     or new.pq_pub is distinct from old.pq_pub or new.created_at is distinct from old.created_at then raise exception 'a proof key never changes' using errcode = '42501'; end if;
  if old.revoked_at is not null and (new.revoked_at is distinct from old.revoked_at or new.revoke_reason is distinct from old.revoke_reason) then raise exception 'a revoked proof key stays revoked' using errcode = '42501'; end if;
  return new;
end $$;
drop trigger if exists founder_proofkeys_guard on public.founder_device_proofkeys;
create trigger founder_proofkeys_guard before update or delete on public.founder_device_proofkeys for each row execute function public._proofkey_guard();

-- the event ledger learns the new kinds (only the allowed list grows)
do $$ begin
  if position('proofkey_registered' in (select pg_get_constraintdef(oid) from pg_constraint where conname = 'founder_dbsc_events_kind_check')) = 0 then
    alter table public.founder_dbsc_events drop constraint founder_dbsc_events_kind_check;
    alter table public.founder_dbsc_events add constraint founder_dbsc_events_kind_check check (kind = any (array['registered','refreshed','revoked','reject_signature','reject_replay','reject_challenge','reject_key','would_block','blocked','allowed_bound','test','reject_downgrade','proofkey_registered','proofkey_replaced','reject_proofkey']));
  end if;
end $$;

create or replace function public.founder_proofkey_get(p_uid uuid, p_device_hash text) returns jsonb
language sql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
  select coalesce((select jsonb_build_object('found', true, 'id', k.id, 'es', k.es_pub, 'pq', k.pq_pub, 'since', k.created_at, 'uses', k.use_count, 'last_used_at', k.last_used_at)
                     from public.founder_device_proofkeys k
                     join public.founder_devices d on d.user_id = k.user_id and d.ua_hash = k.device_hash and d.approved_at is not null and d.revoked_at is null
                    where k.user_id = p_uid and k.device_hash = p_device_hash and k.revoked_at is null), jsonb_build_object('found', false))
$$;

create or replace function public.founder_proofkey_register(p_uid uuid, p_device_hash text, p_es text, p_pq text, p_jti_hash text, p_allow_replace boolean) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '8s' as $$
declare v_old uuid;
begin
  if p_device_hash is null or p_device_hash !~ '^[0-9a-f]{64}$' or p_es is null or p_es !~ '^04[0-9a-f]{128}$' or p_pq is null or length(p_pq) <> 3904 or p_pq ~ '[^0-9a-f]'
     or p_jti_hash is null or p_jti_hash !~ '^[0-9a-f]{64}$' then return jsonb_build_object('ok', false, 'error', 'shape'); end if;
  perform pg_advisory_xact_lock(hashtextextended('founder_proofkey:dev:' || p_uid::text || p_device_hash, 0));
  if not exists (select 1 from public.founder_devices where user_id = p_uid and ua_hash = p_device_hash and approved_at is not null and revoked_at is null) then
    return jsonb_build_object('ok', false, 'error', 'device_not_approved'); end if;
  select id into v_old from public.founder_device_proofkeys where user_id = p_uid and device_hash = p_device_hash and revoked_at is null;
  if v_old is not null and not coalesce(p_allow_replace, false) then
    perform public._dbsc_log(p_uid, null, 'reject_proofkey', jsonb_build_object('why', 'exists'));
    return jsonb_build_object('ok', false, 'error', 'exists'); end if;
  if not public._dbsc_take_jti(p_jti_hash, 'register') then
    perform public._dbsc_log(p_uid, null, 'reject_replay', jsonb_build_object('purpose', 'proofkey'));
    return jsonb_build_object('ok', false, 'error', 'replay'); end if;
  if v_old is not null then update public.founder_device_proofkeys set revoked_at = now(), revoke_reason = 'replaced' where id = v_old; end if;
  insert into public.founder_device_proofkeys (user_id, device_hash, es_pub, pq_pub) values (p_uid, p_device_hash, p_es, p_pq);
  perform public._dbsc_log(p_uid, null, case when v_old is null then 'proofkey_registered' else 'proofkey_replaced' end, jsonb_build_object('alg', 'ES256+ML-DSA-65'));
  return jsonb_build_object('ok', true, 'replaced', v_old is not null);
end $$;

create or replace function public.founder_proofkey_use(p_id uuid, p_jti_hash text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '5s' as $$
declare k public.founder_device_proofkeys%rowtype;
begin
  if p_jti_hash is null or p_jti_hash !~ '^[0-9a-f]{64}$' then return jsonb_build_object('ok', false, 'error', 'shape'); end if;
  select * into k from public.founder_device_proofkeys where id = p_id for update;
  if not found or k.revoked_at is not null then return jsonb_build_object('ok', false, 'error', 'unknown'); end if;
  if not public._dbsc_take_jti(p_jti_hash, 'refresh') then
    perform public._dbsc_log(k.user_id, null, 'reject_replay', jsonb_build_object('purpose', 'proofkey_exchange'));
    return jsonb_build_object('ok', false, 'error', 'replay'); end if;
  update public.founder_device_proofkeys set last_used_at = now(), use_count = use_count + 1 where id = p_id;
  return jsonb_build_object('ok', true);
end $$;

revoke all on function public.founder_proofkey_get(uuid, text), public.founder_proofkey_register(uuid, text, text, text, text, boolean), public.founder_proofkey_use(uuid, text) from public, anon, authenticated;
grant execute on function public.founder_proofkey_get(uuid, text), public.founder_proofkey_register(uuid, text, text, text, text, boolean), public.founder_proofkey_use(uuid, text) to service_role;

create or replace function public.founder_proofkey_posture164() returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions as $$
begin
  return jsonb_build_object(
    'table_rls_on', (select relrowsecurity from pg_class where oid = 'public.founder_device_proofkeys'::regclass),
    'no_client_grants', not has_table_privilege('anon', 'public.founder_device_proofkeys', 'select') and not has_table_privilege('authenticated', 'public.founder_device_proofkeys', 'select'),
    'one_active_per_device', exists (select 1 from pg_indexes where indexname = 'founder_device_proofkeys_one_active'),
    'guard_trigger', exists (select 1 from pg_trigger where tgname = 'founder_proofkeys_guard' and not tgisinternal),
    'service_role_only', not has_function_privilege('anon', 'public.founder_proofkey_register(uuid,text,text,text,text,boolean)', 'execute')
      and not has_function_privilege('authenticated', 'public.founder_proofkey_use(uuid,text)', 'execute')
      and has_function_privilege('service_role', 'public.founder_proofkey_get(uuid,text)', 'execute'),
    'event_kinds', position('proofkey_registered' in (select pg_get_constraintdef(oid) from pg_constraint where conname = 'founder_dbsc_events_kind_check')) > 0);
end $$;
revoke all on function public.founder_proofkey_posture164() from public, anon, authenticated;
grant execute on function public.founder_proofkey_posture164() to service_role;

create or replace function public.founder_proofkey_selftest164() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare
  v_msg text := 'E164 selftest FAIL: unknown'; v_uid uuid; v_dev text; j jsonb; v_id uuid;
  es1 text := '04' || repeat('11', 64); es2 text := '04' || repeat('22', 64); pq1 text := repeat('ab', 1952); pq2 text := repeat('cd', 1952);
  h text;
begin
  select d.user_id, d.ua_hash into v_uid, v_dev from public.founder_devices d where d.approved_at is not null and d.revoked_at is null order by d.created_at limit 1;
  if v_uid is null then return 'E164 selftest SKIP: no approved founder device yet'; end if;
  begin
    -- a LIVE chip binding on the device must not matter (his device is chip-bound): make one if none
    if not exists (select 1 from public.founder_dbsc_sessions where user_id = v_uid and device_hash = v_dev and revoked_at is null) then
      insert into public.founder_dbsc_sessions (sid, user_id, device_hash, pub, source) values ('e164chip000000001', v_uid, v_dev, '04' || repeat('ef', 64), 'dbsc'); end if;
    update public.founder_device_proofkeys set revoked_at = now(), revoke_reason = 'selftest' where user_id = v_uid and device_hash = v_dev and revoked_at is null;
    if public.founder_proofkey_get(v_uid, v_dev) ->> 'found' <> 'false' then raise exception 'a key was found before any was made'; end if;
    if public.founder_proofkey_register(v_uid, v_dev, 'zz', pq1, encode(extensions.digest('e164-0', 'sha256'), 'hex'), false) ->> 'error' <> 'shape' then raise exception 'bad shape accepted'; end if;
    j := public.founder_proofkey_register(v_uid, v_dev, es1, pq1, encode(extensions.digest('e164-1', 'sha256'), 'hex'), false);
    if j ->> 'ok' <> 'true' then raise exception 'first registration refused: %', j; end if;
    j := public.founder_proofkey_get(v_uid, v_dev);
    if j ->> 'es' <> es1 or j ->> 'pq' <> pq1 then raise exception 'get does not return the keys'; end if;
    v_id := (j ->> 'id')::uuid;
    -- a second key without permission is refused; with permission (chip alive) it replaces and the old one is revoked
    if public.founder_proofkey_register(v_uid, v_dev, es2, pq2, encode(extensions.digest('e164-2', 'sha256'), 'hex'), false) ->> 'error' <> 'exists' then raise exception 'a key was swapped without permission'; end if;
    -- replay of the registration nonce
    if public.founder_proofkey_register(v_uid, v_dev, es2, pq2, encode(extensions.digest('e164-1', 'sha256'), 'hex'), true) ->> 'error' <> 'replay' then raise exception 'registration nonce replay accepted'; end if;
    -- use: once ok, replay refused, unknown id refused
    h := encode(extensions.digest('e164-use', 'sha256'), 'hex');
    if public.founder_proofkey_use(v_id, h) ->> 'ok' <> 'true' then raise exception 'use refused'; end if;
    if public.founder_proofkey_use(v_id, h) ->> 'error' <> 'replay' then raise exception 'use replay accepted'; end if;
    if public.founder_proofkey_use(gen_random_uuid(), encode(extensions.digest('e164-use2', 'sha256'), 'hex')) ->> 'error' <> 'unknown' then raise exception 'unknown key accepted'; end if;
    -- keys never change in place
    begin update public.founder_device_proofkeys set pq_pub = pq2 where id = v_id; raise exception 'key swapped in place'; exception when insufficient_privilege then null; end;
    begin delete from public.founder_device_proofkeys where id = v_id; raise exception 'key deleted'; exception when insufficient_privilege then null; end;
    -- replacement
    j := public.founder_proofkey_register(v_uid, v_dev, es2, pq2, encode(extensions.digest('e164-3', 'sha256'), 'hex'), true);
    if j ->> 'ok' <> 'true' or (j ->> 'replaced')::boolean is not true then raise exception 'replacement refused: %', j; end if;
    if public.founder_proofkey_use(v_id, encode(extensions.digest('e164-use3', 'sha256'), 'hex')) ->> 'error' <> 'unknown' then raise exception 'a replaced key still works'; end if;
    -- a revoked device makes the key inert
    update public.founder_devices set revoked_at = now() where user_id = v_uid and ua_hash = v_dev;
    if public.founder_proofkey_get(v_uid, v_dev) ->> 'found' <> 'false' then raise exception 'a revoked device still has a live proof key'; end if;
    if (select count(*) from jsonb_each_text(public.founder_proofkey_posture164()) where value::boolean is not true) <> 0 then raise exception 'posture164: %', public.founder_proofkey_posture164(); end if;
    v_msg := 'E164 selftest PASS';
    raise exception using errcode = 'P0164', message = v_msg;
  exception
    when sqlstate 'P0164' then return v_msg;
    when others then return 'E164 selftest FAIL: ' || sqlerrm;
  end;
end $$;
revoke all on function public.founder_proofkey_selftest164() from public, anon, authenticated;
grant execute on function public.founder_proofkey_selftest164() to service_role;
