-- ============================================================
-- ANEXOMAIL — Phase 18: AI Automation (Supabase #4)
-- Idempotent + self-healing. Safe to run again.
-- ============================================================

do $$
declare
  specs text[][] := array[
    ['ai_workflows','trigger_kind'],
    ['ai_workflow_steps','workflow_id'],
    ['ai_workflow_runs','workflow_id'],
    ['ai_rules','conditions'],
    ['ai_variables','value'],
    ['ai_suggestions','kind'],
    ['ai_email_automations','mailbox']
  ];
  i int;
  t text;
  sentinel text;
  stamp text := to_char(now(), 'YYYYMMDDHH24MISS');
begin
  for i in 1..array_length(specs, 1) loop
    t := specs[i][1];
    sentinel := specs[i][2];
    if exists (select 1 from information_schema.tables
               where table_schema = 'public' and table_name = t)
       and not (
         exists (select 1 from information_schema.columns
                 where table_schema = 'public' and table_name = t and column_name = sentinel)
         and exists (select 1 from information_schema.columns
                     where table_schema = 'public' and table_name = t and column_name = 'user_id')
       )
    then
      execute format('alter table public.%I rename to %I', t, '_legacy_' || stamp || '_' || t);
    end if;
  end loop;
end $$;

create table if not exists public.ai_workflows (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid(),
  name          text not null,
  description   text,
  trigger_kind  text not null,        -- mail_received | thread_idle | schedule | manual | deal_stage
  trigger_config jsonb not null default '{}'::jsonb,
  enabled       boolean not null default false,
  -- Human approval gate: AI kabhi chup-chaap send nahi karta.
  requires_approval boolean not null default true,
  runs          int not null default 0,
  failures      int not null default 0,
  last_run_at   timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz
);

create table if not exists public.ai_workflow_steps (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid(),
  workflow_id uuid not null references public.ai_workflows(id) on delete cascade,
  position    int not null default 0,
  action      text not null,          -- studio_tool | send_reply | create_task | create_event | assign | tag | escalate | notify
  config      jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now()
);

create table if not exists public.ai_workflow_runs (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid(),
  workflow_id uuid not null references public.ai_workflows(id) on delete cascade,
  trigger_ref text,
  state       text not null default 'running', -- running | done | failed | awaiting_approval | skipped
  steps_done  int not null default 0,
  cost        numeric(12,6) not null default 0,
  currency    text not null default 'GBP',
  latency_ms  int,
  log         jsonb not null default '[]'::jsonb,
  error       text,
  created_at  timestamptz not null default now(),
  finished_at timestamptz
);

create table if not exists public.ai_rules (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid(),
  name        text not null,
  scope       text not null default 'mail',   -- mail | crm | calendar | tasks
  -- [{ field, op, value }]
  conditions  jsonb not null default '[]'::jsonb,
  -- [{ action, config }]
  actions     jsonb not null default '[]'::jsonb,
  priority    int not null default 100,
  enabled     boolean not null default false,
  matches     int not null default 0,
  last_match_at timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz
);

create table if not exists public.ai_variables (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid(),
  key         text not null,
  value       text not null default '',
  kind        text not null default 'static', -- static | computed | secret_free
  description text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz,
  unique (user_id, key)
);

create table if not exists public.ai_suggestions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid(),
  kind        text not null,          -- workflow | rule | variable | cleanup
  title       text not null,
  reason      text not null default '',
  evidence    jsonb not null default '{}'::jsonb,
  confidence  numeric(5,2),
  payload     jsonb not null default '{}'::jsonb,
  state       text not null default 'open',  -- open | accepted | dismissed
  decided_at  timestamptz,
  created_at  timestamptz not null default now()
);

create table if not exists public.ai_email_automations (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid(),
  mailbox      text not null,
  name         text not null,
  mode         text not null default 'draft_only', -- draft_only | auto_send | notify_only
  hours        jsonb not null default '{}'::jsonb, -- working hours window
  workflow_id  uuid references public.ai_workflows(id) on delete set null,
  enabled      boolean not null default false,
  handled      int not null default 0,
  escalations  int not null default 0,
  last_handled_at timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz
);

create index if not exists ai_workflow_steps_wf_idx
  on public.ai_workflow_steps (workflow_id, position);
create index if not exists ai_workflow_runs_wf_idx
  on public.ai_workflow_runs (workflow_id, created_at desc);
create index if not exists ai_rules_user_priority_idx on public.ai_rules (user_id, priority);
create index if not exists ai_suggestions_state_idx on public.ai_suggestions (user_id, state);

do $$
declare
  t text;
  tables text[] := array[
    'ai_workflows','ai_workflow_steps','ai_workflow_runs',
    'ai_rules','ai_variables','ai_suggestions','ai_email_automations'
  ];
begin
  foreach t in array tables loop
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
    execute format('grant all on public.%I to service_role', t);
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists own_rows on public.%I', t);
    execute format(
      'create policy own_rows on public.%I for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid())',
      t);
  end loop;
end $$;

-- Verify — 7 rows aani chahiye
select table_name
from information_schema.columns
where table_schema = 'public'
  and column_name = 'user_id'
  and table_name in ('ai_workflows','ai_workflow_steps','ai_workflow_runs',
                     'ai_rules','ai_variables','ai_suggestions','ai_email_automations')
group by table_name
order by table_name;