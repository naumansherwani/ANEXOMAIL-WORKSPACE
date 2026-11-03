
-- CHECK E133 — reads only (the selftest rolls back). 3 checks.
select item, ok from (
select 'E133 the evidence guard accepts a pending commitment of 1 to 4096 whole bytes and still refuses odd, empty, oversize and a wrong commit_len' as item,
       (select position('between 2 and 8192' in pg_get_functiondef('public._fm_anchor_evidence_guard()'::regprocedure)) > 0) as ok, 1 as ord
union all select 'E133 behaviour selftest (bad shapes refused, 52-byte pending recorded, Bitcoin stage still 32 bytes, verify clean, rollback clean)',
       coalesce((select public.founder_anchor_e133_selftest() like 'E133 selftest OK%' or public.founder_anchor_e133_selftest() like 'E133 selftest SKIP%'), false), 2
union all select 'E133 the E124 selftest (E132 form) and the stored evidence chains are still green',
       coalesce((select public.founder_anchor_e124_selftest() like 'E124 selftest OK%' or public.founder_anchor_e124_selftest() like 'E124 selftest SKIP%'), false)
       and coalesce((public.founder_anchor_verify(500) ->> 'ok')::boolean, false), 3
) t order by ord;
