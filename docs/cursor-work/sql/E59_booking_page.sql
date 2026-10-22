
-- =============================================================================
-- E59 — BOOKING PAGE (B7c): har user ka public `/book/<handle>` link (22 Oct 2026). E31 + E56 + E57 + E58 ke baad chalti hai.
-- Dobara chalana safe (idempotent). Koi DROP TABLE/COLUMN nahi. Fail ho to USI file ko theek karo (naya naam banned).
--
-- Kya banta hai:
--   * booking_pages  : ek user ka ek page (handle, title, durations, buffer, min notice, kitne din aage, time zone, location, on/off).
--                      Working hours + out-of-office E58 (`awam_ui_pref.extra`) se aate hain — alag copy nahi.
--   * bookings       : har booking (visitor, slot, cancel/reschedule ka secret token). calendar_events mein asli meeting bhi banti hai,
--                      to organiser ke calendar mein, conflict/busy/ICS sab pehle se chalta hai.
--   * booking_context / booking_book / booking_manage / booking_cancel / booking_reschedule : Rust (service_role) sirf yeh functions
--                      bulata hai. Saari "do log ek hi slot na len" ki zimmedari DATABASE ki hai:
--                        1. page row par `for update` (ek page par ek waqt mein ek hi booking chal sakti hai),
--                        2. slot dobara VALIDATE hota hai (working hours, out-of-office, min notice, max days, length, busy+buffer),
--                        3. aakhri deewar: EXCLUDE constraint (gist) — kisi bhi bug ke baad bhi overlap table mein ja hi nahi sakta.
--
-- Advance level (Rule 38): lock_timeout/statement_timeout, constraints NOT VALID phir VALIDATE, IMMUTABLE validators, pinned search_path,
--   RLS ON + revoke + sirf service_role, FK ON DELETE (account delete = page + bookings saaf), partial/covering index,
--   comments, aur isi file ke aakhir mein self-test (sab rollback) jo accept/reject/race/cancel/reschedule asli INSERT se saabit karta hai.
-- Limit jo sach hai: ghair-doharane wali (non-recurring) meetings aur bookings DB-level lock ke andar check hoti hain. Organiser ki *doharane wali*
--   meetings ka busy-hona Rust slot nikalte waqt ginta hai (expansion Rust mein hai); booking ke lamhe par woh DB check mein nahi.
-- =============================================================================

-- ============================ PART 1 — schema (ek transaction) ===============================
begin;
set local lock_timeout = '15s';
set local statement_timeout = '120s';
select pg_advisory_xact_lock(hashtext('anexomail.E59'));

-- 0. preflight: jin par yeh file khadi hai woh maujood hain? (na hon to saaf wajah, adhoora kaam nahi)
do $$
declare
  need constant text[] := array[
    'calendar_events.id', 'calendar_events.org_id', 'calendar_events.title', 'calendar_events.starts_at', 'calendar_events.ends_at',
    'calendar_events.organiser', 'calendar_events.sequence', 'calendar_events.cancelled_at', 'calendar_events.tz',
    'calendar_attendees.event_id', 'calendar_attendees.org_id', 'calendar_attendees.address', 'calendar_attendees.response',
    'calendar_attendees.rsvp_token', 'awam_ui_pref.user_id', 'awam_ui_pref.extra'];
  n text;
  missing text[] := '{}';
begin
  foreach n in array need loop
    if not exists (select 1 from information_schema.columns
                    where table_schema = 'public' and table_name = split_part(n, '.', 1) and column_name = split_part(n, '.', 2)) then
      missing := missing || n;
    end if;
  end loop;
  if array_length(missing, 1) > 0 then
    raise exception 'E59: pehle E31 + E56 + E57 + E58 chalayen — yeh columns nahi mile: %', array_to_string(missing, ', ') using errcode = 'AX059';
  end if;
end $$;

-- 1. btree_gist (EXCLUDE constraint ke liye). Na lag sake to saaf notice — tab bhi row-lock + validate DB mein rehte hain.
do $$
begin
  create extension if not exists btree_gist;
exception when others then
  raise notice 'E59: btree_gist nahi lag saka (%). EXCLUDE constraint chhoot jayegi; row-lock + validate phir bhi chalte hain.', sqlerrm;
end $$;

-- 2. validators (IMMUTABLE, pinned search_path) — Rust ke qaide ka mirror, kabhi Rust se sakht nahi
create or replace function public.booking_handle_ok(h text)
returns boolean language sql immutable parallel safe set search_path = pg_catalog, public as $$
  select h is not null and h ~ '^[a-z0-9](?:[a-z0-9-]{1,28})[a-z0-9]$' and h !~ '--'
     and h not in ('admin', 'api', 'app', 'auth', 'book', 'manage', 'new', 'support', 'www', 'anexomail', 'founder', 'billing', 'help')
$$;

create or replace function public.booking_durations_ok(d integer[])
returns boolean language sql immutable parallel safe set search_path = pg_catalog, public as $$
  select d is not null and coalesce(array_length(d, 1), 0) between 1 and 5
     and not exists (select 1 from unnest(d) m where m is null or m < 5 or m > 480)
     and (select count(distinct m) from unnest(d) m) = array_length(d, 1)
$$;

