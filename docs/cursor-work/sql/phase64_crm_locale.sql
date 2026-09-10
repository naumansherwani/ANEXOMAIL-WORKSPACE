-- =============================================================================
-- ANEXOMAIL — Phase 64: CRM recorded graph + 28-locale catalog
-- Supabase #4 SQL Editor — poori file paste → Run. Sirf yahi raasta.
--
-- Yeh file:
--   1) 28 awam locales lock karti hai (Hebrew/Swahili nahi)
--   2) User ki zubaan persist (awam_locale_pref) — future pages t() se auto
--   3) ui_copy overlay — asli tarjuma; missing = English, dummy nahi
--   4) CRM tables the API already reads/writes (leads, deals, graph, evidence)
--
-- Koi table DROP nahi. Idempotent. Fail ho to USI file ko theek likho — naya naam nahi.
-- =============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 28 locales (source of truth)
-- ---------------------------------------------------------------------------
create table if not exists public.locale_registry (
  tag        text primary key,
  english    text not null,
  native     text not null,
  dir        text not null check (dir in ('ltr', 'rtl')),
  sort_n     smallint not null
);

insert into public.locale_registry (tag, english, native, dir, sort_n) values
  ('en-GB', 'English',           'English',            'ltr', 1),
  ('hi-IN', 'Hindi',             'हिन्दी',               'ltr', 2),
  ('ur-PK', 'Urdu',              'اردو',               'rtl', 3),
  ('ar-SA', 'Arabic',            'العربية',            'rtl', 4),
  ('es-ES', 'Spanish',           'Español',            'ltr', 5),
  ('fr-FR', 'French',            'Français',           'ltr', 6),
  ('de-DE', 'German',            'Deutsch',            'ltr', 7),
  ('de-CH', 'Swiss German',      'Schweizerdeutsch',   'ltr', 8),
  ('pt-BR', 'Portuguese',        'Português',          'ltr', 9),
  ('zh-CN', 'Chinese',           '中文',                'ltr', 10),
  ('ja-JP', 'Japanese',          '日本語',              'ltr', 11),
  ('ko-KR', 'Korean',            '한국어',              'ltr', 12),
  ('tr-TR', 'Turkish',           'Türkçe',             'ltr', 13),
  ('it-IT', 'Italian',           'Italiano',           'ltr', 14),
  ('ro-RO', 'Romanian',          'Română',             'ltr', 15),
  ('ru-RU', 'Russian',           'Русский',            'ltr', 16),
  ('nl-NL', 'Dutch',             'Nederlands',         'ltr', 17),
  ('pl-PL', 'Polish',            'Polski',             'ltr', 18),
  ('uk-UA', 'Ukrainian',         'Українська',         'ltr', 19),
  ('id-ID', 'Indonesian',        'Bahasa Indonesia',   'ltr', 20),
  ('ms-MY', 'Malay',             'Bahasa Melayu',      'ltr', 21),
  ('vi-VN', 'Vietnamese',        'Tiếng Việt',         'ltr', 22),
  ('th-TH', 'Thai',              'ไทย',                'ltr', 23),
  ('bn-BD', 'Bengali',           'বাংলা',               'ltr', 24),
  ('pa-IN', 'Punjabi',           'ਪੰਜਾਬੀ',              'ltr', 25),
  ('fa-IR', 'Persian',           'فارسی',              'rtl', 26),
  ('el-GR', 'Greek',             'Ελληνικά',           'ltr', 27),
  ('sv-SE', 'Swedish',           'Svenska',            'ltr', 28)
on conflict (tag) do update
  set english = excluded.english,
      native  = excluded.native,
      dir     = excluded.dir,
      sort_n  = excluded.sort_n;

delete from public.locale_registry
 where tag not in (
   'en-GB','hi-IN','ur-PK','ar-SA','es-ES','fr-FR','de-DE','de-CH','pt-BR','zh-CN',
   'ja-JP','ko-KR','tr-TR','it-IT','ro-RO','ru-RU','nl-NL','pl-PL','uk-UA','id-ID',
   'ms-MY','vi-VN','th-TH','bn-BD','pa-IN','fa-IR','el-GR','sv-SE'
 );

-- ---------------------------------------------------------------------------
-- Awam locale preference (cross-device). Founder/family client never writes.
-- ---------------------------------------------------------------------------
create table if not exists public.awam_locale_pref (
  user_id    uuid primary key,
  locale_tag text not null references public.locale_registry(tag),
  updated_at timestamptz not null default now()
);

