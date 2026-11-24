
-- CHECK E202 - awam package facts + pool levels. Writes nothing (the selftest rolls itself back).
select item, ok from (
select 'E202 facts table has forced RLS' as item, (public.package_facts_posture202() ->> 'rls_forced')::boolean as ok, 1 as n
union all select 'E202 six packages with their chart facts', (public.package_facts_posture202() ->> 'six_facts')::boolean, 2
union all select 'E202 pool = seats x 50 GB for the five capped packages (250 GB, 1 TB, 3 TB, 28.5 TB, 350 TB)', (public.package_facts_posture202() ->> 'pool_is_seats_x_50gb')::boolean, 3
union all select 'E202 Max pool 500 TB is starred (a recommendation, not a promise)', (public.package_facts_posture202() ->> 'max_pool_500tb_starred')::boolean, 4
union all select 'E202 "unlimited" only for Max seats, never Business Pro or Premium', (public.package_facts_posture202() ->> 'unlimited_only_max')::boolean, 5
union all select 'E202 yearly free months: Business 2, Pro 2, Premium 2, Max 3', (public.package_facts_posture202() ->> 'yearly_free_2_2_2_3')::boolean, 6
union all select 'E202 Premium and Max use their own domain for mailboxes', (public.package_facts_posture202() ->> 'own_domain_premium_max')::boolean, 7
union all select 'E202 the public card hides every starred number', (public.package_facts_posture202() ->> 'public_card_hides_stars')::boolean, 8
union all select 'E202 no grants for anon / authenticated / PUBLIC', (public.package_facts_posture202() ->> 'no_client_grants')::boolean, 9
union all select 'E202 doors are service_role only', (public.package_facts_posture202() ->> 'doors_service_only')::boolean, 10
union all select 'E202 ledger knows the pool kinds, chain verifies', (public.package_facts_posture202() ->> 'ledger_kinds')::boolean and (public.package_facts_posture202() ->> 'chain_ok')::boolean, 11
union all select 'E202 selftest all ok (' || (public.package_facts_selftest202() ->> 'total') || ' checks)', (public.package_facts_selftest202() ->> 'ok')::boolean, 12
union all select 'E202 FACT (not pass/fail), price differences chart vs workspace_plans: ' || coalesce((public.package_facts_posture202() -> 'price_differences_vs_workspace_plans')::text, '{}'), true, 13
) t order by n;
