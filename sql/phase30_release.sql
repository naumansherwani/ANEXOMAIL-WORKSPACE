-- ANEXOMAIL — Phase 30: Production & Founder Lock
-- Supabase #4 mein chalao (SQL Editor -> paste -> Run). Idempotent + self-healing.
-- Purani conflicting table ko _legacy rename karta hai, phir fresh banata hai.

begin;

-- ---------------------------------------------------------------- helpers --
do $$
declare
  t text;
  names text[] := array[
    'release_runs','release_checks','release_checklist','deployments',
    'release_locks','roadmap_items','subscription_pipeline'
  ];
begin
  foreach t in array names loop
    -- agar table maujood hai lekin user_id column nahi (purana schema), to legacy kar do
    if exists (select 1 from information_schema.tables
               where table_schema='public' and table_name=t)
       and not exists (select 1 from information_schema.columns
               where table_schema='public' and table_name=t and column_name='user_id') then
      execute format('alter table public.%I rename to %I', t, t || '_legacy_' || to_char(now(),'YYYYMMDDHH24MISS'));
    end if;
  end loop;
end $$;

-- ------------------------------------------------------------- QA runs ----
create table if not exists public.release_runs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  suite text not null default 'all',
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  passed int not null default 0,
  warned int not null default 0,
  failed int not null default 0,
  skipped int not null default 0,
  total int not null default 0,
  ms int,
  verdict text not null default 'unknown'
);
create index if not exists release_runs_started_idx on public.release_runs(started_at desc);

create table if not exists public.release_checks (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.release_runs(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  suite text not null,
  name text not null,
  status text not null check (status in ('pass','warn','fail','skip')),
  ms int,
  code int,
  detail text,
  at timestamptz not null default now()
);
create index if not exists release_checks_run_idx on public.release_checks(run_id);

-- ------------------------------------------------ production checklist ----
create table if not exists public.release_checklist (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  area text not null,
  label text not null,
  detail text,
  state text not null default 'open' check (state in ('open','done','blocker')),
  owner text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (area, label)
);

-- ------------------------------------------------------- deploy receipts --
create table if not exists public.deployments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  target text not null default 'production',
  commit_sha text not null,
  commit_subject text,
  actor text,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  ms int,
  state text not null default 'running' check (state in ('running','success','failed','rolled_back')),
  rollback_of uuid references public.deployments(id) on delete set null,
  changed_since_green jsonb not null default '[]'::jsonb
);
create index if not exists deployments_started_idx on public.deployments(started_at desc);

-- --------------------------------------------------- version lock ledger --
create table if not exists public.release_locks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  run_id uuid references public.release_runs(id) on delete set null,
  version text not null unique,
  signed_by text not null,
  signature_hash text not null,
  verdict text not null,
  notes text,
  override_reason text,
  frozen_at timestamptz not null default now()
);

-- ------------------------------------------------------ v2.0 roadmap -----
create table if not exists public.roadmap_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  title text not null,
  area text not null default 'general',
  impact int not null default 3 check (impact between 1 and 5),
  effort int not null default 3 check (effort between 1 and 5),
  revenue_link text,
  state text not null default 'idea' check (state in ('idea','next','building','shipped')),
  created_at timestamptz not null default now()
);

-- ----------------------------------------------------- offline outbox ----
-- mail_outbox pehle se phase_wire_founder.sql mein bana hai (from_address wala).
-- Usay RENAME nahi karte — sirf Phase 30 ke columns additive add karte hain.
create table if not exists public.mail_outbox (
  id uuid primary key default gen_random_uuid(),
  from_address text,
  to_address text not null,
  subject text not null default '',
  body text not null default '',
  state text not null default 'queued',
  created_at timestamptz not null default now(),
  sent_at timestamptz
);
alter table public.mail_outbox add column if not exists user_id uuid references auth.users(id) on delete cascade;
alter table public.mail_outbox add column if not exists idempotency_key text;
alter table public.mail_outbox add column if not exists thread_id uuid;
alter table public.mail_outbox add column if not exists attempts int not null default 0;
alter table public.mail_outbox add column if not exists last_error text;
alter table public.mail_outbox alter column from_address drop not null;
create unique index if not exists mail_outbox_idem_idx
  on public.mail_outbox(idempotency_key) where idempotency_key is not null;
create index if not exists mail_outbox_user_state_idx on public.mail_outbox(user_id, state);

-- --------------------------------- migration lead -> subscription MRR ----
create table if not exists public.subscription_pipeline (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  lead_id uuid,
  plan text not null default 'pro' check (plan in ('basic','pro','business')),
  plan_seats int not null default 1,
  expected_mrr_gbp numeric(10,2) not null default 0,
  stage text not null default 'new',
  created_at timestamptz not null default now()
);
create index if not exists subscription_pipeline_lead_idx on public.subscription_pipeline(lead_id);

-- ------------------------------------------------------------- GRANTS ----
grant select, insert, update, delete on public.release_runs to authenticated;
grant select, insert, update, delete on public.release_checks to authenticated;
grant select, insert, update, delete on public.release_checklist to authenticated;
grant select, insert, update, delete on public.deployments to authenticated;
grant select, insert on public.release_locks to authenticated;
grant select, insert, update, delete on public.roadmap_items to authenticated;
grant select, insert, update, delete on public.mail_outbox to authenticated;
grant select, insert, update, delete on public.subscription_pipeline to authenticated;
grant all on public.release_runs, public.release_checks, public.release_checklist,
  public.deployments, public.release_locks, public.roadmap_items,
  public.mail_outbox, public.subscription_pipeline to service_role;

