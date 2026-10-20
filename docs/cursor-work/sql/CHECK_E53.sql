-- CHECK E53 — sirf padhta hai. Har row ok = true.
select item, ok from (
  select 'E53 auth_session_alive maujood' as item, to_regprocedure('public.auth_session_alive(uuid)') is not null as ok, 1 as o
  union all select 'E53 nakli session = false', public.auth_session_alive('00000000-0000-0000-0000-000000000000') = false, 2
  union all select 'E53 band: anon/authenticated nahi chala sakte',
         not (has_function_privilege('anon', 'public.auth_session_alive(uuid)', 'execute') or has_function_privilege('authenticated', 'public.auth_session_alive(uuid)', 'execute')), 3
  union all select 'E53 service_role chala sakta hai', has_function_privilege('service_role', 'public.auth_session_alive(uuid)', 'execute'), 4
) t order by o;
