-- CHECK E52 — sirf padhta hai. Har row ok = true.
select item, ok from (
  select 'E52 org_alias_cap(basic)=5' as item, public.org_alias_cap('basic') = 5 as ok, 1 as o
  union all select 'E52 org_alias_cap(pro)=5', public.org_alias_cap('pro') = 5, 2
  union all select 'E52 org_alias_cap(business)=unlimited', public.org_alias_cap('business') is null, 3
  union all select 'E52 trigger maujood', exists (select 1 from pg_trigger where tgname = 'org_alias_cap_guard_trg' and not tgisinternal), 4
  union all select 'E52 band: anon/authenticated nahi chala sakte',
         not (has_function_privilege('anon', 'public.org_alias_cap_guard()', 'execute') or has_function_privilege('authenticated', 'public.org_alias_cap_guard()', 'execute')), 5
) t order by o;
