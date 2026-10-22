
-- =============================================================================
-- E56 — Calendar recurrence (B7b, 22 Oct 2026): repeating meetings for EVERY package (koi plan-gating nahi).
--
-- Kya judta hai (sirf additive + idempotent — koi drop/rename nahi):
--   calendar_events.rrule          : RFC 5545 rule ("FREQ=WEEKLY;BYDAY=MO,WE") — sirf "master" row par
--   calendar_events.exdates        : jo instances hata di gayin / alag row bana di gayin (UTC starts)
--   calendar_events.series_id      : exception row -> master ka id ("sirf yeh meeting" badli)
--   calendar_events.recurrence_id  : exception row ka ASLI start (master ke hisaab se)
--   calendar_events.tz_offset_min  : bhejne wale browser ka UTC offset (minutes) — tz database na mile to bhi waqt sahi
--   calendar_busy                  : ab sirf non-recurring + exception rows; masters ke liye calendar_busy_masters
--
-- Rust engine (cal_core::recur) instances khud banata hai — time zone / DST ke saath; browser sirf rule bhejta hai.
-- Grants: service_role par explicit (Supabase 30 Oct 2026 change). authenticated ko koi naya haq nahi (calendar tables E32 se locked).
-- Chalane ka tareeqa: poori file ek saath (Supabase SQL Editor). Aakhri jawab: ek row `e56_result`.
-- =============================================================================
begin;
set local lock_timeout = '15s';
set local statement_timeout = '120s';
select pg_advisory_xact_lock(hashtext('anexomail.E56'));

do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema='public' and table_name='calendar_events' and column_name='tz') then
    raise exception 'E56 PREFLIGHT: calendar_events.tz maujood nahi — pehle E31 chalayen' using errcode = 'AX056';
  end if;
end $$;

alter table public.calendar_events add column if not exists rrule         text;
alter table public.calendar_events add column if not exists exdates       timestamptz[] not null default '{}';
alter table public.calendar_events add column if not exists series_id     uuid;
alter table public.calendar_events add column if not exists recurrence_id timestamptz;
alter table public.calendar_events add column if not exists tz_offset_min integer;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'calendar_events_rrule_ck') then
    alter table public.calendar_events add constraint calendar_events_rrule_ck
      check (rrule is null or (char_length(rrule) between 5 and 300 and rrule ~ '^[A-Za-z0-9=;,:+-]+$')) not valid;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'calendar_events_series_ck') then
    alter table public.calendar_events add constraint calendar_events_series_ck
      check ((series_id is null) = (recurrence_id is null) and (series_id is null or rrule is null)) not valid;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'calendar_events_offset_ck') then
    alter table public.calendar_events add constraint calendar_events_offset_ck
      check (tz_offset_min is null or tz_offset_min between -840 and 840) not valid;
  end if;
  alter table public.calendar_events validate constraint calendar_events_rrule_ck;
  alter table public.calendar_events validate constraint calendar_events_series_ck;
  alter table public.calendar_events validate constraint calendar_events_offset_ck;
end $$;

create index if not exists calendar_events_masters_idx on public.calendar_events (org_id, starts_at) where rrule is not null;
create unique index if not exists calendar_events_exception_uq on public.calendar_events (series_id, recurrence_id) where series_id is not null;

-- busy: masters ko Rust expand karta hai; yahan sirf ek-baar wali + exception rows
create or replace function public.calendar_busy(p_org uuid, p_addresses text[], p_from timestamptz, p_to timestamptz)
returns table (address text, starts_at timestamptz, ends_at timestamptz)
language sql
stable
set search_path = public, pg_temp
as $$
  select lower(a.address), e.starts_at, e.ends_at
    from public.calendar_attendees a
    join public.calendar_events e on e.id = a.event_id
   where e.org_id = p_org
     and lower(a.address) = any (select lower(x) from unnest(p_addresses) x)
     and e.starts_at < p_to and e.ends_at > p_from
     and coalesce(e.status, 'confirmed') <> 'cancelled' and e.cancelled_at is null
     and coalesce(a.response, 'needs_action') <> 'declined'
     and coalesce(e.kind, 'meeting') <> 'hold'
     and e.rrule is null
   order by 1, 2
$$;

create or replace function public.calendar_busy_masters(p_org uuid, p_addresses text[], p_to timestamptz)
returns table (address text, event_id uuid, starts_at timestamptz, ends_at timestamptz, rrule text, exdates timestamptz[], tz text, tz_offset_min integer)
language sql
stable
set search_path = public, pg_temp
as $$
  select lower(a.address), e.id, e.starts_at, e.ends_at, e.rrule, e.exdates, e.tz, e.tz_offset_min
    from public.calendar_attendees a
    join public.calendar_events e on e.id = a.event_id
   where e.org_id = p_org
     and lower(a.address) = any (select lower(x) from unnest(p_addresses) x)
     and e.rrule is not null and e.starts_at < p_to
     and coalesce(e.status, 'confirmed') <> 'cancelled' and e.cancelled_at is null
     and coalesce(a.response, 'needs_action') <> 'declined'
     and coalesce(e.kind, 'meeting') <> 'hold'
   limit 2000
$$;

revoke all on function public.calendar_busy(uuid, text[], timestamptz, timestamptz)       from public, anon, authenticated;
revoke all on function public.calendar_busy_masters(uuid, text[], timestamptz)            from public, anon, authenticated;
grant execute on function public.calendar_busy(uuid, text[], timestamptz, timestamptz)    to service_role;
grant execute on function public.calendar_busy_masters(uuid, text[], timestamptz)         to service_role;
grant select, insert, update, delete on public.calendar_events to service_role;
commit;

select 'E56 OK — recurrence schema lag gaya' as e56_result,
       (select count(*) from information_schema.columns where table_schema='public' and table_name='calendar_events'
          and column_name in ('rrule','exdates','series_id','recurrence_id','tz_offset_min')) as new_columns_5,
       (select count(*) from pg_proc where proname in ('calendar_busy','calendar_busy_masters')) as busy_functions_2,
       (select coalesce(bool_or(has_function_privilege('anon','public.calendar_busy_masters(uuid,text[],timestamptz)','execute')),false)) as anon_can_call_must_be_false;
