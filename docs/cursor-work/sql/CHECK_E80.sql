
-- CHECK E80 — CalDAV neev (sirf padhta hai + behaviour test; kuch likhta nahi). Har row ok = true.
select item, ok from (
  select 'E80 RLS on + band: caldav_app_passwords aur caldav_org_state par anon/authenticated ko koi haq nahi' as item,
         (select bool_and(c.relrowsecurity) from pg_class c where c.oid in ('public.caldav_app_passwords'::regclass, 'public.caldav_org_state'::regclass))
         and not has_table_privilege('anon', 'public.caldav_app_passwords', 'select') and not has_table_privilege('authenticated', 'public.caldav_app_passwords', 'select')
         and not has_table_privilege('anon', 'public.caldav_org_state', 'select') and not has_table_privilege('authenticated', 'public.caldav_org_state', 'select') as ok, 1 as o
  union all select 'E80 shape: token_id aur hash ke sahi/ghalat roop',
         public.caldav_token_id_ok('abcdefg234') and not public.caldav_token_id_ok('ABCDEFG234') and not public.caldav_token_id_ok('abc')
         and not public.caldav_token_id_ok('abcdefg189') and not public.caldav_token_id_ok(null)
         and public.caldav_hash_ok(repeat('a', 64)) and not public.caldav_hash_ok(repeat('g', 64)) and not public.caldav_hash_ok(repeat('a', 63)), 2
  union all select 'E80 functions: service_role ke ilawa kisi ko execute nahi',
         not has_function_privilege('anon', 'public.caldav_auth_lookup(text)', 'execute')
         and not has_function_privilege('authenticated', 'public.caldav_auth_lookup(text)', 'execute')
         and not has_function_privilege('authenticated', 'public.caldav_apppw_create(uuid,uuid,text,text,text,text)', 'execute')
         and has_function_privilege('service_role', 'public.caldav_auth_lookup(text)', 'execute'), 3
  union all select 'E80 events par dav_rev/dav_updated_at + dono trigger + ctag function',
         exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'calendar_events' and column_name = 'dav_rev')
         and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'calendar_events' and column_name = 'dav_updated_at')
         and exists (select 1 from pg_trigger where tgname = 'calendar_dav_touch_upd' and tgrelid = 'public.calendar_events'::regclass)
         and exists (select 1 from pg_trigger where tgname = 'calendar_dav_touch_insdel' and tgrelid = 'public.calendar_events'::regclass)
         and public.caldav_ctag('00000000-0000-0000-0000-000000000000'::uuid) >= 1, 4
  union all select 'E80 functions pinned search_path',
         (select bool_and(coalesce(p.proconfig::text, '') like '%search_path%') from pg_proc p where p.oid in (
            'public.caldav_member_ok(uuid,uuid)'::regprocedure, 'public.caldav_apppw_create(uuid,uuid,text,text,text,text)'::regprocedure,
            'public.caldav_auth_lookup(text)'::regprocedure, 'public.caldav_auth_result(uuid,boolean)'::regprocedure, 'public.calendar_dav_touch()'::regprocedure)), 5
) t order by o;
