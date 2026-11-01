-- CHECK E107 — kuch persist nahi karta (selftest rollback). Har row ok = true.
select item, ok from (
select 'E107 tables maujood + RLS on + anon/authenticated ko access nahi' as item,
       (select bool_and(to_regclass(t) is not null and (select relrowsecurity from pg_class where oid = to_regclass(t))
                        and not has_table_privilege('anon', t, 'select') and not has_table_privilege('authenticated', t, 'select'))
          from unnest(array['public.founder_audit_checkpoints','public.founder_audit_merkle_policy']) t) as ok, 1 as ord
union all select 'E107 RPC maujood, anon/authenticated execute nahi, service_role hai',
       (select bool_and(to_regprocedure(f) is not null and not has_function_privilege('anon', f, 'execute') and not has_function_privilege('authenticated', f, 'execute') and has_function_privilege('service_role', f, 'execute'))
          from unnest(array['public.founder_audit_merkle_root(bigint)','public.founder_audit_merkle_proof(bigint,bigint)','public.founder_audit_proof_check(text,jsonb,text)',
                            'public.founder_audit_checkpoint(uuid,text)','public.founder_audit_checkpoint_due()','public.founder_audit_checkpoint_verify(integer)',
                            'public.founder_audit_checkpoint_list(integer)','public.founder_audit_consistency(bigint)','public.founder_audit_export(bigint,bigint)',
                            'public.founder_audit_merkle_stats()','public.founder_audit_merkle_pulse()','public.founder_audit_merkle_vectors()','public.founder_audit_merkle_selftest()',
                            'public.founder_audit_checkpoint_preview()','public.founder_audit_merkle_verify_range(bigint,bigint)','public.founder_audit_merkle_crosscheck()']) f), 2
union all select 'E107 checkpoints append-only triggers chalu',
       (select count(*) from pg_trigger where tgrelid = to_regclass('public.founder_audit_checkpoints') and tgname in ('founder_audit_checkpoints_no_upd','founder_audit_checkpoints_no_trunc')) = 2
       and not has_table_privilege('service_role', 'public.founder_audit_checkpoints', 'update') and not has_table_privilege('service_role', 'public.founder_audit_checkpoints', 'delete'), 3
union all select 'E107 security definer RPC par search_path + statement_timeout pinned',
       (select bool_and(exists (select 1 from unnest(proconfig) c where c like 'search_path=%') and exists (select 1 from unnest(proconfig) c where c like 'statement_timeout=%'))
          from pg_proc where oid in (to_regprocedure('public.founder_audit_checkpoint(uuid,text)'), to_regprocedure('public.founder_audit_merkle_root(bigint)'),
                                     to_regprocedure('public.founder_audit_merkle_proof(bigint,bigint)'), to_regprocedure('public.founder_audit_export(bigint,bigint)'),
                                     to_regprocedure('public.founder_audit_merkle_stats()'))), 4
union all select 'E107 policy row maujood (ek hi)', (select count(*) from public.founder_audit_merkle_policy) = 1, 5
union all select 'E107 tree qaida: RFC 6962 recursive == iterative (1..70 leaves)', public.founder_audit_merkle_crosscheck() like 'E107 crosscheck OK%', 6
union all select 'E107 behaviour selftest (hash qaide, tree, vectors, proofs, checkpoint chain, append-only, due/pulse/stats/policy, export, tamper)',
       coalesce((select public.founder_audit_merkle_selftest() like 'E107 selftest OK%' or public.founder_audit_merkle_selftest() like 'E107 selftest SKIP%'), false), 7
union all select 'E107 selftest2 (preview, range verify, leaf, rule)',
       coalesce((select public.founder_audit_merkle_selftest2() like 'E107 selftest2 OK%' or public.founder_audit_merkle_selftest2() like 'E107 selftest2 SKIP%'), false), 8
union all select 'E107 asli chain par root jawab deta hai', coalesce((select public.founder_audit_merkle_root() ? 'root'), false), 9
union all select 'E107 checkpoints saaf (aakhri 20)', public.founder_audit_checkpoint_verify(20) is null, 10
union all select 'E107 live source audit_checkpoints register', exists (select 1 from public.founder_live_sources where key = 'audit_checkpoints'), 11
union all select 'E107 audit chain saaf (E102)', public.founder_audit_verify(1) is null, 12
) t order by ord;