create or replace function public.booking_tz_ok(z text)
returns boolean language sql immutable parallel safe set search_path = pg_catalog, public as $$
  select z is not null and z ~ '^[A-Za-z][A-Za-z0-9_+/-]{0,63}$'
$$;

-- 3. tables
create table if not exists public.booking_pages (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null,
  org_id         uuid not null,
  handle         text not null,
  host_email     text not null,
  host_name      text,
  title          text not null default 'Book a meeting',
  description    text,
  durations      integer[] not null default array[30],
  buffer_min     integer not null default 0,
  min_notice_min integer not null default 240,
  max_days       integer not null default 30,
  timezone       text not null default 'UTC',
  location       text,
  calendar_key   text,
  enabled        boolean not null default false,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
-- dobara chalane par purani table mein naye column aa jayen (idempotent)
alter table public.booking_pages add column if not exists host_name text;
alter table public.booking_pages add column if not exists description text;
alter table public.booking_pages add column if not exists location text;
alter table public.booking_pages add column if not exists calendar_key text;

create unique index if not exists booking_pages_user_uq   on public.booking_pages (user_id);
create unique index if not exists booking_pages_handle_uq on public.booking_pages (lower(handle));

create table if not exists public.bookings (
  id            uuid primary key default gen_random_uuid(),
  page_id       uuid not null references public.booking_pages (id) on delete cascade,
  event_id      uuid,
  starts_at     timestamptz not null,
  ends_at       timestamptz not null,
  visitor_name  text not null,
  visitor_email text not null,
  visitor_tz    text,
  note          text,
  token         uuid not null default gen_random_uuid(),
  status        text not null default 'confirmed',
  reschedules   integer not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  cancelled_at  timestamptz
);
create unique index if not exists bookings_token_uq      on public.bookings (token);
create index        if not exists bookings_page_time_idx on public.bookings (page_id, starts_at) include (ends_at) where status = 'confirmed';
create index        if not exists bookings_visitor_idx   on public.bookings (page_id, lower(visitor_email), created_at);
create index        if not exists bookings_event_idx     on public.bookings (event_id) where event_id is not null;

-- 4. constraints (NOT VALID phir VALIDATE: badi live table par lamba lock nahi)
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'booking_pages_handle_ck') then
    alter table public.booking_pages add constraint booking_pages_handle_ck check (public.booking_handle_ok(handle)) not valid; end if;
  if not exists (select 1 from pg_constraint where conname = 'booking_pages_durations_ck') then
    alter table public.booking_pages add constraint booking_pages_durations_ck check (public.booking_durations_ok(durations)) not valid; end if;
  if not exists (select 1 from pg_constraint where conname = 'booking_pages_tz_ck') then
    alter table public.booking_pages add constraint booking_pages_tz_ck check (public.booking_tz_ok(timezone)) not valid; end if;
  if not exists (select 1 from pg_constraint where conname = 'booking_pages_limits_ck') then
    alter table public.booking_pages add constraint booking_pages_limits_ck check (
      buffer_min between 0 and 120 and min_notice_min between 0 and 43200 and max_days between 1 and 180
      and char_length(title) between 1 and 80 and (description is null or char_length(description) <= 500)
      and (location is null or char_length(location) <= 300) and (host_name is null or char_length(host_name) <= 80)
      and (calendar_key is null or calendar_key ~ '^[a-z0-9_-]{1,24}$')
      and char_length(host_email) between 3 and 254) not valid; end if;
  if not exists (select 1 from pg_constraint where conname = 'bookings_time_ck') then
    alter table public.bookings add constraint bookings_time_ck check (ends_at > starts_at and ends_at - starts_at <= interval '8 hours') not valid; end if;
  if not exists (select 1 from pg_constraint where conname = 'bookings_status_ck') then
    alter table public.bookings add constraint bookings_status_ck check (status in ('confirmed', 'cancelled')) not valid; end if;
  if not exists (select 1 from pg_constraint where conname = 'bookings_visitor_ck') then
    alter table public.bookings add constraint bookings_visitor_ck check (
      char_length(btrim(visitor_name)) between 1 and 80 and char_length(visitor_email) between 5 and 254
      and visitor_email ~ '^[^@\s<>"]+@[^@\s<>"]+\.[^@\s<>"]{2,}$'
      and (visitor_tz is null or public.booking_tz_ok(visitor_tz)) and (note is null or char_length(note) <= 1000)
      and reschedules between 0 and 3) not valid; end if;
  -- aakhri deewar: ek page par do confirmed bookings ka waqt kabhi overlap nahi (btree_gist ho to)
  if exists (select 1 from pg_extension where extname = 'btree_gist')
     and not exists (select 1 from pg_constraint where conname = 'bookings_no_overlap') then
    alter table public.bookings add constraint bookings_no_overlap
      exclude using gist (page_id with =, tstzrange(starts_at, ends_at, '[)') with &&) where (status = 'confirmed');
  end if;
  -- account delete => page + bookings saaf (privacy). auth.users na ho (test DB) to FK chhod do.
  if to_regclass('auth.users') is not null and not exists (select 1 from pg_constraint where conname = 'booking_pages_user_fk') then
    alter table public.booking_pages add constraint booking_pages_user_fk foreign key (user_id) references auth.users (id) on delete cascade not valid;
  end if;
  -- booking ki meeting hat jaye to booking ka event_id khali (booking khud record rehti hai)
  if not exists (select 1 from pg_constraint where conname = 'bookings_event_fk') then
    alter table public.bookings add constraint bookings_event_fk foreign key (event_id) references public.calendar_events (id) on delete set null not valid;
  end if;
