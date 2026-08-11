-- ============================================================
-- ANEXOMAIL · LEO BRAIN MEMORY (Supabase #4)
-- Leo ko Jimmy jaisa banane ke liye: 3,000,000 msgs long-term memory
-- Idempotent + self-healing + grants + RLS (locked rules)
-- Tier lock: Jimmy 3M · Leo 3M · Sherlock 1M · Industry AIs 100K
-- ============================================================

create extension if not exists vector;
create extension if not exists pg_trgm;

-- ---------------------------------------------- 1. memory config (tiers)
create table if not exists public.agent_memory_config (
  agent        text primary key,
  max_memories bigint not null default 100000,
  description  text
);

insert into public.agent_memory_config (agent, max_memories, description) values
  ('jimmy',    3000000, 'Supreme Commander / CEO — full ecosystem memory'),
  ('leo',      3000000, 'ANEXOMAIL AI — mail, threads, support, founder ops'),
  ('sherlock', 1000000, 'Deputy — audit, security, backend'),
  ('industry',  100000, 'Industry AIs — per-domain memory')
on conflict (agent) do update
  set max_memories = excluded.max_memories,
      description  = excluded.description;

-- ---------------------------------------------- 2. leo memory (vector)
do $$
declare t text;
begin
  select data_type into t from information_schema.columns
   where table_schema='public' and table_name='leo_memory_vectors' and column_name='id';
  if t is not null and t <> 'uuid' then
    execute format('alter table public.leo_memory_vectors rename to leo_memory_vectors_legacy_%s',
                   to_char(now(),'YYYYMMDDHH24MISS'));
  end if;
end $$;

create table if not exists public.leo_memory_vectors (
  id           uuid primary key default gen_random_uuid(),
  agent        text not null default 'leo',
  user_id      uuid,
  session_id   text,
  thread_id    uuid,
  layer        text not null default 'episodic',   -- working | episodic | semantic
  role         text not null default 'user',       -- user | assistant | system | tool
  content      text not null,
  summary      text,
  embedding    vector(1536),
  importance   double precision not null default 0.5,
  access_count integer not null default 0,
  pinned       boolean not null default false,
  metadata     jsonb not null default '{}'::jsonb,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

alter table public.leo_memory_vectors alter column id set default gen_random_uuid();
alter table public.leo_memory_vectors add column if not exists thread_id uuid;
alter table public.leo_memory_vectors add column if not exists layer text not null default 'episodic';
alter table public.leo_memory_vectors add column if not exists pinned boolean not null default false;

create index if not exists leo_mem_user_time_idx  on public.leo_memory_vectors (user_id, created_at desc);
create index if not exists leo_mem_session_idx    on public.leo_memory_vectors (session_id, created_at desc);
create index if not exists leo_mem_thread_idx     on public.leo_memory_vectors (thread_id, created_at desc);
create index if not exists leo_mem_layer_idx      on public.leo_memory_vectors (layer, importance desc);
create index if not exists leo_mem_content_trgm   on public.leo_memory_vectors using gin (content gin_trgm_ops);
create index if not exists leo_mem_embedding_idx  on public.leo_memory_vectors
  using ivfflat (embedding vector_cosine_ops) with (lists = 200);

grant select, insert, update, delete on public.leo_memory_vectors to authenticated;
grant all on public.leo_memory_vectors to service_role;
grant select on public.agent_memory_config to authenticated;
grant all on public.agent_memory_config to service_role;

alter table public.leo_memory_vectors enable row level security;
alter table public.agent_memory_config enable row level security;

drop policy if exists leo_mem_own_rows on public.leo_memory_vectors;
create policy leo_mem_own_rows on public.leo_memory_vectors
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists agent_memory_config_read on public.agent_memory_config;
create policy agent_memory_config_read on public.agent_memory_config
  for select to authenticated using (true);

-- ---------------------------------------------- 3. semantic recall (RPC)
create or replace function public.leo_recall(
  p_user_id uuid,
  p_embedding vector(1536),
  p_limit int default 12
)
returns table (
  id uuid, content text, summary text, layer text,
  importance double precision, created_at timestamptz, score double precision
)
language sql
stable
security definer
set search_path = public
as $$
  select m.id, m.content, m.summary, m.layer, m.importance, m.created_at,
         1 - (m.embedding <=> p_embedding) as score
    from public.leo_memory_vectors m
   where m.user_id = p_user_id
     and m.embedding is not null
   order by m.embedding <=> p_embedding
   limit p_limit
$$;

grant execute on function public.leo_recall(uuid, vector, int) to authenticated, service_role;

-- ---------------------------------------------- 4. 3M cap prune (never delete pinned)
create or replace function public.leo_memory_prune()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  cap    bigint;
  killed integer := 0;
begin
  select max_memories into cap from public.agent_memory_config where agent = 'leo';
  if cap is null then cap := 3000000; end if;

  with ranked as (
    select id, row_number() over (
             order by pinned desc, importance desc, access_count desc, created_at desc
           ) as rn
      from public.leo_memory_vectors
  )
  delete from public.leo_memory_vectors m
   using ranked r
   where m.id = r.id and r.rn > cap and m.pinned = false;

  get diagnostics killed = row_count;
  return killed;
end $$;

grant execute on function public.leo_memory_prune() to service_role;
