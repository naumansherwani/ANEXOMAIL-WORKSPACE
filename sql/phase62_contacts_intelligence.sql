-- =============================================================================
-- ANEXOMAIL — Phase 62: CONTACTS & COMMUNICATION INTELLIGENCE (idempotent)
-- Supabase #4 SQL editor mein poori file copy-paste karo.
--
-- ASLI MASLA: `server/routes/contacts.ts` (Phase 10) poora likha hua hai —
-- list/search/tags/timeline, sab "NO MOCK: real mail se banta hai" comment ke
-- saath. Lekin `contacts`, `contact_stats`, `companies`, `contact_tags`,
-- `contact_tag_map` tables aur `anexo_rebuild_contacts()` RPC — jo yeh route
-- call karta hai — repo mein kahin migrate nahi thi.
--
-- IMPORTANT — is file ka rebuild function ek REASONABLE derivation hai
-- (from/to addresses ginkar), maine live data par test nahi kiya (koi DB
-- access nahi hai). Paste karne ke baad `/app/people` khol kar verify karo
-- ke counts sahi lag rahe hain — status is "READY", "DONE" nahi.
--
-- Depends on: public.mail_messages, public.mail_threads (Phase 52/54/58).
-- =============================================================================

-- ---------- companies ----------
create table if not exists public.companies (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null,
  name        text,
  domain      text,
  created_at  timestamptz not null default now()
);
create unique index if not exists companies_org_domain_uniq
  on public.companies (org_id, domain) where domain is not null;

