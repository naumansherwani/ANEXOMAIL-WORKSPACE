
-- CHECK E201 - awam package caps final. Writes nothing (the selftest rolls itself back). Every row must be true.
select item, ok from (
select 'E201 both tables have forced RLS' as item, (public.package_caps_posture201() ->> 'rls_forced')::boolean as ok, 1 as n
union all select 'E201 no grants for anon / authenticated / PUBLIC', (public.package_caps_posture201() ->> 'no_client_grants')::boolean, 2
union all select 'E201 six packages exist in workspace_plans and in the cap table', (public.package_caps_posture201() ->> 'six_packages')::boolean, 3
union all select 'E201 Premium 7,000 and Max strict 125,000', (public.package_caps_posture201() ->> 'premium_7000_max_125000')::boolean, 4
union all select 'E201 Premium and Max are contract-only (not self-serve)', (public.package_caps_posture201() ->> 'premium_max_not_self_serve')::boolean, 5
union all select 'E201 seat guard + alert triggers on org_members', (public.package_caps_posture201() ->> 'guard_triggers')::boolean, 6
union all select 'E201 ledger is append-only (chain, row guard, truncate guard)', (public.package_caps_posture201() ->> 'ledger_append_only')::boolean, 7
union all select 'E201 doors are service_role only', (public.package_caps_posture201() ->> 'doors_service_only')::boolean, 8
union all select 'E201 ledger chain verifies', (public.package_caps_posture201() ->> 'chain_ok')::boolean, 9
union all select 'E201 old 21,000 Premium cap is gone from file_chart (or phase61 not installed)', (public.package_caps_posture201() ->> 'old_21000_gone')::boolean, 10
union all select 'E201 selftest all ok (' || (public.package_caps_selftest201() ->> 'total') || ' checks)', (public.package_caps_selftest201() ->> 'ok')::boolean, 11
union all select 'E201 FACT (not pass/fail): ' || (select count(*) from public.package_cap_ledger) || ' ledger lines, ' || (select count(*) from public.package_cap_alerts_open()) || ' companies at 90 percent or more of their cap, ' || (select count(*) from public.workspace_subscriptions) || ' subscriptions', true, 12
union all select 'E201 facts table has forced RLS', (public.package_facts_posture201() ->> 'rls_forced')::boolean, 13
union all select 'E201 six packages with their chart facts', (public.package_facts_posture201() ->> 'six_facts')::boolean, 14
union all select 'E201 pool = seats x 50 GB for the five capped packages (250 GB, 1 TB, 3 TB, 28.5 TB, 350 TB)', (public.package_facts_posture201() ->> 'pool_is_seats_x_50gb')::boolean, 15
union all select 'E201 Max pool 500 TB is starred (a recommendation, not a promise)', (public.package_facts_posture201() ->> 'max_pool_500tb_starred')::boolean, 16
union all select 'E201 "unlimited" only for Max seats, never Business Pro or Premium', (public.package_facts_posture201() ->> 'unlimited_only_max')::boolean, 17
union all select 'E201 yearly free months: Business 2, Pro 2, Premium 2, Max 3', (public.package_facts_posture201() ->> 'yearly_free_2_2_2_3')::boolean, 18
union all select 'E201 Premium and Max use their own domain for mailboxes', (public.package_facts_posture201() ->> 'own_domain_premium_max')::boolean, 19
union all select 'E201 the public card hides every starred number', (public.package_facts_posture201() ->> 'public_card_hides_stars')::boolean, 20
union all select 'E201 no grants for anon / authenticated / PUBLIC', (public.package_facts_posture201() ->> 'no_client_grants')::boolean, 21
union all select 'E201 facts doors are service_role only', (public.package_facts_posture201() ->> 'doors_service_only')::boolean, 22
union all select 'E201 ledger knows the pool kinds, chain verifies', (public.package_facts_posture201() ->> 'ledger_kinds')::boolean and (public.package_facts_posture201() ->> 'chain_ok')::boolean, 23
union all select 'E201 selftest all ok (' || (public.package_facts_selftest201() ->> 'total') || ' checks)', (public.package_facts_selftest201() ->> 'ok')::boolean, 24
union all select 'E201 FACT (not pass/fail), price differences chart vs workspace_plans: ' || coalesce((public.package_facts_posture201() -> 'price_differences_vs_workspace_plans')::text, '{}'), true, 25
) t order by n;
