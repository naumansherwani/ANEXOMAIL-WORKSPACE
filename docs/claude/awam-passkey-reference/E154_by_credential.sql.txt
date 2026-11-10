
-- ==============================================================================================================================
-- E154 (G-MIX 2b / S7 fix, 10 Nov 2026) - FOUNDER: the passkey sign-in door finds an ACTIVE key by its credential id, and the posture is provable.
-- Found live 10 Nov 20:30 PKT: the passkey tap failed with 503 because Rust read founder_passkeys.passkey directly, but E117 grants service_role
-- NO select on that column (the key body is readable only through a SQL door). This is that door, built to the founder SQL law:
--   * one door, one job: credential id in -> {user_id, passkey, sign_count} out, or null. Unknown, revoked, malformed and not-a-founder look the SAME (null): no account oracle.
--   * the key must belong to a row in founder_accounts (an orphan or non-founder key can never start a founder sign-in).
--   * SECURITY DEFINER, search_path pinned to pg_catalog+public, 3 s statement timeout, STABLE (reads only), no dynamic SQL, input shape checked BEFORE any table is touched.
--   * EXECUTE for service_role only; anon / authenticated / PUBLIC refused. The column stays unreadable directly (E117 posture kept, proven by posture154()).
--   * founder_passkey_posture154() = ONE jsonb of every property above, read from the catalogs (not from memory), so CHECK and the future Devices card can show it.
--   * founder_passkey_selftest154() = rolled-back end-to-end proof (active found, other user's key refused, revoked null, malformed null, shape exact, key body intact).
-- Needs E117 first. Idempotent: safe to run twice. Nothing is deleted or rewritten.
-- ==============================================================================================================================
set lock_timeout = '5s';
set statement_timeout = '60s';

do $$ begin
  perform pg_advisory_xact_lock(hashtextextended('founder_passkey:ddl154', 0));
  if to_regclass('public.founder_passkeys') is null or to_regclass('public.founder_accounts') is null then
    raise exception 'E117 pehle chalao' using errcode = '55000'; end if;
end $$;

create or replace function public.founder_passkey_by_credential(p_credential_id text) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '3s' as $$
declare r record;
begin
  if p_credential_id is null or p_credential_id !~ '^[A-Za-z0-9_-]{16,255}$' then return null; end if;
  select k.user_id, k.passkey, k.sign_count into r
    from public.founder_passkeys k join public.founder_accounts a on a.user_id = k.user_id
   where k.credential_id = p_credential_id and k.revoked_at is null limit 1;
  if not found then return null; end if;
  return jsonb_build_object('user_id', r.user_id, 'passkey', r.passkey, 'sign_count', r.sign_count);
end $$;

-- the posture, read from the catalogs
create or replace function public.founder_passkey_posture154() returns jsonb
language sql stable security definer set search_path = pg_catalog, public as $$
  select jsonb_build_object(
    'door_exists',           to_regprocedure('public.founder_passkey_by_credential(text)') is not null,
    'service_role_execute',  has_function_privilege('service_role', 'public.founder_passkey_by_credential(text)', 'execute'),
    'anon_execute',          has_function_privilege('anon', 'public.founder_passkey_by_credential(text)', 'execute'),
    'authenticated_execute', has_function_privilege('authenticated', 'public.founder_passkey_by_credential(text)', 'execute'),
    'key_column_direct_read', has_column_privilege('service_role', 'public.founder_passkeys', 'passkey', 'select'),
    'security_definer',      coalesce((select p.prosecdef from pg_proc p where p.oid = to_regprocedure('public.founder_passkey_by_credential(text)')), false),
    'search_path_pinned',    coalesce((select p.proconfig::text like '%search_path=pg_catalog, public%' from pg_proc p where p.oid = to_regprocedure('public.founder_passkey_by_credential(text)')), false),
    'read_only_stable',      coalesce((select p.provolatile = 's' from pg_proc p where p.oid = to_regprocedure('public.founder_passkey_by_credential(text)')), false),
    'credential_id_unique',  exists (select 1 from pg_index i where i.indrelid = 'public.founder_passkeys'::regclass and i.indisunique and i.indnatts = 1
                                      and (select attname from pg_attribute where attrelid = i.indrelid and attnum = i.indkey[0]) = 'credential_id'));
$$;

create or replace function public.founder_passkey_selftest154() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare v_msg text := 'E154 selftest FAIL: unknown'; v_uid uuid; v_other uuid; v_c1 text := 'E154SelftestCredential0001'; v_c2 text := 'E154SelftestCredential0002'; v_j jsonb; v_pk jsonb := '{"e154":"key-body-intact"}';
begin
  select user_id into v_uid from public.founder_accounts order by user_id limit 1;
  if v_uid is null then return 'E154 selftest SKIP: no founder account yet'; end if;
  begin
    -- clean slate inside the rolled-back block only (his real keys come back on rollback), so the 5-active limit can never make the test flaky
    update public.founder_passkeys set revoked_at = now(), revoked_reason = 'e154 selftest park' where user_id = v_uid and revoked_at is null;
    insert into public.founder_passkeys (user_id, credential_id, passkey, label) values (v_uid, v_c1, v_pk, 'e154 test');
    v_j := public.founder_passkey_by_credential(v_c1);
    if v_j is null or v_j ->> 'user_id' <> v_uid::text or v_j -> 'passkey' <> v_pk or (v_j ->> 'sign_count')::bigint <> 0 then raise exception 'the active key was not returned exactly'; end if;
    if (select count(*) from jsonb_object_keys(v_j)) <> 3 then raise exception 'the answer shape changed'; end if;
    if public.founder_passkey_by_credential(v_c2) is not null then raise exception 'an unknown credential answered'; end if;
    if public.founder_passkey_by_credential('short') is not null or public.founder_passkey_by_credential(null) is not null or public.founder_passkey_by_credential(v_c1 || '!') is not null
       or public.founder_passkey_by_credential(repeat('A', 300)) is not null then raise exception 'a malformed credential id answered'; end if;
    update public.founder_passkeys set revoked_at = now(), revoked_reason = 'e154 selftest revoke' where credential_id = v_c1;
    if public.founder_passkey_by_credential(v_c1) is not null then raise exception 'a revoked key still answered'; end if;
    -- a key whose owner is not a founder can never answer (checked by the join): simulate by pointing a fresh active key at a user that is not in founder_accounts
    v_other := gen_random_uuid();
    begin
      insert into public.founder_passkeys (user_id, credential_id, passkey, label) values (v_other, v_c2, v_pk, 'e154 orphan');
      if public.founder_passkey_by_credential(v_c2) is not null then raise exception 'a non-founder key answered'; end if;
    exception when foreign_key_violation then null; -- the table itself already refuses such a row: even better
    end;
    if (public.founder_passkey_posture154() ->> 'key_column_direct_read')::boolean then raise exception 'the key column became readable directly'; end if;
    v_msg := 'E154 selftest PASS (active key exact, shape fixed, unknown/malformed/revoked/non-founder all null, key column still closed)';
    raise exception 'e154_rollback' using errcode = 'P0001';
  exception when others then
    if sqlerrm = 'e154_rollback' then null; else v_msg := 'E154 selftest FAIL: ' || sqlerrm; end if;
  end;
  return v_msg;
end $$;

revoke all on function public.founder_passkey_by_credential(text), public.founder_passkey_posture154(), public.founder_passkey_selftest154() from public, anon, authenticated;
grant execute on function public.founder_passkey_by_credential(text), public.founder_passkey_posture154(), public.founder_passkey_selftest154() to service_role;
comment on function public.founder_passkey_by_credential(text) is 'E154: one ACTIVE passkey of a founder by credential id ({user_id, passkey, sign_count}). service_role only; null for unknown, revoked, malformed or non-founder ids.';
comment on function public.founder_passkey_posture154() is 'E154: the passkey door posture read from the catalogs (grants, definer, pinned search_path, stable, column closed).';
