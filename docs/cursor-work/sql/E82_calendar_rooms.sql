
-- E82 — Calendar #8: ROOMS / RESOURCES (pseudo-attendee, wohi conflict engine). 23 Oct 2026. E31 ke baad. Dobara chalana safe. Koi DROP nahi.
-- Soch: room = ek "guest" jis ka apna pseudo address hai (room-<12 hex>@rooms.anexomail.com). Room book karna = us address ko meeting mein attendee jodna.
--   Is se conflict engine (calendar_busy, RSVP collision, team overlay) bina badle rooms ko bhi dekhta hai. Room par KABHI mail nahi jati (Rust @rooms.anexomail.com ko invite se nikalta hai; yeh domain hamara hai, kisi ka inbox nahi).
-- Double-booking ka ilaaj DB mein: har room par advisory lock (transaction level) + overlap check + insert ek hi function mein => do log ek saath book karein to ek hi jeetega, doosre ko 'room_busy'.
-- Qaide: room banana/hatana sirf owner/admin; book/release sirf meeting ka organiser (ya banane wala) apni hi org mein; archived room book nahi hota; ek org mein max 200 room;
--   room ka naam org mein zinda rooms mein unique (case-insensitive). Privacy: room ki schedule mein SIRF waqt + organiser ka address, meeting ka title/agenda/guests kabhi nahi.
-- Advance: lock_timeout/statement_timeout, NOT VALID -> VALIDATE, IMMUTABLE shape function (pinned search_path), RLS on + service_role policy, sab revoke/grant, partial unique + partial index,
--   constraint_name se saaf error (name_taken vs address retry), koi naya column calendar_attendees par nahi (role CHECK 'required|optional' wahi rahi — room ki pehchaan address ka domain hai).
set lock_timeout = '5s';
set statement_timeout = '60s';

do $$ begin
  if to_regclass('public.calendar_events') is null or to_regclass('public.calendar_attendees') is null then
    raise exception 'E82 PREFLIGHT: calendar_events/calendar_attendees maujood nahi — pehle E31 chalayen' using errcode = 'AX082';
  end if;
  if to_regclass('public.org_members') is null then
    raise exception 'E82 PREFLIGHT: org_members maujood nahi' using errcode = 'AX082';
  end if;
end $$;

-- 1. shape ---------------------------------------------------------------------------------------------------------------
create or replace function public.calendar_room_address_ok(a text)
returns boolean language sql immutable parallel safe set search_path = pg_catalog, public as
$$ select a is not null and a ~ '^room-[0-9a-f]{12}@rooms\.anexomail\.com$' $$;

-- 2. rooms ---------------------------------------------------------------------------------------------------------------
create table if not exists public.calendar_rooms (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null,
  name        text not null,
  kind        text not null default 'room',
  capacity    integer,
  location    text,
  address     text not null,
  created_by  uuid,
  created_at  timestamptz not null default now(),
  archived_at timestamptz
);

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'calendar_rooms_shape' and conrelid = 'public.calendar_rooms'::regclass) then
    alter table public.calendar_rooms add constraint calendar_rooms_shape check (
      char_length(btrim(name)) between 1 and 60
      and kind in ('room', 'resource')
      and (capacity is null or capacity between 1 and 10000)
      and (location is null or char_length(location) <= 120)
      and public.calendar_room_address_ok(address)
    ) not valid;
  end if;
end $$;
alter table public.calendar_rooms validate constraint calendar_rooms_shape;

create unique index if not exists calendar_rooms_address_uidx on public.calendar_rooms (address);
create unique index if not exists calendar_rooms_org_name_live_uidx on public.calendar_rooms (org_id, lower(btrim(name))) where archived_at is null;
create index if not exists calendar_rooms_org_live_idx on public.calendar_rooms (org_id, name) where archived_at is null;

alter table public.calendar_rooms enable row level security;
revoke all on public.calendar_rooms from public, anon, authenticated;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'calendar_rooms' and policyname = 'calendar_rooms_service') then
    create policy calendar_rooms_service on public.calendar_rooms for all to service_role using (true) with check (true);
  end if;
end $$;
comment on table public.calendar_rooms is 'E82: rooms/resources. Pseudo-attendee address rooms.anexomail.com; sirf service_role (Rust cal module).';

-- 3. helpers -------------------------------------------------------------------------------------------------------------
create or replace function public.calendar_room_admin_ok(p_org uuid, p_user uuid)
returns boolean language sql stable set search_path = pg_catalog, public as
$$ select p_org is not null and p_user is not null and exists (
     select 1 from public.org_members m where m.org_id = p_org and m.user_id = p_user and m.status = 'active' and m.role in ('owner', 'admin')) $$;

