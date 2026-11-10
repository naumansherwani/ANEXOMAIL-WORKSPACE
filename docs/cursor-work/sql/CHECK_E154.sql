
-- CHECK E154 - reads only (the selftest rolls back). 4 checks.
select item, ok from (
select 'E154 the door exists, is for service_role only, definer, pinned search_path, read-only' as item,
       (p ->> 'door_exists')::boolean and (p ->> 'service_role_execute')::boolean and not (p ->> 'anon_execute')::boolean and not (p ->> 'authenticated_execute')::boolean
       and (p ->> 'security_definer')::boolean and (p ->> 'search_path_pinned')::boolean and (p ->> 'read_only_stable')::boolean and (p ->> 'credential_id_unique')::boolean as ok, 1 as ord
  from (select public.founder_passkey_posture154() as p) x
union all select 'E154 the key column is still unreadable directly by service_role (E117 posture kept)', not (public.founder_passkey_posture154() ->> 'key_column_direct_read')::boolean, 2
union all select 'E154 selftest: ' || public.founder_passkey_selftest154(), public.founder_passkey_selftest154() ~ '^E154 selftest (PASS|SKIP)', 3
union all select 'E154 an unknown or malformed credential id gives null (no oracle)', public.founder_passkey_by_credential('NoSuchCredentialIdNoSuchCredentialId') is null and public.founder_passkey_by_credential('x') is null, 4
) t order by ord;
