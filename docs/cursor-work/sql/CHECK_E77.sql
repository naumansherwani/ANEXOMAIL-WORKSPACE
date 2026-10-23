
-- CHECK E77 — RSVP collision warning (sirf padhta hai). Har row ok = true.
select item, ok from (
  select 'E77 calendar_rsvp_conflicts(uuid) maujood, STABLE, pinned search_path' as item,
         exists (select 1 from pg_proc p where p.oid = 'public.calendar_rsvp_conflicts(uuid)'::regprocedure
                  and p.provolatile = 's' and coalesce(p.proconfig::text, '') like '%search_path%') as ok, 1 as o
  union all select 'E77 execute sirf service_role (anon/authenticated nahi)',
         has_function_privilege('service_role', 'public.calendar_rsvp_conflicts(uuid)', 'execute')
         and not has_function_privilege('anon', 'public.calendar_rsvp_conflicts(uuid)', 'execute')
         and not has_function_privilege('authenticated', 'public.calendar_rsvp_conflicts(uuid)', 'execute'), 2
  union all select 'E77 ajnabi token = khali jawab (count 0, token ka wujood leak nahi)',
         (public.calendar_rsvp_conflicts('00000000-0000-0000-0000-000000000000'::uuid) ->> 'count')::int = 0
         and public.calendar_rsvp_conflicts('00000000-0000-0000-0000-000000000000'::uuid) -> 'overlaps' = '[]'::jsonb, 3
) t order by o;