-- 4. rooms ka CRUD -------------------------------------------------------------------------------------------------------
create or replace function public.calendar_room_create(p_org uuid, p_user uuid, p_name text, p_kind text, p_capacity integer, p_location text)
returns jsonb language plpgsql set search_path = pg_catalog, public as $$
declare v_id uuid; v_addr text; v_n integer; v_try integer := 0; v_con text; v_name text := btrim(coalesce(p_name, '')); v_kind text := coalesce(nullif(btrim(p_kind), ''), 'room');
begin
  if not public.calendar_room_admin_ok(p_org, p_user) then return jsonb_build_object('error', 'forbidden'); end if;
  if char_length(v_name) not between 1 and 60 then return jsonb_build_object('error', 'bad_name'); end if;
  if v_kind not in ('room', 'resource') then return jsonb_build_object('error', 'bad_kind'); end if;
  if p_capacity is not null and p_capacity not between 1 and 10000 then return jsonb_build_object('error', 'bad_capacity'); end if;
  if p_location is not null and char_length(p_location) > 120 then return jsonb_build_object('error', 'bad_location'); end if;
  select count(*) into v_n from public.calendar_rooms where org_id = p_org and archived_at is null;
  if v_n >= 200 then return jsonb_build_object('error', 'too_many'); end if;
  loop
    v_try := v_try + 1;
    v_addr := 'room-' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 12) || '@rooms.anexomail.com';
    begin
      insert into public.calendar_rooms (org_id, name, kind, capacity, location, address, created_by)
      values (p_org, v_name, v_kind, p_capacity, nullif(btrim(coalesce(p_location, '')), ''), v_addr, p_user) returning id into v_id;
      return jsonb_build_object('id', v_id, 'address', v_addr, 'name', v_name);
    exception when unique_violation then
      get stacked diagnostics v_con = constraint_name;
      if v_con is distinct from 'calendar_rooms_address_uidx' then return jsonb_build_object('error', 'name_taken'); end if;
      if v_try >= 5 then return jsonb_build_object('error', 'retry'); end if;
    end;
  end loop;
end $$;

create or replace function public.calendar_room_list(p_org uuid)
returns jsonb language sql stable set search_path = pg_catalog, public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'name', name, 'kind', kind, 'capacity', capacity, 'location', location, 'address', address) order by lower(name)), '[]'::jsonb)
  from public.calendar_rooms where org_id = p_org and archived_at is null $$;

create or replace function public.calendar_room_archive(p_org uuid, p_user uuid, p_id uuid)
returns jsonb language plpgsql set search_path = pg_catalog, public as $$
declare v_n integer;
begin
  if not public.calendar_room_admin_ok(p_org, p_user) then return jsonb_build_object('error', 'forbidden'); end if;
  update public.calendar_rooms set archived_at = now() where id = p_id and org_id = p_org and archived_at is null;
  get diagnostics v_n = row_count;
  return jsonb_build_object('archived', v_n);
end $$;

-- 5. kaun si room is waqt khali hai (event ko chhod kar — edit karte waqt apni hi booking busy na dikhe) ---------------------
create or replace function public.calendar_room_state(p_org uuid, p_from timestamptz, p_to timestamptz, p_exclude_event uuid default null)
returns jsonb language sql stable set search_path = pg_catalog, public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', r.id, 'name', r.name, 'kind', r.kind, 'capacity', r.capacity, 'location', r.location, 'address', r.address,
           'mine', p_exclude_event is not null and exists (select 1 from public.calendar_attendees m where m.event_id = p_exclude_event and m.org_id = p_org and lower(m.address) = r.address),
           'busy', exists (
             select 1 from public.calendar_attendees a join public.calendar_events e on e.id = a.event_id
              where lower(a.address) = r.address and e.org_id = p_org and (p_exclude_event is null or e.id <> p_exclude_event)
                and e.starts_at < p_to and e.ends_at > p_from
                and coalesce(e.status, 'confirmed') <> 'cancelled' and e.cancelled_at is null
                and coalesce(a.response, 'needs_action') <> 'declined' and coalesce(e.kind, 'meeting') <> 'hold')
         ) order by lower(r.name)), '[]'::jsonb)
  from public.calendar_rooms r
  where r.org_id = p_org and r.archived_at is null and p_from < p_to $$;

-- 6. book / release (organiser ke liye; race-safe) -----------------------------------------------------------------------
create or replace function public.calendar_room_book(p_org uuid, p_user uuid, p_event uuid, p_room uuid)
returns jsonb language plpgsql set search_path = pg_catalog, public as $$
declare
  v_email text; v_ev record; v_room record; v_guests integer;
