-- E58 — calendar: alag calendars + rang, working hours, out-of-office (account pasand `awam_ui_pref.extra`) aur
--        har meeting par calendar_key + reminders (22 Oct 2026). E57 ke baad chalti hai. Dobara chalana safe. Koi DROP TABLE/COLUMN nahi.
-- Advance level (Rule 38):
--   * DB khud poori shape check karta hai (awam_ui_extra_ok): sirf 3 keys, calendars 1..20 unique id + hex rang,
--     working hours = 7 din, ooo <= 20 dates ke saath from<=to, note <= 200, size <= 16 KB. Rust ke qaide ka mirror (DB kabhi Rust se sakht nahi).
--   * Naye constraints NOT VALID + VALIDATE: purani badi table par lamba ACCESS EXCLUSIVE lock nahi (sirf SHARE UPDATE EXCLUSIVE).
--   * lock_timeout / statement_timeout: lock na mile to 5s mein saaf fail, live traffic atakti nahi; dobara chalana safe.
--   * Functions IMMUTABLE + PARALLEL SAFE + pinned search_path (search_path hijack nahi).
--   * Reminder timer (agla step) ke liye partial index: sirf wahi events jinki reminder set hai aur cancel nahi hui.
set lock_timeout = '5s';
set statement_timeout = '60s';

-- ---- 1. extra jsonb ka poora validator -------------------------------------------------------------------------
create or replace function public.awam_ui_extra_ok(x jsonb)
returns boolean language plpgsql immutable parallel safe set search_path = pg_catalog, public as $$
declare
  k text; wh jsonb; d jsonb; p jsonb; c jsonb; ids text[] := '{}';
  s text; e text;
begin
  if x is null or jsonb_typeof(x) <> 'object' then return false; end if;
  for k in select jsonb_object_keys(x) loop
    if k not in ('calendars', 'work_hours', 'ooo') then return false; end if;
  end loop;

  if x ? 'calendars' then
    c := x -> 'calendars';
    if jsonb_typeof(c) <> 'array' or jsonb_array_length(c) not between 1 and 20 then return false; end if;
    for p in select * from jsonb_array_elements(c) loop
      if jsonb_typeof(p) <> 'object'
         or jsonb_typeof(p -> 'id') <> 'string' or (p ->> 'id') !~ '^[a-z0-9_-]{1,24}$'
         or (p ->> 'id') = any (ids)
         or jsonb_typeof(p -> 'name') <> 'string' or char_length(btrim(p ->> 'name')) not between 1 and 40
         or jsonb_typeof(p -> 'color') <> 'string' or (p ->> 'color') !~ '^#[0-9a-fA-F]{6}$'
      then return false; end if;
      ids := ids || (p ->> 'id');
    end loop;
  end if;

  if x ? 'work_hours' then
    wh := x -> 'work_hours';
    if jsonb_typeof(wh) <> 'object' or jsonb_typeof(wh -> 'days') <> 'array' or jsonb_array_length(wh -> 'days') <> 7 then
      return false;
    end if;
    for d in select * from jsonb_array_elements(wh -> 'days') loop
      if jsonb_typeof(d) <> 'object' or jsonb_typeof(d -> 'on') <> 'boolean' then return false; end if;
      s := coalesce(d ->> 'start', '09:00');
      e := coalesce(d ->> 'end', '17:00');
      if s !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' or e !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then return false; end if;
      if (d -> 'on') = 'true'::jsonb and s collate "C" >= e collate "C" then return false; end if;
    end loop;
    if wh ? 'tz' and (jsonb_typeof(wh -> 'tz') <> 'string' or (wh ->> 'tz') !~ '^[A-Za-z0-9_/+-]{1,64}$') then
      return false;
    end if;
  end if;

  if x ? 'ooo' then
    if jsonb_typeof(x -> 'ooo') <> 'array' or jsonb_array_length(x -> 'ooo') > 20 then return false; end if;
    for p in select * from jsonb_array_elements(x -> 'ooo') loop
      if jsonb_typeof(p) <> 'object'
         or jsonb_typeof(p -> 'from') <> 'string' or (p ->> 'from') !~ '^[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$'
         or jsonb_typeof(p -> 'to') <> 'string' or (p ->> 'to') !~ '^[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$'
         or (p ->> 'from') > (p ->> 'to')
         or (p ? 'note' and (jsonb_typeof(p -> 'note') <> 'string' or char_length(p ->> 'note') > 200))
      then return false; end if;
    end loop;
  end if;
  return true;
end $$;

create or replace function public.calendar_remind_ok(a integer[])
returns boolean language sql immutable parallel safe set search_path = pg_catalog, public as $$
  select a is null or (coalesce(array_length(a, 1), 0) <= 5
                       and not exists (select 1 from unnest(a) m where m is null or m < 0 or m > 40320))
$$;

-- ---- 2. awam_ui_pref.extra: 4 KB -> 16 KB + poori shape (NOT VALID phir VALIDATE) ------------------------------------
do $$ begin
  if to_regclass('public.awam_ui_pref') is not null then
    alter table public.awam_ui_pref drop constraint if exists awam_ui_pref_extra_ck;
    alter table public.awam_ui_pref add constraint awam_ui_pref_extra_ck
      check (pg_column_size(extra) <= 16384 and public.awam_ui_extra_ok(extra)) not valid;
    alter table public.awam_ui_pref validate constraint awam_ui_pref_extra_ck;
  end if;
end $$;

-- ---- 3. meeting par calendar_key + remind_min ---------------------------------------------------------------------------
-- (calendar_key jsonb ke calendars se jodna FK se nahi ho sakta; Rust meta.set pehle id check karta hai, UI purani id ko default rang deti hai.)
do $$ begin
  if to_regclass('public.calendar_events') is not null then
    alter table public.calendar_events add column if not exists calendar_key text;
    alter table public.calendar_events add column if not exists remind_min integer[];
    if not exists (select 1 from pg_constraint where conname = 'calendar_events_calendar_key_ck') then
      alter table public.calendar_events add constraint calendar_events_calendar_key_ck
        check (calendar_key is null or calendar_key ~ '^[a-z0-9_-]{1,24}$') not valid;
    end if;
    if not exists (select 1 from pg_constraint where conname = 'calendar_events_remind_min_ck') then
      alter table public.calendar_events add constraint calendar_events_remind_min_ck
        check (public.calendar_remind_ok(remind_min)) not valid;
    end if;
    alter table public.calendar_events validate constraint calendar_events_calendar_key_ck;
    alter table public.calendar_events validate constraint calendar_events_remind_min_ck;
    -- reminder timer ka raasta: sirf reminder wali, zinda events (chhota index)
    if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'calendar_events' and column_name = 'cancelled_at')
       and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'calendar_events' and column_name = 'org_id')
       and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'calendar_events' and column_name = 'starts_at') then
      create index if not exists calendar_events_remind_idx on public.calendar_events (starts_at) include (org_id)
        where remind_min is not null and cancelled_at is null;
    end if;
  end if;
end $$;

comment on function public.awam_ui_extra_ok(jsonb) is 'Validates awam_ui_pref.extra (calendars, work_hours, ooo). Mirror of Rust locale_glue clean_extra — never stricter.';
