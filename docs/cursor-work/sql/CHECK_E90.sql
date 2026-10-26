
-- CHECK E90 — sirf padhta hai. Har row ok = true (last column ok, sql-run.sh ' | f' dhoondta hai).
select item, ok from (
select 'E90 dastoor ke 11 articles (0..10) darj' as item,
       (select count(*) from public.kernel_constitution where article between 0 and 10) = 11 as ok, 1 as n
union all select 'article 0 mein STAMP: Rust + async + Tokio + WebTransport + HMAC-SHA256',
       (select body from public.kernel_constitution where article = 0) ilike '%Rust, async, Tokio, WebTransport%'
       and (select body from public.kernel_constitution where article = 0) ilike '%HMAC-SHA256%', 2
union all select 'dastoor append-only (trigger maujood)',
       exists (select 1 from pg_trigger where tgname = 'kernel_constitution_no_change' and not tgisinternal), 3
union all select 'ek hi current kernel release, hmac@1 samet',
       (select count(*) from public.kernel_releases where status = 'current' and 'hmac@1' = any (modules)) = 1, 4
union all select '5 purposes ki active HMAC chaabi (ticket/chunk/link/webhook/audit)',
       (select count(distinct purpose) from public.kernel_hmac_keys where status = 'active') = 5, 5
union all select 'HMAC chaabi table par koi privilege anon/authenticated/service_role ko nahi',
       not has_table_privilege('anon', 'public.kernel_hmac_keys', 'select')
       and not has_table_privilege('authenticated', 'public.kernel_hmac_keys', 'select')
       and not has_table_privilege('service_role', 'public.kernel_hmac_keys', 'select'), 6
union all select 'har kernel table par RLS on',
       (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
         where n.nspname = 'public' and c.relname in ('kernel_constitution','kernel_releases','kernel_modules','kernel_surfaces',
               'kernel_hmac_keys','kernel_sessions') and c.relrowsecurity) = 6, 7
union all select 'functions SECURITY DEFINER + search_path pinned (sign/verify/ticket/policy)',
       (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
         where n.nspname = 'public' and p.proname in ('kernel_hmac_sign','kernel_hmac_verify','kernel_ticket_issue','kernel_ticket_verify',
               'kernel_request_verify','kernel_policy_check','kernel_report','kernel_constitution_ok','founder_revenue_truth')
           and p.prosecdef and exists (select 1 from unnest(p.proconfig) c where c like 'search_path=%')) = 9, 8
union all select 'sign/verify EXECUTE sirf service_role',
       has_function_privilege('service_role', 'public.kernel_hmac_sign(text,text)', 'execute')
       and not has_function_privilege('anon', 'public.kernel_hmac_sign(text,text)', 'execute')
       and not has_function_privilege('authenticated', 'public.kernel_hmac_verify(text,text,text)', 'execute'), 9
union all select 'HMAC round trip: sahi tag pass, badla hua message fail',
       public.kernel_hmac_verify('audit', 'm', public.kernel_hmac_sign('audit', 'm'))
       and not public.kernel_hmac_verify('audit', 'm2', public.kernel_hmac_sign('audit', 'm')), 10
union all select 'dastoor khud-jaanch ok (koi violation nahi)',
       (public.kernel_constitution_ok()->>'ok')::boolean, 11
union all select 'har registered surface ke liye wildcard *.anexomail.com maujood',
       exists (select 1 from public.kernel_surfaces where host_pattern = '*.anexomail.com' and requires_kernel), 12
union all select 'tampered wasm hash block hota hai',
       (public.kernel_policy_check('anexomail.com', '0.2.0', repeat('0', 64))->>'action') = 'block', 13
union all select 'founder_revenue_truth chalta hai (flat price)',
       (public.founder_revenue_truth()->>'currency') = 'GBP', 14
) q order by n;
