-- CHECK PHASE 61 — reads only (the selftest rolls back). 5 checks.
select item, ok from (
select 'PHASE 61 the founder chart is the table: 500 MB / 1.5 GB / 4 GB per file, 20 / 570 / unlimited users, no 2/5/7 GB gate, no workspace-wide quota' as item,
       (select count(*) = 4 from public.file_plan_limits where plan in ('business','business_pro','business_premium','enterprise'))
       and not exists (select 1 from public.file_plan_limits where max_file_bytes in (2147483648, 5368709120, 7516192768))
       and (select max_file_bytes from public.file_plan_limits where plan = 'business') = 524288000
       and (select max_file_bytes from public.file_plan_limits where plan = 'business_pro') = 1610612736
       and (select max_file_bytes from public.file_plan_limits where plan = 'business_premium') = 4294967296
       and not exists (select 1 from public.file_plan_limits where plan in ('business','business_pro','business_premium','enterprise') and (transfer_unlimited or monthly_transfer_bytes is not null)) as ok, 1 as ord
union all select 'PHASE 61 quota numbers: 50 / 150 / 400 GB per user per month, burst = per file x 10, org pool 20 x 50 GB and 570 x 150 GB, Premium has no user cap',
       (select per_user_monthly_bytes = 524288000::bigint*100 and org_pool_transfer_bytes = 524288000::bigint*100*20 and burst_hour_bytes = 524288000::bigint*10 from public.file_plan_limits where plan = 'business')
       and (select per_user_monthly_bytes = 161061273600 and org_pool_transfer_bytes = 161061273600::bigint*570 from public.file_plan_limits where plan = 'business_pro')
       and (select per_user_monthly_bytes = 429496729600 and org_pool_transfer_bytes is null and max_users is null from public.file_plan_limits where plan = 'business_premium'), 2
union all select 'PHASE 61 drift guard + never-block constraint installed',
       exists (select 1 from pg_trigger where tgname = 'file_plan_limits_chart' and not tgisinternal and tgenabled <> 'D')
       and exists (select 1 from pg_constraint where conname = 'file_plan_limits_never_block' and convalidated), 3
union all select 'PHASE 61 doors closed to anon/authenticated, open to service_role',
       (select bool_and(not has_function_privilege('anon', f, 'execute') and not has_function_privilege('authenticated', f, 'execute') and has_function_privilege('service_role', f, 'execute'))
        from unnest(array['public.file_chart(text)', 'public.file_quota_level(bigint,bigint)', 'public.file_is_dedup(uuid,uuid)', 'public.file_quota_state(uuid,uuid)', 'public.file_quota_phase61_selftest()']) f), 4
union all select 'PHASE 61 behaviour selftest (chart, guard, 80/100 thresholds, throttle never block, per user, dedup, pool state)',
       coalesce((select public.file_quota_phase61_selftest() like 'PHASE 61 selftest OK%'), false), 5
) t order by ord;
