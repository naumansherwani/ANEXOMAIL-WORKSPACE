
-- CHECK E78 — Travelling status: DB validator ab `travel` maanta hai (sirf padhta hai + behaviour test; kuch likhta nahi). Har row ok = true.
select item, ok from (
  select 'E78 validator: sahi trip accept (Tokyo, 9 ghante)' as item,
         public.awam_ui_extra_ok('{"travel":{"to_city":"Tokyo","to_zone":"Asia/Tokyo","depart_at":"2026-10-23T14:00:00Z","arrive_at":"2026-10-23T23:00:00Z"}}'::jsonb) as ok, 1 as o
  union all select 'E78 validator: purane 5 keys ab bhi theek',
         public.awam_ui_extra_ok('{"clocks":["Asia/Karachi"]}'::jsonb)
         and public.awam_ui_extra_ok('{"home":{"city":"Lahore","country":"Pakistan","iana":"Asia/Karachi","lat":31.52,"lon":74.36}}'::jsonb)
         and public.awam_ui_extra_ok('{}'::jsonb), 2
  union all select 'E78 validator: ghalat trip reject (khali shehar, ghalat zone, ulta waqt, 72h se lamba, Feb 30, offset waqt, array, faltu field ke bina)',
         not public.awam_ui_extra_ok('{"travel":{"to_city":"","to_zone":"Asia/Tokyo","depart_at":"2026-10-23T14:00:00Z","arrive_at":"2026-10-23T23:00:00Z"}}'::jsonb)
         and not public.awam_ui_extra_ok('{"travel":{"to_city":"Tokyo","to_zone":"Asia/../x","depart_at":"2026-10-23T14:00:00Z","arrive_at":"2026-10-23T23:00:00Z"}}'::jsonb)
         and not public.awam_ui_extra_ok('{"travel":{"to_city":"Tokyo","to_zone":"Asia/Tokyo","depart_at":"2026-10-23T23:00:00Z","arrive_at":"2026-10-23T14:00:00Z"}}'::jsonb)
         and not public.awam_ui_extra_ok('{"travel":{"to_city":"Tokyo","to_zone":"Asia/Tokyo","depart_at":"2026-10-23T14:00:00Z","arrive_at":"2026-10-26T14:00:01Z"}}'::jsonb)
         and not public.awam_ui_extra_ok('{"travel":{"to_city":"Tokyo","to_zone":"Asia/Tokyo","depart_at":"2026-02-30T14:00:00Z","arrive_at":"2026-03-01T14:00:00Z"}}'::jsonb)
         and not public.awam_ui_extra_ok('{"travel":{"to_city":"Tokyo","to_zone":"Asia/Tokyo","depart_at":"2026-10-23T14:00:00+05:00","arrive_at":"2026-10-23T23:00:00Z"}}'::jsonb)
         and not public.awam_ui_extra_ok('{"travel":["Tokyo"]}'::jsonb)
         and not public.awam_ui_extra_ok('{"nope":1}'::jsonb), 3
  union all select 'E78 function pinned search_path + immutable',
         (select coalesce(p.proconfig::text, '') like '%search_path%' and p.provolatile = 'i' from pg_proc p where p.oid = 'public.awam_ui_extra_ok(jsonb)'::regprocedure), 4
) t order by o;
