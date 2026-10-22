-- CHECK_CAL_GUESTS — sirf padhta hai. 22 Oct 2026: "iMIP test - Gmail Yes" meeting mein guest save nahi hua — saboot.
-- Koi email address print nahi hota, sirf ginti/haal.
select item, ok from (
  select 'event: ' || coalesce((select 'mila, cancelled_at=' || coalesce(cancelled_at::text, 'null') || ' status=' || coalesce(status, '?') || ' tz=' || coalesce(tz, '-') || ' created=' || created_at::text
                                  from public.calendar_events where title like 'iMIP test%' order by created_at desc limit 1), 'NAHI MILA') as item, true as ok, 1 as o
  union all select 'attendee rows is event ke: ' || coalesce((select count(*)::text from public.calendar_attendees a
                      where a.event_id = (select id from public.calendar_events where title like 'iMIP test%' order by created_at desc limit 1)), '0'), true, 2
  union all select 'invite_status ginti: ' || coalesce((select string_agg(invite_status || '=' || n, ', ') from (
                      select invite_status, count(*) n from public.calendar_attendees a
                       where a.event_id = (select id from public.calendar_events where title like 'iMIP test%' order by created_at desc limit 1) group by 1) s), 'koi nahi'), true, 3
  union all select 'invite_error: ' || coalesce((select left(string_agg(distinct coalesce(invite_error, '-'), ' | '), 200) from public.calendar_attendees a
                      where a.event_id = (select id from public.calendar_events where title like 'iMIP test%' order by created_at desc limit 1)), 'koi nahi'), true, 4
  union all select 'triggers calendar_attendees: ' || coalesce((select string_agg(tgname, ', ') from pg_trigger where tgrelid = 'public.calendar_attendees'::regclass and not tgisinternal), 'koi nahi'), true, 5
  union all select 'triggers calendar_events: ' || coalesce((select string_agg(tgname, ', ') from pg_trigger where tgrelid = 'public.calendar_events'::regclass and not tgisinternal), 'koi nahi'), true, 6
  union all select 'attendee columns: ' || (select string_agg(column_name, ',') from information_schema.columns where table_schema='public' and table_name='calendar_attendees'), true, 9
  union all select 'attendee check constraints: ' || coalesce((select string_agg(conname, ', ') from pg_constraint where conrelid = 'public.calendar_attendees'::regclass and contype = 'c'), 'koi nahi'), true, 7
  union all select 'aaj ke events ke attendee rows: ' || (select count(*)::text from public.calendar_attendees a join public.calendar_events e on e.id = a.event_id where e.created_at > now() - interval '1 day'), true, 8
) t order by o;
