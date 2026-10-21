-- E58 — calendar: alag calendars + rang, working hours, out-of-office (account pasand `awam_ui_pref.extra` mein) aur
--        har meeting par calendar_key + reminders (22 Oct 2026). E57 ke baad chalti hai. Dobara chalana safe. Koi DROP nahi.
--   * calendars / working hours / OOO user ki apni chhoti settings hain => E57 ka `extra` jsonb (limit 4 KB -> 16 KB)
--   * meeting par `calendar_key` (user ke calendars mein se kaun sa) aur `remind_min` (kitne minute pehle yaad dilana)
--   * galat shape table mein ja hi nahi sakti (CHECK); Rust bhi pehle validate karta hai (do taale)
do $$ begin
  if to_regclass('public.awam_ui_pref') is not null then
    alter table public.awam_ui_pref drop constraint if exists awam_ui_pref_extra_ck;
    alter table public.awam_ui_pref add constraint awam_ui_pref_extra_ck
      check (jsonb_typeof(extra) = 'object' and pg_column_size(extra) <= 16384);
  end if;
end $$;

create or replace function public.calendar_remind_ok(a integer[])
returns boolean language sql immutable as $$
  select a is null or (coalesce(array_length(a, 1), 0) <= 5
                       and not exists (select 1 from unnest(a) m where m is null or m < 0 or m > 40320))
$$;

do $$ begin
  if to_regclass('public.calendar_events') is not null then
    alter table public.calendar_events add column if not exists calendar_key text;
    alter table public.calendar_events add column if not exists remind_min integer[];
    if not exists (select 1 from pg_constraint where conname = 'calendar_events_calendar_key_ck') then
      alter table public.calendar_events add constraint calendar_events_calendar_key_ck
        check (calendar_key is null or calendar_key ~ '^[a-z0-9_-]{1,40}$');
    end if;
    if not exists (select 1 from pg_constraint where conname = 'calendar_events_remind_min_ck') then
      alter table public.calendar_events add constraint calendar_events_remind_min_ck
        check (public.calendar_remind_ok(remind_min));
    end if;
  end if;
end $$;
