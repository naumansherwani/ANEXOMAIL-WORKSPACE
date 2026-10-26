
-- ============================================================================
-- E92 — CRM P1 + P2 (founder "haan" 26 Oct 2026): multiple pipelines, custom fields, duplicate merge, web forms -> lead.
-- Package cap (Pro 1 pipeline / 5 fields / 1 form; Business 5/25/10; Biz Pro+ unlimited) Rust mein resolve_plan se lagta hai (crmx_core::limits);
-- yahan SQL mein sirf abuse-ceiling (50 pipelines / 200 fields / 100 forms har scope par) trigger se — plan ka bharosa SQL par nahi.
-- scope = org uuid (text) ya 'u:<email>' (bina org wale user ka). Rate limit + duplicate-guard form submit par ATOMIC (SQL function).
-- RLS ON (Rule 43): har nayi table par RLS + anon/authenticated revoke; sab functions service_role only, search_path pinned.
-- Idempotent. Kuch DROP nahi. Pehle phase64_crm_locale (crm_leads/crm_deals) chali honi chahiye.
-- ============================================================================
set lock_timeout = '5s';
set statement_timeout = '60s';
set search_path = public, extensions;

do $$
begin
  if to_regclass('public.crm_leads') is null or to_regclass('public.crm_deals') is null or to_regclass('public.crm_activities') is null then
    raise exception 'E92 PREFLIGHT: crm_leads / crm_deals / crm_activities maujood nahi' using errcode = 'AX092';
  end if;
end $$;

-- ---- 1. pipelines + stages -------------------------------------------------------------------------------------------------
create table if not exists public.crm_pipelines (
  id         uuid primary key default gen_random_uuid(),
  scope      text not null,
  name       text not null check (char_length(btrim(name)) between 1 and 60),
  is_default boolean not null default false,
  position   int not null default 0,
  created_by text,
  created_at timestamptz not null default now()
);
create unique index if not exists crm_pipelines_scope_name on public.crm_pipelines (scope, lower(btrim(name)));
create unique index if not exists crm_pipelines_one_default on public.crm_pipelines (scope) where is_default;

create table if not exists public.crm_pipeline_stages (
  id          uuid primary key default gen_random_uuid(),
  pipeline_id uuid not null references public.crm_pipelines(id) on delete cascade,
  key         text not null check (key ~ '^[a-z][a-z0-9_]{0,29}$'),
  label       text not null check (char_length(btrim(label)) between 1 and 40),
  position    int not null default 0,
  probability int not null default 0 check (probability between 0 and 100),
  kind        text not null default 'open' check (kind in ('open', 'won', 'lost')),
  unique (pipeline_id, key)
);

-- ---- 2. custom fields ------------------------------------------------------------------------------------------------------
create table if not exists public.crm_field_defs (
  id         uuid primary key default gen_random_uuid(),
  scope      text not null,
  entity     text not null check (entity in ('lead', 'deal')),
  key        text not null check (key ~ '^[a-z][a-z0-9_]{0,29}$'),
  label      text not null check (char_length(btrim(label)) between 1 and 40),
  kind       text not null check (kind in ('text', 'number', 'date', 'select', 'checkbox')),
  options    jsonb not null default '[]'::jsonb check (jsonb_typeof(options) = 'array' and jsonb_array_length(options) <= 30),
  position   int not null default 0,
  created_at timestamptz not null default now(),
  unique (scope, entity, key)
);

alter table public.crm_leads add column if not exists custom jsonb not null default '{}'::jsonb;
alter table public.crm_deals add column if not exists custom jsonb not null default '{}'::jsonb;
alter table public.crm_deals add column if not exists pipeline_id uuid references public.crm_pipelines(id) on delete set null;
create index if not exists crm_deals_pipeline on public.crm_deals (pipeline_id) where pipeline_id is not null;
create index if not exists crm_leads_email_lower on public.crm_leads (lower(email));

