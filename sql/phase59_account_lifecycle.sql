-- ANEXOMAIL Phase 59 — real account profile, organisation membership and sessions
-- Idempotent. Auth credentials remain in auth.users; roles are never stored on profiles.
set search_path = public, extensions;

create table if not exists public.account_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  legal_name text not null,
  display_name text not null,
  avatar_url text,
  work_role text,
  preferences jsonb not null default '{}'::jsonb,
  onboarded boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
grant select, insert, update on public.account_profiles to authenticated;
grant all on public.account_profiles to service_role;
alter table public.account_profiles enable row level security;
drop policy if exists account_profiles_own_select on public.account_profiles;
create policy account_profiles_own_select on public.account_profiles for select to authenticated using (user_id=auth.uid());
drop policy if exists account_profiles_own_update on public.account_profiles;
create policy account_profiles_own_update on public.account_profiles for update to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());

do $$ begin create type public.app_role as enum ('admin','moderator','user'); exception when duplicate_object then null; end $$;
do $$ begin alter type public.app_role add value if not exists 'user'; exception when duplicate_object then null; end $$;
create table if not exists public.user_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.app_role not null,
  unique(user_id,role)
);
grant select on public.user_roles to authenticated;
grant all on public.user_roles to service_role;
alter table public.user_roles enable row level security;
drop policy if exists user_roles_own_select on public.user_roles;
create policy user_roles_own_select on public.user_roles for select to authenticated using (user_id=auth.uid());

create or replace function public.has_role(_user_id uuid, _role public.app_role)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.user_roles where user_id=_user_id and role=_role)
$$;
grant execute on function public.has_role(uuid,public.app_role) to authenticated, service_role;

-- Signup profile is written server-side, but this keeps retries safe if Auth already owns the user.
create or replace function public.account_profile_touch_updated_at()
returns trigger language plpgsql as $$ begin new.updated_at=now(); return new; end $$;
drop trigger if exists account_profiles_touch_updated_at on public.account_profiles;
create trigger account_profiles_touch_updated_at before update on public.account_profiles
for each row execute function public.account_profile_touch_updated_at();

create table if not exists public.account_organisations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  domain text,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);
grant select, insert, update on public.account_organisations to authenticated;
grant all on public.account_organisations to service_role;
alter table public.account_organisations enable row level security;

create table if not exists public.account_org_members (
  org_id uuid not null references public.account_organisations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check(role in ('owner','admin','member')),
  created_at timestamptz not null default now(),
  primary key(org_id,user_id)
);
grant select, insert, update, delete on public.account_org_members to authenticated;
grant all on public.account_org_members to service_role;
alter table public.account_org_members enable row level security;
drop policy if exists account_org_members_own_select on public.account_org_members;
create policy account_org_members_own_select on public.account_org_members for select to authenticated using (user_id=auth.uid());
drop policy if exists account_organisations_member_select on public.account_organisations;
create policy account_organisations_member_select on public.account_organisations for select to authenticated
using (exists(select 1 from public.account_org_members m where m.org_id=id and m.user_id=auth.uid()));

create table if not exists public.account_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token_hash text not null unique,
  device text,
  browser text,
  ip text,
  location text,
  last_seen_at timestamptz not null default now(),
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);
grant select, delete on public.account_sessions to authenticated;
grant all on public.account_sessions to service_role;
alter table public.account_sessions enable row level security;
drop policy if exists account_sessions_own_select on public.account_sessions;
create policy account_sessions_own_select on public.account_sessions for select to authenticated using (user_id=auth.uid());

notify pgrst, 'reload schema';