
-- CHECK E65 — sirf padhta hai. Har row ok = true. Advisor ke warnings ki asli ginti (0 honi chahiye).
select item, ok from (
  select 'E65 koi public table RLS-off nahi' as item,
         not exists (select 1 from pg_class c join pg_namespace s on s.oid = c.relnamespace
                      where s.nspname = 'public' and c.relkind in ('r','p') and not c.relispartition and not c.relrowsecurity
                        and not exists (select 1 from pg_depend d where d.classid = 'pg_class'::regclass and d.objid = c.oid and d.deptype = 'e')) as ok, 1 as o
  union all select 'E65 RLS-on par policy ya privilege-band: anon/authenticated ko bina policy ke koi haq nahi',
         not exists (select 1 from pg_class c join pg_namespace s on s.oid = c.relnamespace
                      where s.nspname = 'public' and c.relkind in ('r','p') and c.relrowsecurity
                        and not exists (select 1 from pg_policy p where p.polrelid = c.oid)), 2
  union all select 'E65 views security_invoker (PG15+)',
         current_setting('server_version_num')::int < 150000
         or not exists (select 1 from pg_class c join pg_namespace s on s.oid = c.relnamespace
                         where s.nspname = 'public' and c.relkind = 'v'
                           and (c.reloptions is null or not (c.reloptions && array['security_invoker=on','security_invoker=true','security_invoker=1']))), 3
  union all select 'E65 functions: search_path pinned (extension-owned chhod kar)',
         not exists (select 1 from pg_proc p join pg_namespace s on s.oid = p.pronamespace
                      where s.nspname = 'public' and p.prokind in ('f','p')
                        and (p.proconfig is null or array_to_string(p.proconfig, ' ') not like '%search_path=%')
                        and not exists (select 1 from pg_depend d where d.classid = 'pg_proc'::regclass and d.objid = p.oid and d.deptype = 'e')), 4
  union all select 'E65 SECURITY DEFINER functions: public/anon execute nahi',
         not exists (select 1 from pg_proc p join pg_namespace s on s.oid = p.pronamespace
                      where s.nspname = 'public' and p.prokind in ('f','p') and p.prosecdef
                        and (has_function_privilege('anon', p.oid, 'execute'))), 5
  union all select 'E65 event trigger ax_rls_auto_enable maujood (nayi tables par RLS khud ON) — superuser na ho to n/a',
         exists (select 1 from pg_event_trigger where evtname = 'ax_rls_auto_enable' and evtenabled <> 'D') or not (select rolsuper from pg_roles where rolname = current_user), 6
) t order by o;
