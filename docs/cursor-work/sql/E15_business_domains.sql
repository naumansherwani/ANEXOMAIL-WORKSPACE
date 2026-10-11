-- ============================================================================
-- E15 — Business domains + company addresses (Zoho-style "bring your own domain")
-- ============================================================================
-- Login hamesha name@anexomail.com (free, mailbox limit mein NAHI ginta).
-- Business user apni domain jodta hai, phir info@company.com jaise addresses banata hai.
--   * Sirf NAYI tables + functions. Koi maujooda table/function nahi badli.
--   * Sirf service_role (Rust/Bun) in functions ko call karta hai. RLS on, policies nahi.
--   * Domain limit: basic 1, pro 3, business / business_pro unlimited ("on request" = founder).
--   * Mailbox limit: storage_plans.mailbox_limit (NULL = unlimited); alias ginti mein nahi.
--   * Personal org (slug personal-*) domain nahi jod sakta.
-- Idempotent: dobara chalane par kuch nahi bigadta.
-- ============================================================================

create table if not exists public.org_domains (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references public.organisations(id) on delete cascade,
  domain          text not null check (domain = lower(domain) and domain ~ '^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$'),
  status          text not null default 'pending' check (status in ('pending','verified','removed')),
  verify_token    text not null default replace(gen_random_uuid()::text, '-', ''),
  dkim_selector   text not null default 'anexo1',
  dkim_public     text,
  txt_ok          boolean not null default false,
  mx_ok           boolean not null default false,
  spf_ok          boolean not null default false,
  dkim_ok         boolean not null default false,
  dmarc_ok        boolean not null default false,
  last_checked_at timestamptz,
  verified_at     timestamptz,
  created_at      timestamptz not null default now()
);
create unique index if not exists org_domains_domain_active_uq
  on public.org_domains (domain) where status <> 'removed';
create index if not exists org_domains_org_idx on public.org_domains (org_id);

create table if not exists public.org_addresses (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid not null references public.organisations(id) on delete cascade,
  domain_id      uuid not null references public.org_domains(id) on delete cascade,
  local_part     text not null check (local_part = lower(local_part) and local_part ~ '^[a-z0-9]([a-z0-9._-]{0,62}[a-z0-9])?$'),
  address        text not null,
  kind           text not null default 'mailbox' check (kind in ('mailbox','shared','alias')),
  owner_user_id  uuid,
  alias_target   text,
  active         boolean not null default true,
  created_at     timestamptz not null default now(),
  constraint org_addresses_alias_ck check (kind <> 'alias' or alias_target is not null)
);
create unique index if not exists org_addresses_address_uq on public.org_addresses (address) where active;
create index if not exists org_addresses_org_idx on public.org_addresses (org_id);

alter table public.org_domains   enable row level security;
alter table public.org_addresses enable row level security;
revoke all on public.org_domains, public.org_addresses from public, anon, authenticated;
grant all on public.org_domains, public.org_addresses to service_role;

-- ---- plan helpers -----------------------------------------------------------
create or replace function public.org_plan_of(_org uuid)
returns text language sql stable security definer set search_path = public as $$
  select coalesce(
    (select e.plan from public.org_members m
       join public.entitlement_state e on e.user_id = m.user_id
      where m.org_id = _org and m.role = 'owner' limit 1),
    'basic');
$$;

create or replace function public.org_domain_cap(_plan text)
returns integer language sql immutable as $$
  select case _plan when 'basic' then 1 when 'pro' then 3 else null end;   -- NULL = unlimited
$$;

create or replace function public.org_mailbox_cap(_plan text)
returns integer language sql stable security definer set search_path = public as $$
  select case when exists (select 1 from public.storage_plans where plan_id = _plan)
              then (select mailbox_limit from public.storage_plans where plan_id = _plan limit 1)
              else 3 end;
$$;

-- ---- domains ------------------------------------------------------------------
create or replace function public.org_domain_add(_org uuid, _domain text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare d text := lower(trim(coalesce(_domain,''))); plan text; cap integer; used integer; row_ public.org_domains;
begin
  d := regexp_replace(d, '^(https?://)?(www\.)?', '');
  d := regexp_replace(d, '[/:].*$', '');
  if d !~ '^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$' then
    return jsonb_build_object('ok', false, 'error', 'invalid_domain');
  end if;
  if d in ('anexomail.com') or d like '%.anexomail.com' then
    return jsonb_build_object('ok', false, 'error', 'reserved_domain');
  end if;
  if exists (select 1 from public.organisations o where o.id = _org and o.slug like 'personal-%') then
    return jsonb_build_object('ok', false, 'error', 'business_required');
  end if;
  if exists (select 1 from public.org_domains x where x.domain = d and x.status <> 'removed') then
    return jsonb_build_object('ok', false, 'error', 'domain_taken');
  end if;
  plan := public.org_plan_of(_org);
  cap  := public.org_domain_cap(plan);
  select count(*) into used from public.org_domains where org_id = _org and status <> 'removed';
  if cap is not null and used >= cap then
    return jsonb_build_object('ok', false, 'error', 'domain_limit_reached', 'plan', plan, 'limit', cap, 'used', used);
  end if;
  insert into public.org_domains (org_id, domain) values (_org, d) returning * into row_;
  return jsonb_build_object('ok', true, 'domain', to_jsonb(row_));
end $$;

create or replace function public.org_domain_list(_org uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at), '[]'::jsonb)
    from public.org_domains x where x.org_id = _org and x.status <> 'removed';
$$;

