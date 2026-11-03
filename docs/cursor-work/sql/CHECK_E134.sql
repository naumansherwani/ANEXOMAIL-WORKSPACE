
-- CHECK E134 — reads only (the selftest rolls back). 3 checks.
select item, ok from (
select 'E134 the requeue door exists, is service_role only, and the events log knows the value requeued' as item,
       to_regprocedure('public.founder_anchor_requeue(uuid,text,text,text)') is not null
       and not has_function_privilege('anon', 'public.founder_anchor_requeue(uuid,text,text,text)', 'execute') and not has_function_privilege('authenticated', 'public.founder_anchor_requeue(uuid,text,text,text)', 'execute')
       and exists (select 1 from pg_constraint where conrelid = 'public.founder_anchor_events'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%requeued%') as ok, 1 as ord
union all select 'E134 behaviour selftest (refusals, exact set, other causes + switched-off providers untouched, one event + one audit row, second run no-op, rollback clean)',
       coalesce((select public.founder_anchor_e134_selftest() like 'E134 selftest OK%' or public.founder_anchor_e134_selftest() like 'E134 selftest SKIP%'), false), 2
union all select 'E134 the E133 + E124 selftests and the stored evidence chains are still green',
       coalesce((select public.founder_anchor_e133_selftest() like 'E133 selftest OK%' or public.founder_anchor_e133_selftest() like 'E133 selftest SKIP%'), false)
       and coalesce((select public.founder_anchor_e124_selftest() like 'E124 selftest OK%' or public.founder_anchor_e124_selftest() like 'E124 selftest SKIP%'), false)
       and coalesce((public.founder_anchor_verify(500) ->> 'ok')::boolean, false), 3
) t order by ord;
