
-- E51: calendar.create 500 ka asli sabab (live saboot 21 Oct 00:29):
--   calendar_attendees_response_check 'needs_action' ko rokta tha (live default 'pending'), Rust 'needs_action' bhejta hai.
-- Fix: check ko wapas banao (needs_action + purane pending sab allowed), default needs_action, yatim events cancel,
--      PostgREST cache reload. Idempotent, editor-safe (koi psql \ command nahi).
alter table public.calendar_attendees drop constraint if exists calendar_attendees_response_check;
alter table public.calendar_attendees
  add constraint calendar_attendees_response_check
  check (response in ('needs_action','pending','accepted','declined','tentative'));
alter table public.calendar_attendees alter column response set default 'needs_action';

-- Pichli fail koshishon ke yatim events (attendee ke bina) — hataye nahi, cancel kiye (audit ke liye)
update public.calendar_events e
   set cancelled_at = coalesce(e.cancelled_at, now()), status = 'cancelled'
 where e.cancelled_at is null
   and not exists (select 1 from public.calendar_attendees a where a.event_id = e.id);

-- self-test: asli shape ka insert chalna chahiye (sab rollback hota hai)
do $$
declare o uuid; e uuid; ok boolean := false;
begin
  select id into o from public.orgs limit 1;
  if o is null then raise notice 'E51 selftest skip: koi org nahi'; return; end if;
  begin
    insert into public.calendar_events(org_id,title,agenda,starts_at,ends_at,all_day,organiser,kind,status,sequence)
      values (o,'e51 selftest','e51 selftest agenda',now(),now()+interval '30 min',false,'e51@test.invalid','meeting','confirmed',0)
      returning id into e;
    insert into public.calendar_attendees(event_id,org_id,address,response,invite_status)
      values (e,o,'e51@test.invalid','needs_action','not_sent');
    insert into public.calendar_attendees(event_id,org_id,address,response,invite_status)
      values (e,o,'e51b@test.invalid','accepted','not_sent');
    ok := true;
    raise exception 'e51_rollback';
  exception when others then
    if sqlerrm <> 'e51_rollback' then raise exception 'E51 FAILED: %', sqlerrm; end if;
  end;
  if not ok then raise exception 'E51 FAILED: test insert poora nahi hua'; end if;
end $$;

notify pgrst, 'reload schema';
