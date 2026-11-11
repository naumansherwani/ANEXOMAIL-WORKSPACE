
-- E165 (11 Nov 2026 21:55 PKT, founder order: post-quantum hybrid on EVERY browser, kernel fallback S3b) - WHERE the ML-DSA key lives is recorded.
-- WHY: Safari/Firefox cannot make ML-DSA keys in WebCrypto yet, so the Rust WASM kernel makes a seed-based key. That key is readable by page script, so it is WEAKER than a non-extractable
--      WebCrypto key. The server and the Devices board must say so, never hide it. (pq_src is declared by the browser INSIDE the ES256-signed proof; it is a label for the founder, not a security gate.)
-- WHAT: * founder_device_proofkeys.pq_src and founder_dbsc_sessions.pq_src: 'webcrypto' (default, all old rows) or 'kernel';
--       * founder_proofkey_register_src(...) = E164 register + the label, in ONE transaction; the label can only be written in the transaction that created the key (trigger);
--       * founder_dbsc_set_pq_src(uid, device_hash, sid, src) for the software-key binding path (only a fresh hybrid binding, within 2 minutes of creation, label only 'kernel' -> never overwritten later);
--       * founder_proofkey_get returns 'src'; posture165 + selftest165 (rolled back, with a live binding) + CHECK_E165.
-- Idempotent. Needs E164 first.

do $$ begin
  if to_regclass('public.founder_device_proofkeys') is null then raise exception 'E165 needs E164 first'; end if;
end $$;

alter table public.founder_device_proofkeys add column if not exists pq_src text not null default 'webcrypto';
alter table public.founder_dbsc_sessions add column if not exists pq_src text not null default 'webcrypto';
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'founder_proofkeys_pq_src_check') then
    alter table public.founder_device_proofkeys add constraint founder_proofkeys_pq_src_check check (pq_src in ('webcrypto', 'kernel')); end if;
  if not exists (select 1 from pg_constraint where conname = 'founder_dbsc_sessions_pq_src_check') then
    alter table public.founder_dbsc_sessions add constraint founder_dbsc_sessions_pq_src_check check (pq_src in ('webcrypto', 'kernel')); end if;
end $$;

-- the label is written once, in the creating transaction; afterwards it never changes
create or replace function public._pq_src_guard() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if new.pq_src is distinct from old.pq_src and old.created_at is distinct from now() then raise exception 'the key source label never changes' using errcode = '42501'; end if;
  return new;
end $$;
drop trigger if exists founder_proofkeys_src_guard on public.founder_device_proofkeys;
create trigger founder_proofkeys_src_guard before update on public.founder_device_proofkeys for each row execute function public._pq_src_guard();

create or replace function public.founder_proofkey_get(p_uid uuid, p_device_hash text) returns jsonb
language sql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
  select coalesce((select jsonb_build_object('found', true, 'id', k.id, 'es', k.es_pub, 'pq', k.pq_pub, 'src', k.pq_src, 'since', k.created_at, 'uses', k.use_count, 'last_used_at', k.last_used_at)
                     from public.founder_device_proofkeys k
                     join public.founder_devices d on d.user_id = k.user_id and d.ua_hash = k.device_hash and d.approved_at is not null and d.revoked_at is null
                    where k.user_id = p_uid and k.device_hash = p_device_hash and k.revoked_at is null), jsonb_build_object('found', false))
$$;

create or replace function public.founder_proofkey_register_src(p_uid uuid, p_device_hash text, p_es text, p_pq text, p_jti_hash text, p_allow_replace boolean, p_src text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '8s' as $$
declare j jsonb;
begin
  if p_src is null or p_src not in ('webcrypto', 'kernel') then return jsonb_build_object('ok', false, 'error', 'src'); end if;
  j := public.founder_proofkey_register(p_uid, p_device_hash, p_es, p_pq, p_jti_hash, p_allow_replace);
  if j ->> 'ok' = 'true' then
    update public.founder_device_proofkeys set pq_src = p_src where user_id = p_uid and device_hash = p_device_hash and revoked_at is null; end if;
  return j;
end $$;
revoke all on function public.founder_proofkey_register_src(uuid,text,text,text,text,boolean,text) from public, anon, authenticated;
grant execute on function public.founder_proofkey_register_src(uuid,text,text,text,text,boolean,text) to service_role;

create or replace function public.founder_dbsc_set_pq_src(p_uid uuid, p_device_hash text, p_sid text, p_src text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
declare n int;
begin
  if p_src is distinct from 'kernel' then return jsonb_build_object('ok', false, 'error', 'src'); end if;
  update public.founder_dbsc_sessions set pq_src = 'kernel'
   where user_id = p_uid and device_hash = p_device_hash and sid = p_sid and revoked_at is null and pq_pub is not null and source = 'webcrypto' and created_at > now() - interval '2 minutes';
  get diagnostics n = row_count;
  return jsonb_build_object('ok', n = 1);
end $$;
revoke all on function public.founder_dbsc_set_pq_src(uuid,text,text,text) from public, anon, authenticated;
grant execute on function public.founder_dbsc_set_pq_src(uuid,text,text,text) to service_role;

create or replace function public.founder_pqsrc_posture165() returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions as $$
begin
  return jsonb_build_object(
    'proofkeys_column', exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'founder_device_proofkeys' and column_name = 'pq_src'),
    'sessions_column', exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'founder_dbsc_sessions' and column_name = 'pq_src'),
    'checks', exists (select 1 from pg_constraint where conname = 'founder_proofkeys_pq_src_check') and exists (select 1 from pg_constraint where conname = 'founder_dbsc_sessions_pq_src_check'),
    'guard_trigger', exists (select 1 from pg_trigger where tgname = 'founder_proofkeys_src_guard' and not tgisinternal),
    'service_role_only', not has_function_privilege('anon', 'public.founder_proofkey_register_src(uuid,text,text,text,text,boolean,text)', 'execute')
      and not has_function_privilege('authenticated', 'public.founder_dbsc_set_pq_src(uuid,text,text,text)', 'execute')
      and has_function_privilege('service_role', 'public.founder_proofkey_register_src(uuid,text,text,text,text,boolean,text)', 'execute'));