end $$;
alter table public.booking_pages validate constraint booking_pages_handle_ck;
alter table public.booking_pages validate constraint booking_pages_durations_ck;
alter table public.booking_pages validate constraint booking_pages_tz_ck;
alter table public.booking_pages validate constraint booking_pages_limits_ck;
alter table public.bookings      validate constraint bookings_time_ck;
alter table public.bookings      validate constraint bookings_status_ck;
alter table public.bookings      validate constraint bookings_visitor_ck;
alter table public.bookings      validate constraint bookings_event_fk;
do $$ begin
  if exists (select 1 from pg_constraint where conname = 'booking_pages_user_fk') then
    alter table public.booking_pages validate constraint booking_pages_user_fk; end if;
end $$;

-- 5. updated_at hamesha DB lagata hai
create or replace function public.booking_touch()
returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin new.updated_at := now(); return new; end $$;
drop trigger if exists booking_pages_touch on public.booking_pages;
create trigger booking_pages_touch before update on public.booking_pages for each row execute function public.booking_touch();
drop trigger if exists bookings_touch on public.bookings;
create trigger bookings_touch before update on public.bookings for each row execute function public.booking_touch();

-- 6. RLS ON, browser (anon/authenticated) ko kuch nahi — sirf Rust (service_role)
alter table public.booking_pages enable row level security;
alter table public.bookings      enable row level security;
revoke all on public.booking_pages from anon, authenticated;
revoke all on public.bookings      from anon, authenticated;
grant select, insert, update, delete on public.booking_pages to service_role;
grant select, insert, update, delete on public.bookings      to service_role;
revoke all on function public.booking_touch() from public, anon, authenticated;

-- 7. slot ka sach — EK jagah (book aur reschedule dono yahi use karte hain). NULL = theek; warna wajah ka code.
--    Working hours + out-of-office page-owner ki E58 settings se; na hon to default Mon–Fri 09:00–17:00.
create or replace function public.booking_slot_problem(p_page public.booking_pages, p_start timestamptz, p_end timestamptz, p_ignore uuid default null)
returns text language plpgsql stable set search_path = pg_catalog, public as $$
declare
  v_minutes integer := (extract(epoch from (p_end - p_start)) / 60)::integer;
  v_local   timestamp;
  v_end_l   timestamp;
  v_extra   jsonb;
  v_day     jsonb;
  v_dow     integer;
  v_from    time;
  v_to      time;
  v_date    text;
  v_ooo     jsonb;
begin
  if not p_page.enabled then return 'not_enabled'; end if;
  if not (v_minutes = any (p_page.durations)) then return 'bad_duration'; end if;
  if p_start < now() + make_interval(mins => p_page.min_notice_min) then return 'too_soon'; end if;
  if p_start > now() + make_interval(days => p_page.max_days) then return 'too_far'; end if;
  if extract(second from p_start) <> 0 or (extract(minute from p_start)::integer % 5) <> 0 then return 'bad_start'; end if;

  v_local := p_start at time zone p_page.timezone;
  v_end_l := p_end   at time zone p_page.timezone;
  v_date  := to_char(v_local, 'YYYY-MM-DD');
  select extra into v_extra from public.awam_ui_pref where user_id = p_page.user_id;
  v_extra := coalesce(v_extra, '{}'::jsonb);

  for v_ooo in select * from jsonb_array_elements(coalesce(v_extra -> 'ooo', '[]'::jsonb)) loop
    if (v_ooo ->> 'from') <= v_date and v_date <= (v_ooo ->> 'to') then return 'out_of_office'; end if;
  end loop;

  v_dow := extract(isodow from v_local)::integer - 1;                     -- 0 = Monday
  v_day := (v_extra -> 'work_hours' -> 'days') -> v_dow;
  if v_day is null then
    if v_dow > 4 then return 'outside_hours'; end if;
    v_from := time '09:00'; v_to := time '17:00';
  else
    if (v_day ->> 'on')::boolean is not true then return 'outside_hours'; end if;
    v_from := coalesce(v_day ->> 'start', '09:00')::time; v_to := coalesce(v_day ->> 'end', '17:00')::time;
  end if;
  if v_end_l::date <> v_local::date or v_local::time < v_from or v_end_l::time > v_to then return 'outside_hours'; end if;

  -- busy + buffer: organiser ki koi bhi (cancel nahi, decline nahi, hold nahi) meeting ya doosri confirmed booking
  if exists (
    select 1 from public.calendar_attendees a
      join public.calendar_events e on e.id = a.event_id
     where e.org_id = p_page.org_id and lower(a.address) = lower(p_page.host_email)
       and e.starts_at < p_end + make_interval(mins => p_page.buffer_min)
       and e.ends_at   > p_start - make_interval(mins => p_page.buffer_min)
       and coalesce(e.status, 'confirmed') <> 'cancelled' and e.cancelled_at is null
       and coalesce(a.response, 'needs_action') <> 'declined' and coalesce(e.kind, 'meeting') <> 'hold'
       and (p_ignore is null or e.id is distinct from (select b.event_id from public.bookings b where b.id = p_ignore))
  ) or exists (
    select 1 from public.bookings b
     where b.page_id = p_page.id and b.status = 'confirmed' and (p_ignore is null or b.id <> p_ignore)
       and b.starts_at < p_end + make_interval(mins => p_page.buffer_min)
       and b.ends_at   > p_start - make_interval(mins => p_page.buffer_min)
  ) then return 'taken'; end if;
  return null;