alter table public.awam_locale_pref add column if not exists user_id uuid;
alter table public.awam_locale_pref add column if not exists locale_tag text;
alter table public.awam_locale_pref add column if not exists updated_at timestamptz;

-- ---------------------------------------------------------------------------
-- ui_copy — original overlay. Missing locale row = English at runtime.
-- Future page: t("English") + optional insert here. Dummy rows banned.
-- ---------------------------------------------------------------------------
create table if not exists public.ui_copy (
  id          uuid primary key default gen_random_uuid(),
  english_key text not null,
  locale_tag  text not null references public.locale_registry(tag),
  text        text not null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

alter table public.ui_copy add column if not exists english_key text;
alter table public.ui_copy add column if not exists locale_tag text;
alter table public.ui_copy add column if not exists text text;
alter table public.ui_copy add column if not exists created_at timestamptz;
alter table public.ui_copy add column if not exists updated_at timestamptz;

create unique index if not exists ui_copy_key_tag_uidx
  on public.ui_copy (english_key, locale_tag);

create index if not exists ui_copy_tag_idx on public.ui_copy (locale_tag);

-- Register an English source key (no invented translations).
create or replace function public.ui_copy_register(p_english text)
returns void
language plpgsql
as $$
begin
  if p_english is null or length(btrim(p_english)) = 0 then
    return;
  end if;
  insert into public.ui_copy (english_key, locale_tag, text)
  values (btrim(p_english), 'en-GB', btrim(p_english))
  on conflict (english_key, locale_tag) do nothing;
end;
$$;

create or replace function public.ui_copy_bundle(p_tag text)
returns jsonb
language sql
stable
as $$
  select coalesce(jsonb_object_agg(c.english_key, c.text), '{}'::jsonb)
    from public.ui_copy c
   where c.locale_tag = p_tag
     and c.text is not null
     and length(btrim(c.text)) > 0
     and not (p_tag <> 'en-GB' and c.text = c.english_key);
$$;

-- ---------------------------------------------------------------------------
-- CRM book (API already uses these names)
-- ---------------------------------------------------------------------------
create table if not exists public.crm_leads (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid,
  email         text not null,
  display_name  text,
  company       text,
  source        text not null default 'manual',
  score         numeric,
  score_reason  text,
  owner         text,
  state         text not null default 'new',
  last_touch_at timestamptz,
  created_at    timestamptz not null default now()
);

create table if not exists public.crm_deals (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid,
  title          text not null,
  company        text,
  contact_email  text,
  stage          text not null default 'new',
  value          numeric not null default 0,
  currency       text not null default 'GBP',
  probability    numeric,
  owner          text,
  next_step      text,
  next_step_due  timestamptz,
  thread_id      uuid,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create table if not exists public.crm_activities (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid,
  kind           text not null default 'note',
  actor          text,
  subject        text,
  body           text,
  deal_id        uuid,
  contact_email  text,
  created_at     timestamptz not null default now()
);

create table if not exists public.crm_audit (
  id         uuid primary key default gen_random_uuid(),
  actor      text,
  action     text not null,
  target     text,
  ip         text,
  created_at timestamptz not null default now()
);

create table if not exists public.crm_shared_items (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid,
  kind          text not null,
  subject       text,
  preview       text,
  from_address  text,
  assigned_to   text,
  state         text not null default 'unassigned',
  thread_id     uuid,
  created_at    timestamptz not null default now()
);

create table if not exists public.crm_mentions (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid,
  actor      text,
  target     text,
  context    text,
  thread_id  uuid,
  deal_id    uuid,
  read       boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.crm_approvals (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid,
  requested_by  text,
  subject       text,
  reason        text,
  amount        numeric,
  currency      text,
  state         text not null default 'pending',
  decided_by    text,
  decided_at    timestamptz,
  created_at    timestamptz not null default now()
);

create table if not exists public.crm_permissions (
  id                  uuid primary key default gen_random_uuid(),
  org_id              uuid,
  user_id             uuid,
  email               text,
  role                text not null default 'member',
  can_see_all_deals   boolean not null default false,
  can_send_as_shared  boolean not null default false,
  can_approve         boolean not null default false
);

-- Recorded links only (no inferred AI edges)
create table if not exists public.crm_graph_edges (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid,
  from_kind  text not null,
  from_id    text not null,
  to_kind    text not null,
  to_id      text not null,
  kind       text not null,
  created_at timestamptz not null default now()
);

-- Append-only evidence (CR11). No UPDATE trigger — historical rows stay.
create table if not exists public.crm_evidence (
  id           uuid primary key default gen_random_uuid(),
  org_id       uuid,
  actor        text,
  decision     text not null,
  why          text,
  source_table text,
  source_id    text,
  action       text,
  result       text,
  created_at   timestamptz not null default now()
);

-- Heal columns if tables already existed without them.
alter table public.crm_leads add column if not exists org_id uuid;
alter table public.crm_leads add column if not exists email text;
alter table public.crm_leads add column if not exists display_name text;
alter table public.crm_leads add column if not exists company text;
alter table public.crm_leads add column if not exists source text;
alter table public.crm_leads add column if not exists score numeric;
alter table public.crm_leads add column if not exists score_reason text;
alter table public.crm_leads add column if not exists owner text;
alter table public.crm_leads add column if not exists state text;
alter table public.crm_leads add column if not exists last_touch_at timestamptz;
alter table public.crm_leads add column if not exists created_at timestamptz;

alter table public.crm_deals add column if not exists org_id uuid;
alter table public.crm_deals add column if not exists title text;
alter table public.crm_deals add column if not exists company text;
alter table public.crm_deals add column if not exists contact_email text;
alter table public.crm_deals add column if not exists stage text;
alter table public.crm_deals add column if not exists value numeric;
alter table public.crm_deals add column if not exists currency text;
alter table public.crm_deals add column if not exists probability numeric;
alter table public.crm_deals add column if not exists owner text;
alter table public.crm_deals add column if not exists next_step text;
alter table public.crm_deals add column if not exists next_step_due timestamptz;
alter table public.crm_deals add column if not exists thread_id uuid;
alter table public.crm_deals add column if not exists created_at timestamptz;
alter table public.crm_deals add column if not exists updated_at timestamptz;

alter table public.crm_activities add column if not exists org_id uuid;
alter table public.crm_activities add column if not exists kind text;
alter table public.crm_activities add column if not exists actor text;
alter table public.crm_activities add column if not exists subject text;
alter table public.crm_activities add column if not exists body text;
alter table public.crm_activities add column if not exists deal_id uuid;
alter table public.crm_activities add column if not exists contact_email text;
alter table public.crm_activities add column if not exists created_at timestamptz;

alter table public.crm_audit add column if not exists actor text;
alter table public.crm_audit add column if not exists action text;
alter table public.crm_audit add column if not exists target text;
alter table public.crm_audit add column if not exists ip text;
alter table public.crm_audit add column if not exists created_at timestamptz;

alter table public.work_tasks add column if not exists source_deal_id uuid;

do $$
begin
  execute 'create index if not exists crm_leads_org_owner_idx on public.crm_leads (org_id, owner)';
  execute 'create index if not exists crm_leads_email_idx on public.crm_leads (email)';
  execute 'create index if not exists crm_deals_org_owner_idx on public.crm_deals (org_id, owner)';
  execute 'create index if not exists crm_deals_thread_idx on public.crm_deals (thread_id)';
  execute 'create index if not exists crm_deals_contact_idx on public.crm_deals (contact_email)';
  execute 'create index if not exists crm_activities_deal_idx on public.crm_activities (deal_id, created_at desc)';
  execute 'create index if not exists crm_audit_created_idx on public.crm_audit (created_at desc)';
  execute 'create unique index if not exists crm_graph_edges_uidx on public.crm_graph_edges (org_id, from_kind, from_id, to_kind, to_id, kind)';
  execute 'create index if not exists crm_evidence_org_idx on public.crm_evidence (org_id, created_at desc)';
  execute 'create index if not exists awam_locale_pref_tag_idx on public.awam_locale_pref (locale_tag)';
exception when others then
  raise notice 'phase64 index: %', sqlerrm;
end $$;

-- Append-only: block updates/deletes on evidence
create or replace function public.crm_evidence_no_mutate()
returns trigger
language plpgsql
as $$
begin
  raise exception 'crm_evidence is append-only';
end;
$$;

drop trigger if exists crm_evidence_no_update on public.crm_evidence;
create trigger crm_evidence_no_update
  before update or delete on public.crm_evidence
  for each row execute procedure public.crm_evidence_no_mutate();

-- Grants
grant select on public.locale_registry to anon, authenticated;
grant select on public.ui_copy to anon, authenticated;
grant select, insert, update on public.awam_locale_pref to authenticated;
grant select, insert, update, delete on
  public.crm_leads, public.crm_deals, public.crm_activities, public.crm_audit,
  public.crm_shared_items, public.crm_mentions, public.crm_approvals,
  public.crm_permissions, public.crm_graph_edges
  to authenticated;
grant select, insert on public.crm_evidence to authenticated;
grant all on
  public.locale_registry, public.ui_copy, public.awam_locale_pref,
  public.crm_leads, public.crm_deals, public.crm_activities, public.crm_audit,
  public.crm_shared_items, public.crm_mentions, public.crm_approvals,
  public.crm_permissions, public.crm_graph_edges, public.crm_evidence
  to service_role;
grant execute on function public.ui_copy_bundle(text) to anon, authenticated, service_role;
grant execute on function public.ui_copy_register(text) to service_role;

do $$
declare r record;
begin
  for r in
    select unnest(array[
      'locale_registry','ui_copy','awam_locale_pref',
      'crm_leads','crm_deals','crm_activities','crm_audit',
      'crm_shared_items','crm_mentions','crm_approvals','crm_permissions',
      'crm_graph_edges','crm_evidence'
    ]) as t
  loop
    execute format('alter table public.%I enable row level security', r.t);
  end loop;

  drop policy if exists locale_registry_read on public.locale_registry;
  create policy locale_registry_read on public.locale_registry
    for select to anon, authenticated using (true);

  drop policy if exists ui_copy_read on public.ui_copy;
  create policy ui_copy_read on public.ui_copy
    for select to anon, authenticated using (true);

  drop policy if exists awam_locale_own on public.awam_locale_pref;
  create policy awam_locale_own on public.awam_locale_pref
    for all to authenticated
    using (user_id = auth.uid())
    with check (user_id = auth.uid());

  for r in
    select unnest(array[
      'crm_leads','crm_deals','crm_activities','crm_audit',
      'crm_shared_items','crm_mentions','crm_approvals','crm_permissions',
      'crm_graph_edges'
    ]) as t
  loop
    execute format('drop policy if exists auth_read on public.%I', r.t);
    execute format('create policy auth_read on public.%I for select to authenticated using (true)', r.t);
    execute format('drop policy if exists auth_write on public.%I', r.t);
    execute format('create policy auth_write on public.%I for all to authenticated using (true) with check (true)', r.t);
  end loop;

  drop policy if exists crm_evidence_read on public.crm_evidence;
  create policy crm_evidence_read on public.crm_evidence
    for select to authenticated using (true);
  drop policy if exists crm_evidence_insert on public.crm_evidence;
  create policy crm_evidence_insert on public.crm_evidence
    for insert to authenticated with check (true);
end $$;

-- Catalog a handful of CRM English keys so future overlay rows have a home.
select public.ui_copy_register('CRM');
select public.ui_copy_register('Dashboard');
select public.ui_copy_register('Relationships');
select public.ui_copy_register('Leads');
select public.ui_copy_register('Pipeline');
select public.ui_copy_register('Shared work');
select public.ui_copy_register('Activity');
select public.ui_copy_register('The book next to mail');
select public.ui_copy_register('Every number is a row. Empty is empty.');
select public.ui_copy_register('Capture');
select public.ui_copy_register('Memory');
select public.ui_copy_register('Timeline');
select public.ui_copy_register('Promises');
select public.ui_copy_register('Health');
select public.ui_copy_register('Risk');
select public.ui_copy_register('Graph');
select public.ui_copy_register('Evidence');
select public.ui_copy_register('Next');
select public.ui_copy_register('Attach mail');

commit;

select
  (select count(*) from public.locale_registry) as locales_28,
  exists(select 1 from information_schema.tables where table_schema='public' and table_name='crm_deals') as crm_deals_ready,
  exists(select 1 from information_schema.tables where table_schema='public' and table_name='crm_evidence') as crm_evidence_ready,
  exists(select 1 from information_schema.tables where table_schema='public' and table_name='ui_copy') as ui_copy_ready,
  exists(select 1 from information_schema.tables where table_schema='public' and table_name='awam_locale_pref') as locale_pref_ready;
