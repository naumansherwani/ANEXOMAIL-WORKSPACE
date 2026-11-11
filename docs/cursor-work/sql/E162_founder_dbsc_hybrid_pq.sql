
-- E162 (11 Nov 2026 21:10 PKT, founder order: ML-DSA + ECDSA HYBRID device proof, GAP 2 of K7) - SQL half of the post-quantum device key.
-- WHAT THIS DOES:
--   1) founder_dbsc_sessions gets pq_pub (the ML-DSA-65 public key, 1952 bytes = 3904 hex chars) + pq_alg. The shape is a CHECK; both columns are IMMUTABLE after insert (trigger): a binding can
--      never be upgraded, swapped or stripped in place. A new key means a NEW session row (the old one is revoked 'replaced').
--   2) founder_dbsc_register_pq(...) = the registration door for a hybrid device. NO DOWNGRADE: while a live hybrid binding exists for the device, a registration WITHOUT a pq key is refused
--      ('pq_downgrade'); a software hybrid key never replaces a live chip key (E158 rule kept); hybrid is only allowed with source 'webcrypto' (the DBSC chip path is ES256, browser standard).
--   3) founder_dbsc_register_src (E158, 6 arguments) becomes a wrapper of the new door with no pq key, so every old caller gets the same no-downgrade rule.
--   4) founder_dbsc_device_state also returns pq (the stored ML-DSA key or null): Rust uses it to REQUIRE the second signature at the exchange.
--   5) posture162 + selftest162 (rolled back) + CHECK_E162.sql. service_role only, definer, pinned search_path.
-- Nothing is dropped; exact-text patch (raises when the old text is missing) for device_state.

do $$ begin
  if to_regprocedure('public.founder_dbsc_register_src(uuid,text,text,text,text,text)') is null or to_regprocedure('public.founder_dbsc_device_state(uuid,text)') is null then
    raise exception 'E162 needs E158 and E161 first'; end if;
end $$;

alter table public.founder_dbsc_sessions add column if not exists pq_pub text;
alter table public.founder_dbsc_sessions add column if not exists pq_alg text;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'founder_dbsc_sessions_pq_shape') then
    alter table public.founder_dbsc_sessions add constraint founder_dbsc_sessions_pq_shape check ((pq_pub is null and pq_alg is null) or (pq_alg = 'ML-DSA-65' and length(pq_pub) = 3904 and pq_pub !~ '[^0-9a-f]' and source = 'webcrypto'));
  end if;
end $$;

-- the ledger of DBSC events learns one more kind: a refused downgrade is evidence, so it is written (append-only table, only the allowed list grows)
do $$ begin
  if position('reject_downgrade' in (select pg_get_constraintdef(oid) from pg_constraint where conname = 'founder_dbsc_events_kind_check')) = 0 then
    alter table public.founder_dbsc_events drop constraint founder_dbsc_events_kind_check;
    alter table public.founder_dbsc_events add constraint founder_dbsc_events_kind_check check (kind = any (array['registered','refreshed','revoked','reject_signature','reject_replay','reject_challenge','reject_key','would_block','blocked','allowed_bound','test','reject_downgrade']));
  end if;
end $$;

create or replace function public._dbsc_pq_immutable() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if new.pq_pub is distinct from old.pq_pub or new.pq_alg is distinct from old.pq_alg then raise exception 'the post-quantum key of a binding never changes' using errcode = '42501'; end if;
  return new;
end $$;
drop trigger if exists founder_dbsc_pq_immutable on public.founder_dbsc_sessions;
create trigger founder_dbsc_pq_immutable before update on public.founder_dbsc_sessions for each row execute function public._dbsc_pq_immutable();