end $$;

-- 8. public page + Rust ke liye poora context (page + owner ke working hours / out-of-office). Sirf enabled page dikhta hai.
create or replace function public.booking_context(p_handle text)
returns jsonb language plpgsql stable set search_path = pg_catalog, public as $$
declare
  v_page public.booking_pages;
  v_extra jsonb;
begin
  select * into v_page from public.booking_pages where lower(handle) = lower(coalesce(p_handle, '')) and enabled;
  if not found then return jsonb_build_object('found', false); end if;
  select extra into v_extra from public.awam_ui_pref where user_id = v_page.user_id;
  v_extra := coalesce(v_extra, '{}'::jsonb);
  return jsonb_build_object(
    'found', true, 'id', v_page.id, 'org_id', v_page.org_id, 'user_id', v_page.user_id, 'handle', v_page.handle,
    'host_email', v_page.host_email, 'host_name', v_page.host_name, 'title', v_page.title, 'description', v_page.description,
    'durations', to_jsonb(v_page.durations), 'buffer_min', v_page.buffer_min, 'min_notice_min', v_page.min_notice_min,
    'max_days', v_page.max_days, 'timezone', v_page.timezone, 'location', v_page.location,
    'work_hours', v_extra -> 'work_hours',
    'ooo', coalesce((select jsonb_agg(jsonb_build_object('from', o ->> 'from', 'to', o ->> 'to'))   -- note (nijji) kabhi bahar nahi
                       from jsonb_array_elements(coalesce(v_extra -> 'ooo', '[]'::jsonb)) o), '[]'::jsonb));
end $$;

-- 9. BOOK — row-lock + dobara validate + insert (event + guests + booking), sab ek transaction
create or replace function public.booking_book(p_handle text, p_start timestamptz, p_minutes integer, p_name text,
                                               p_email text, p_tz text, p_note text)
returns jsonb language plpgsql set search_path = pg_catalog, public as $$
declare
  v_page   public.booking_pages;
  v_end    timestamptz := p_start + make_interval(mins => p_minutes);
  v_why    text;
  v_name   text := btrim(coalesce(p_name, ''));
  v_email  text := lower(btrim(coalesce(p_email, '')));
  v_note   text := nullif(btrim(coalesce(p_note, '')), '');
  v_event  uuid;
  v_book   public.bookings;
  v_n      integer;
begin
  if p_minutes is null or p_minutes < 5 or p_minutes > 480 or p_start is null then return jsonb_build_object('ok', false, 'code', 'bad_input'); end if;
  if char_length(v_name) not between 1 and 80 or v_email !~ '^[^@\s<>"]+@[^@\s<>"]+\.[^@\s<>"]{2,}$' or char_length(v_email) > 254
     or (v_note is not null and char_length(v_note) > 1000) or (p_tz is not null and not public.booking_tz_ok(p_tz)) then
    return jsonb_build_object('ok', false, 'code', 'bad_input');
  end if;

  select * into v_page from public.booking_pages where lower(handle) = lower(coalesce(p_handle, '')) and enabled for update;   -- (1) ek page, ek waqt, ek booking
  if not found then return jsonb_build_object('ok', false, 'code', 'not_found'); end if;
  if v_email = lower(v_page.host_email) then return jsonb_build_object('ok', false, 'code', 'bad_input'); end if;

  v_why := public.booking_slot_problem(v_page, p_start, v_end);                                                             -- (2) dobara validate
  if v_why is not null then return jsonb_build_object('ok', false, 'code', v_why); end if;

  select count(*) into v_n from public.bookings
   where page_id = v_page.id and lower(visitor_email) = v_email and status = 'confirmed' and ends_at > now();
  if v_n >= 3 then return jsonb_build_object('ok', false, 'code', 'too_many'); end if;
  select count(*) into v_n from public.bookings where page_id = v_page.id and created_at > now() - interval '24 hours';
  if v_n >= 100 then return jsonb_build_object('ok', false, 'code', 'busy_day'); end if;

  begin
    insert into public.calendar_events (org_id, title, agenda, starts_at, ends_at, all_day, location, organiser, kind, status, created_by, tz, sequence)
      values (v_page.org_id, left(v_page.title || ' — ' || v_name, 200), coalesce(v_note, 'Booked through ' || v_page.title),
              p_start, v_end, false, v_page.location, lower(v_page.host_email), 'meeting', 'confirmed', v_page.user_id, v_page.timezone, 0)
      returning id into v_event;
    if v_page.calendar_key is not null and exists (select 1 from information_schema.columns
        where table_schema = 'public' and table_name = 'calendar_events' and column_name = 'calendar_key') then
      execute 'update public.calendar_events set calendar_key = $1 where id = $2' using v_page.calendar_key, v_event;
    end if;
    insert into public.calendar_attendees (event_id, org_id, address, display_name, timezone, response)
      values (v_event, v_page.org_id, lower(v_page.host_email), v_page.host_name, v_page.timezone, 'accepted'),
             (v_event, v_page.org_id, v_email, v_name, p_tz, 'accepted');
    insert into public.bookings (page_id, event_id, starts_at, ends_at, visitor_name, visitor_email, visitor_tz, note)       -- (3) EXCLUDE yahin pakadta hai
      values (v_page.id, v_event, p_start, v_end, v_name, v_email, p_tz, v_note)
      returning * into v_book;
  exception when exclusion_violation then
    return jsonb_build_object('ok', false, 'code', 'taken');
  end;

  return jsonb_build_object('ok', true, 'booking_id', v_book.id, 'event_id', v_event, 'token', v_book.token,
    'starts_at', v_book.starts_at, 'ends_at', v_book.ends_at, 'title', v_page.title, 'host_email', v_page.host_email,
    'host_name', v_page.host_name, 'location', v_page.location, 'timezone', v_page.timezone, 'org_id', v_page.org_id,
    'handle', v_page.handle, 'visitor_name', v_name, 'visitor_email', v_email, 'visitor_tz', p_tz);
