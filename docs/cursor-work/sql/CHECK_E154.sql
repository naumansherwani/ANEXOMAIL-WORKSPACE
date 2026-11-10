
-- CHECK E154 - reads only. 3 checks.
select item, ok from (
select 'E154 the door exists and is for service_role only' as item,
       to_regprocedure('public.founder_passkey_by_credential(text)') is not null
       and has_function_privilege('service_role', 'public.founder_passkey_by_credential(text)', 'execute')
       and not has_function_privilege('anon', 'public.founder_passkey_by_credential(text)', 'execute')
       and not has_function_privilege('authenticated', 'public.founder_passkey_by_credential(text)', 'execute') as ok, 1 as ord
union all select 'E154 an unknown or malformed credential id gives null (no oracle)',
       public.founder_passkey_by_credential('NoSuchCredentialIdNoSuchCredentialId') is null and public.founder_passkey_by_credential('x') is null, 2
union all select 'E154 the key body is still unreadable directly by service_role (E117 posture kept)',
       not has_column_privilege('service_role', 'public.founder_passkeys', 'passkey', 'select'), 3
) t order by ord;
