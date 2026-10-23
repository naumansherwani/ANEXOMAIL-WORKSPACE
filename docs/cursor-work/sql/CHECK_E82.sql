-- CHECK E82 — Rooms. Sirf padhta hai. Har row ok = true.
select item, ok from (
  select 'E82 table + shape constraint VALIDATED' as item,
         to_regclass('public.calendar_rooms') is not null
         and exists (select 1 from pg_constraint c where c.conname = 'calendar_rooms_shape' and c.convalidated) as ok, 1 as o
  union all select 'E82 RLS on + anon/authenticated ko table par koi haq nahi',
         (select relrowsecurity from pg_class where oid = 'public.calendar_rooms'::regclass)
         and not has_table_privilege('anon', 'public.calendar_rooms', 'select')
         and not has_table_privilege('authenticated', 'public.calendar_rooms', 'select'), 2
  union all select 'E82 7 room functions: sirf service_role execute kar sakta hai',
         (select count(*) = 7 from pg_proc where proname in ('calendar_room_create','calendar_room_list','calendar_room_archive','calendar_room_state','calendar_room_book','calendar_room_release','calendar_room_schedule'))
         and not has_function_privilege('authenticated', 'public.calendar_room_book(uuid,uuid,uuid,uuid)', 'execute')
         and not has_function_privilege('anon', 'public.calendar_room_state(uuid,timestamptz,timestamptz,uuid)', 'execute')
         and has_function_privilege('service_role', 'public.calendar_room_book(uuid,uuid,uuid,uuid)', 'execute'), 3
  union all select 'E82 unique indexes (address, zinda naam)',
         exists (select 1 from pg_indexes where indexname = 'calendar_rooms_address_uidx')
         and exists (select 1 from pg_indexes where indexname = 'calendar_rooms_org_name_live_uidx'), 4
  union all select 'E82 book mein advisory lock + room_busy (function ka asli matn)',
         pg_get_functiondef('public.calendar_room_book(uuid,uuid,uuid,uuid)'::regprocedure) like '%pg_advisory_xact_lock%'
         and pg_get_functiondef('public.calendar_room_book(uuid,uuid,uuid,uuid)'::regprocedure) like '%room_busy%', 5
  union all select 'E82 behaviour: anjaan org ki list khali, shape function theek',
         public.calendar_room_list('00000000-0000-0000-0000-000000000000'::uuid) = '[]'::jsonb
         and public.calendar_room_address_ok('room-0123456789ab@rooms.anexomail.com')
         and not public.calendar_room_address_ok('x@rooms.anexomail.com'), 6
) t order by o;
