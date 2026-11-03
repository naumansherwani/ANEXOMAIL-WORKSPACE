-- ============================================================
-- ANEXOMAIL — Phase 17: AI Studio (Supabase #4)
-- Idempotent + self-healing. Safe to run again.
-- ============================================================

-- 1) Purani conflicting tables ko legacy bana do (sentinel column ya user_id missing)
do $$
declare
  specs text[][] := array[
    ['ai_studio_runs','tool'],
    ['ai_studio_recipes','steps'],
    ['ai_studio_recipe_runs','recipe_id'],
    ['ai_studio_batches','tool']
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

-- 2) Fresh schema
create table if not exists public.ai_studio_runs (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid(),
  session_id   uuid,
  tool         text not null,           -- rewrite | grammar | translate | summarize | draft | tone | meeting | tasks | template
  input        text not null default '',
  output       text not null default '',
  options      jsonb not null default '{}'::jsonb,  -- language, tone, length, target
  source_kind  text,                    -- thread | message | draft | free
  source_ref   text,
  applied      boolean not null default false,
  applied_to   text,                    -- compose | thread | calendar_events | work_tasks
  applied_ref  text,
  model        text,
  input_tokens int not null default 0,
  output_tokens int not null default 0,
  cost         numeric(12,6) not null default 0,
  currency     text not null default 'GBP',
  ttft_ms      int,
  latency_ms   int,
  sources      jsonb not null default '[]'::jsonb,
  batch_id     uuid,
  recipe_run_id uuid,
  state        text not null default 'done',  -- done | failed | paused
  error        text,
  created_at   timestamptz not null default now()
);

create table if not exists public.ai_studio_recipes (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid(),
  name        text not null,
  description text,
  -- [{ tool, options, feed: 'output'|'input' }]
  steps       jsonb not null default '[]'::jsonb,
  runs        int not null default 0,
  last_run_at timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz
);

create table if not exists public.ai_studio_recipe_runs (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid(),
  recipe_id  uuid not null references public.ai_studio_recipes(id) on delete cascade,
  input      text not null default '',
  output     text not null default '',
  step_count int not null default 0,
  cost       numeric(12,6) not null default 0,
  currency   text not null default 'GBP',
  latency_ms int,
  state      text not null default 'done',
  error      text,
  created_at timestamptz not null default now()
);

create table if not exists public.ai_studio_batches (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid(),
  tool       text not null,
  options    jsonb not null default '{}'::jsonb,
  targets    jsonb not null default '[]'::jsonb,  -- [{ kind, ref, label }]
  total      int not null default 0,
  done       int not null default 0,
  failed     int not null default 0,
  cost       numeric(12,6) not null default 0,
  currency   text not null default 'GBP',
  state      text not null default 'running',     -- running | done | failed
  created_at timestamptz not null default now(),
  finished_at timestamptz
);

-- 3) Indexes
create index if not exists ai_studio_runs_user_created_idx
  on public.ai_studio_runs (user_id, created_at desc);
create index if not exists ai_studio_runs_tool_idx on public.ai_studio_runs (user_id, tool);
create index if not exists ai_studio_runs_batch_idx on public.ai_studio_runs (batch_id);
create index if not exists ai_studio_recipe_runs_recipe_idx
  on public.ai_studio_recipe_runs (recipe_id, created_at desc);

-- 4) Grants -> RLS -> policy (isi tarteeb se)
do $$
declare
  t text;
  tables text[] := array[
    'ai_studio_runs','ai_studio_recipes','ai_studio_recipe_runs','ai_studio_batches'
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

-- 5) Verify — 4 rows aani chahiye
select table_name
from information_schema.columns
where table_schema = 'public'
  and column_name = 'user_id'
  and table_name like 'ai\_studio\_%'
group by table_name
order by table_name;