end $$;

-- 10. MANAGE (token se) — visitor ki booking dekhna
create or replace function public.booking_manage(p_token uuid)
returns jsonb language plpgsql stable set search_path = pg_catalog, public as $$
declare
  v_book public.bookings;
  v_page public.booking_pages;
begin
  select * into v_book from public.bookings where token = p_token;
  if not found then return jsonb_build_object('found', false); end if;
  select * into v_page from public.booking_pages where id = v_book.page_id;
  return jsonb_build_object('found', true, 'status', v_book.status, 'starts_at', v_book.starts_at, 'ends_at', v_book.ends_at,
    'visitor_name', v_book.visitor_name, 'visitor_email', v_book.visitor_email, 'visitor_tz', v_book.visitor_tz,
    'reschedules', v_book.reschedules, 'can_change', v_book.status = 'confirmed' and v_book.starts_at > now(),
    'handle', v_page.handle, 'title', v_page.title, 'host_name', v_page.host_name, 'host_email', v_page.host_email,
    'location', v_page.location, 'timezone', v_page.timezone, 'minutes', (extract(epoch from (v_book.ends_at - v_book.starts_at)) / 60)::integer,
    'event_id', v_book.event_id, 'org_id', v_page.org_id, 'enabled', v_page.enabled);
end $$;

-- 11. CANCEL — booking + organiser ki meeting dono, sequence +1 (taake CANCEL .ics sahi chale)
create or replace function public.booking_cancel(p_token uuid)
returns jsonb language plpgsql set search_path = pg_catalog, public as $$
declare
  v_book public.bookings;
  v_seq  integer;
begin
  select b.* into v_book from public.bookings b where b.token = p_token for update;
  if not found then return jsonb_build_object('ok', false, 'code', 'not_found'); end if;
  if v_book.status = 'cancelled' then return jsonb_build_object('ok', true, 'already', true); end if;
  if v_book.starts_at <= now() then return jsonb_build_object('ok', false, 'code', 'past'); end if;
  update public.bookings set status = 'cancelled', cancelled_at = now() where id = v_book.id;
  if v_book.event_id is not null then
    update public.calendar_events set status = 'cancelled', cancelled_at = now(), sequence = coalesce(sequence, 0) + 1
     where id = v_book.event_id returning sequence into v_seq;
  end if;
  return jsonb_build_object('ok', true, 'already', false, 'booking_id', v_book.id, 'event_id', v_book.event_id, 'sequence', coalesce(v_seq, 1));
end $$;

-- 12. RESCHEDULE — naya slot wahi validation se (apni purani jagah ko "busy" nahi ginta), sequence +1, 3 baar tak
create or replace function public.booking_reschedule(p_token uuid, p_start timestamptz)
returns jsonb language plpgsql set search_path = pg_catalog, public as $$
declare
  v_book public.bookings;
  v_page public.booking_pages;
  v_mins integer;
  v_end  timestamptz;
  v_why  text;
  v_seq  integer;
begin
  select b.* into v_book from public.bookings b where b.token = p_token;
  if not found then return jsonb_build_object('ok', false, 'code', 'not_found'); end if;
  select * into v_page from public.booking_pages where id = v_book.page_id for update;                                       -- (1)
  select b.* into v_book from public.bookings b where b.token = p_token for update;
  if v_book.status <> 'confirmed' then return jsonb_build_object('ok', false, 'code', 'cancelled'); end if;
  if v_book.starts_at <= now() then return jsonb_build_object('ok', false, 'code', 'past'); end if;
  if v_book.reschedules >= 3 then return jsonb_build_object('ok', false, 'code', 'limit'); end if;
  if p_start is null then return jsonb_build_object('ok', false, 'code', 'bad_input'); end if;
  v_mins := (extract(epoch from (v_book.ends_at - v_book.starts_at)) / 60)::integer;
  v_end := p_start + make_interval(mins => v_mins);
  v_why := public.booking_slot_problem(v_page, p_start, v_end, v_book.id);                                                    -- (2)
  if v_why is not null then return jsonb_build_object('ok', false, 'code', v_why); end if;
  begin
    update public.bookings set starts_at = p_start, ends_at = v_end, reschedules = reschedules + 1 where id = v_book.id;     -- (3)
  exception when exclusion_violation then
    return jsonb_build_object('ok', false, 'code', 'taken');
  end;
  if v_book.event_id is not null then
    update public.calendar_events set starts_at = p_start, ends_at = v_end, sequence = coalesce(sequence, 0) + 1
     where id = v_book.event_id returning sequence into v_seq;
  end if;
  return jsonb_build_object('ok', true, 'booking_id', v_book.id, 'event_id', v_book.event_id, 'sequence', coalesce(v_seq, 1),
    'starts_at', p_start, 'ends_at', v_end);
