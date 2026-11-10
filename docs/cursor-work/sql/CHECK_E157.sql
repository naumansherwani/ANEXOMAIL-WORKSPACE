
-- CHECK E157 - reads only (the selftest rolls back). 4 checks.
select item, ok from (
select 'E157 posture: both doors service_role only + definer + pinned, session.policy is T2, helpers closed' as item, (select bool_and(value::boolean) from jsonb_each_text(public.founder_session_posture157())) as ok, 1 as ord
union all select 'E157 selftest: ' || public.founder_session_selftest157(), public.founder_session_selftest157() ~ '^E157 selftest (PASS|SKIP)', 2
union all select 'E157 the E156 posture still holds', (select bool_and(value::boolean) from jsonb_each_text(public.founder_session_posture156())), 3
union all select 'E157 a digest for a made-up session is refused', public.founder_session_policy_digest((select user_id from public.founder_accounts limit 1), repeat('0', 64), 'off', '{}', 'alert', 900, 20, 10, 4, 'alert', 86400, 604800, 'PK', 'check made-up session', 'n157checkcheck001') ->> 'error' = 'session_not_live', 4
) t order by ord;