create or replace function public.founder_dbsc_register_pq(p_uid uuid, p_device_hash text, p_sid text, p_pub text, p_jti_hash text, p_source text, p_pq text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '8s' as $$
declare v_old text; v_old_src text; v_live boolean; v_old_pq text; v_hyb boolean := p_pq is not null;
begin
  if p_source is null or p_source not in ('dbsc', 'webcrypto') or (v_hyb and p_source <> 'webcrypto') then return jsonb_build_object('ok', false, 'error', 'source'); end if;
  if v_hyb and (length(p_pq) <> 3904 or p_pq ~ '[^0-9a-f]') then return jsonb_build_object('ok', false, 'error', 'pq_shape'); end if;
  if p_device_hash is null or p_device_hash !~ '^[0-9a-f]{64}$' or p_pub is null or p_pub !~ '^04[0-9a-f]{128}$' or p_sid is null or p_sid !~ '^[A-Za-z0-9_-]{16,64}$' or p_jti_hash is null or p_jti_hash !~ '^[0-9a-f]{64}$' then
    return jsonb_build_object('ok', false, 'error', 'shape'); end if;
  perform pg_advisory_xact_lock(hashtextextended('founder_dbsc:dev:' || p_uid::text || p_device_hash, 0));
  if not exists (select 1 from public.founder_devices where user_id = p_uid and ua_hash = p_device_hash and approved_at is not null and revoked_at is null) then
    return jsonb_build_object('ok', false, 'error', 'device_not_approved'); end if;
  select sid, source, pq_pub, coalesce(last_refresh_at, created_at) > now() - interval '30 minutes' into v_old, v_old_src, v_old_pq, v_live from public.founder_dbsc_sessions where user_id = p_uid and device_hash = p_device_hash and revoked_at is null;
  if v_old_pq is not null and not v_hyb then   -- NO DOWNGRADE: a hybrid device is never re-registered classical-only, whatever the caller says
    perform public._dbsc_log(p_uid, v_old, 'reject_downgrade', jsonb_build_object('source', p_source));
    return jsonb_build_object('ok', false, 'error', 'pq_downgrade'); end if;
  if not public._dbsc_take_jti(p_jti_hash, 'register') then
    perform public._dbsc_log(p_uid, null, 'reject_replay', jsonb_build_object('purpose', 'register', 'source', p_source));
    return jsonb_build_object('ok', false, 'error', 'replay'); end if;
  if v_old is not null and v_old_src = 'dbsc' and p_source = 'webcrypto' and coalesce(v_live, false) then
    return jsonb_build_object('ok', true, 'kept', 'dbsc', 'sid', v_old); end if;
  if v_old is not null then
    update public.founder_dbsc_sessions set revoked_at = now(), revoke_reason = 'replaced' where sid = v_old;
    perform public._dbsc_log(p_uid, v_old, 'revoked', jsonb_build_object('reason', 'replaced', 'by', p_source, 'hybrid', v_hyb)); end if;
  insert into public.founder_dbsc_sessions (sid, user_id, device_hash, pub, source, pq_pub, pq_alg) values (p_sid, p_uid, p_device_hash, p_pub, p_source, p_pq, case when v_hyb then 'ML-DSA-65' end);
  perform public._dbsc_log(p_uid, p_sid, 'registered', jsonb_build_object('replaced', v_old is not null, 'source', p_source, 'hybrid', v_hyb));
  return jsonb_build_object('ok', true, 'sid', p_sid, 'replaced', v_old is not null, 'source', p_source, 'hybrid', v_hyb);
end $$;
revoke all on function public.founder_dbsc_register_pq(uuid, text, text, text, text, text, text) from public, anon, authenticated;
grant execute on function public.founder_dbsc_register_pq(uuid, text, text, text, text, text, text) to service_role;

create or replace function public.founder_dbsc_register_src(p_uid uuid, p_device_hash text, p_sid text, p_pub text, p_jti_hash text, p_source text) returns jsonb
language sql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '8s' as $$
  select public.founder_dbsc_register_pq(p_uid, p_device_hash, p_sid, p_pub, p_jti_hash, p_source, null)
$$;
revoke all on function public.founder_dbsc_register_src(uuid, text, text, text, text, text) from public, anon, authenticated;
grant execute on function public.founder_dbsc_register_src(uuid, text, text, text, text, text) to service_role;

do $$
declare d text; n text;
begin
  select pg_get_functiondef('public.founder_dbsc_device_state(uuid,text)'::regprocedure) into d;
  if position('''pq''' in d) = 0 then
    n := replace(d, '''idle_s'', floor(', '''pq'', pq_pub, ''idle_s'', floor(');
    if n = d then raise exception 'E162: the E161 founder_dbsc_device_state text was not found'; end if;
    execute n;
  end if;
end $$;

create or replace function public.founder_dbsc_posture162() returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions as $$
begin
  return jsonb_build_object(
    'pq_columns', (select count(*) = 2 from information_schema.columns where table_schema = 'public' and table_name = 'founder_dbsc_sessions' and column_name in ('pq_pub', 'pq_alg')),
    'pq_shape_check', exists (select 1 from pg_constraint where conname = 'founder_dbsc_sessions_pq_shape'),
    'pq_immutable_trigger', exists (select 1 from pg_trigger where tgname = 'founder_dbsc_pq_immutable' and not tgisinternal),
    'device_state_reports_pq', position('''pq''' in pg_get_functiondef('public.founder_dbsc_device_state(uuid,text)'::regprocedure)) > 0,
    'register_src_is_wrapper', position('founder_dbsc_register_pq' in pg_get_functiondef('public.founder_dbsc_register_src(uuid,text,text,text,text,text)'::regprocedure)) > 0,
    'service_role_only', not has_function_privilege('anon', 'public.founder_dbsc_register_pq(uuid,text,text,text,text,text,text)', 'execute')
      and not has_function_privilege('authenticated', 'public.founder_dbsc_register_pq(uuid,text,text,text,text,text,text)', 'execute')
      and has_function_privilege('service_role', 'public.founder_dbsc_register_pq(uuid,text,text,text,text,text,text)', 'execute'));
end $$;
revoke all on function public.founder_dbsc_posture162() from public, anon, authenticated;
grant execute on function public.founder_dbsc_posture162() to service_role;

create or replace function public.founder_dbsc_selftest162() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare
  v_msg text := 'E162 selftest FAIL: unknown'; v_uid uuid; v_dev text; j jsonb;
  pq1 text := repeat('ab', 1952); pq2 text := repeat('cd', 1952);
  k1 text := '04' || repeat('11', 64); k2 text := '04' || repeat('22', 64);
  h text := encode(extensions.digest('e162-j', 'sha256'), 'hex');
begin
  select d.user_id, d.ua_hash into v_uid, v_dev from public.founder_devices d where d.approved_at is not null and d.revoked_at is null order by d.created_at limit 1;
  if v_uid is null then return 'E162 selftest SKIP: no approved founder device yet'; end if;
  begin
    -- 1) a chip session ends first so the device is clean inside this rolled-back test
    update public.founder_dbsc_sessions set revoked_at = now(), revoke_reason = 'e162test' where user_id = v_uid and device_hash = v_dev and revoked_at is null;
    -- 2) classical-only registration works; a pq key is refused with source dbsc and with a bad shape
    j := public.founder_dbsc_register_pq(v_uid, v_dev, 'e162classic000001', k1, encode(extensions.digest('e162-1', 'sha256'), 'hex'), 'webcrypto', null);
    if j ->> 'ok' <> 'true' then raise exception 'classical registration refused: %', j; end if;
    if public.founder_dbsc_register_pq(v_uid, v_dev, 'e162bad000000001', k2, encode(extensions.digest('e162-2', 'sha256'), 'hex'), 'dbsc', pq1) ->> 'error' <> 'source' then raise exception 'pq with dbsc accepted'; end if;
    if public.founder_dbsc_register_pq(v_uid, v_dev, 'e162bad000000002', k2, encode(extensions.digest('e162-3', 'sha256'), 'hex'), 'webcrypto', 'abcd') ->> 'error' <> 'pq_shape' then raise exception 'short pq accepted'; end if;
    -- 3) upgrade to hybrid, state reports the pq key
    j := public.founder_dbsc_register_pq(v_uid, v_dev, 'e162hybrid0000001', k2, encode(extensions.digest('e162-4', 'sha256'), 'hex'), 'webcrypto', pq1);
    if j ->> 'ok' <> 'true' or (j ->> 'hybrid')::boolean is not true then raise exception 'hybrid registration refused: %', j; end if;
    if public.founder_dbsc_device_state(v_uid, v_dev) ->> 'pq' <> pq1 then raise exception 'device_state does not report the pq key'; end if;
    -- 4) NO DOWNGRADE: classical-only registration (new door and old wrapper) is refused while the hybrid binding is live
    if public.founder_dbsc_register_pq(v_uid, v_dev, 'e162down000000001', k1, encode(extensions.digest('e162-5', 'sha256'), 'hex'), 'webcrypto', null) ->> 'error' <> 'pq_downgrade' then raise exception 'downgrade accepted'; end if;
    if public.founder_dbsc_register_src(v_uid, v_dev, 'e162down000000002', k1, encode(extensions.digest('e162-6', 'sha256'), 'hex'), 'webcrypto') ->> 'error' <> 'pq_downgrade' then raise exception 'downgrade via the old door accepted'; end if;
    -- 5) the pq key cannot be changed or stripped in place
    begin update public.founder_dbsc_sessions set pq_pub = pq2 where sid = 'e162hybrid0000001'; raise exception 'pq key swapped in place';
    exception when insufficient_privilege then null; end;
    begin update public.founder_dbsc_sessions set pq_pub = null, pq_alg = null where sid = 'e162hybrid0000001'; raise exception 'pq key stripped in place';
    exception when insufficient_privilege then null; end;
    -- 6) a replacement hybrid (new key) is allowed and the old row is revoked
    j := public.founder_dbsc_register_pq(v_uid, v_dev, 'e162hybrid0000002', k1, encode(extensions.digest('e162-7', 'sha256'), 'hex'), 'webcrypto', pq2);
    if j ->> 'ok' <> 'true' or (j ->> 'replaced')::boolean is not true then raise exception 'hybrid replacement refused: %', j; end if;
    if (select count(*) from jsonb_each_text(public.founder_dbsc_posture162()) where value::boolean is not true) <> 0 then raise exception 'posture162: %', public.founder_dbsc_posture162(); end if;
    v_msg := 'E162 selftest PASS';
    raise exception using errcode = 'P0162', message = v_msg;
  exception
    when sqlstate 'P0162' then return v_msg;
    when others then return 'E162 selftest FAIL: ' || sqlerrm;
  end;
end $$;
revoke all on function public.founder_dbsc_selftest162() from public, anon, authenticated;
grant execute on function public.founder_dbsc_selftest162() to service_role;
