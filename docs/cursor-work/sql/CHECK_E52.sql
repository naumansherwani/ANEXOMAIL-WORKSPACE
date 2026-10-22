
-- CHECK E52 — sirf padhta hai. Har row ok = true.
select item, ok from (
  select 'E52 trigger maujood' as item, exists (select 1 from pg_trigger where tgname = 'org_alias_fair_use_trg' and not tgisinternal) as ok, 1 as o
  union all select 'E52 band: anon/authenticated nahi chala sakte',
         not (has_function_privilege('anon', 'public.org_alias_fair_use_guard()', 'execute') or has_function_privilege('authenticated', 'public.org_alias_fair_use_guard()', 'execute')), 2
) t order by o;