begin
  select lower(m.email) into v_email from public.org_members m where m.org_id = p_org and m.user_id = p_user and m.status = 'active';
  if v_email is null then return jsonb_build_object('error', 'forbidden'); end if;
  select e.id, e.starts_at, e.ends_at, e.organiser, e.created_by, e.location into v_ev
    from public.calendar_events e
   where e.id = p_event and e.org_id = p_org and e.cancelled_at is null and coalesce(e.status, 'confirmed') <> 'cancelled';
  if not found then return jsonb_build_object('error', 'no_event'); end if;
  if v_ev.created_by is distinct from p_user and lower(coalesce(v_ev.organiser, '')) <> v_email then return jsonb_build_object('error', 'not_organiser'); end if;
  select r.id, r.name, r.address, r.capacity, r.location into v_room
    from public.calendar_rooms r where r.id = p_room and r.org_id = p_org and r.archived_at is null;
  if not found then return jsonb_build_object('error', 'no_room'); end if;

  -- is room par ek waqt mein ek hi booking: lock phir check phir insert
  perform pg_advisory_xact_lock(hashtextextended('calendar_room:' || p_room::text, 0));
  if exists (
    select 1 from public.calendar_attendees a join public.calendar_events e on e.id = a.event_id
     where lower(a.address) = v_room.address and e.org_id = p_org and e.id <> p_event
       and e.starts_at < v_ev.ends_at and e.ends_at > v_ev.starts_at
       and coalesce(e.status, 'confirmed') <> 'cancelled' and e.cancelled_at is null
       and coalesce(a.response, 'needs_action') <> 'declined' and coalesce(e.kind, 'meeting') <> 'hold'
  ) then
    return jsonb_build_object('error', 'room_busy');
  end if;

  insert into public.calendar_attendees (event_id, org_id, address, display_name, response, invite_status)
  select p_event, p_org, v_room.address, v_room.name, 'accepted', 'not_sent'
   where not exists (select 1 from public.calendar_attendees a where a.event_id = p_event and lower(a.address) = v_room.address);

  -- jagah khali ho to room ka naam location ban jaye (ICS LOCATION); pehle se likhi hui jagah nahi badalti
  update public.calendar_events set location = coalesce(nullif(btrim(location), ''), v_room.name || coalesce(' — ' || v_room.location, ''))
   where id = p_event and coalesce(nullif(btrim(location), ''), '') = '';

  select count(*) into v_guests from public.calendar_attendees a where a.event_id = p_event and lower(a.address) not like '%@rooms.anexomail.com';
  return jsonb_build_object('booked', true, 'room', v_room.name, 'over_capacity', v_room.capacity is not null and v_guests + 1 > v_room.capacity);
end $$;

create or replace function public.calendar_room_release(p_org uuid, p_user uuid, p_event uuid, p_room uuid)
returns jsonb language plpgsql set search_path = pg_catalog, public as $$
declare v_email text; v_n integer; v_addr text;
begin
  select lower(m.email) into v_email from public.org_members m where m.org_id = p_org and m.user_id = p_user and m.status = 'active';
  if v_email is null then return jsonb_build_object('error', 'forbidden'); end if;
  select r.address into v_addr from public.calendar_rooms r where r.id = p_room and r.org_id = p_org;
  if v_addr is null then return jsonb_build_object('error', 'no_room'); end if;
  if not exists (select 1 from public.calendar_events e where e.id = p_event and e.org_id = p_org
                   and (e.created_by = p_user or lower(coalesce(e.organiser, '')) = v_email)) then
    return jsonb_build_object('error', 'not_organiser');
  end if;
  delete from public.calendar_attendees where event_id = p_event and org_id = p_org and lower(address) = v_addr;
  get diagnostics v_n = row_count;
  return jsonb_build_object('released', v_n);
end $$;

-- room ki schedule: SIRF waqt + organiser (title/agenda/guests kabhi nahi)
create or replace function public.calendar_room_schedule(p_org uuid, p_room uuid, p_from timestamptz, p_to timestamptz)
returns jsonb language sql stable set search_path = pg_catalog, public as $$
  select coalesce(jsonb_agg(jsonb_build_object('starts_at', s.starts_at, 'ends_at', s.ends_at, 'organiser', s.organiser) order by s.starts_at), '[]'::jsonb)
  from (
    select e.starts_at, e.ends_at, e.organiser
      from public.calendar_rooms r
      join public.calendar_attendees a on lower(a.address) = r.address
      join public.calendar_events e on e.id = a.event_id and e.org_id = p_org
     where r.id = p_room and r.org_id = p_org and p_from < p_to
       and e.starts_at < p_to and e.ends_at > p_from
       and coalesce(e.status, 'confirmed') <> 'cancelled' and e.cancelled_at is null
       and coalesce(a.response, 'needs_action') <> 'declined' and coalesce(e.kind, 'meeting') <> 'hold'
     order by e.starts_at limit 200
  ) s $$;

do $$
declare f text;
begin
  foreach f in array array[
    'public.calendar_room_admin_ok(uuid,uuid)', 'public.calendar_room_create(uuid,uuid,text,text,integer,text)', 'public.calendar_room_list(uuid)',
    'public.calendar_room_archive(uuid,uuid,uuid)', 'public.calendar_room_state(uuid,timestamptz,timestamptz,uuid)',
    'public.calendar_room_book(uuid,uuid,uuid,uuid)', 'public.calendar_room_release(uuid,uuid,uuid,uuid)', 'public.calendar_room_schedule(uuid,uuid,timestamptz,timestamptz)'
  ] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

notify pgrst, 'reload schema';
