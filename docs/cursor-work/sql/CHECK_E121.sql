-- CHECK E121 — kuch persist nahi karta (selftest rollback). Har row ok = true. 3 checks.
select item, ok from (
select 'E121 5 function maujood (_fm_subproof, _fm_consistency_from_leaves, _fm_consistency_check, _fm_g5a_vector, founder_audit_consistency_proof); sab ka execute anon/authenticated ko nahi; sirf darwaza service_role ko khula' as item,
       (select bool_and(to_regprocedure(f) is not null and not has_function_privilege('anon', f, 'execute') and not has_function_privilege('authenticated', f, 'execute'))
          from unnest(array['public._fm_subproof(bytea[],integer,integer,integer,boolean)','public._fm_consistency_from_leaves(bytea[],integer,integer)','public._fm_consistency_check(bigint,bigint,text,text,jsonb)','public._fm_g5a_vector(integer,integer)','public.founder_audit_consistency_proof(bigint,bigint)']) f)
       and has_function_privilege('service_role', 'public.founder_audit_consistency_proof(bigint,bigint)', 'execute')
       and has_function_privilege('service_role', 'public.founder_audit_consistency_selftest()', 'execute') as ok, 1 as ord
union all select 'E121 darwaza SECURITY DEFINER hai aur search_path band hai (pg_catalog, public, extensions)',
       (select bool_and(p.prosecdef and exists (select 1 from unnest(p.proconfig) c where c like 'search_path=%'))
          from pg_proc p where p.oid in ('public.founder_audit_consistency_proof(bigint,bigint)'::regprocedure, 'public.founder_audit_consistency_selftest()'::regprocedure)), 2
union all select 'E121 behaviour selftest: Python reference ke literal vectors, 1..40 patton ki saari 820 jodiyan SQL verifier se saaf, har chhed-chhaad refuse, asli ledger par proof + E107 roots + seals + galat sizes refuse; E107 selftests bhi saaf; chain saaf',
       coalesce((select public.founder_audit_consistency_selftest() like 'E121 selftest OK%'), false)
       and coalesce((select public.founder_audit_merkle_selftest() like 'E107 selftest OK%' or public.founder_audit_merkle_selftest() like 'E107 selftest SKIP%'), false)
       and public.founder_audit_verify(1) is null, 3
) t order by ord;
