-- E86 — Compose: (1) mail_followups table tha hi nahi (Follow-up GET/POST live 500), (2) draft versions mein (draft_id, version) unique nahi tha — do saath saves ek hi version number le sakte the. 24 Oct 2026. Dobara chalana safe.
set lock_timeout = '5s';
set statement_timeout = '60s';

-- 1) Follow-up reminders (service_role only; Rust/Bun filter by org_id + user_id)
create table if not exists public.mail_followups (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organisations(id) on delete cascade,
  user_id uuid not null,
  thread_id uuid references public.mail_threads(id) on delete cascade,
  subject text check (subject is null or char_length(subject) <= 998),
  remind_at timestamptz not null,
  status text not null default 'pending' check (status in ('pending', 'kept', 'missed')),
  created_at timestamptz not null default now()
);
create index if not exists mail_followups_user_idx on public.mail_followups (org_id, user_id, remind_at);
alter table public.mail_followups enable row level security;
revoke all on public.mail_followups from public, anon, authenticated;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'mail_followups' and policyname = 'mail_followups_service') then
    create policy mail_followups_service on public.mail_followups for all to service_role using (true) with check (true);
  end if;
end $$;
grant all on public.mail_followups to service_role;

-- 2) Draft versions: renumber any duplicates (keeps order), then one unique key
with n as (
  select id, row_number() over (partition by draft_id order by version, saved_at, id) as rn
  from public.mail_drafts_versions
)
update public.mail_drafts_versions d set version = n.rn from n where d.id = n.id and d.version <> n.rn;
create unique index if not exists mail_drafts_versions_draft_version_uq on public.mail_drafts_versions (draft_id, version);
