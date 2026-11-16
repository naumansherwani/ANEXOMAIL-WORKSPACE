
-- CHECK E184 - sending is ON and defaults to ON. Writes nothing.
select item, ok from (
select 'E184 sending is ON now' as item, (select send_enabled from public.fmail_policy where id = 1) as ok, 1 as n
union all select 'E184 column default is true', (select column_default from information_schema.columns where table_schema='public' and table_name='fmail_policy' and column_name='send_enabled') = 'true', 2
union all select 'E184 door audit (E179) clean', not exists (select 1 from public.fmail_door_audit179()), 3
union all select 'E184 selftest all ok', public.fmail_selftest184() = 'E184 selftest: 2 ok, 0 failed', 4
) t order by n;