end $$;

-- 13. functions sirf service_role ke liye
revoke all on function public.booking_slot_problem(public.booking_pages, timestamptz, timestamptz, uuid) from public, anon, authenticated;
revoke all on function public.booking_context(text)                                                       from public, anon, authenticated;
revoke all on function public.booking_book(text, timestamptz, integer, text, text, text, text)           from public, anon, authenticated;
revoke all on function public.booking_manage(uuid)                                                        from public, anon, authenticated;
revoke all on function public.booking_cancel(uuid)                                                        from public, anon, authenticated;
revoke all on function public.booking_reschedule(uuid, timestamptz)                                       from public, anon, authenticated;
grant execute on function public.booking_slot_problem(public.booking_pages, timestamptz, timestamptz, uuid) to service_role;
grant execute on function public.booking_context(text)                                                       to service_role;
grant execute on function public.booking_book(text, timestamptz, integer, text, text, text, text)           to service_role;
grant execute on function public.booking_manage(uuid)                                                        to service_role;
grant execute on function public.booking_cancel(uuid)                                                        to service_role;
grant execute on function public.booking_reschedule(uuid, timestamptz)                                       to service_role;

comment on table  public.booking_pages is 'Public booking page of one user (/book/<handle>). Written only by the Rust engine (service_role). Working hours + out-of-office come from awam_ui_pref.extra (E58).';
comment on table  public.bookings is 'One row per booking. EXCLUDE constraint makes an overlapping confirmed booking on the same page impossible. token = visitor''s secret for cancel/reschedule.';
comment on function public.booking_book(text, timestamptz, integer, text, text, text, text) is 'Atomic: lock page row, re-validate slot, insert event + guests + booking. Returns {ok, code|...}.';
comment on function public.booking_slot_problem(public.booking_pages, timestamptz, timestamptz, uuid) is 'Single source of truth for slot validity (hours, out-of-office, notice, horizon, length, busy+buffer). NULL = ok.';

notify pgrst, 'reload schema';
commit;

-- ============================ PART 2 — self-test (alag transaction, sab rollback) ===============================
-- Fixture na ban sake to SKIPPED likhta hai (schema Part 1 tab bhi lag chuka). Mantiq ki galti = FAIL (exception).
do $$
declare
  v_org uuid; v_user uuid; v_page public.booking_pages; v_h text := 'e59-selftest';
  v_start timestamptz; v_r jsonb; v_t uuid; v_n integer; v_chk integer := 0; v_skip text; v_result text;
  v_owner text := 'owner@e59.test'; v_pair record; v_sql text; v_first boolean := true;