-- ---------- contacts ----------
create table if not exists public.contacts (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null,
  display_name    text,
  primary_address text not null,
  addresses       text[] not null default '{}',
  title           text,
  company_domain  text,
  company_id      uuid references public.companies(id) on delete set null,
  vip             boolean not null default false,
  notes           text,
  health_score    int,
  last_contact_at timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create unique index if not exists contacts_org_address_uniq
  on public.contacts (org_id, primary_address);
create index if not exists contacts_org_idx on public.contacts (org_id);

-- ---------- per-contact rolling stats (joined by contacts.ts as `stats:contact_stats(...)`) ----------
create table if not exists public.contact_stats (
  contact_id        uuid primary key references public.contacts(id) on delete cascade,
  org_id            uuid not null,
  messages_in       int not null default 0,
  messages_out      int not null default 0,
  avg_reply_minutes numeric,
  open_threads      int not null default 0,
  last_contact_at   timestamptz,
  relationship      text not null default 'new',
  health_score      int,
  updated_at        timestamptz not null default now()
);

-- ---------- tags ----------
create table if not exists public.contact_tags (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null,
  name        text not null,
  colour      text,
  created_by  uuid,
  created_at  timestamptz not null default now()
);
create unique index if not exists contact_tags_org_name_uniq
  on public.contact_tags (org_id, lower(name));

create table if not exists public.contact_tag_map (
  org_id      uuid not null,
  contact_id  uuid not null references public.contacts(id) on delete cascade,
  tag_id      uuid not null references public.contact_tags(id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (contact_id, tag_id)
);
create index if not exists contact_tag_map_tag_idx on public.contact_tag_map (tag_id);

-- ---------- self-heal: /search/universal (contacts.ts) mail_attachments.org_id
-- se filter karta hai — Phase 58 ne yeh column mail_attachments par nahi
-- add kiya tha (sirf mailboxes/threads/messages par). Add-only, safe. ----------
do $$ begin
  if to_regclass('public.mail_attachments') is not null then
    alter table public.mail_attachments add column if not exists org_id uuid;
    update public.mail_attachments a
       set org_id = m.org_id
      from public.mail_messages m
     where a.message_id = m.id and a.org_id is null and m.org_id is not null;
  end if;
end $$;

-- ---------- GRANTS + RLS (phase52 convention) ----------
grant select, insert, update, delete on
  public.companies, public.contacts, public.contact_stats, public.contact_tags, public.contact_tag_map
  to authenticated;
grant all on
  public.companies, public.contacts, public.contact_stats, public.contact_tags, public.contact_tag_map
  to service_role;

do $$
declare r record;
begin
  for r in
    select unnest(array['companies','contacts','contact_stats','contact_tags','contact_tag_map']) as t
  loop
    execute format('alter table public.%I enable row level security', r.t);
    execute format('drop policy if exists auth_read on public.%I', r.t);
    execute format('create policy auth_read on public.%I for select to authenticated using (true)', r.t);
    execute format('drop policy if exists auth_write on public.%I', r.t);
    execute format('create policy auth_write on public.%I for all to authenticated using (true) with check (true)', r.t);
  end loop;
end $$;

-- =============================================================================
-- RPC: anexo_rebuild_contacts(p_org uuid) — real mail se contacts derive
-- karta hai (koi seed/dummy row nahi). contacts.ts ensureFresh() isay har
-- list-read se pehle throttled (60s) call karta hai.
--
-- Rule: apna domain (@anexomail.com) kabhi contact nahi banta — sirf bahar
-- ke counterpart addresses.
-- =============================================================================
drop function if exists public.anexo_rebuild_contacts(uuid) cascade;
create or replace function public.anexo_rebuild_contacts(p_org uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_own_domain text := 'anexomail.com';
  v_count int := 0;
begin
  if p_org is null then
    return jsonb_build_object('ok', false, 'error', 'no_org');
  end if;

  -- distinct counterpart addresses touched by this org's mail, with rollups
  with inbound as (
    select lower(m.from_address) as address,
           m.from_name,
           m.sent_at,
           m.thread_id
      from public.mail_messages m
     where m.org_id = p_org
       and m.direction = 'in'
       and m.from_address is not null
       and lower(m.from_address) not like '%@' || v_own_domain
  ),
  outbound_to as (
    select lower(a) as address, null::text as from_name, m.sent_at, m.thread_id
      from public.mail_messages m, unnest(m.to_addresses) a
     where m.org_id = p_org and m.direction = 'out'
       and lower(a) not like '%@' || v_own_domain
  ),
  outbound_cc as (
    select lower(a) as address, null::text as from_name, m.sent_at, m.thread_id
      from public.mail_messages m, unnest(m.cc_addresses) a
     where m.org_id = p_org and m.direction = 'out'
       and lower(a) not like '%@' || v_own_domain
  ),
  touched as (
    select address, from_name, sent_at, thread_id, 'in'::text as direction from inbound
    union all
    select address, from_name, sent_at, thread_id, 'out'::text as direction from outbound_to
    union all
    select address, from_name, sent_at, thread_id, 'out'::text as direction from outbound_cc
  ),
  agg as (
    select
      address,
      max(from_name) as display_name,
      count(*) filter (where direction = 'in')  as messages_in,
      count(*) filter (where direction = 'out') as messages_out,
      max(sent_at) as last_contact_at,
      count(distinct thread_id) as open_threads
    from touched
    where address is not null and address <> ''
    group by address
  ),
  upserted_contacts as (
    insert into public.contacts (org_id, display_name, primary_address, addresses, company_domain, last_contact_at)
    select p_org, a.display_name, a.address, array[a.address], split_part(a.address, '@', 2), a.last_contact_at
      from agg a
    on conflict (org_id, primary_address) do update
      set display_name    = coalesce(excluded.display_name, public.contacts.display_name),
          last_contact_at = excluded.last_contact_at,
          updated_at      = now()
    returning id, primary_address
  )
  insert into public.contact_stats (contact_id, org_id, messages_in, messages_out, open_threads, last_contact_at, relationship)
  select
    c.id, p_org, a.messages_in, a.messages_out, a.open_threads, a.last_contact_at,
    case
      when a.last_contact_at is null then 'new'
      when a.last_contact_at > now() - interval '14 days' then 'active'
      when a.last_contact_at < now() - interval '60 days' then 'dormant'
      else 'active'
    end
    from upserted_contacts c
    join agg a on a.address = c.primary_address
  on conflict (contact_id) do update
    set messages_in     = excluded.messages_in,
        messages_out    = excluded.messages_out,
        open_threads    = excluded.open_threads,
        last_contact_at = excluded.last_contact_at,
        relationship    = excluded.relationship,
        updated_at      = now();

  select count(*) into v_count from public.contacts where org_id = p_org;
  return jsonb_build_object('ok', true, 'contacts', v_count);
exception when others then
  raise notice '[anexo_rebuild_contacts] %', sqlerrm;
  return jsonb_build_object('ok', false, 'error', sqlerrm);
end $$;

grant execute on function public.anexo_rebuild_contacts(uuid) to service_role, authenticated;

-- ---------- VERIFY ----------
select
  exists(select 1 from information_schema.tables where table_schema='public' and table_name='contacts') as contacts_ready,
  exists(select 1 from pg_proc where pronamespace='public'::regnamespace and proname='anexo_rebuild_contacts') as rpc_ready;