-- ---- 3. web forms ----------------------------------------------------------------------------------------------------------
create table if not exists public.crm_forms (
  id              uuid primary key default gen_random_uuid(),
  scope           text not null,
  org_id          uuid,
  slug            text not null unique check (slug ~ '^[0-9a-f]{16}$'),
  name            text not null check (char_length(btrim(name)) between 1 and 60),
  owner           text not null,
  fields          jsonb not null default '[]'::jsonb check (jsonb_typeof(fields) = 'array' and jsonb_array_length(fields) <= 12),
  success_message text not null default 'Thank you. We will be in touch.' check (char_length(success_message) <= 300),
  active          boolean not null default true,
  submissions     int not null default 0,
  created_by      text,
  created_at      timestamptz not null default now()
);

-- ---- 4. merge log ----------------------------------------------------------------------------------------------------------
create table if not exists public.crm_merge_log (
  id         uuid primary key default gen_random_uuid(),
  scope      text not null,
  kind       text not null check (kind in ('lead', 'deal')),
  kept_id    uuid not null,
  dropped    jsonb not null,
  actor      text,
  created_at timestamptz not null default now()
);

-- ---- 5. RLS (Rule 43) ------------------------------------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['crm_pipelines', 'crm_pipeline_stages', 'crm_field_defs', 'crm_forms', 'crm_merge_log'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon, authenticated', t);
    execute format('drop policy if exists %I on public.%I', t || '_service', t);
    execute format('create policy %I on public.%I for all to service_role using (true) with check (true)', t || '_service', t);
  end loop;
end $$;

-- ---- 6. abuse ceiling (plan cap Rust mein) ---------------------------------------------------------------------------------
create or replace function public.crm_ceiling_guard()
returns trigger language plpgsql set search_path = public, pg_temp as $$
declare n int; cap int;
begin
  if tg_table_name = 'crm_pipelines' then
    select count(*) into n from public.crm_pipelines where scope = new.scope; cap := 50;
  elsif tg_table_name = 'crm_field_defs' then
    select count(*) into n from public.crm_field_defs where scope = new.scope; cap := 200;
  else
    select count(*) into n from public.crm_forms where scope = new.scope; cap := 100;
  end if;
  if n >= cap then raise exception 'crm_ceiling: % limit % poori' , tg_table_name, cap using errcode = 'AX092'; end if;
  return new;
end $$;
drop trigger if exists crm_pipelines_ceiling on public.crm_pipelines;
create trigger crm_pipelines_ceiling before insert on public.crm_pipelines for each row execute function public.crm_ceiling_guard();
drop trigger if exists crm_fields_ceiling on public.crm_field_defs;
create trigger crm_fields_ceiling before insert on public.crm_field_defs for each row execute function public.crm_ceiling_guard();
drop trigger if exists crm_forms_ceiling on public.crm_forms;
create trigger crm_forms_ceiling before insert on public.crm_forms for each row execute function public.crm_ceiling_guard();

-- ---- 7. web form: public get (sirf render ke liye zaroori) -----------------------------------------------------------------
create or replace function public.crm_form_public(p_slug text)
returns jsonb language sql stable security definer set search_path = public, pg_temp as $$
  select coalesce((select jsonb_build_object('ok', true, 'name', f.name, 'fields', f.fields, 'success_message', f.success_message)
                   from public.crm_forms f where f.slug = lower(btrim(p_slug)) and f.active), jsonb_build_object('ok', false, 'reason', 'not_found'));
$$;

-- ---- 8. web form: submit — ATOMIC. rate limit 30 / 10 min har form par; wohi email 1 ghante mein dobara = duplicate (naya lead nahi) ----
create or replace function public.crm_form_submit(p_slug text, p_data jsonb, p_spam int)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare f public.crm_forms; em text; nm text; co text; cust jsonb := '{}'::jsonb; fld jsonb; k text; v jsonb; recent int; dup uuid; lid uuid; src text;
begin
  select * into f from public.crm_forms where slug = lower(btrim(p_slug)) and active for update;
  if not found then return jsonb_build_object('ok', false, 'reason', 'not_found'); end if;
  if coalesce(p_spam, 0) >= 5 then return jsonb_build_object('ok', true, 'duplicate', false, 'spam', true); end if;  -- bot ko jhoota ok: pata na chale
  src := 'form:' || f.slug;
  select count(*) into recent from public.crm_leads where source = src and created_at > now() - interval '10 minutes';
  if recent >= 30 then return jsonb_build_object('ok', false, 'reason', 'rate_limited'); end if;
  em := lower(btrim(coalesce(p_data->>'email', '')));
  if em !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' or char_length(em) > 254 then return jsonb_build_object('ok', false, 'reason', 'bad_email'); end if;
  for fld in select * from jsonb_array_elements(f.fields) loop
    k := fld->>'key'; v := p_data->k;
    if coalesce((fld->>'required')::boolean, false) and (v is null or btrim(v #>> '{}') = '') then
      return jsonb_build_object('ok', false, 'reason', 'missing_field', 'field', k);
    end if;
    if k not in ('email', 'name', 'company') and v is not null and char_length(v #>> '{}') <= 500 then cust := cust || jsonb_build_object(k, v); end if;
  end loop;
  nm := nullif(left(btrim(coalesce(p_data->>'name', '')), 120), '');
  co := nullif(left(btrim(coalesce(p_data->>'company', '')), 120), '');
  select id into dup from public.crm_leads where lower(email) = em and owner = f.owner and created_at > now() - interval '1 hour' limit 1;
  if dup is not null then return jsonb_build_object('ok', true, 'duplicate', true, 'lead_id', dup); end if;
  insert into public.crm_leads (org_id, email, display_name, company, source, owner, state, custom)
    values (f.org_id, em, nm, co, src, f.owner, 'new', cust) returning id into lid;
  update public.crm_forms set submissions = submissions + 1 where id = f.id;
  insert into public.crm_activities (org_id, kind, actor, subject, body, contact_email)
    values (f.org_id, 'lead', 'web form', 'New lead from form: ' || f.name, left(coalesce(nm, em), 200), em);
  return jsonb_build_object('ok', true, 'duplicate', false, 'lead_id', lid);
end $$;

-- ---- 9. duplicate merge — ATOMIC. Keep jeetta hai, khali jagah drops se bharti hai, activities keep par, drops mit-te hain, log banta hai ----
create or replace function public.crm_merge(p_kind text, p_keep uuid, p_drop uuid[], p_actor text, p_scope text)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare n int; snap jsonb := '[]'::jsonb; r record; keep_email text;
begin
  if p_kind not in ('lead', 'deal') then return jsonb_build_object('ok', false, 'reason', 'bad_kind'); end if;
  if p_drop is null or cardinality(p_drop) = 0 or cardinality(p_drop) > 20 or p_keep = any(p_drop) then
    return jsonb_build_object('ok', false, 'reason', 'bad_ids');
  end if;
  if p_kind = 'lead' then
    perform 1 from public.crm_leads where id = p_keep and (org_id is null or p_scope like 'u:%' or org_id::text = p_scope) for update;
    if not found then return jsonb_build_object('ok', false, 'reason', 'keep_not_found'); end if;
    select count(*) into n from public.crm_leads where id = any(p_drop) and (org_id is null or p_scope like 'u:%' or org_id::text = p_scope);
    if n <> cardinality(p_drop) then return jsonb_build_object('ok', false, 'reason', 'not_same_workspace'); end if;
    for r in select * from public.crm_leads where id = any(p_drop) order by created_at loop
      snap := snap || to_jsonb(r);
      update public.crm_leads k set
        display_name = coalesce(k.display_name, r.display_name), company = coalesce(k.company, r.company),
        score = greatest(k.score, r.score), last_touch_at = greatest(k.last_touch_at, r.last_touch_at),
        custom = r.custom || k.custom
      where k.id = p_keep;
    end loop;
    delete from public.crm_leads where id = any(p_drop);
  else
    perform 1 from public.crm_deals where id = p_keep and (org_id is null or p_scope like 'u:%' or org_id::text = p_scope) for update;
    if not found then return jsonb_build_object('ok', false, 'reason', 'keep_not_found'); end if;
    select count(*) into n from public.crm_deals where id = any(p_drop) and (org_id is null or p_scope like 'u:%' or org_id::text = p_scope);
    if n <> cardinality(p_drop) then return jsonb_build_object('ok', false, 'reason', 'not_same_workspace'); end if;
    for r in select * from public.crm_deals where id = any(p_drop) order by created_at loop
      snap := snap || to_jsonb(r);
      update public.crm_deals k set
        company = coalesce(k.company, r.company), contact_email = coalesce(k.contact_email, r.contact_email),
        next_step = coalesce(k.next_step, r.next_step), next_step_due = coalesce(k.next_step_due, r.next_step_due),
        thread_id = coalesce(k.thread_id, r.thread_id), custom = r.custom || k.custom
      where k.id = p_keep;
      update public.crm_activities set deal_id = p_keep where deal_id = r.id;
    end loop;
    delete from public.crm_deals where id = any(p_drop);
  end if;
  insert into public.crm_merge_log (scope, kind, kept_id, dropped, actor) values (p_scope, p_kind, p_keep, snap, p_actor);
  return jsonb_build_object('ok', true, 'merged', jsonb_array_length(snap), 'kept_id', p_keep);
end $$;


-- ---- 9b. config save/delete — ATOMIC, plan cap (p_cap, -1 = unlimited) advisory lock ke andar (race se cap nahi toot-ta) ------------
create or replace function public.crm_scope_deals_where(p_scope text)
returns text language sql immutable set search_path = public, pg_temp as $$
  select case when p_scope like 'u:%' then 'org_id is null and lower(owner::text) = ' || quote_literal(substr(p_scope, 3))
              else 'org_id::text = ' || quote_literal(p_scope) end;
$$;

create or replace function public.crm_ensure_default_pipeline(p_scope text, p_actor text)
returns uuid language plpgsql security definer set search_path = public, pg_temp as $$
declare pid uuid;
begin
  perform pg_advisory_xact_lock(hashtext('crm_pipe:' || p_scope));
  select id into pid from public.crm_pipelines where scope = p_scope and is_default;
  if pid is not null then return pid; end if;
  insert into public.crm_pipelines (scope, name, is_default, position, created_by) values (p_scope, 'Sales', true, 0, p_actor) returning id into pid;
  insert into public.crm_pipeline_stages (pipeline_id, key, label, position, probability, kind) values
    (pid, 'new', 'New', 0, 10, 'open'), (pid, 'qualified', 'Qualified', 1, 30, 'open'), (pid, 'proposal', 'Proposal', 2, 55, 'open'),
    (pid, 'negotiation', 'Negotiation', 3, 75, 'open'), (pid, 'won', 'Won', 4, 100, 'won'), (pid, 'lost', 'Lost', 5, 0, 'lost');
  return pid;
end $$;

create or replace function public.crm_pipeline_save(p_scope text, p_id uuid, p_name text, p_stages jsonb, p_actor text, p_cap int)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare pid uuid := p_id; n int; st jsonb; i int := 0; used int; keys text[];
begin
  perform pg_advisory_xact_lock(hashtext('crm_pipe:' || p_scope));
  if jsonb_typeof(p_stages) <> 'array' or jsonb_array_length(p_stages) not between 2 and 12 then return jsonb_build_object('ok', false, 'reason', 'bad_stages'); end if;
  select array_agg(e->>'key') into keys from jsonb_array_elements(p_stages) e;
  if (select count(distinct k) from unnest(keys) k) <> cardinality(keys) then return jsonb_build_object('ok', false, 'reason', 'duplicate_stage'); end if;
  if pid is null then
    select count(*) into n from public.crm_pipelines where scope = p_scope;
    if p_cap >= 0 and n >= p_cap then return jsonb_build_object('ok', false, 'reason', 'limit_reached', 'cap', p_cap); end if;
    if exists (select 1 from public.crm_pipelines where scope = p_scope and lower(btrim(name)) = lower(btrim(p_name))) then return jsonb_build_object('ok', false, 'reason', 'name_taken'); end if;
    insert into public.crm_pipelines (scope, name, is_default, position, created_by) values (p_scope, btrim(p_name), n = 0, n, p_actor) returning id into pid;
  else
    perform 1 from public.crm_pipelines where id = pid and scope = p_scope;
    if not found then return jsonb_build_object('ok', false, 'reason', 'not_found'); end if;
    if exists (select 1 from public.crm_pipelines where scope = p_scope and id <> pid and lower(btrim(name)) = lower(btrim(p_name))) then return jsonb_build_object('ok', false, 'reason', 'name_taken'); end if;
    execute format('select count(*) from public.crm_deals where (pipeline_id::text = %L or (pipeline_id is null and %L = (select id::text from public.crm_pipelines where scope = %L and is_default))) and %s and not (stage::text = any(%L::text[]))',
                   pid, pid, p_scope, public.crm_scope_deals_where(p_scope), keys) into used;
    if used > 0 then return jsonb_build_object('ok', false, 'reason', 'stage_in_use', 'deals', used); end if;
    update public.crm_pipelines set name = btrim(p_name) where id = pid;
    delete from public.crm_pipeline_stages where pipeline_id = pid;
  end if;
  for st in select * from jsonb_array_elements(p_stages) loop
    insert into public.crm_pipeline_stages (pipeline_id, key, label, position, probability, kind)
      values (pid, st->>'key', st->>'label', i, (st->>'probability')::int, coalesce(st->>'kind', 'open'));
    i := i + 1;
  end loop;
  return jsonb_build_object('ok', true, 'id', pid);
end $$;

create or replace function public.crm_pipeline_delete(p_scope text, p_id uuid)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare d boolean; used int;
begin
  perform pg_advisory_xact_lock(hashtext('crm_pipe:' || p_scope));
  select is_default into d from public.crm_pipelines where id = p_id and scope = p_scope;
  if not found then return jsonb_build_object('ok', false, 'reason', 'not_found'); end if;
  if d then return jsonb_build_object('ok', false, 'reason', 'default_pipeline'); end if;
  select count(*) into used from public.crm_deals where pipeline_id = p_id;
  if used > 0 then return jsonb_build_object('ok', false, 'reason', 'has_deals', 'deals', used); end if;
  delete from public.crm_pipelines where id = p_id;
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.crm_field_save(p_scope text, p_id uuid, p_entity text, p_label text, p_kind text, p_key text, p_options jsonb, p_cap int)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare fid uuid := p_id; n int;
begin
  perform pg_advisory_xact_lock(hashtext('crm_fld:' || p_scope));
  if fid is null then
    select count(*) into n from public.crm_field_defs where scope = p_scope;
    if p_cap >= 0 and n >= p_cap then return jsonb_build_object('ok', false, 'reason', 'limit_reached', 'cap', p_cap); end if;
    if exists (select 1 from public.crm_field_defs where scope = p_scope and entity = p_entity and key = p_key) then return jsonb_build_object('ok', false, 'reason', 'key_taken'); end if;
    insert into public.crm_field_defs (scope, entity, key, label, kind, options, position) values (p_scope, p_entity, p_key, btrim(p_label), p_kind, coalesce(p_options, '[]'::jsonb), n) returning id into fid;
  else
    update public.crm_field_defs set label = btrim(p_label), options = coalesce(p_options, '[]'::jsonb) where id = fid and scope = p_scope;  -- key + kind badalte nahi (data toot'ta)
    if not found then return jsonb_build_object('ok', false, 'reason', 'not_found'); end if;
  end if;
  return jsonb_build_object('ok', true, 'id', fid);
end $$;

create or replace function public.crm_field_delete(p_scope text, p_id uuid)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare d public.crm_field_defs;
begin
  delete from public.crm_field_defs where id = p_id and scope = p_scope returning * into d;
  if not found then return jsonb_build_object('ok', false, 'reason', 'not_found'); end if;
  if d.entity = 'lead' then update public.crm_leads set custom = custom - d.key where custom ? d.key and (case when p_scope like 'u:%' then org_id is null and lower(owner::text) = substr(p_scope, 3) else org_id::text = p_scope end);
  else update public.crm_deals set custom = custom - d.key where custom ? d.key and (case when p_scope like 'u:%' then org_id is null and lower(owner::text) = substr(p_scope, 3) else org_id::text = p_scope end); end if;
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.crm_form_save(p_scope text, p_org uuid, p_id uuid, p_name text, p_owner text, p_fields jsonb, p_success text, p_active boolean, p_cap int)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare fid uuid := p_id; n int; sl text; wanted text;
begin
  perform pg_advisory_xact_lock(hashtext('crm_frm:' || p_scope));
  if fid is null then
    select count(*) into n from public.crm_forms where scope = p_scope;
    if p_cap >= 0 and n >= p_cap then return jsonb_build_object('ok', false, 'reason', 'limit_reached', 'cap', p_cap); end if;
    sl := left(replace(gen_random_uuid()::text, '-', ''), 16);
    insert into public.crm_forms (scope, org_id, slug, name, owner, fields, success_message, active, created_by)
      values (p_scope, p_org, sl, btrim(p_name), lower(btrim(p_owner)), p_fields, coalesce(nullif(btrim(p_success), ''), 'Thank you. We will be in touch.'), coalesce(p_active, true), lower(btrim(p_owner)))
      returning id into fid;
  else
    update public.crm_forms set name = btrim(p_name), fields = p_fields, success_message = coalesce(nullif(btrim(p_success), ''), success_message), active = coalesce(p_active, active)
      where id = fid and scope = p_scope returning slug into sl;
    if not found then return jsonb_build_object('ok', false, 'reason', 'not_found'); end if;
  end if;
  return jsonb_build_object('ok', true, 'id', fid, 'slug', sl);
end $$;

create or replace function public.crm_form_delete(p_scope text, p_id uuid)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
begin
  delete from public.crm_forms where id = p_id and scope = p_scope;
  if not found then return jsonb_build_object('ok', false, 'reason', 'not_found'); end if;
  return jsonb_build_object('ok', true);
end $$;

-- ---- 10. grants: sab service_role only ------------------------------------------------------------------------------------
revoke all on function public.crm_ceiling_guard() from public, anon, authenticated;
revoke all on function public.crm_form_public(text) from public, anon, authenticated;
revoke all on function public.crm_form_submit(text, jsonb, int) from public, anon, authenticated;
revoke all on function public.crm_merge(text, uuid, uuid[], text, text) from public, anon, authenticated;
revoke all on function public.crm_scope_deals_where(text) from public, anon, authenticated;
revoke all on function public.crm_ensure_default_pipeline(text, text) from public, anon, authenticated;
revoke all on function public.crm_pipeline_save(text, uuid, text, jsonb, text, int) from public, anon, authenticated;
revoke all on function public.crm_pipeline_delete(text, uuid) from public, anon, authenticated;
revoke all on function public.crm_field_save(text, uuid, text, text, text, text, jsonb, int) from public, anon, authenticated;
revoke all on function public.crm_field_delete(text, uuid) from public, anon, authenticated;
revoke all on function public.crm_form_save(text, uuid, uuid, text, text, jsonb, text, boolean, int) from public, anon, authenticated;
revoke all on function public.crm_form_delete(text, uuid) from public, anon, authenticated;
grant execute on function public.crm_scope_deals_where(text), public.crm_ensure_default_pipeline(text, text), public.crm_pipeline_save(text, uuid, text, jsonb, text, int),
  public.crm_pipeline_delete(text, uuid), public.crm_field_save(text, uuid, text, text, text, text, jsonb, int), public.crm_field_delete(text, uuid),
  public.crm_form_save(text, uuid, uuid, text, text, jsonb, text, boolean, int), public.crm_form_delete(text, uuid) to service_role;
grant execute on function public.crm_form_public(text) to service_role;
grant execute on function public.crm_form_submit(text, jsonb, int) to service_role;
grant execute on function public.crm_merge(text, uuid, uuid[], text, text) to service_role;

-- ---- 11. self-test (rollback-safe: apne banaye rows khud saaf) ---------------------------------------------------------------
do $$
declare s text := 'u:e92@test.invalid'; f public.crm_forms; a uuid; b uuid; r jsonb; n int; pid uuid;
begin
  insert into public.crm_forms (scope, slug, name, owner, fields) values (s, 'e92e92e92e92e92e', 'E92 test', 'e92@test.invalid',
    '[{"key":"email","required":true},{"key":"name"},{"key":"budget"}]'::jsonb) returning * into f;
  r := public.crm_form_submit(f.slug, '{"email":"A@X.com","name":"Ann","budget":"5k"}'::jsonb, 0);
  if not (r->>'ok')::boolean or (r->>'duplicate')::boolean then raise exception 'E92 SELFTEST: pehla submit'; end if;
  r := public.crm_form_submit(f.slug, '{"email":"a@x.com"}'::jsonb, 0);
  if not (r->>'duplicate')::boolean then raise exception 'E92 SELFTEST: duplicate pakda nahi'; end if;
  r := public.crm_form_submit(f.slug, '{"email":"nope"}'::jsonb, 0);
  if r->>'reason' <> 'bad_email' then raise exception 'E92 SELFTEST: bad email'; end if;
  r := public.crm_form_submit(f.slug, '{"email":"bot@x.com"}'::jsonb, 9);
  if not coalesce((r->>'spam')::boolean, false) then raise exception 'E92 SELFTEST: spam'; end if;
  select id into a from public.crm_leads where source = 'form:' || f.slug and email = 'a@x.com';
  if (select custom->>'budget' from public.crm_leads where id = a) <> '5k' then raise exception 'E92 SELFTEST: custom field'; end if;
  insert into public.crm_leads (email, source, owner, display_name, company) values ('a@x.com', 'manual', 'e92@test.invalid', null, 'Acme') returning id into b;
  r := public.crm_merge('lead', a, array[b], 'e92', s);
  if not (r->>'ok')::boolean then raise exception 'E92 SELFTEST: merge %', r; end if;
  if (select company from public.crm_leads where id = a) <> 'Acme' then raise exception 'E92 SELFTEST: merge ne khali jagah nahi bhari'; end if;
  select count(*) into n from public.crm_leads where id = b;
  if n <> 0 then raise exception 'E92 SELFTEST: drop mita nahi'; end if;
  insert into public.crm_leads (email, source, owner, org_id) values ('a@x.com', 'manual', 'e92@test.invalid', '99999999-9999-4999-8999-999999999999') returning id into b;
  r := public.crm_merge('lead', a, array[b], 'e92', '11111111-1111-4111-8111-111111111111');
  if (r->>'reason') <> 'not_same_workspace' and (r->>'reason') <> 'keep_not_found' then raise exception 'E92 SELFTEST: doosre workspace ka merge nahi rukna chahiye tha %', r; end if;
  delete from public.crm_leads where id = b;
  pid := public.crm_ensure_default_pipeline(s, 'e92');
  if (select count(*) from public.crm_pipeline_stages where pipeline_id = pid) <> 6 then raise exception 'E92 SELFTEST: default pipeline stages'; end if;
  r := public.crm_pipeline_save(s, null, 'Second', '[{"key":"a","label":"A","probability":10},{"key":"b","label":"B","probability":90,"kind":"won"}]'::jsonb, 'e92', 1);
  if r->>'reason' <> 'limit_reached' then raise exception 'E92 SELFTEST: pipeline cap %', r; end if;
  r := public.crm_pipeline_save(s, null, 'Second', '[{"key":"a","label":"A","probability":10},{"key":"b","label":"B","probability":90,"kind":"won"}]'::jsonb, 'e92', 5);
  if not (r->>'ok')::boolean then raise exception 'E92 SELFTEST: pipeline save %', r; end if;
  if not (public.crm_pipeline_delete(s, (r->>'id')::uuid)->>'ok')::boolean then raise exception 'E92 SELFTEST: pipeline delete'; end if;
  if (public.crm_pipeline_delete(s, pid)->>'reason') <> 'default_pipeline' then raise exception 'E92 SELFTEST: default delete hona nahi chahiye'; end if;
  r := public.crm_field_save(s, null, 'lead', 'Budget', 'number', 'budget', '[]'::jsonb, 1);
  if not (r->>'ok')::boolean then raise exception 'E92 SELFTEST: field save'; end if;
  if (public.crm_field_save(s, null, 'lead', 'Other', 'text', 'other', '[]'::jsonb, 1)->>'reason') <> 'limit_reached' then raise exception 'E92 SELFTEST: field cap'; end if;
  if not (public.crm_field_delete(s, (r->>'id')::uuid)->>'ok')::boolean then raise exception 'E92 SELFTEST: field delete'; end if;
  delete from public.crm_pipelines where scope = s;
  delete from public.crm_leads where source = 'form:' || f.slug;
  delete from public.crm_activities where subject = 'New lead from form: E92 test';
  delete from public.crm_merge_log where scope = s;
  delete from public.crm_forms where id = f.id;
end $$;
