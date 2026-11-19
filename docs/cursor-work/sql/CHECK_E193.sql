
-- CHECK E193 - company emoji pack (awam only). Writes nothing (the selftest rolls itself back).
select item, ok from (
select 'E193 selftest all ok (' || (public.company_emoji_selftest193() ->> 'passed') || ' passed)' as item, (public.company_emoji_selftest193() ->> 'ok')::boolean as ok, 1 as n
union all select 'E193 every door is service_role only', (public.company_emoji_posture193() ->> 'doors_service_only')::boolean, 2
union all select 'E193 RLS forced on both tables', (public.company_emoji_posture193() ->> 'rls_forced')::boolean, 3
union all select 'E193 anon / authenticated have no table access', (public.company_emoji_posture193() ->> 'anon_no_table_access')::boolean, 4
union all select 'E193 service_role can only read the tables (every write is a door)', (public.company_emoji_posture193() ->> 'service_role_read_only')::boolean, 5
union all select 'E193 3 triggers (guard + ledger update/delete + ledger truncate)', (public.company_emoji_posture193() ->> 'triggers') = '3', 6
union all select 'E193 tier limits business 10 / premium 50 / max 200', (public.company_emoji_posture193() #>> '{tiers,business}') = '10' and (public.company_emoji_posture193() #>> '{tiers,business_premium}') = '50' and (public.company_emoji_posture193() #>> '{tiers,business_max}') = '200', 7
union all select 'E193 every company chain verifies', not exists (select 1 from (select distinct org_id from public.company_emoji_ledger) o where not coalesce((public.company_emoji_verify(o.org_id) ->> 'ok')::boolean, false)), 8
union all select 'E193 advance: ClamAV scan + Storage Box columns, 3 checks, ledger scan/store', (public.company_emoji_posture193() ->> 'advance_cols')::int = 4 and (public.company_emoji_posture193() ->> 'advance_checks')::int = 3 and (public.company_emoji_posture193() ->> 'ledger_actions_ok')::boolean, 9
) t order by n;
