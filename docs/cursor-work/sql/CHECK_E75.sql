
-- CHECK E75 — home city: DB validator ab `home` maanta hai (sirf padhta hai + behaviour test; kuch likhta nahi). Har row ok = true.
select item, ok from (
  select 'E75 validator: sahi home accept' as item,
         public.awam_ui_extra_ok('{"home":{"city":"Lahore","country":"Pakistan","iana":"Asia/Karachi","lat":31.52,"lon":74.36}}'::jsonb) as ok, 1 as o
  union all select 'E75 validator: purani 4 keys ab bhi theek',
         public.awam_ui_extra_ok('{"clocks":["Asia/Karachi"]}'::jsonb) and public.awam_ui_extra_ok('{}'::jsonb), 2
  union all select 'E75 validator: ghalat home reject (khali shehar, lat 91, string lat, ghalat zone, bahari key nahi, array)',
         not public.awam_ui_extra_ok('{"home":{"city":"","country":"","iana":"Asia/Karachi","lat":1,"lon":1}}'::jsonb)
         and not public.awam_ui_extra_ok('{"home":{"city":"X","country":"","iana":"Asia/Karachi","lat":91,"lon":1}}'::jsonb)
         and not public.awam_ui_extra_ok('{"home":{"city":"X","country":"","iana":"Asia/Karachi","lat":"1","lon":1}}'::jsonb)
         and not public.awam_ui_extra_ok('{"home":{"city":"X","country":"","iana":"Asia/../x","lat":1,"lon":1}}'::jsonb)
         and not public.awam_ui_extra_ok('{"home":{"city":"X","country":"","iana":"Asia/Karachi","lat":1,"lon":181}}'::jsonb)
         and not public.awam_ui_extra_ok('{"home":["Lahore"]}'::jsonb)
         and not public.awam_ui_extra_ok('{"nope":1}'::jsonb), 3
  union all select 'E75 function pinned search_path + immutable',
         (select coalesce(p.proconfig::text, '') like '%search_path%' and p.provolatile = 'i' from pg_proc p where p.oid = 'public.awam_ui_extra_ok(jsonb)'::regprocedure), 4
) t order by o;
