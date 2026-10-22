
-- E63 — calendar #9 "outcome colours": har meeting par user ka APNA maqsad (goal, 2000 harf tak, multi-line) aur uski asli halat (open / achieved / missed) (22 Oct 2026).
-- E58 ke baad chalti hai. Dobara chalana safe. Koi DROP TABLE/COLUMN nahi. Naam `goal` isliye ke purana `outcome` (jsonb: faislay + action items) alag cheez hai — woh nahi chhua.
-- Sach ka usool: rang sirf user ke asli tap se badalta hai (Achieved / Missed). Koi score, koi percentage, koi andaza nahi — isliye DB mein bhi sirf teen halat.
-- Advance level (Rule 38):
--   * PREFLIGHT: Postgres >= 11 (constant DEFAULT = bina table rewrite), calendar_events maujood, aur agar kisi column ka naam pehle se hai to uska TYPE sahi hona chahiye (warna saaf error, chup-chaap galat column nahi).
--   * EK hi ALTER mein teeno columns (ACCESS EXCLUSIVE lock ek baar, bahut chhota) + LOCK RETRY: lock_timeout 3s, 6 koshishein, har baar badhta intezaar. Live traffic kabhi 3s se zyada nahi atakti; busy waqt mein khud dobara koshish.
--   * goal = 1..2000 harf, newline theek, baqi control character nahi — calendar_goal_ok (IMMUTABLE + PARALLEL SAFE + pinned search_path). Rust ke qaide ka mirror, kabhi Rust se sakht nahi.
--   * TEEN alag constraints (error ka naam saaf batata hai kya toota): goal_ck (shape) · goal_state_ck (sirf open/achieved/missed) · goal_state_at_ck (waqt tabhi jab halat open nahi). NOT VALID phir VALIDATE (SHARE UPDATE EXCLUSIVE, writes nahi rukte).
--   * POST-CONDITION: script ke aakhir mein khud check — teeno columns, teeno constraints validated, function flags sahi; warna script FAIL (aadha kaam chup-chaap nahi chhoda jata).
--   * Account export (E44) `to_jsonb(row)` use karta hai, isliye nayi columns apne-aap export mein aati hain (alag kaam nahi). Delete/purge poori row hatata hai — goal alag nahi bachta.
--   * Naya index nahi: abhi koi query goal par filter nahi karti (history search #10 ke saath, uski zaroorat par).
--   * WAPAS LENA (sirf zaroorat par, haath se; yahan chalta nahi): alter table public.calendar_events drop constraint calendar_events_goal_ck, drop constraint calendar_events_goal_state_ck, drop constraint calendar_events_goal_state_at_ck, drop column goal, drop column goal_state, drop column goal_state_at; drop function public.calendar_goal_ok(text);
set lock_timeout = '3s';
set statement_timeout = '60s';

-- ---- 1. goal ka shape (ek jagah) -------------------------------------------------------------------------------------------
create or replace function public.calendar_goal_ok(g text)
returns boolean language sql immutable parallel safe set search_path = pg_catalog, public as $$
  select g is null or (char_length(btrim(g)) between 1 and 2000 and g !~ E'[\\x01-\\x09\\x0b-\\x1f\\x7f]')
$$;

-- ---- 2. PREFLIGHT ---------------------------------------------------------------------------------------------------------
do $$
declare c record;
begin
  if current_setting('server_version_num')::int < 110000 then
    raise exception 'E63 PREFLIGHT: Postgres 11+ chahiye (constant DEFAULT bina rewrite)' using errcode = 'AX063';
  end if;
  if to_regclass('public.calendar_events') is null then
    raise exception 'E63 PREFLIGHT: calendar_events maujood nahi — pehle phase61/E31 chalayen' using errcode = 'AX063';
  end if;
  for c in
    select * from (values ('goal', 'text'), ('goal_state', 'text'), ('goal_state_at', 'timestamp with time zone')) v(col, typ)
  loop
    if exists (select 1 from information_schema.columns
                where table_schema = 'public' and table_name = 'calendar_events' and column_name = c.col and data_type <> c.typ) then
      raise exception 'E63 PREFLIGHT: calendar_events.% ka type % nahi — pehle se koi aur cheez hai, chhuyi nahi', c.col, c.typ using errcode = 'AX063';
    end if;
  end loop;
end $$;

-- ---- 3. columns: ek ALTER, lock retry ---------------------------------------------------------------------------------------
do $$
declare attempt int := 0;
begin
  loop
    attempt := attempt + 1;
    begin
      alter table public.calendar_events
        add column if not exists goal text,
        add column if not exists goal_state text not null default 'open',
        add column if not exists goal_state_at timestamptz;
      exit;
    exception when lock_not_available then
      if attempt >= 6 then
        raise exception 'E63: calendar_events ka lock % koshishon mein nahi mila (busy). Thori der baad dobara chalayen — kuch badla nahi.', attempt using errcode = 'AX063';
      end if;
      perform pg_sleep(attempt * 1.5);
    end;
  end loop;
end $$;

-- ---- 4. constraints: NOT VALID phir VALIDATE --------------------------------------------------------------------------------
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'calendar_events_goal_ck' and conrelid = 'public.calendar_events'::regclass) then
    alter table public.calendar_events add constraint calendar_events_goal_ck check (public.calendar_goal_ok(goal)) not valid;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'calendar_events_goal_state_ck' and conrelid = 'public.calendar_events'::regclass) then
    alter table public.calendar_events add constraint calendar_events_goal_state_ck check (goal_state in ('open', 'achieved', 'missed')) not valid;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'calendar_events_goal_state_at_ck' and conrelid = 'public.calendar_events'::regclass) then
    alter table public.calendar_events add constraint calendar_events_goal_state_at_ck check ((goal_state = 'open') = (goal_state_at is null)) not valid;
  end if;
  alter table public.calendar_events validate constraint calendar_events_goal_ck;
  alter table public.calendar_events validate constraint calendar_events_goal_state_ck;
  alter table public.calendar_events validate constraint calendar_events_goal_state_at_ck;
