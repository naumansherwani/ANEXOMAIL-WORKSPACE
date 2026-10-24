
-- E83 — Rooms: DB-level guard (loophole band). 24 Oct 2026. E82 ke baad. Dobara chalana safe.
-- Live test mein socha gaya: (1) guest ki jagah room ka address haath se likh dena, (2) booked meeting ko aisay waqt par reschedule/drag karna jahan room dusri meeting ke paas hai —
-- dono raste calendar_room_book se nahi guzarte the. Ab trigger har raste par wohi niyam lagata hai: room sirf apni org ka, zinda (archive nahi), aur overlapping booking nahi.
-- Qaida: sirf live (cancelled nahi) meeting; series ke apne exception/master ek doosre se conflict nahi karte. Repeat meeting ka sirf pehla slot (stored waqt) check hota hai — baqi occurrences ka check nahi (saaf likha hai).
set lock_timeout = '5s';
set statement_timeout = '60s';

do $$ begin
  if to_regclass('public.calendar_rooms') is null then
    raise exception 'E83 PREFLIGHT: calendar_rooms nahi — pehle E82 chalayen' using errcode = 'AX083';
  end if;
end $$;

-- ek room, ek event, ek waqt: error 'room_busy' / 'no_room'. Lock room par (book wale lock jaisa; ek hi transaction mein dobara lena theek).
drop function if exists public.calendar_room_guard(uuid, text);
create or replace function public.calendar_room_guard(p_event uuid, p_address text, p_start timestamptz, p_end timestamptz)
returns void language plpgsql set search_path = pg_catalog, public as $$
declare v_ev record; v_room record;
begin
  select e.id, e.org_id, e.starts_at, e.ends_at, e.series_id, e.status, e.cancelled_at into v_ev from public.calendar_events e where e.id = p_event;
  if not found or v_ev.cancelled_at is not null or coalesce(v_ev.status, 'confirmed') = 'cancelled' then return; end if;
  select r.id, r.org_id, r.archived_at into v_room from public.calendar_rooms r where r.address = lower(p_address);
  if not found or v_room.org_id <> v_ev.org_id or v_room.archived_at is not null then
    raise exception 'no_room' using errcode = 'AX083';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('calendar_room:' || v_room.id::text, 0));
  if exists (
    select 1 from public.calendar_attendees a join public.calendar_events e on e.id = a.event_id
     where lower(a.address) = lower(p_address) and e.org_id = v_ev.org_id and e.id <> v_ev.id
       and (v_ev.series_id is null or e.series_id is distinct from v_ev.series_id)
       and e.starts_at < p_end and e.ends_at > p_start
       and coalesce(e.status, 'confirmed') <> 'cancelled' and e.cancelled_at is null
       and coalesce(a.response, 'needs_action') <> 'declined' and coalesce(e.kind, 'meeting') <> 'hold'
  ) then
    raise exception 'room_busy' using errcode = 'AX083';
  end if;
end $$;

create or replace function public.calendar_attendee_room_trg() returns trigger
language plpgsql set search_path = pg_catalog, public as $$
begin
  if public.calendar_room_address_ok(lower(new.address)) then
    perform public.calendar_room_guard(new.event_id, new.address, (select e.starts_at from public.calendar_events e where e.id = new.event_id), (select e.ends_at from public.calendar_events e where e.id = new.event_id));
  end if;
  return new;
end $$;

create or replace function public.calendar_event_room_trg() returns trigger
language plpgsql set search_path = pg_catalog, public as $$
declare a record;
begin
  if (new.starts_at, new.ends_at) is distinct from (old.starts_at, old.ends_at) and new.cancelled_at is null then
    for a in select address from public.calendar_attendees where event_id = new.id and lower(address) like 'room-%@rooms.anexomail.com' loop
      perform public.calendar_room_guard(new.id, a.address, new.starts_at, new.ends_at);
    end loop;
  end if;
  return new;
end $$;

drop trigger if exists calendar_attendee_room on public.calendar_attendees;
create trigger calendar_attendee_room before insert or update of address, event_id on public.calendar_attendees
  for each row execute function public.calendar_attendee_room_trg();
drop trigger if exists calendar_event_room on public.calendar_events;
create trigger calendar_event_room before update of starts_at, ends_at on public.calendar_events
  for each row execute function public.calendar_event_room_trg();

revoke all on function public.calendar_room_guard(uuid, text, timestamptz, timestamptz) from public, anon, authenticated;
revoke all on function public.calendar_attendee_room_trg() from public, anon, authenticated;
revoke all on function public.calendar_event_room_trg() from public, anon, authenticated;
grant execute on function public.calendar_room_guard(uuid, text, timestamptz, timestamptz) to service_role;
notify pgrst, 'reload schema';
