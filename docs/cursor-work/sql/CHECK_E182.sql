
-- CHECK E182 - the sending switch exists, defaults/keeps a real value, is ledgered and closed to anon. Writes nothing (the selftest rolls back).
select item, ok from (
select 'E182 policy has send_enabled' as item, exists (select 1 from information_schema.columns where table_schema='public' and table_name='fmail_policy' and column_name='send_enabled') as ok, 1 as n
union all select 'E182 claim honours the switch', (select pg_get_functiondef('public.fmail_outbox_claim(integer)'::regprocedure) like '%send_enabled%'), 2
union all select 'E182 policy_set knows the key', (select pg_get_functiondef('public.fmail_policy_set(uuid,text,text,text)'::regprocedure) like '%''send_enabled''%'), 3
union all select 'E182 doors service_role only', has_function_privilege('service_role','public.fmail_sending_set182(uuid,boolean,text)','execute') and has_function_privilege('service_role','public.fmail_sending_state182()','execute') and not has_function_privilege('anon','public.fmail_sending_set182(uuid,boolean,text)','execute'), 4
union all select 'E182 door audit (E179) clean', not exists (select 1 from public.fmail_door_audit179()), 5
union all select 'E182 selftest all ok', public.fmail_selftest182() like 'E182 selftest: 8 ok, 0 failed', 6
) t order by n;
