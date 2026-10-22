-- CHECK E72 — sirf padhta hai. Har row ok = true. (appeal: 20,000 characters + evidence files)
select item, ok from (
  select 'E72 4 tables maujood + RLS ON + anon/authenticated ko koi haq nahi' as item,
         (select count(*) from pg_class where relname in ('appeal_limits', 'appeal_evidence', 'appeal_evidence_links', 'appeal_evidence_access') and relnamespace = 'public'::regnamespace and relrowsecurity) = 4
         and not has_table_privilege('anon', 'public.appeal_evidence', 'select') and not has_table_privilege('authenticated', 'public.appeal_evidence', 'insert')
         and not has_table_privilege('authenticated', 'public.appeal_evidence_access', 'select') as ok, 1 as o
  union all select 'E72 hadein: statement 20000, 5 files, 10MB, 25MB',
         public._ap_limit('statement_max_chars', 0) = 20000 and public._ap_limit('max_files', 0) = 5
         and public._ap_limit('max_file_bytes', 0) = 10000000 and public._ap_limit('max_total_bytes', 0) = 25000000, 2
  union all select 'E72 sab functions maujood: execute sirf service_role',
         (select bool_and(has_function_privilege('service_role', f, 'execute') and not has_function_privilege('anon', f, 'execute') and not has_function_privilege('authenticated', f, 'execute'))
            from unnest(array['public.appeal_evidence_ctx(uuid)', 'public.appeal_evidence_register(uuid,text,bigint,text,text,text,jsonb)', 'public.appeal_evidence_remove(uuid,uuid)',
                              'public.appeal_evidence_attach(uuid,uuid,uuid[])', 'public.device_appeal_open_v2(uuid,text,text,uuid[])', 'public.device_appeal_open(uuid,text,text)',
                              'public.account_integrity_appeal_v2(uuid,text,uuid[])', 'public.account_integrity_appeal(uuid,text)', 'public.appeal_evidence_list(uuid,uuid)',
                              'public.appeal_evidence_resolve(uuid,uuid)', 'public.device_appeal_queue(uuid,text)', 'public.appeal_evidence_purge_list(int)',
                              'public.appeal_evidence_purge_done(uuid[])']) f), 3
  union all select 'E72 sign-up appeal ki had 20000 (purani 2000 wali nahi)',
         exists (select 1 from pg_constraint where conrelid = 'public.identity_signup_appeals'::regclass and conname = 'identity_signup_appeals_statement_20k')
         and not exists (select 1 from pg_constraint where conrelid = 'public.identity_signup_appeals'::regclass and contype = 'c'
                            and pg_get_constraintdef(oid) like '%char_length(statement)%' and pg_get_constraintdef(oid) like '%2000)%' and pg_get_constraintdef(oid) not like '%20000%'), 4
  union all select 'E72 device appeal table par 20000 ki check',
         exists (select 1 from pg_constraint where conrelid = 'public.device_ban_appeals'::regclass and conname = 'device_ban_appeals_statement_20k'), 5
  union all select 'E72 har appeal_*/device_appeal* function ka search_path pinned',
         not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                      where n.nspname = 'public' and (p.proname like 'appeal\_%' or p.proname like 'device\_appeal%' or p.proname like '\_ap%' or p.proname = 'account_integrity_appeal_v2') and p.proconfig is null), 6
  union all select 'E72 invariant: hataai/judi file ka rel_path sirf appeals/<user>/ ke andar',
         not exists (select 1 from public.appeal_evidence where rel_path not like 'appeals/' || user_id::text || '/%'), 7
) q order by o;
