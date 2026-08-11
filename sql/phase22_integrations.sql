-- ANEXOMAIL — Phase 22: Integrations Platform (Supabase #4)
-- Native provider connections (Gmail / Microsoft 365 / Zoho / Proton bridge / IMAP / SMTP),
-- one-run migration engine, delivery proof, one-click export, Leo Actions.
-- NO API / NO WEBHOOK RULE: awam ko public keys ya webhook URLs kabhi nahi —
-- is liye yahan koi api_keys / webhooks table nahi hai. Jaan bujh kar.
-- Tokens sirf server (service_role) padhta hai; user ko sirf metadata dikhta hai.

do $$
declare ts text := to_char(now(), 'YYYYMMDDHH24MISS');
begin
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='integration_connections')
     and not exists (select 1 from information_schema.columns where table_schema='public' and table_name='integration_connections' and column_name='user_id') then
    execute format('alter table public.integration_connections rename to integration_connections_legacy_%s', ts);
  end if;
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='integration_migrations')
     and not exists (select 1 from information_schema.columns where table_schema='public' and table_name='integration_migrations' and column_name='user_id') then
    execute format('alter table public.integration_migrations rename to integration_migrations_legacy_%s', ts);
  end if;
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='integration_exports')
     and not exists (select 1 from information_schema.columns where table_schema='public' and table_name='integration_exports' and column_name='user_id') then
    execute format('alter table public.integration_exports rename to integration_exports_legacy_%s', ts);
  end if;
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='leo_actions')
     and not exists (select 1 from information_schema.columns where table_schema='public' and table_name='leo_actions' and column_name='user_id') then
    execute format('alter table public.leo_actions rename to leo_actions_legacy_%s', ts);
  end if;
end $$;

-- 1. Provider catalog (public read, server-managed)
create table if not exists public.integration_providers (
  id text primary key,
  label text not null,
  kind text not null check (kind in ('oauth','credentials','bridge')),
  can_migrate boolean not null default true,
  can_sync boolean not null default true,
  can_send boolean not null default false,
  notes text,
  available boolean not null default true,
  sort_order integer not null default 0
);

insert into public.integration_providers (id, label, kind, can_migrate, can_sync, can_send, notes, available, sort_order) values
  ('gmail',            'Gmail',            'oauth',       true, true, true,  'Personal Gmail — one-tap sign-in, labels map to folders.', true, 1),
  ('google_workspace', 'Google Workspace', 'oauth',       true, true, true,  'Whole domain move-in, per-user consent or admin-wide.',    true, 2),
  ('outlook',          'Outlook.com',      'oauth',       true, true, true,  'Outlook / Hotmail / Live accounts.',                       true, 3),
  ('microsoft365',     'Microsoft 365',    'oauth',       true, true, true,  'Work accounts, shared mailboxes included.',                true, 4),
  ('zoho',             'Zoho Mail',        'oauth',       true, true, true,  'Folders, tags and read state preserved.',                  true, 5),
  ('proton',           'Proton Mail',      'bridge',      true, true, false, 'Needs Proton Bridge running locally for IMAP access.',     true, 6),
  ('imap',             'Any IMAP mailbox', 'credentials', true, true, false, 'Host, port, TLS — works with any provider.',               true, 7),
  ('smtp',             'External SMTP',    'credentials', false, false, true,'Send through your own relay while we host receiving.',     true, 8)
on conflict (id) do update
  set label = excluded.label, kind = excluded.kind, can_migrate = excluded.can_migrate,
      can_sync = excluded.can_sync, can_send = excluded.can_send, notes = excluded.notes,
      available = excluded.available, sort_order = excluded.sort_order;

grant select on public.integration_providers to authenticated, anon;
grant all on public.integration_providers to service_role;

-- 2. Connections — tokens server-only
create table if not exists public.integration_connections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  provider text not null references public.integration_providers(id),
  account text not null,
  state text not null default 'connected' check (state in ('connected','needs_reauth','error','paused')),
  scopes text[] not null default '{}',
  host text,
  port integer,
  secret_ref text,                    -- server-side vault reference, never a raw password
  last_sync_at timestamptz,
  synced_threads integer not null default 0,
  error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, provider, account)
);

create index if not exists integration_connections_user_idx on public.integration_connections (user_id, created_at desc);

grant select, insert, update, delete on public.integration_connections to authenticated;
grant all on public.integration_connections to service_role;
alter table public.integration_connections enable row level security;
drop policy if exists own_rows on public.integration_connections;
create policy own_rows on public.integration_connections
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 3. Migration jobs
create table if not exists public.integration_migrations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  connection_id uuid references public.integration_connections(id) on delete set null,
  provider text not null,
  source_account text not null,
  target_mailbox text not null,
  mode text not null default 'copy' check (mode in ('copy','mirror')),
  state text not null default 'queued' check (state in ('queued','running','paused','done','failed')),
  total integer not null default 0,
  done integer not null default 0,
  failed integer not null default 0,
  eta_minutes integer,
  cursor text,
  last_error text,
  started_at timestamptz,
  finished_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists integration_migrations_user_idx on public.integration_migrations (user_id, created_at desc);
create index if not exists integration_migrations_state_idx on public.integration_migrations (state);

