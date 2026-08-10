-- ANEXOMAIL — WIRING PAGE 1: Founder Command Deck + AI Email Center
-- Supabase #4. Idempotent + self-healing from the first line.
-- Ye registry REAL hai: har address woh hai jo Postfix/Dovecot par banega.
-- Legacy UUID id columns without defaults are repaired before any seed runs.

/* ---------------------------------------------------------------- mailboxes */
do $$
begin
  if exists (select 1 from information_schema.tables
             where table_schema='public' and table_name='mailboxes')
     and not exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='mailboxes' and column_name='kind')
  then
    execute format('alter table public.mailboxes rename to mailboxes_legacy_%s',
                   to_char(now(),'YYYYMMDDHH24MISS'));
  end if;
end $$;

create table if not exists public.mailboxes (
  id uuid primary key default gen_random_uuid(),
  address text not null unique,
  display_name text,
  kind text not null default 'founder',
  domain text not null default 'anexomail.com',
  provisioned boolean not null default false,
  agent text,
  aliases text[] not null default '{}',
  note text,
  provision_requested_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.mailboxes add column if not exists display_name text;
alter table public.mailboxes add column if not exists kind text not null default 'founder';
alter table public.mailboxes add column if not exists domain text not null default 'anexomail.com';
alter table public.mailboxes add column if not exists provisioned boolean not null default false;
alter table public.mailboxes add column if not exists agent text;
alter table public.mailboxes add column if not exists aliases text[] not null default '{}';
alter table public.mailboxes add column if not exists note text;
alter table public.mailboxes add column if not exists provision_requested_at timestamptz;
alter table public.mailboxes add column if not exists created_at timestamptz not null default now();

-- Purani compatible table mein UUID default missing ho sakta hai.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='mailboxes'
      and column_name='id' and data_type='uuid'
  ) then
    alter table public.mailboxes alter column id set default gen_random_uuid();
  end if;
end $$;
alter table public.mailboxes alter column created_at set default now();

-- purane duplicate address hatao, phir unique constraint pakka karo (ON CONFLICT ke liye lazmi)
delete from public.mailboxes a using public.mailboxes b
  where a.address = b.address and a.ctid > b.ctid;
do $$
begin
  if not exists (
    select 1 from pg_indexes
    where schemaname='public' and tablename='mailboxes' and indexname='mailboxes_address_key'
  ) then
    execute 'create unique index mailboxes_address_key on public.mailboxes(address)';
  end if;
end $$;

grant select on public.mailboxes to authenticated;
grant all on public.mailboxes to service_role;
alter table public.mailboxes enable row level security;
drop policy if exists mailboxes_read on public.mailboxes;
create policy mailboxes_read on public.mailboxes for select to authenticated using (true);

/* ------------------------------------------------------------------ domains */
create table if not exists public.mail_domains (
  domain text primary key,
  spf_ok boolean not null default false,
  dkim_ok boolean not null default false,
  dmarc_ok boolean not null default false,
  checked_at timestamptz
);
grant select on public.mail_domains to authenticated;
grant all on public.mail_domains to service_role;
alter table public.mail_domains enable row level security;
drop policy if exists mail_domains_read on public.mail_domains;
create policy mail_domains_read on public.mail_domains for select to authenticated using (true);

insert into public.mail_domains (domain) values ('anexomail.com'), ('nexatect.com')
on conflict (domain) do nothing;

/* ------------------------------------------------------------- agent roster */
create table if not exists public.ai_agents (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  role text not null,
  address text not null unique,
  reports_to text,
  model text,
  status text not null default 'provisioning',
  created_at timestamptz not null default now()
);

alter table public.ai_agents add column if not exists reports_to text;
alter table public.ai_agents add column if not exists model text;
alter table public.ai_agents add column if not exists status text not null default 'provisioning';
alter table public.ai_agents add column if not exists created_at timestamptz not null default now();

-- Critical self-heal: old ai_agents.id UUID NOT NULL tha magar default nahi tha.
-- Is repair ke baad every inserted agent gets a real UUID automatically.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='ai_agents'
      and column_name='id' and data_type='uuid'
  ) then
    alter table public.ai_agents alter column id set default gen_random_uuid();
  else
    raise exception 'public.ai_agents.id must be uuid; incompatible legacy schema detected';
  end if;
end $$;
alter table public.ai_agents alter column created_at set default now();

delete from public.ai_agents a using public.ai_agents b
  where a.address = b.address and a.ctid > b.ctid;
do $$
begin
  if not exists (
    select 1 from pg_indexes
    where schemaname='public' and tablename='ai_agents' and indexname='ai_agents_address_key'
  ) then
    execute 'create unique index ai_agents_address_key on public.ai_agents(address)';
  end if;
end $$;

grant select on public.ai_agents to authenticated;
grant all on public.ai_agents to service_role;
alter table public.ai_agents enable row level security;
drop policy if exists ai_agents_read on public.ai_agents;
create policy ai_agents_read on public.ai_agents for select to authenticated using (true);