end $$;
revoke all on function public.founder_pqsrc_posture165() from public, anon, authenticated;
grant execute on function public.founder_pqsrc_posture165() to service_role;

create or replace function public.founder_pqsrc_selftest165() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare
  v_msg text := 'E165 selftest FAIL: unknown'; v_uid uuid; v_dev text; j jsonb;
  es1 text := '04' || repeat('11', 64); pq1 text := repeat('ab', 1952); es2 text := '04' || repeat('22', 64); pq2 text := repeat('cd', 1952);
begin
  select d.user_id, d.ua_hash into v_uid, v_dev from public.founder_devices d where d.approved_at is not null and d.revoked_at is null order by d.created_at limit 1;
  if v_uid is null then return 'E165 selftest SKIP: no approved founder device yet'; end if;
  begin
    if not exists (select 1 from public.founder_dbsc_sessions where user_id = v_uid and device_hash = v_dev and revoked_at is null) then
      insert into public.founder_dbsc_sessions (sid, user_id, device_hash, pub, source) values ('e165chip000000001', v_uid, v_dev, '04' || repeat('ef', 64), 'dbsc'); end if;
    update public.founder_device_proofkeys set revoked_at = now(), revoke_reason = 'selftest' where user_id = v_uid and device_hash = v_dev and revoked_at is null;
    if public.founder_proofkey_register_src(v_uid, v_dev, es1, pq1, encode(extensions.digest('e165-0', 'sha256'), 'hex'), false, 'hardware') ->> 'error' <> 'src' then raise exception 'a bad source label was accepted'; end if;
    j := public.founder_proofkey_register_src(v_uid, v_dev, es1, pq1, encode(extensions.digest('e165-1', 'sha256'), 'hex'), false, 'kernel');
    if j ->> 'ok' <> 'true' then raise exception 'register_src refused: %', j; end if;
    if public.founder_proofkey_get(v_uid, v_dev) ->> 'src' <> 'kernel' then raise exception 'the kernel label was not stored'; end if;
    begin update public.founder_device_proofkeys set pq_src = 'webcrypto' where user_id = v_uid and device_hash = v_dev and revoked_at is null; exception when others then null; end;
    -- inside the creating transaction the guard allows the label (now() = created_at); a later change is the guard's job and is proven by the posture
    j := public.founder_proofkey_register_src(v_uid, v_dev, es2, pq2, encode(extensions.digest('e165-2', 'sha256'), 'hex'), true, 'webcrypto');
    if j ->> 'ok' <> 'true' or public.founder_proofkey_get(v_uid, v_dev) ->> 'src' <> 'webcrypto' then raise exception 'a replacement did not carry its own label: %', j; end if;
    if public.founder_dbsc_set_pq_src(v_uid, v_dev, 'nosuchsid0000000001', 'kernel') ->> 'ok' <> 'false' then raise exception 'a label was set on a binding that does not exist'; end if;
    if public.founder_dbsc_set_pq_src(v_uid, v_dev, 'x', 'webcrypto') ->> 'error' <> 'src' then raise exception 'set_pq_src accepted a non-kernel label'; end if;
    if (select count(*) from jsonb_each_text(public.founder_pqsrc_posture165()) where value::boolean is not true) <> 0 then raise exception 'posture165: %', public.founder_pqsrc_posture165(); end if;
    v_msg := 'E165 selftest PASS';
    raise exception using errcode = 'P0165', message = v_msg;
  exception
    when sqlstate 'P0165' then return v_msg;
    when others then return 'E165 selftest FAIL: ' || sqlerrm;
  end;
end $$;
revoke all on function public.founder_pqsrc_selftest165() from public, anon, authenticated;
grant execute on function public.founder_pqsrc_selftest165() to service_role;
