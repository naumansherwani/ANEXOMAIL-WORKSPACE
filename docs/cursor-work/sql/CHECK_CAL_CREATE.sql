-- READ-ONLY diagnosis: calendar.create 500. Sab kuch ROLLBACK hota hai.
\echo == calendar_events columns
select column_name, data_type, is_nullable, column_default from information_schema.columns where table_schema='public' and table_name='calendar_events' order by ordinal_position;
\echo == calendar_attendees columns
select column_name, data_type, is_nullable, column_default from information_schema.columns where table_schema='public' and table_name='calendar_attendees' order by ordinal_position;
\echo == check constraints
select conrelid::regclass, conname, pg_get_constraintdef(oid) from pg_constraint where conrelid in ('public.calendar_events'::regclass,'public.calendar_attendees'::regclass) and contype in ('c','f');
\echo == triggers
select event_object_table, trigger_name, action_statement from information_schema.triggers where event_object_table in ('calendar_events','calendar_attendees');
\echo == test insert (rollback) — basic.test org
begin;
do $$
declare o uuid; u uuid; e uuid;
begin
  select m.org_id, m.user_id into o, u from public.org_members m join auth.users a on a.id=m.user_id where lower(a.email)='basic.test@anexomail.com' limit 1;
  raise notice 'org=% user=%', o, u;
  insert into public.calendar_events(org_id,title,agenda,starts_at,ends_at,all_day,organiser,kind,status,created_by,tz,sequence)
    values (o,'diag','diag agenda',now(),now()+interval '30 min',false,'basic.test@anexomail.com','meeting','confirmed',u,null,0) returning id into e;
  raise notice 'EVENT OK %', e;
  insert into public.calendar_attendees(event_id,org_id,address,timezone,response,invite_status)
    values (e,o,'basic.test@anexomail.com',null,'accepted','not_sent');
  raise notice 'ATTENDEE OK';
exception when others then raise notice 'FAIL: % | %', sqlstate, sqlerrm;
end $$;
rollback;
\echo == orphan events (event bina attendee)
select e.id, e.title, e.created_at from public.calendar_events e where not exists (select 1 from public.calendar_attendees a where a.event_id=e.id) order by e.created_at desc limit 10;