grant select, insert, update, delete on public.integration_migrations to authenticated;
grant all on public.integration_migrations to service_role;
alter table public.integration_migrations enable row level security;
drop policy if exists own_rows on public.integration_migrations;
create policy own_rows on public.integration_migrations
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 4. Per-item migration log (retry ke liye — kuch bhi chup ke fail nahi hota)
create table if not exists public.integration_migration_items (
  id uuid primary key default gen_random_uuid(),
  migration_id uuid not null references public.integration_migrations(id) on delete cascade,
  user_id uuid not null,
  remote_id text not null,
  folder text,
  state text not null default 'pending' check (state in ('pending','copied','skipped','failed')),
  error text,
  updated_at timestamptz not null default now(),
  unique (migration_id, remote_id)
);

create index if not exists integration_migration_items_job_idx on public.integration_migration_items (migration_id, state);

grant select, insert, update, delete on public.integration_migration_items to authenticated;
grant all on public.integration_migration_items to service_role;
alter table public.integration_migration_items enable row level security;
drop policy if exists own_rows on public.integration_migration_items;
create policy own_rows on public.integration_migration_items
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 5. Delivery proof snapshots (SPF/DKIM/DMARC/MX/MTA-STS/TLS-RPT/PTR/BIMI)
create table if not exists public.delivery_checks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid,
  domain text not null,
  key text not null check (key in ('SPF','DKIM','DMARC','MX','MTA-STS','TLS-RPT','PTR','BIMI')),
  state text not null check (state in ('ok','warn','fail')),
  detail text not null default '',
  fix text,
  checked_at timestamptz not null default now(),
  unique (domain, key)
);

create table if not exists public.delivery_blocklists (
  id uuid primary key default gen_random_uuid(),
  domain text not null,
  name text not null,
  listed boolean not null default false,
  checked_at timestamptz not null default now(),
  unique (domain, name)
);

grant select on public.delivery_checks, public.delivery_blocklists to authenticated;
grant all on public.delivery_checks, public.delivery_blocklists to service_role;
alter table public.delivery_checks enable row level security;
alter table public.delivery_blocklists enable row level security;
drop policy if exists read_all on public.delivery_checks;
create policy read_all on public.delivery_checks for select to authenticated using (true);
drop policy if exists read_all on public.delivery_blocklists;
create policy read_all on public.delivery_blocklists for select to authenticated using (true);

-- 6. Export jobs — User Freedom: one click, real archive
create table if not exists public.integration_exports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  scope text not null check (scope in ('mail','calendar','contacts','everything')),
  format text not null check (format in ('mbox','eml','ics','csv','json')),
  state text not null default 'queued' check (state in ('queued','running','ready','expired','failed')),
  size_bytes bigint not null default 0,
  storage_path text,
  url text,
  expires_at timestamptz,
  error text,
  created_at timestamptz not null default now()
);

create index if not exists integration_exports_user_idx on public.integration_exports (user_id, created_at desc);

grant select, insert, update, delete on public.integration_exports to authenticated;
grant all on public.integration_exports to service_role;
alter table public.integration_exports enable row level security;
drop policy if exists own_rows on public.integration_exports;
create policy own_rows on public.integration_exports
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 7. Leo Actions — public API ki jagah
create table if not exists public.leo_actions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  action_key text not null,
  label text not null,
  target text not null,
  description text not null default '',
  enabled boolean not null default false,
  requires_approval boolean not null default true,
  runs_30d integer not null default 0,
  updated_at timestamptz not null default now(),
  unique (user_id, action_key)
);

grant select, insert, update, delete on public.leo_actions to authenticated;
grant all on public.leo_actions to service_role;
alter table public.leo_actions enable row level security;
drop policy if exists own_rows on public.leo_actions;
create policy own_rows on public.leo_actions
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 8. Founder god-view helper
create or replace function public.founder_integrations_overview()
returns json
language sql
stable
security definer
set search_path = public
as $$
  select json_build_object(
    'connections', (select count(*) from public.integration_connections),
    'needs_reauth', (select count(*) from public.integration_connections where state = 'needs_reauth'),
    'migrations_running', (select count(*) from public.integration_migrations where state = 'running'),
    'migrations_failed', (select count(*) from public.integration_migrations where state = 'failed'),
    'threads_migrated_30d', coalesce((select sum(done) from public.integration_migrations where created_at > now() - interval '30 days'), 0),
    'by_provider', coalesce((
      select json_agg(row_to_json(p)) from (
        select c.provider,
               count(*) as connections,
               count(*) filter (where c.state in ('error','needs_reauth')) as failures
        from public.integration_connections c
        group by c.provider
        order by count(*) desc
      ) p
    ), '[]'::json),
    'worst_delivery', coalesce((
      select json_agg(row_to_json(d)) from (
        select domain,
               round(100.0 * count(*) filter (where state = 'ok') / greatest(count(*), 1)) as score
        from public.delivery_checks
        group by domain
        order by 2 asc
        limit 5
      ) d
    ), '[]'::json)
  );
$$;

revoke all on function public.founder_integrations_overview() from public, anon, authenticated;
grant execute on function public.founder_integrations_overview() to service_role;
