-- =============================================================================
-- ANEXOMAIL — Phase 60 PATCH: org identity (idempotent)
-- Supabase #4 SQL Editor — poori file paste → Run. Sirf yahi raasta.
--
-- Live error: org_members.role type `org_role` hai, pehli file text insert
-- karti thi. Yeh patch drop/rename nahi karti — cast + missing columns.
-- =============================================================================

create table if not exists public.orgs (
  id          uuid primary key default gen_random_uuid(),
  name        text not null default 'ANEXOMAIL Workspace',
  created_at  timestamptz not null default now()
);

create table if not exists public.org_members (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null,
  user_id     uuid not null,
  email       text,
  role        text not null default 'member',
  status      text not null default 'active',
  created_at  timestamptz not null default now()
);

create table if not exists public.mail_accounts (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid,
  address     text not null unique,
  created_at  timestamptz not null default now()
);

alter table public.org_members add column if not exists email text;
alter table public.org_members add column if not exists status text;
alter table public.mail_accounts add column if not exists org_id uuid;
alter table public.mail_accounts add column if not exists address text;

create unique index if not exists org_members_org_user_uniq
  on public.org_members (org_id, user_id);
create index if not exists org_members_user_idx on public.org_members (user_id);

-- Backfill: account_org_members → org_members. role ko live column type par cast.
do $$
declare
  role_udt text;
  has_status boolean;
  role_sql text;
  cols text;
  sels text;
begin
  if to_regclass('public.account_org_members') is null then
    return;
  end if;

  select c.udt_name into role_udt
    from information_schema.columns c
   where c.table_schema = 'public'
     and c.table_name = 'org_members'
     and c.column_name = 'role';

  if role_udt is null then
    alter table public.org_members add column role text;
    role_udt := 'text';
  end if;

  select exists (
    select 1 from information_schema.columns
     where table_schema = 'public' and table_name = 'org_members' and column_name = 'status'
  ) into has_status;

  if role_udt = 'org_role' then
    role_sql := 'coalesce(nullif(trim(m.role::text), ''''), ''member'')::public.org_role';
  else
    role_sql := 'coalesce(nullif(trim(m.role::text), ''''), ''member'')';
  end if;

  cols := 'org_id, user_id, role';
  sels := format('m.org_id, m.user_id, %s', role_sql);
  if has_status then
    cols := cols || ', status';
    sels := format('m.org_id, m.user_id, %s, %L', role_sql, 'active');
  end if;

  execute format($q$
    insert into public.org_members (%s)
    select %s
      from public.account_org_members m
     where not exists (
       select 1 from public.org_members o
        where o.org_id = m.org_id and o.user_id = m.user_id
     )
  $q$, cols, sels);
end $$;

grant select, insert, update, delete on public.org_members, public.mail_accounts to authenticated;
grant select on public.orgs to authenticated;
grant all on public.orgs, public.org_members, public.mail_accounts to service_role;

alter table public.orgs enable row level security;
alter table public.org_members enable row level security;
alter table public.mail_accounts enable row level security;

drop policy if exists auth_read on public.orgs;
create policy auth_read on public.orgs for select to authenticated using (true);
drop policy if exists auth_read on public.org_members;
create policy auth_read on public.org_members for select to authenticated using (true);
drop policy if exists auth_write on public.org_members;
create policy auth_write on public.org_members for all to authenticated using (true) with check (true);
drop policy if exists auth_read on public.mail_accounts;
create policy auth_read on public.mail_accounts for select to authenticated using (true);

select
  (select count(*) from public.orgs) as orgs_rows,
  (select count(*) from public.org_members) as org_members_rows,
  (select count(*) from public.mail_accounts) as mail_accounts_rows;
