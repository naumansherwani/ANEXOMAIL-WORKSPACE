-- =============================================================================
-- ANEXOMAIL — Phase 60: ORG IDENTITY REPAIR (idempotent, self-healing)
-- Supabase #4 SQL editor mein poori file copy-paste karo.
--
-- ASLI MASLA (live audit se): server/routes/auth.ts, dashboard.ts, calendar.ts,
-- contacts.ts, mail.ts, mail-compose.ts, org.ts, settings.ts, workspace.ts,
-- release.ts — sab `public.org_members` (aur kuch jagah `public.orgs`,
-- `public.mail_accounts`) query karte hain. Repo ke sql/ folder mein in teeno
-- tables ki KOI migration nahi thi — sirf `account_org_members` +
-- `account_organisations` (Phase 59, onboarding flow) bani thi. Isi wajah se
-- login ke baad "No organisation yet" (409 no_workspace) aur mail/calendar/
-- contacts 401/500 aate hain — feature code sahi hai, sirf uski table gayab thi.
--
-- Yeh file:
--   1) `orgs`, `org_members`, `mail_accounts` ensure karti hai (agar missing hon)
--   2) account_org_members se org_members mein backfill karti hai (koi row
--      delete/rename nahi — sirf reconcile)
--   3) Grants + RLS existing repo convention se match (phase52/phase59 jaisa)
-- Koi existing table drop/rename nahi hoti. Purana data safe hai.
-- =============================================================================

-- ---------- 1) orgs (auth.ts operationalOrganisation() ka fallback lookup) ----------
create table if not exists public.orgs (
  id          uuid primary key default gen_random_uuid(),
  name        text not null default 'ANEXOMAIL Workspace',
  created_at  timestamptz not null default now()
);

-- ---------- 2) org_members (majority backend code isi naam se padhta hai) ----------
create table if not exists public.org_members (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null,
  user_id     uuid not null,
  email       text,
  role        text not null default 'member',
  status      text not null default 'active',
  created_at  timestamptz not null default now()
);
create unique index if not exists org_members_org_user_uniq
  on public.org_members (org_id, user_id);
create index if not exists org_members_user_idx on public.org_members (user_id);

-- ---------- 3) mail_accounts (mailbox -> org resolution; auth.ts + mail_ingest se) ----------
create table if not exists public.mail_accounts (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid,
  address     text not null unique,
  created_at  timestamptz not null default now()
);

-- ---------- 4) self-heal: agar org_members purani generation mein bina zaroori
-- columns ke maujood ho (jaise sirf org_id/user_id), missing columns add karo
-- (drop/rename nahi — sirf columns add, purana data safe) ----------
alter table public.org_members add column if not exists email  text;
alter table public.org_members add column if not exists role  text not null default 'member';
alter table public.org_members add column if not exists status text not null default 'active';

-- ---------- 5) backfill: account_org_members (Phase 59, real onboarding data)
-- se org_members mein reconcile — taake purana + naya dono code path chalen ----------
do $$
begin
  if to_regclass('public.account_org_members') is not null then
    insert into public.org_members (org_id, user_id, role, status)
    select m.org_id, m.user_id, coalesce(m.role, 'member'), 'active'
      from public.account_org_members m
    on conflict (org_id, user_id) do update
      set role = excluded.role, status = 'active';
  end if;
end $$;

-- ---------- GRANTS (RLS se pehle, warna PostgREST band — phase52 convention) ----------
grant select, insert, update, delete on public.org_members, public.mail_accounts to authenticated;
grant select on public.orgs to authenticated;
grant all on public.orgs, public.org_members, public.mail_accounts to service_role;

alter table public.orgs         enable row level security;
alter table public.org_members  enable row level security;
alter table public.mail_accounts enable row level security;

drop policy if exists auth_read on public.orgs;
create policy auth_read on public.orgs for select to authenticated using (true);

drop policy if exists auth_read on public.org_members;
create policy auth_read on public.org_members for select to authenticated using (true);
drop policy if exists auth_write on public.org_members;
create policy auth_write on public.org_members for all to authenticated using (true) with check (true);

drop policy if exists auth_read on public.mail_accounts;
create policy auth_read on public.mail_accounts for select to authenticated using (true);

-- ---------- VERIFY ----------
select
  (select count(*) from public.orgs)          as orgs_rows,
  (select count(*) from public.org_members)   as org_members_rows,
  (select count(*) from public.mail_accounts) as mail_accounts_rows,
  exists(select 1 from information_schema.tables
          where table_schema='public' and table_name='account_org_members') as account_org_members_present;