-- --------------------------------------------------------------- RLS -----
alter table public.release_runs enable row level security;
alter table public.release_checks enable row level security;
alter table public.release_checklist enable row level security;
alter table public.deployments enable row level security;
alter table public.release_locks enable row level security;
alter table public.roadmap_items enable row level security;
alter table public.mail_outbox enable row level security;
alter table public.subscription_pipeline enable row level security;

do $$
begin
  -- apna data hi dikhta hai (Brain service_role se chalta hai, RLS bypass)
  if not exists (select 1 from pg_policies where tablename='release_runs' and policyname='own runs') then
    create policy "own runs" on public.release_runs for all to authenticated
      using (user_id = auth.uid()) with check (user_id = auth.uid());
  end if;
  if not exists (select 1 from pg_policies where tablename='release_checks' and policyname='own checks') then
    create policy "own checks" on public.release_checks for all to authenticated
      using (user_id = auth.uid()) with check (user_id = auth.uid());
  end if;
  if not exists (select 1 from pg_policies where tablename='mail_outbox' and policyname='own outbox') then
    create policy "own outbox" on public.mail_outbox for all to authenticated
      using (user_id = auth.uid()) with check (user_id = auth.uid());
  end if;
  if not exists (select 1 from pg_policies where tablename='release_checklist' and policyname='checklist read') then
    create policy "checklist read" on public.release_checklist for select to authenticated using (true);
  end if;
  if not exists (select 1 from pg_policies where tablename='release_checklist' and policyname='checklist write') then
    create policy "checklist write" on public.release_checklist for update to authenticated using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where tablename='deployments' and policyname='deployments read') then
    create policy "deployments read" on public.deployments for select to authenticated using (true);
  end if;
  if not exists (select 1 from pg_policies where tablename='release_locks' and policyname='locks read') then
    create policy "locks read" on public.release_locks for select to authenticated using (true);
  end if;
  if not exists (select 1 from pg_policies where tablename='roadmap_items' and policyname='roadmap all') then
    create policy "roadmap all" on public.roadmap_items for all to authenticated using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where tablename='subscription_pipeline' and policyname='pipeline read') then
    create policy "pipeline read" on public.subscription_pipeline for select to authenticated using (true);
  end if;
end $$;

-- --------------------------------------- production checklist (real rows) --
insert into public.release_checklist (area, label, detail) values
  ('deliverability','MX records live','anexomail.com aur nexatect.com dono par MX Server 2 pe point karte hain'),
  ('deliverability','SPF published','v=spf1 include + -all, koi extra sender nahi'),
  ('deliverability','DKIM signing on','Outbound mail signed, selector DNS mein published'),
  ('deliverability','DMARC enforced','p=quarantine se shuru, reports founder mailbox par'),
  ('deliverability','Reverse DNS matches','PTR record mail hostname ke barabar'),
  ('security','TLS certificates auto-renew','Caddy renewal 30 din pehle, expiry alert on'),
  ('security','Founder-only allowlist','founderworkspace + aiemail subdomain par IP allowlist active'),
  ('security','Service role key server-side only','Frontend bundle mein sirf VITE_* keys'),
  ('security','Session revoke works','Ek click par device + session dono dead'),
  ('backup','Database backup verified','Supabase backup se ek restore drill pass'),
  ('backup','Mail store snapshot','Maildir snapshot + offsite copy check'),
  ('backup','Export tested end to end','mbox + CSV export download aur khol ke verify'),
  ('operations','PM2 resurrect on reboot','pm2 save chala, reboot ke baad services live'),
  ('operations','Memory guard set','max_memory_restart 4GB budget ke andar'),
  ('operations','Disk headroom > 30%','80GB disk par alert 70% par'),
  ('operations','Log rotation on','pm2-logrotate active, disk log se na bhare'),
  ('product','Every page visited by founder','/pages se har route khud khol ke dekha'),
  ('product','Empty states have a next action','Har khali screen par ek hi agla qadam'),
  ('product','Keyboard path for core work','Compose, reply, archive, search sab keyboard se'),
  ('product','Offline read + outbox honest','Send confirm hone se pehle kabhi sent nahi likhta'),
  ('revenue','Plans page prices correct','Basic £23 · Pro £46 · Business £97 · Business Pro £2,850'),
  ('revenue','Lead intake writes a real row','/migration, /partners, /enterprise teeno test'),
  ('revenue','Migration quote maths reviewed','Rate card £568 floor, £3,350 ceiling'),
  ('revenue','MRR vs one-off separated','Founder deck par committed, pipeline, gap alag')
on conflict (area, label) do nothing;

-- --------------------------------------------------- v2.0 roadmap seed ----
insert into public.roadmap_items (title, area, impact, effort, revenue_link, state)
select * from (values
  ('Polar checkout + auto provisioning','billing',5,3,'subscriptions','next'),
  ('VAT invoices and receipts in workspace','billing',4,2,'subscriptions','next'),
  ('Partner portal with commission statements','partners',4,3,'partner commission','next'),
  ('Email-as-command signed addresses','automation',4,3,'retention','idea'),
  ('Audited read-only share links','collaboration',3,2,'retention','idea'),
  ('Scheduled CSV / Sheets sync','integrations',3,3,'retention','idea'),
  ('Domain concierge (register + DNS managed)','domains',4,4,'new road','idea'),
  ('Offline compose queue with conflict merge','mobile',3,4,'retention','idea')
) as v(title, area, impact, effort, revenue_link, state)
where not exists (select 1 from public.roadmap_items limit 1);

commit;
