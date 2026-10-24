-- CHECK E83 — Room guard. Sirf padhta hai. Har row ok = true.
select item, ok from (
  select 'E83 guard function + 2 triggers maujood' as item,
         to_regprocedure('public.calendar_room_guard(uuid,text,timestamptz,timestamptz)') is not null
         and exists (select 1 from pg_trigger where tgname = 'calendar_attendee_room' and not tgisinternal)
         and exists (select 1 from pg_trigger where tgname = 'calendar_event_room' and not tgisinternal) as ok, 1 as o
  union all select 'E83 guard: anon/authenticated execute nahi, search_path pinned',
         not has_function_privilege('anon', 'public.calendar_room_guard(uuid,text,timestamptz,timestamptz)', 'execute')
         and not has_function_privilege('authenticated', 'public.calendar_room_guard(uuid,text,timestamptz,timestamptz)', 'execute')
         and coalesce((select proconfig::text from pg_proc where oid = 'public.calendar_room_guard(uuid,text,timestamptz,timestamptz)'::regprocedure), '') like '%search_path%', 2
  union all select 'E83 guard matn mein room_busy + advisory lock',
         pg_get_functiondef('public.calendar_room_guard(uuid,text,timestamptz,timestamptz)'::regprocedure) like '%room_busy%'
         and pg_get_functiondef('public.calendar_room_guard(uuid,text,timestamptz,timestamptz)'::regprocedure) like '%pg_advisory_xact_lock%', 3
) t order by o;