end $$;

-- ---- 5. comments -------------------------------------------------------------------------------------------------------------
comment on column public.calendar_events.goal is 'Optional aim (up to 2000 chars, line breaks allowed) written by the organiser (e.g. "contract signed"). Not the same as `outcome` (decisions/action items jsonb).';
comment on column public.calendar_events.goal_state is 'open | achieved | missed — set only by the organiser tapping; never computed.';
comment on column public.calendar_events.goal_state_at is 'When the organiser tapped achieved/missed. NULL exactly while goal_state = open.';
comment on function public.calendar_goal_ok(text) is 'Shape of calendar_events.goal. Mirror of Rust cal_core::clean_goal — never stricter.';

-- ---- 6. POST-CONDITION: aadha kaam chup-chaap nahi ---------------------------------------------------------------------------
do $$
declare bad text;
begin
  select string_agg(x, ', ') into bad from (
    select 'columns' as x where (select count(*) from information_schema.columns
             where table_schema = 'public' and table_name = 'calendar_events' and column_name in ('goal', 'goal_state', 'goal_state_at')) <> 3
    union all select 'constraints' where (select count(*) from pg_constraint
             where conrelid = 'public.calendar_events'::regclass and conname in ('calendar_events_goal_ck', 'calendar_events_goal_state_ck', 'calendar_events_goal_state_at_ck') and convalidated) <> 3
    union all select 'function flags' where not exists (select 1 from pg_proc where oid = 'public.calendar_goal_ok(text)'::regprocedure
             and provolatile = 'i' and proparallel = 's' and proconfig is not null)
  ) q;
  if bad is not null then raise exception 'E63 POST-CONDITION fail: %', bad using errcode = 'AX063'; end if;
end $$;
