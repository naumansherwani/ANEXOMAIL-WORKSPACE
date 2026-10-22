
-- E63 — calendar #9 "outcome colours": har meeting par user ka APNA maqsad (goal, 2000 harf tak, multi-line) aur uski asli halat (open / achieved / missed) (22 Oct 2026).
-- E58 ke baad chalti hai. Dobara chalana safe. Koi DROP TABLE/COLUMN nahi. Naam `goal` isliye ke purana `outcome` (jsonb: faislay + action items) alag cheez hai — woh nahi chhua.
-- Sach ka usool: rang sirf user ke asli tap se badalta hai (Achieved / Missed). Koi score, koi percentage, koi andaza nahi — isliye DB mein bhi sirf teen halat.
-- Advance level (Rule 38):
--   * goal = 1..2000 harf, naye line (newline) theek, baqi control character (tab, bell...) nahi (calendar_goal_ok: IMMUTABLE + PARALLEL SAFE + pinned search_path). Rust ke qaide ka mirror, kabhi Rust se sakht nahi.
--   * goal_state in (open, achieved, missed); goal_state_at tabhi hota hai jab halat 'open' nahi — DB khud "tap ka waqt" ka hisaab sahi rakhta hai.
--   * Naye constraints NOT VALID phir VALIDATE (purani badi table par lamba ACCESS EXCLUSIVE lock nahi).
--   * ADD COLUMN ... DEFAULT constant = sirf catalog badalta hai (table rewrite nahi); purani rows 'open' + goal_state_at NULL = constraint par poori.
--   * lock_timeout / statement_timeout: lock na mile to 5s mein saaf fail, live traffic atakti nahi.
--   * Naya index nahi: abhi koi query goal par filter nahi karti (history search #10 ke saath, uski zaroorat par).
set lock_timeout = '5s';
set statement_timeout = '60s';

-- ---- 1. goal ka shape (ek jagah) -------------------------------------------------------------------------------------------
create or replace function public.calendar_goal_ok(g text)
returns boolean language sql immutable parallel safe set search_path = pg_catalog, public as $$
  select g is null or (char_length(btrim(g)) between 1 and 2000 and g !~ E'[\\x01-\\x09\\x0b-\\x1f\\x7f]')
$$;

-- ---- 2. calendar_events: goal, goal_state, goal_state_at -----------------------------------------------------------------
do $$ begin
  if to_regclass('public.calendar_events') is null then
    raise exception 'E63 PREFLIGHT: calendar_events maujood nahi — pehle phase61/E31 chalayen' using errcode = 'AX063';
  end if;
  alter table public.calendar_events add column if not exists goal text;
  alter table public.calendar_events add column if not exists goal_state text not null default 'open';
  alter table public.calendar_events add column if not exists goal_state_at timestamptz;
  if not exists (select 1 from pg_constraint where conname = 'calendar_events_goal_ck') then
    alter table public.calendar_events add constraint calendar_events_goal_ck check (public.calendar_goal_ok(goal)) not valid;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'calendar_events_goal_state_ck') then
    alter table public.calendar_events add constraint calendar_events_goal_state_ck
      check (goal_state in ('open', 'achieved', 'missed') and ((goal_state = 'open') = (goal_state_at is null))) not valid;
  end if;
  alter table public.calendar_events validate constraint calendar_events_goal_ck;
  alter table public.calendar_events validate constraint calendar_events_goal_state_ck;
end $$;

comment on column public.calendar_events.goal is 'Optional aim (up to 2000 chars, line breaks allowed) written by the organiser (e.g. "contract signed"). Not the same as `outcome` (decisions/action items jsonb).';
comment on column public.calendar_events.goal_state is 'open | achieved | missed — set only by the organiser tapping; never computed.';
comment on column public.calendar_events.goal_state_at is 'When the organiser tapped achieved/missed. NULL exactly while goal_state = open.';
comment on function public.calendar_goal_ok(text) is 'Shape of calendar_events.goal. Mirror of Rust cal_glue goal_of — never stricter.';
