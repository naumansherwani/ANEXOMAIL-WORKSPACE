-- DIAG (reads only): which part of CHECK_E143 row 5 and row 2 fails on this database.
select 'idx founder_vault_lease_event_once' as item, (select string_agg(indexdef, ' | ') from pg_indexes where indexname = 'founder_vault_lease_event_once') as val
union all select 'col dev_prev_hash', (select count(*)::text from information_schema.columns where table_name = 'founder_vault_lease_event' and column_name = 'dev_prev_hash')
union all select 'view reloptions', (select reloptions::text from pg_class where relname = 'founder_vault_lease_live')
union all select 'constraint ' || conname || ' validated=' || convalidated, pg_get_constraintdef(oid) from pg_constraint where conrelid = 'public.founder_vault_lease'::regclass and contype = 'c'
union all select 'panic open to service_role', has_function_privilege('service_role', 'public.founder_vault_lease_panic(uuid,uuid)', 'execute')::text
union all select 'ledger E143 sha', coalesce((select string_agg(x, ',') from (select 'n/a' x) q), '');
