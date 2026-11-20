
-- QCONNECT_bootstrap.sql (20 Nov 2026): the compatibility layer a PLAIN PostgreSQL needs so the whole E-line (E1..E196, written for the managed project) runs on his own server.
-- Built on what the E-line uses (read first, schema-first law): roles anon / authenticated / service_role, schema extensions (pgcrypto digest/hmac/gen_random_bytes), schema auth (users, sessions, refresh_tokens,
-- identities, audit_log_entries, uid(), role(), jwt()), schema storage (objects). The auth and storage tables here are MINIMAL STUBS so the E-files can reference them; in step 4 the real rows come from a data dump
-- and the real column sets from a schema-only dump of the managed project (then this file is not run again). Safe to run again (idempotent). Opens no port, writes no secret.

do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin noinherit; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin noinherit; end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then create role service_role nologin noinherit bypassrls; end if;
end $$;

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
create extension if not exists pg_trgm with schema extensions;
create extension if not exists btree_gist with schema extensions;
grant usage on schema extensions to anon, authenticated, service_role;
grant usage on schema public to anon, authenticated, service_role;

create schema if not exists auth;
create table if not exists auth.users (
  id uuid primary key default gen_random_uuid(), instance_id uuid, aud text default 'authenticated', role text default 'authenticated', email text unique,
  encrypted_password text, email_confirmed_at timestamptz, phone text, raw_app_meta_data jsonb default '{}'::jsonb, raw_user_meta_data jsonb default '{}'::jsonb,
  is_super_admin boolean, is_sso_user boolean not null default false, is_anonymous boolean not null default false, banned_until timestamptz, deleted_at timestamptz,
  last_sign_in_at timestamptz, created_at timestamptz default now(), updated_at timestamptz default now());
create table if not exists auth.sessions (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade, created_at timestamptz default now(), updated_at timestamptz default now(),
  factor_id uuid, aal text, not_after timestamptz, refreshed_at timestamp, user_agent text, ip inet, tag text);
create table if not exists auth.refresh_tokens (
  id bigserial primary key, token text unique, user_id text, revoked boolean, created_at timestamptz default now(), updated_at timestamptz default now(), parent text, session_id uuid references auth.sessions(id) on delete cascade);
create table if not exists auth.identities (
  id uuid primary key default gen_random_uuid(), provider_id text not null, user_id uuid not null references auth.users(id) on delete cascade, identity_data jsonb not null default '{}'::jsonb, provider text not null,
  last_sign_in_at timestamptz, created_at timestamptz default now(), updated_at timestamptz default now(), email text);
create table if not exists auth.audit_log_entries (id uuid primary key default gen_random_uuid(), instance_id uuid, payload json, created_at timestamptz default now(), ip_address varchar(64) not null default '');
create or replace function auth.uid() returns uuid language sql stable as $$ select nullif(coalesce(current_setting('request.jwt.claim.sub', true), (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')), '')::uuid $$;
create or replace function auth.role() returns text language sql stable as $$ select nullif(coalesce(current_setting('request.jwt.claim.role', true), (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')), '')::text $$;
create or replace function auth.jwt() returns jsonb language sql stable as $$ select coalesce(nullif(current_setting('request.jwt.claim', true), ''), nullif(current_setting('request.jwt.claims', true), ''))::jsonb $$;
grant usage on schema auth to anon, authenticated, service_role;
grant all on all tables in schema auth to service_role;
grant all on all sequences in schema auth to service_role;
grant execute on function auth.uid(), auth.role(), auth.jwt() to anon, authenticated, service_role;

create schema if not exists storage;
create table if not exists storage.objects (id uuid primary key default gen_random_uuid(), bucket_id text, name text, owner uuid, created_at timestamptz default now(), updated_at timestamptz default now(), metadata jsonb);
grant usage on schema storage to service_role;
grant all on storage.objects to service_role;

-- default privileges the managed project gives: tables made later in public are reachable by service_role (the doors still grant explicitly; this only matches the old default)
alter default privileges in schema public grant all on tables to service_role;
alter default privileges in schema public grant all on sequences to service_role;
alter default privileges in schema public grant execute on functions to service_role;
select 'QCONNECT bootstrap ok' as result;