begin
  begin
    -- 1. org: jise calendar_events/attendees.org_id ke SAB FK maante hain (E31 wala tareeqa)
    v_sql := null;
    for v_pair in
      select distinct c.confrelid::regclass as tab, a.attname as col
        from pg_constraint c
        join pg_attribute a on a.attrelid = c.confrelid and a.attnum = c.confkey[1]
       where c.contype = 'f'
         and c.conrelid in ('public.calendar_events'::regclass, 'public.calendar_attendees'::regclass)
         and c.conkey = array[(select x.attnum from pg_attribute x where x.attrelid = c.conrelid and x.attname = 'org_id')]
       order by 1
    loop
      if v_first then v_sql := format('select t.%I from %s t where true', v_pair.col, v_pair.tab); v_first := false;
      else v_sql := v_sql || format(' and exists (select 1 from %s u where u.%I = t.%I)', v_pair.tab, v_pair.col, v_pair.col); end if;
    end loop;
    if v_sql is null then v_org := gen_random_uuid();
    else execute v_sql || ' limit 1' into v_org; if v_org is null then v_skip := 'FK wali table mein koi organisation row nahi'; end if; end if;

    -- 2. user: asli (auth.users), jiska abhi koi booking page nahi; usi ki E58 settings is test mein saaf (sab rollback)
    if v_skip is null then
      if to_regclass('auth.users') is not null then
        execute 'select u.id from auth.users u where not exists (select 1 from public.booking_pages p where p.user_id = u.id) limit 1' into v_user;
        if v_user is null then v_skip := 'auth.users mein aisa user nahi jiska booking page na ho'; end if;
      else v_user := gen_random_uuid(); end if;
    end if;

    if v_skip is null then
      begin
        insert into public.awam_ui_pref (user_id, extra) values (v_user, '{}'::jsonb)
          on conflict (user_id) do update set extra = '{}'::jsonb;
        -- aisa dopahar: 3+ din baad ka Monday 10:00 (page tz UTC) — min notice / horizon / working hours sab theek
        v_start := date_trunc('day', now() + interval '3 days');
        while extract(isodow from v_start) <> 1 loop v_start := v_start + interval '1 day'; end loop;
        v_start := v_start + interval '10 hours';
        insert into public.booking_pages (user_id, org_id, handle, host_email, host_name, title, durations, buffer_min, min_notice_min, max_days, timezone, enabled)
          values (v_user, v_org, v_h, v_owner, 'Selftest Host', 'Selftest page', array[30, 60], 15, 60, 60, 'UTC', true) returning * into v_page;
      exception when others then v_skip := format('fixture nahi bana: %s [%s]', sqlerrm, sqlstate);
      end;
    end if;

    if v_skip is null then
      -- 1. handle ke qaide
      if public.booking_handle_ok('ab') or public.booking_handle_ok('admin') or public.booking_handle_ok('a--b') or not public.booking_handle_ok('ali-khan') then
        raise exception 'E59 FAILED: handle validator' using errcode = 'AX059'; end if;
      v_chk := v_chk + 1;
      -- 2. context: sirf enabled page
      v_r := public.booking_context(v_h);
      if not (v_r ->> 'found')::boolean or v_r ->> 'title' <> 'Selftest page' then raise exception 'E59 FAILED: context %', v_r using errcode = 'AX059'; end if;
      if (public.booking_context('no-such-handle') ->> 'found')::boolean is not false then raise exception 'E59 FAILED: anjaan handle' using errcode = 'AX059'; end if;
      v_chk := v_chk + 1;
      -- 3. theek slot book hota hai; event + 2 guests + booking
      v_r := public.booking_book(v_h, v_start, 30, 'Ali Visitor', 'ALI@visitor.test', 'Asia/Karachi', 'Need a quick chat');
      if not (v_r ->> 'ok')::boolean then raise exception 'E59 FAILED: pehli booking %', v_r using errcode = 'AX059'; end if;
      v_t := (v_r ->> 'token')::uuid;
      select count(*) into v_n from public.calendar_attendees where event_id = (v_r ->> 'event_id')::uuid;
      if v_n <> 2 then raise exception 'E59 FAILED: guests % (2 chahiye)', v_n using errcode = 'AX059'; end if;
      v_chk := v_chk + 1;
      -- 4. wahi slot / overlap / buffer = taken; buffer ke baad ka slot khula
      if public.booking_book(v_h, v_start, 30, 'Bob', 'bob@visitor.test', null, null) ->> 'code' <> 'taken' then raise exception 'E59 FAILED: double booking' using errcode = 'AX059'; end if;
      if public.booking_book(v_h, v_start + interval '15 minutes', 30, 'Bob', 'bob@visitor.test', null, null) ->> 'code' <> 'taken' then raise exception 'E59 FAILED: overlap' using errcode = 'AX059'; end if;
      if public.booking_book(v_h, v_start + interval '40 minutes', 30, 'Bob', 'bob@visitor.test', null, null) ->> 'code' <> 'taken' then raise exception 'E59 FAILED: buffer' using errcode = 'AX059'; end if;
      if not (public.booking_book(v_h, v_start + interval '45 minutes', 30, 'Bob', 'bob@visitor.test', null, null) ->> 'ok')::boolean then raise exception 'E59 FAILED: buffer ke baad ka slot band hai' using errcode = 'AX059'; end if;
      v_chk := v_chk + 1;
      -- 5. EXCLUDE aakhri deewar: seedha INSERT bhi overlap par fail
      if exists (select 1 from pg_constraint where conname = 'bookings_no_overlap') then
        begin
          insert into public.bookings (page_id, starts_at, ends_at, visitor_name, visitor_email) values (v_page.id, v_start, v_start + interval '30 minutes', 'x', 'x@yy.test');
          raise exception 'E59 FAILED: EXCLUDE ne overlap nahi roka' using errcode = 'AX059';
        exception when exclusion_violation then null; end;
        v_chk := v_chk + 1;
      end if;
      -- 6. galat length / jaldi / door / 5-min ke bagair / raat / Saturday / galat input / host khud
      if public.booking_book(v_h, v_start + interval '2 hours', 45, 'Z', 'z@vv.test', null, null) ->> 'code' <> 'bad_duration' then raise exception 'E59 FAILED: bad_duration' using errcode = 'AX059'; end if;
      if public.booking_book(v_h, now() + interval '10 minutes', 30, 'Z', 'z@vv.test', null, null) ->> 'code' <> 'too_soon' then raise exception 'E59 FAILED: too_soon' using errcode = 'AX059'; end if;
      if public.booking_book(v_h, now() + interval '90 days', 30, 'Z', 'z@vv.test', null, null) ->> 'code' <> 'too_far' then raise exception 'E59 FAILED: too_far' using errcode = 'AX059'; end if;
      if public.booking_book(v_h, v_start + interval '3 hours 7 minutes', 30, 'Z', 'z@vv.test', null, null) ->> 'code' <> 'bad_start' then raise exception 'E59 FAILED: bad_start' using errcode = 'AX059'; end if;
      if public.booking_book(v_h, v_start + interval '8 hours', 30, 'Z', 'z@vv.test', null, null) ->> 'code' <> 'outside_hours' then raise exception 'E59 FAILED: raat ka slot' using errcode = 'AX059'; end if;
      if public.booking_book(v_h, v_start + interval '5 days', 30, 'Z', 'z@vv.test', null, null) ->> 'code' <> 'outside_hours' then raise exception 'E59 FAILED: Saturday' using errcode = 'AX059'; end if;
      if public.booking_book(v_h, v_start + interval '2 hours', 30, '', 'not-an-email', null, null) ->> 'code' <> 'bad_input' then raise exception 'E59 FAILED: bad_input' using errcode = 'AX059'; end if;
      if public.booking_book(v_h, v_start + interval '2 hours', 30, 'Me', v_owner, null, null) ->> 'code' <> 'bad_input' then raise exception 'E59 FAILED: host khud ko book' using errcode = 'AX059'; end if;
      v_chk := v_chk + 1;
      -- 7. out-of-office (E58) us din ko band karta hai; uska note bahar nahi jata
      update public.awam_ui_pref set extra = jsonb_build_object('ooo', jsonb_build_array(jsonb_build_object('from', to_char(v_start + interval '7 days', 'YYYY-MM-DD'), 'to', to_char(v_start + interval '7 days', 'YYYY-MM-DD'), 'note', 'secret'))) where user_id = v_user;
      if public.booking_book(v_h, v_start + interval '7 days 2 hours', 30, 'Z', 'z@vv.test', null, null) ->> 'code' <> 'out_of_office' then raise exception 'E59 FAILED: out_of_office' using errcode = 'AX059'; end if;
      if (public.booking_context(v_h) ->> 'ooo') like '%secret%' then raise exception 'E59 FAILED: ooo note leak' using errcode = 'AX059'; end if;
      v_chk := v_chk + 1;
      -- 8. ek visitor ki 3 se zyada booking nahi
      perform public.booking_book(v_h, v_start + interval '1 day 2 hours', 30, 'Cara', 'cara@vv.test', null, null);
      perform public.booking_book(v_h, v_start + interval '1 day 4 hours', 30, 'Cara', 'cara@vv.test', null, null);
      perform public.booking_book(v_h, v_start + interval '1 day 6 hours', 30, 'Cara', 'cara@vv.test', null, null);
      if public.booking_book(v_h, v_start + interval '2 days 2 hours', 30, 'Cara', 'cara@vv.test', null, null) ->> 'code' <> 'too_many' then raise exception 'E59 FAILED: too_many' using errcode = 'AX059'; end if;
      v_chk := v_chk + 1;
      -- 9. manage + reschedule + cancel
      v_r := public.booking_manage(v_t);
      if not (v_r ->> 'found')::boolean or not (v_r ->> 'can_change')::boolean or (v_r ->> 'minutes')::int <> 30 then raise exception 'E59 FAILED: manage %', v_r using errcode = 'AX059'; end if;
      if (public.booking_manage(gen_random_uuid()) ->> 'found')::boolean is not false then raise exception 'E59 FAILED: anjaan token' using errcode = 'AX059'; end if;
      v_r := public.booking_reschedule(v_t, v_start + interval '2 days');
      if not (v_r ->> 'ok')::boolean or (v_r ->> 'sequence')::int <> 1 then raise exception 'E59 FAILED: reschedule %', v_r using errcode = 'AX059'; end if;
      if public.booking_reschedule(v_t, v_start + interval '2 days 9 hours') ->> 'code' <> 'outside_hours' then raise exception 'E59 FAILED: reschedule raat' using errcode = 'AX059'; end if;
      v_r := public.booking_cancel(v_t);
      if not (v_r ->> 'ok')::boolean or (v_r ->> 'sequence')::int <> 2 then raise exception 'E59 FAILED: cancel %', v_r using errcode = 'AX059'; end if;
      if (public.booking_cancel(v_t) ->> 'already')::boolean is not true then raise exception 'E59 FAILED: cancel idempotent' using errcode = 'AX059'; end if;
      if public.booking_reschedule(v_t, v_start + interval '3 days') ->> 'code' <> 'cancelled' then raise exception 'E59 FAILED: cancelled ko reschedule' using errcode = 'AX059'; end if;
      if not (public.booking_book(v_h, v_start + interval '2 days', 30, 'Dan', 'dan@vv.test', null, null) ->> 'ok')::boolean then raise exception 'E59 FAILED: cancel ke baad slot khula nahi' using errcode = 'AX059'; end if;
      v_chk := v_chk + 1;
      v_result := format('PASSED (%s checks, sab rollback)', v_chk);
    else
      v_result := 'SKIPPED: ' || v_skip;
    end if;
    perform set_config('anexo.e59_selftest', v_result, false);   -- rollback se PEHLE nahi: neeche dobara set hota hai
    raise exception 'E59_ROLLBACK' using errcode = 'AX900';
  exception when sqlstate 'AX900' then null;
  end;
  perform set_config('anexo.e59_selftest', coalesce(v_result, 'not run'), false);
end $$;

select 'E59 OK — booking schema lag gaya' as e59_result,
       coalesce(nullif(current_setting('anexo.e59_selftest', true), ''), 'not run') as selftest,
       exists (select 1 from pg_constraint where conname = 'bookings_no_overlap') as exclude_wall,
       (select count(*) from pg_proc where proname like 'booking\_%') as functions;
