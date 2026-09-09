-- =============================================================================
-- ANEXOMAIL — Phase 61: CALENDAR + WORK (idempotent, self-healing)
-- Supabase #4 SQL editor mein poori file copy-paste karo.
--
-- ASLI MASLA: `server/routes/calendar.ts` (Phase 11 — mounted at
-- server/index.ts:119 `app.use("/api", calendar)`) poora likha hua hai —
-- events, attendees, focus windows, work tasks, promises, notes, load,
-- follow-through, ICS export — sab real logic hai. Lekin iski 7 tables ki
-- KOI migration repo mein nahi thi, isliye har call live par fail hoti thi
-- (frontend "NotWired" / error dikhata hai — UI bug nahi, missing schema tha).
-- Yeh file wahi 7 tables banati hai jo server/routes/calendar.ts already
-- expect karta hai — koi naya API / naya route nahi likha, sirf uski table.
--
-- Depends on: public.mail_threads (Phase 52), public.org_members (Phase 60).
-- =============================================================================

-- ---------- events ----------
create table if not exists public.calendar_events (
  id                uuid primary key default gen_random_uuid(),
  org_id            uuid not null,
  title             text not null,
  agenda            text,
  starts_at         timestamptz not null,
  ends_at           timestamptz not null,
  all_day           boolean not null default false,
  location          text,
  organiser         text,
  thread_id         uuid references public.mail_threads(id) on delete set null,
  thread_subject    text,
  kind              text not null default 'meeting',
  status            text not null default 'confirmed',
  outcome           jsonb,
  outcome_posted_at timestamptz,
  created_by        uuid,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create index if not exists calendar_events_org_time_idx
  on public.calendar_events (org_id, starts_at);

-- ---------- attendees ----------
create table if not exists public.calendar_attendees (
  id            uuid primary key default gen_random_uuid(),
  event_id      uuid not null references public.calendar_events(id) on delete cascade,
  org_id        uuid not null,
  address       text not null,
  display_name  text,
  timezone      text,
  hourly_rate   numeric,
  response      text not null default 'needs_action',
  created_at    timestamptz not null default now()
);
create index if not exists calendar_attendees_event_idx on public.calendar_attendees (event_id);

-- ---------- focus / protected windows ----------
create table if not exists public.calendar_focus_windows (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null,
  label         text,
  weekday       smallint not null check (weekday between 0 and 6),
  start_minute  int not null check (start_minute between 0 and 1440),
  end_minute    int not null check (end_minute between 0 and 1440),
  protected     boolean not null default false,
  created_at    timestamptz not null default now()
);
create index if not exists calendar_focus_windows_org_idx
  on public.calendar_focus_windows (org_id, weekday);

-- ---------- work tasks ----------
create table if not exists public.work_tasks (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid not null,
  title          text not null,
  status         text not null default 'todo',
  owner          text,
  due_at         timestamptz,
  thread_id      uuid references public.mail_threads(id) on delete set null,
  thread_subject text,
  event_id       uuid references public.calendar_events(id) on delete set null,
  source         text not null default 'manual',
  created_by     uuid,
  created_at     timestamptz not null default now(),
  completed_at   timestamptz
);
create index if not exists work_tasks_org_status_idx on public.work_tasks (org_id, status);
create index if not exists work_tasks_org_owner_idx on public.work_tasks (org_id, owner);

-- ---------- promises (AI-detected commitments in mail — commit/dismiss flow) ----------
create table if not exists public.work_promises (
  id                uuid primary key default gen_random_uuid(),
  org_id            uuid not null,
  quote             text,
  suggested_title   text,
  suggested_due_at  timestamptz,
  thread_id         uuid references public.mail_threads(id) on delete set null,
  thread_subject    text,
  owner             text,
  detected_at       timestamptz not null default now(),
  confidence        numeric not null default 0,
  status            text not null default 'suggested',
  task_id           uuid references public.work_tasks(id) on delete set null,
  created_at        timestamptz not null default now()
);
create index if not exists work_promises_org_status_idx on public.work_promises (org_id, status);

-- ---------- notes (per-thread or per-meeting single note) ----------
create table if not exists public.work_notes (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null,
  body        text not null default '',
  thread_id   uuid references public.mail_threads(id) on delete cascade,
  event_id    uuid references public.calendar_events(id) on delete cascade,
  updated_by  text,
  created_by  uuid,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists work_notes_org_thread_idx on public.work_notes (org_id, thread_id);
create index if not exists work_notes_org_event_idx on public.work_notes (org_id, event_id);

-- ---------- mail thread timeline events (meeting created / outcome posted) ----------
create table if not exists public.mail_thread_events (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null,
  thread_id   uuid not null references public.mail_threads(id) on delete cascade,
  kind        text not null,
  actor       text,
  payload     jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now()
);
create index if not exists mail_thread_events_thread_idx
  on public.mail_thread_events (thread_id, created_at desc);

-- ---------- GRANTS + RLS (phase52 convention: org-scoping app layer mein hai,
-- yahan service_role full access + authenticated broad access) ----------
grant select, insert, update, delete on
  public.calendar_events, public.calendar_attendees, public.calendar_focus_windows,
  public.work_tasks, public.work_promises, public.work_notes, public.mail_thread_events
  to authenticated;
grant all on
  public.calendar_events, public.calendar_attendees, public.calendar_focus_windows,
  public.work_tasks, public.work_promises, public.work_notes, public.mail_thread_events
  to service_role;

do $$
declare r record;
begin
  for r in
    select unnest(array['calendar_events','calendar_attendees','calendar_focus_windows',
                        'work_tasks','work_promises','work_notes','mail_thread_events']) as t
  loop
    execute format('alter table public.%I enable row level security', r.t);
    execute format('drop policy if exists auth_read on public.%I', r.t);
    execute format('create policy auth_read on public.%I for select to authenticated using (true)', r.t);
    execute format('drop policy if exists auth_write on public.%I', r.t);
    execute format('create policy auth_write on public.%I for all to authenticated using (true) with check (true)', r.t);
  end loop;
end $$;

-- ---------- VERIFY ----------
select
  exists(select 1 from information_schema.tables where table_schema='public' and table_name='calendar_events') as calendar_events_ready,
  exists(select 1 from information_schema.tables where table_schema='public' and table_name='work_tasks') as work_tasks_ready,
  exists(select 1 from information_schema.tables where table_schema='public' and table_name='mail_thread_events') as mail_thread_events_ready;
