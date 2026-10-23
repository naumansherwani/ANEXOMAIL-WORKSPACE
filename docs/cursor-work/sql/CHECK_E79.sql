-- CHECK E79 — Market chip: DB validator ab `market` (boolean) maanta hai (sirf padhta hai + behaviour test; kuch likhta nahi). Har row ok = true.
select item, ok from (
  select 'E79 validator: market true/false accept' as item,
         public.awam_ui_extra_ok('{"market":true}'::jsonb) and public.awam_ui_extra_ok('{"market":false}'::jsonb) as ok, 1 as o
  union all select 'E79 validator: market ke ghalat roop reject (string, number, null, object, array)',
         not public.awam_ui_extra_ok('{"market":"yes"}'::jsonb) and not public.awam_ui_extra_ok('{"market":1}'::jsonb)
         and not public.awam_ui_extra_ok('{"market":null}'::jsonb) and not public.awam_ui_extra_ok('{"market":{"on":true}}'::jsonb)
         and not public.awam_ui_extra_ok('{"market":[true]}'::jsonb), 2
  union all select 'E79 validator: purane 6 keys ab bhi theek (clocks, home, travel, khali, market ke saath mila)',
         public.awam_ui_extra_ok('{"clocks":["Asia/Karachi"],"market":true}'::jsonb)
         and public.awam_ui_extra_ok('{"travel":{"to_city":"Tokyo","to_zone":"Asia/Tokyo","depart_at":"2026-10-23T14:00:00Z","arrive_at":"2026-10-23T23:00:00Z"}}'::jsonb)
         and public.awam_ui_extra_ok('{}'::jsonb) and not public.awam_ui_extra_ok('{"nope":1}'::jsonb), 3
  union all select 'E79 function pinned search_path + immutable',
         (select coalesce(p.proconfig::text, '') like '%search_path%' and p.provolatile = 'i' from pg_proc p where p.oid = 'public.awam_ui_extra_ok(jsonb)'::regprocedure), 4
) t order by o;
