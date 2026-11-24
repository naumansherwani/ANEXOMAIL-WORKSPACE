
select t.label, t.ok from (
select 'E202 workspace_plans holds his final prices (40 / 105 / 360 / 2850)' as label, (public.package_price_posture202() ->> 'plans_final')::boolean as ok, 1 as n
union all select 'E202 no old price (23 / 46 / 97) left in workspace_plans', (public.package_price_posture202() ->> 'no_old_price_in_plans')::boolean, 2
union all select 'E202 price book holds the final numbers (or the table is not here)', (public.package_price_posture202() ->> 'price_book_final')::boolean, 3
union all select 'E202 billing function: Business 360, yearly 3600, no 97 left', (public.package_price_posture202() ->> 'billing_function_final')::boolean, 4
union all select 'E202 flat_plan_price (E90) agrees with the table', (public.package_price_posture202() ->> 'flat_plan_price_agrees')::boolean, 5
union all select 'E202 ledger is append-only with forced RLS', (public.package_price_posture202() ->> 'ledger_append_only')::boolean, 6
union all select 'E202 ledger chain verifies', (public.package_price_posture202() ->> 'chain_ok')::boolean, 7
union all select 'E202 no grants for anon / authenticated / PUBLIC on the ledger', (public.package_price_posture202() ->> 'no_client_grants')::boolean, 8
union all select 'E202 FACT (not pass/fail): ' || (select count(*) from public.package_price_ledger) || ' price lines written, ' || (select count(*) from public.workspace_subscriptions) || ' subscriptions (no customer was ever charged on the old figure when 0)', true, 9
) t order by t.n;
