-- =============================================================================
-- ANEXOMAIL — Phase 61 PATCH: calendar + work (idempotent)
-- Supabase #4 SQL Editor — poori file paste → Run. Sirf yahi raasta.
--
-- Live error: `column "status" does not exist` — table pehle se maujood thi,
-- CREATE IF NOT EXISTS skip ho gaya, index `work_tasks(org_id, status)` toot gaya.
-- Yeh file missing columns ADD karti hai. Koi table drop nahi.
-- =============================================================================

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
  thread_id         uuid,
  thread_subject    text,
  kind              text not null default 'meeting',
  status            text not null default 'confirmed',
  outcome           jsonb,
  outcome_posted_at timestamptz,
  created_by        uuid,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create table if not exists public.calendar_attendees (
  id            uuid primary key default gen_random_uuid(),
  event_id      uuid not null,
  org_id        uuid not null,
  address       text not null,
  display_name  text,
  timezone      text,
  hourly_rate   numeric,
  response      text not null default 'needs_action',
  created_at    timestamptz not null default now()
);

create table if not exists public.calendar_focus_windows (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null,
  label         text,
  weekday       smallint not null,
  start_minute  int not null,
  end_minute    int not null,
  protected     boolean not null default false,
  created_at    timestamptz not null default now()
);

create table if not exists public.work_tasks (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid not null,
  title          text not null,
  status         text not null default 'todo',
  owner          text,
  due_at         timestamptz,
  thread_id      uuid,
  thread_subject text,
  event_id       uuid,
  source         text not null default 'manual',
  created_by     uuid,
  created_at     timestamptz not null default now(),
  completed_at   timestamptz
);

create table if not exists public.work_promises (
  id                uuid primary key default gen_random_uuid(),
  org_id            uuid not null,
  quote             text,
  suggested_title   text,
  suggested_due_at  timestamptz,
  thread_id         uuid,
  thread_subject    text,
  owner             text,
  detected_at       timestamptz not null default now(),
  confidence        numeric not null default 0,
  status            text not null default 'suggested',
  task_id           uuid,
  created_at        timestamptz not null default now()
);

create table if not exists public.work_notes (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null,
  body        text not null default '',
  thread_id   uuid,
  event_id    uuid,
  updated_by  text,
  created_by  uuid,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table if not exists public.mail_thread_events (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null,
  thread_id   uuid not null,
  kind        text not null,
  actor       text,
  payload     jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now()
);

-- Existing tables: add columns the Express calendar route already writes.
alter table public.calendar_events add column if not exists org_id uuid;
alter table public.calendar_events add column if not exists title text;
alter table public.calendar_events add column if not exists agenda text;
alter table public.calendar_events add column if not exists starts_at timestamptz;
alter table public.calendar_events add column if not exists ends_at timestamptz;
alter table public.calendar_events add column if not exists all_day boolean;
alter table public.calendar_events add column if not exists location text;
alter table public.calendar_events add column if not exists organiser text;
alter table public.calendar_events add column if not exists thread_id uuid;
alter table public.calendar_events add column if not exists thread_subject text;
alter table public.calendar_events add column if not exists kind text;
alter table public.calendar_events add column if not exists status text;
alter table public.calendar_events add column if not exists outcome jsonb;
alter table public.calendar_events add column if not exists outcome_posted_at timestamptz;
alter table public.calendar_events add column if not exists created_by uuid;
alter table public.calendar_events add column if not exists created_at timestamptz;
alter table public.calendar_events add column if not exists updated_at timestamptz;

alter table public.work_tasks add column if not exists org_id uuid;
alter table public.work_tasks add column if not exists title text;
alter table public.work_tasks add column if not exists status text;
alter table public.work_tasks add column if not exists owner text;
alter table public.work_tasks add column if not exists due_at timestamptz;
alter table public.work_tasks add column if not exists thread_id uuid;
alter table public.work_tasks add column if not exists thread_subject text;
alter table public.work_tasks add column if not exists event_id uuid;
alter table public.work_tasks add column if not exists source text;
alter table public.work_tasks add column if not exists created_by uuid;
alter table public.work_tasks add column if not exists created_at timestamptz;
alter table public.work_tasks add column if not exists completed_at timestamptz;

alter table public.work_promises add column if not exists org_id uuid;
alter table public.work_promises add column if not exists status text;
alter table public.work_promises add column if not exists thread_id uuid;
alter table public.work_promises add column if not exists task_id uuid;

alter table public.calendar_attendees add column if not exists event_id uuid;
alter table public.calendar_attendees add column if not exists org_id uuid;
alter table public.calendar_attendees add column if not exists address text;
alter table public.calendar_attendees add column if not exists display_name text;
alter table public.calendar_attendees add column if not exists timezone text;
alter table public.calendar_attendees add column if not exists hourly_rate numeric;
alter table public.calendar_attendees add column if not exists response text;

do $$
begin
  if exists (
    select 1 from information_schema.columns
     where table_schema='public' and table_name='calendar_events' and column_name='org_id'
  ) and exists (
    select 1 from information_schema.columns
     where table_schema='public' and table_name='calendar_events' and column_name='starts_at'
  ) then
    execute 'create index if not exists calendar_events_org_time_idx on public.calendar_events (org_id, starts_at)';
  end if;
  if exists (
    select 1 from information_schema.columns
     where table_schema='public' and table_name='work_tasks' and column_name='status'
  ) then
    execute 'create index if not exists work_tasks_org_status_idx on public.work_tasks (org_id, status)';
  end if;
  execute 'create index if not exists work_tasks_org_owner_idx on public.work_tasks (org_id, owner)';
  execute 'create index if not exists calendar_attendees_event_idx on public.calendar_attendees (event_id)';
  execute 'create index if not exists calendar_focus_windows_org_idx on public.calendar_focus_windows (org_id, weekday)';
  if exists (
    select 1 from information_schema.columns
     where table_schema='public' and table_name='work_promises' and column_name='status'
  ) then
    execute 'create index if not exists work_promises_org_status_idx on public.work_promises (org_id, status)';
  end if;
  execute 'create index if not exists work_notes_org_thread_idx on public.work_notes (org_id, thread_id)';
  execute 'create index if not exists work_notes_org_event_idx on public.work_notes (org_id, event_id)';
  execute 'create index if not exists mail_thread_events_thread_idx on public.mail_thread_events (thread_id, created_at desc)';
end $$;

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

select
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='calendar_events' and column_name='status') as calendar_status_ready,
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='work_tasks' and column_name='status') as work_status_ready;
