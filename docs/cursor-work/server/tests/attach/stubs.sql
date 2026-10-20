create extension if not exists pgcrypto;
create schema if not exists auth;
create table if not exists auth.users (id uuid primary key default gen_random_uuid(), email text);
do $$ begin
  if not exists (select 1 from pg_roles where rolname='service_role') then create role service_role; end if;
  if not exists (select 1 from pg_roles where rolname='authenticated') then create role authenticated; end if;
  if not exists (select 1 from pg_roles where rolname='anon') then create role anon; end if;
end $$;
create table org_members (org_id uuid not null, user_id uuid not null, role text default 'owner', status text default 'active');
create table entitlement_state (user_id uuid primary key, plan text);
create table founder_accounts (user_id uuid primary key);
create table account_integrity (user_id uuid primary key, state text not null default 'clean');
create table storage_plans (plan_id text primary key, per_mailbox_bytes bigint, mailbox_limit int, pooled_bytes bigint, max_send_bytes bigint not null default 26214400);
insert into storage_plans values ('trial',1073741824,1,null,26214400),('basic',5368709120,3,null,26214400),('pro',10737418240,5,null,26214400),('business',26843545600,30,null,2147483648),('business_pro',null,null,1099511627776,5368709120);
create table mail_messages (id uuid primary key default gen_random_uuid(), org_id uuid, thread_id uuid);
create table mail_attachments (id uuid primary key default gen_random_uuid(), message_id uuid not null references mail_messages(id) on delete cascade, filename text not null, mime_type text, size_bytes bigint not null default 0, disk_path text, created_at timestamptz not null default now(), org_id uuid);
create table mail_scheduled (id uuid primary key default gen_random_uuid(), status text);
create or replace function public.org_plan_of(_org uuid) returns text language sql stable security definer set search_path = public as $$
  select coalesce((select e.plan from public.org_members m join public.entitlement_state e on e.user_id = m.user_id where m.org_id = _org and m.role = 'owner' limit 1),'basic'); $$;