-- Rust verify ke baad checks save karta hai. Sab green => status 'verified'.
create or replace function public.org_domain_set_checks(
  _id uuid, _txt boolean, _mx boolean, _spf boolean, _dkim boolean, _dmarc boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.org_domains; all_ok boolean;
begin
  all_ok := coalesce(_txt,false) and coalesce(_mx,false) and coalesce(_spf,false)
        and coalesce(_dkim,false) and coalesce(_dmarc,false);
  update public.org_domains
     set txt_ok = coalesce(_txt,false), mx_ok = coalesce(_mx,false), spf_ok = coalesce(_spf,false),
         dkim_ok = coalesce(_dkim,false), dmarc_ok = coalesce(_dmarc,false),
         last_checked_at = now(),
         status = case when all_ok then 'verified' else 'pending' end,
         verified_at = case when all_ok then coalesce(verified_at, now()) else null end
   where id = _id and status <> 'removed'
   returning * into r;
  if r.id is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  return jsonb_build_object('ok', true, 'domain', to_jsonb(r));
end $$;

create or replace function public.org_domain_set_dkim(_id uuid, _public text)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  update public.org_domains set dkim_public = nullif(trim(_public), '') where id = _id and status <> 'removed';
  return jsonb_build_object('ok', found);
end $$;

create or replace function public.org_domain_remove(_org uuid, _id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  update public.org_addresses set active = false where domain_id = _id and org_id = _org;
  update public.org_domains set status = 'removed' where id = _id and org_id = _org and status <> 'removed';
  return jsonb_build_object('ok', found);
end $$;

-- ---- company addresses --------------------------------------------------------
create or replace function public.org_address_create(
  _org uuid, _domain_id uuid, _local text, _kind text default 'mailbox',
  _owner uuid default null, _alias_target text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare l text := lower(trim(coalesce(_local,''))); dom public.org_domains; addr text;
        plan text; cap integer; used integer; row_ public.org_addresses; k text := coalesce(_kind,'mailbox');
begin
  select * into dom from public.org_domains where id = _domain_id and org_id = _org and status <> 'removed';
  if dom.id is null then return jsonb_build_object('ok', false, 'error', 'domain_not_found'); end if;
  if dom.status <> 'verified' then return jsonb_build_object('ok', false, 'error', 'domain_not_verified'); end if;
  if k not in ('mailbox','shared','alias') then return jsonb_build_object('ok', false, 'error', 'invalid_kind'); end if;
  if l !~ '^[a-z0-9]([a-z0-9._-]{0,62}[a-z0-9])?$' then return jsonb_build_object('ok', false, 'error', 'invalid_local_part'); end if;
  if k = 'alias' and coalesce(trim(_alias_target),'') = '' then return jsonb_build_object('ok', false, 'error', 'alias_target_required'); end if;
  addr := l || '@' || dom.domain;
  if exists (select 1 from public.org_addresses a where a.address = addr and a.active)
     or exists (select 1 from public.mail_accounts m where lower(m.address) = addr and m.org_id <> _org) then
    return jsonb_build_object('ok', false, 'error', 'address_taken');
  end if;
  if k <> 'alias' then
    plan := public.org_plan_of(_org);
    cap  := public.org_mailbox_cap(plan);
    select count(*) into used from public.org_addresses where org_id = _org and active and kind in ('mailbox','shared');
    if cap is not null and used >= cap then
      return jsonb_build_object('ok', false, 'error', 'mailbox_limit', 'plan', plan, 'limit', cap, 'used', used);
    end if;
  end if;
  insert into public.org_addresses (org_id, domain_id, local_part, address, kind, owner_user_id, alias_target)
  values (_org, _domain_id, l, addr, k, _owner, lower(nullif(trim(_alias_target),''))) returning * into row_;
  if k <> 'alias' then   -- mail_ingest isi se owner org pehchanta hai
    insert into public.mail_accounts (org_id, address) values (_org, addr) on conflict do nothing;
  end if;
  return jsonb_build_object('ok', true, 'address', to_jsonb(row_));
end $$;

create or replace function public.org_address_list(_org uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(to_jsonb(a) order by a.created_at), '[]'::jsonb)
    from public.org_addresses a where a.org_id = _org and a.active;
$$;

create or replace function public.org_address_remove(_org uuid, _id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  update public.org_addresses set active = false where id = _id and org_id = _org and active;
  return jsonb_build_object('ok', found);
end $$;

-- Server helper (root cron) yahi padhta hai: verified domains + active addresses.
create or replace function public.org_mail_sync_state()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'domains',   coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'domain', d.domain, 'selector', d.dkim_selector, 'has_dkim', d.dkim_public is not null))
                           from public.org_domains d where d.status = 'verified'), '[]'::jsonb),
    'pending_dkim', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'domain', d.domain, 'selector', d.dkim_selector))
                           from public.org_domains d where d.status <> 'removed' and d.dkim_public is null), '[]'::jsonb),
    'addresses', coalesce((select jsonb_agg(jsonb_build_object('address', a.address, 'kind', a.kind, 'alias_target', a.alias_target))
                           from public.org_addresses a join public.org_domains d on d.id = a.domain_id
                          where a.active and d.status = 'verified'), '[]'::jsonb));
$$;

do $$ declare f text; begin
  foreach f in array array[
    'org_plan_of(uuid)','org_domain_cap(text)','org_mailbox_cap(text)','org_domain_add(uuid,text)',
    'org_domain_list(uuid)','org_domain_set_checks(uuid,boolean,boolean,boolean,boolean,boolean)',
    'org_domain_set_dkim(uuid,text)','org_domain_remove(uuid,uuid)',
    'org_address_create(uuid,uuid,text,text,uuid,text)','org_address_list(uuid)',
    'org_address_remove(uuid,uuid)','org_mail_sync_state()']
  loop
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
    execute format('grant execute on function public.%s to service_role', f);
  end loop;
end $$;
