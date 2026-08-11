-- ANEXOMAIL — Phase 20: AI Knowledge Workspace (Supabase #4)
-- EMBEDDINGS RULE: koi OpenAI key nahi. Recall = trigram keyword + pinned + recency.
-- CITATION RULE: jawab sirf cited chunks se; source na mile to refusal log hota hai.

create extension if not exists pg_trgm;

do $$
declare ts text := to_char(now(), 'YYYYMMDDHH24MISS');
begin
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='knowledge_spaces')
     and not exists (select 1 from information_schema.columns where table_schema='public' and table_name='knowledge_spaces' and column_name='user_id') then
    execute format('alter table public.knowledge_spaces rename to knowledge_spaces_legacy_%s', ts);
  end if;
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='knowledge_documents')
     and not exists (select 1 from information_schema.columns where table_schema='public' and table_name='knowledge_documents' and column_name='user_id') then
    execute format('alter table public.knowledge_documents rename to knowledge_documents_legacy_%s', ts);
  end if;
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='knowledge_chunks')
     and not exists (select 1 from information_schema.columns where table_schema='public' and table_name='knowledge_chunks' and column_name='user_id') then
    execute format('alter table public.knowledge_chunks rename to knowledge_chunks_legacy_%s', ts);
  end if;
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='knowledge_answers')
     and not exists (select 1 from information_schema.columns where table_schema='public' and table_name='knowledge_answers' and column_name='user_id') then
    execute format('alter table public.knowledge_answers rename to knowledge_answers_legacy_%s', ts);
  end if;
end $$;

create table if not exists public.knowledge_spaces (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  scope text not null default 'business' check (scope in ('personal','business')),
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, name)
);

create table if not exists public.knowledge_documents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  space_id uuid references public.knowledge_spaces(id) on delete cascade,
  title text not null,
  kind text not null default 'note' check (kind in ('note','thread','file','link','snippet')),
  source_ref text,
  body text not null default '',
  words integer not null default 0,
  pinned boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists knowledge_documents_user_idx
  on public.knowledge_documents (user_id, updated_at desc);

create table if not exists public.knowledge_chunks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  document_id uuid not null references public.knowledge_documents(id) on delete cascade,
  space_id uuid references public.knowledge_spaces(id) on delete cascade,
  scope text not null default 'business',
  seq integer not null default 0,
  content text not null,
  created_at timestamptz not null default now()
);
create index if not exists knowledge_chunks_trgm_idx
  on public.knowledge_chunks using gin (content gin_trgm_ops);
create index if not exists knowledge_chunks_user_idx
  on public.knowledge_chunks (user_id, document_id);

create table if not exists public.knowledge_answers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  question text not null,
  scope text,
  answer text,
  refused boolean not null default false,
  refusal_reason text,
  citations jsonb not null default '[]'::jsonb,
  model text,
  cost numeric(12,6) not null default 0,
  currency text not null default 'GBP',
  latency_ms integer,
  created_at timestamptz not null default now()
);
create index if not exists knowledge_answers_user_idx
  on public.knowledge_answers (user_id, created_at desc);

-- Grounded recall: trigram similarity + pinned boost + recency boost.
create or replace function public.knowledge_recall(
  _user_id uuid,
  _query text,
  _scope text default null,
  _limit integer default 8
)
returns table (
  chunk_id uuid,
  document_id uuid,
  doc_title text,
  scope text,
  excerpt text,
  score real
)
language sql
stable
security definer
set search_path = public
as $$
  select c.id,
         d.id,
         d.title,
         c.scope,
         left(c.content, 320),
         (similarity(c.content, _query)
           + case when d.pinned then 0.15 else 0 end
           + greatest(0, 0.1 - (extract(epoch from (now() - d.updated_at)) / 2592000.0) * 0.1)
         )::real as score
  from public.knowledge_chunks c
  join public.knowledge_documents d on d.id = c.document_id
  where c.user_id = _user_id
    and (_scope is null or c.scope = _scope)
    and (c.content ilike '%' || _query || '%' or similarity(c.content, _query) > 0.08)
  order by score desc, d.updated_at desc
  limit greatest(1, least(_limit, 25));
$$;

grant select, insert, update, delete on public.knowledge_spaces to authenticated;
grant select, insert, update, delete on public.knowledge_documents to authenticated;
grant select, insert, update, delete on public.knowledge_chunks to authenticated;
grant select, insert, update, delete on public.knowledge_answers to authenticated;
grant all on public.knowledge_spaces to service_role;
grant all on public.knowledge_documents to service_role;
grant all on public.knowledge_chunks to service_role;
grant all on public.knowledge_answers to service_role;
grant execute on function public.knowledge_recall(uuid, text, text, integer) to authenticated, service_role;

alter table public.knowledge_spaces enable row level security;
alter table public.knowledge_documents enable row level security;
alter table public.knowledge_chunks enable row level security;
alter table public.knowledge_answers enable row level security;

drop policy if exists own_rows on public.knowledge_spaces;
create policy own_rows on public.knowledge_spaces for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists own_rows on public.knowledge_documents;
create policy own_rows on public.knowledge_documents for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists own_rows on public.knowledge_chunks;
create policy own_rows on public.knowledge_chunks for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists own_rows on public.knowledge_answers;
create policy own_rows on public.knowledge_answers for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