/* --------------------------------------------------------- founder mailboxes */
insert into public.mailboxes (address, display_name, kind, domain, agent, note) values
 ('naumansherwani.founder@anexomail.com','Muhammad Nauman Sherwani','founder','anexomail.com',null,'Primary founder mailbox. Private, never AI-answered.'),
 ('naumansherwani.founder@nexatect.com','Muhammad Nauman Sherwani — NEXATECT','founder','nexatect.com',null,'Parent-company founder mailbox.'),
 ('support@anexomail.com','ANEXOMAIL Support','support','anexomail.com','Leo','Leo answers like a human. Under 4 minutes, no tickets.'),
 ('hello@anexomail.com','ANEXOMAIL','support','anexomail.com','Leo','First contact and sales questions.'),
 ('billing@anexomail.com','ANEXOMAIL Billing','support','anexomail.com','Leo','Money topics are draft-only until approved.'),
 ('noreply@anexomail.com','ANEXOMAIL (no reply)','system','anexomail.com',null,'Outbound system mail. Inbound discarded.'),
 ('leo@anexomail.com','Leo — ANEXOMAIL AI','agent','anexomail.com','Leo','Workspace AI. Primary responder.'),
 ('jimmyjohn@nexatect.com','Jimmy John — Supreme Commander','agent','nexatect.com','Jimmy John','Escalation target, never first responder.'),
 ('sherlock@nexatect.com','Sherlock — Deputy','agent','nexatect.com','Sherlock','Validation layer.'),
 ('aria.tth@nexatect.com','Aria — Travel & hospitality','industry','nexatect.com','Aria','Industry desk.'),
 ('orion.airlines@nexatect.com','Captain Orion — Airlines','industry','nexatect.com','Captain Orion','Industry desk.'),
 ('rex@nexatect.com','Rex — Car rental','industry','nexatect.com','Rex','Industry desk.'),
 ('lyra@nexatect.com','Dr. Lyra — Healthcare','industry','nexatect.com','Dr. Lyra','Industry desk.'),
 ('sage.education@nexatect.com','Professor Sage — Education','industry','nexatect.com','Professor Sage','Industry desk.'),
 ('atlas.logistics@nexatect.com','Atlas — Logistics','industry','nexatect.com','Atlas','Industry desk.'),
 ('vega.ee@nexatect.com','Vega — Events & entertainment','industry','nexatect.com','Vega','Industry desk.'),
 ('kai.railways@nexatect.com','Conductor Kai — Railways','industry','nexatect.com','Conductor Kai','Industry desk.')
on conflict (address) do update set
  display_name = excluded.display_name,
  kind = excluded.kind,
  domain = excluded.domain,
  agent = excluded.agent,
  note = excluded.note;

insert into public.ai_agents (name, role, address, reports_to, model) values
 ('Leo','ANEXOMAIL AI · primary responder','leo@anexomail.com','jimmyjohn@nexatect.com',null),
 ('Jimmy John','Supreme Commander · CEO of the AI layer','jimmyjohn@nexatect.com',null,null),
 ('Sherlock','Deputy · validation','sherlock@nexatect.com','jimmyjohn@nexatect.com',null),
 ('Aria','Travel & hospitality','aria.tth@nexatect.com','jimmyjohn@nexatect.com',null),
 ('Captain Orion','Airlines','orion.airlines@nexatect.com','jimmyjohn@nexatect.com',null),
 ('Rex','Car rental','rex@nexatect.com','jimmyjohn@nexatect.com',null),
 ('Dr. Lyra','Healthcare','lyra@nexatect.com','jimmyjohn@nexatect.com',null),
 ('Professor Sage','Education','sage.education@nexatect.com','jimmyjohn@nexatect.com',null),
 ('Atlas','Logistics','atlas.logistics@nexatect.com','jimmyjohn@nexatect.com',null),
 ('Vega','Events & entertainment','vega.ee@nexatect.com','jimmyjohn@nexatect.com',null),
 ('Conductor Kai','Railways','kai.railways@nexatect.com','jimmyjohn@nexatect.com',null)
on conflict (address) do update set
  name = excluded.name, role = excluded.role, reports_to = excluded.reports_to;

/* ------------------------------------------------- Leo / agent email drafts */
create table if not exists public.leo_email_drafts (
  id uuid primary key default gen_random_uuid(),
  agent text not null default 'Leo',
  from_address text not null,
  to_address text not null,
  subject text not null default '',
  body text not null default '',
  confidence numeric,
  state text not null default 'draft',
  escalated_to text,
  approved_at timestamptz,
  approved_by uuid,
  created_at timestamptz not null default now()
);
alter table public.leo_email_drafts add column if not exists agent text not null default 'Leo';
alter table public.leo_email_drafts add column if not exists confidence numeric;
alter table public.leo_email_drafts add column if not exists state text not null default 'draft';
alter table public.leo_email_drafts add column if not exists escalated_to text;
alter table public.leo_email_drafts add column if not exists approved_at timestamptz;
alter table public.leo_email_drafts add column if not exists approved_by uuid;
grant select on public.leo_email_drafts to authenticated;
grant all on public.leo_email_drafts to service_role;
alter table public.leo_email_drafts enable row level security;
drop policy if exists leo_email_drafts_read on public.leo_email_drafts;
create policy leo_email_drafts_read on public.leo_email_drafts for select to authenticated using (true);

/* -------------------------------------------------------------- mail outbox */
create table if not exists public.mail_outbox (
  id uuid primary key default gen_random_uuid(),
  from_address text not null,
  to_address text not null,
  subject text not null default '',
  body text not null default '',
  source text,
  source_id uuid,
  state text not null default 'queued',
  error text,
  created_at timestamptz not null default now(),
  sent_at timestamptz
);
grant select on public.mail_outbox to authenticated;
grant all on public.mail_outbox to service_role;
alter table public.mail_outbox enable row level security;
drop policy if exists mail_outbox_read on public.mail_outbox;
create policy mail_outbox_read on public.mail_outbox for select to authenticated using (true);

/* ---------------------------------------------------------------- founders */
create table if not exists public.founder_accounts (
  user_id uuid primary key,
  email text not null,
  created_at timestamptz not null default now()
);
grant select on public.founder_accounts to authenticated;
grant all on public.founder_accounts to service_role;
alter table public.founder_accounts enable row level security;
drop policy if exists founder_accounts_self on public.founder_accounts;
create policy founder_accounts_self on public.founder_accounts
  for select to authenticated using (user_id = auth.uid());