-- =============================================================================
-- F3 A — WebAuthn public-key store + family awam testers + recovery email
-- Supabase #4 SQL Editor — poori file paste → Run. Idempotent.
-- Passwords yahan NAHI.
-- FK: org_members → organisations (live) ya orgs (phase60) — dono handle.
-- Fail rule: is file ko hi shuru se theek likho; phase63b / _fix naam banned.
-- =============================================================================
set search_path = public, extensions;
create extension if not exists pgcrypto;

-- ── 1) WebAuthn credentials (flag passkey_set ki jagah nahi — asal chaabi) ──
create table if not exists public.webauthn_credentials (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users(id) on delete cascade,
  credential_id   text not null unique,
  public_key      jsonb not null,
  sign_count      bigint not null default 0,
  device_name     text not null default 'This device',
  transports      text[] not null default array['internal']::text[],
  created_at      timestamptz not null default now(),
  last_used_at    timestamptz
);
create index if not exists webauthn_credentials_user_idx
  on public.webauthn_credentials (user_id, created_at desc);

create table if not exists public.webauthn_challenges (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid references auth.users(id) on delete cascade,
  email        text,
  kind         text not null check (kind in ('register','authenticate')),
  challenge    text not null unique,
  rp_id        text not null,
  origin       text not null,
  expires_at   timestamptz not null,
  created_at   timestamptz not null default now()
);
create index if not exists webauthn_challenges_exp_idx
  on public.webauthn_challenges (expires_at);

create table if not exists public.account_recovery (
  user_id          uuid primary key references auth.users(id) on delete cascade,
  kind             text not null check (kind in ('gmail','apple','outlook','other_email')),
  email            text not null,
  hint             text not null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create table if not exists public.account_recovery_tokens (
  token_hash   text primary key,
  user_id      uuid not null references auth.users(id) on delete cascade,
  expires_at   timestamptz not null,
  used_at      timestamptz
);

alter table public.trial_accounts add column if not exists recovery_email text;

grant select on public.webauthn_credentials, public.account_recovery to authenticated;
grant all on public.webauthn_credentials, public.webauthn_challenges,
  public.account_recovery, public.account_recovery_tokens to service_role;

alter table public.webauthn_credentials enable row level security;
alter table public.webauthn_challenges enable row level security;
alter table public.account_recovery enable row level security;
alter table public.account_recovery_tokens enable row level security;

drop policy if exists webauthn_own_select on public.webauthn_credentials;
create policy webauthn_own_select on public.webauthn_credentials
  for select to authenticated using (user_id = auth.uid());
drop policy if exists recovery_own_select on public.account_recovery;
create policy recovery_own_select on public.account_recovery
  for select to authenticated using (user_id = auth.uid());

-- ── 2) Signup device gate (vault se alag nishaan nahi — wahi hash, naya account rokna)
create or replace function public.signup_device_gate(_signals jsonb, _key text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_ua       text := coalesce(_signals->>'ua', '');
  v_platform text;
  v_browser  text;
  v_tz       int;
  v_screen   text;
  v_lang     text;
  v_canon    text;
  v_hash     text;
  v_users    int := 0;
  v_banned   boolean := false;
begin
  if to_regclass('public.device_vault') is null then
    return jsonb_build_object('ok', true, 'device_hash', null, 'skipped', true);
  end if;
  v_platform := coalesce(nullif(_signals->>'platform_class',''), public.device_signal_class(v_ua,'platform'));
  v_browser  := coalesce(nullif(_signals->>'browser_class',''), public.device_signal_class(v_ua,'browser'));
  v_tz       := coalesce((_signals->>'tz_offset_minutes')::int, 0) / 60;
  v_screen   := coalesce(_signals->>'screen_bucket', 'unknown');
  v_lang     := lower(left(coalesce(_signals->>'language','xx'), 2));
  v_canon    := concat_ws('|', v_platform, v_browser, v_tz::text, v_screen, v_lang);
  v_hash     := encode(digest(v_canon || '|' || coalesce(_key, 'no-pepper'), 'sha256'), 'hex');

  if to_regclass('public.device_bans') is not null then
    select exists (
      select 1 from public.device_bans b
       where b.device_hash = v_hash and (b.expires_at is null or b.expires_at > now())
    ) into v_banned;
  end if;
  if v_banned then
    return jsonb_build_object('ok', false, 'error', 'device_banned', 'device_hash', v_hash);
  end if;

  select count(distinct user_id) into v_users
    from public.device_vault where device_hash = v_hash;
  -- ek device shape se bar bar naya account nahi (3+ pe block)
  if v_users >= 3 then
    return jsonb_build_object('ok', false, 'error', 'too_many_accounts',
      'device_hash', v_hash, 'accounts', v_users);
  end if;
  return jsonb_build_object('ok', true, 'device_hash', v_hash, 'accounts', v_users);
end $$;

revoke all on function public.signup_device_gate(jsonb, text) from public, anon, authenticated;
grant execute on function public.signup_device_gate(jsonb, text) to service_role;

create or replace function public.auth_user_id_by_email(_email text)
returns uuid
language sql
stable
security definer
set search_path = public, auth
as $$
  select id from auth.users where lower(email) = lower(_email) limit 1
$$;
revoke all on function public.auth_user_id_by_email(text) from public, anon, authenticated;
grant execute on function public.auth_user_id_by_email(text) to service_role;

-- ── 3) Family testers — aam user plans (founder_accounts nahi)
alter table public.family_accounts alter column ai_plan drop default;
alter table public.family_accounts alter column ai_plan set default '';
alter table public.family_accounts alter column ai_credits set default 0;

insert into public.family_accounts (
  email, display_name, relation, plan, ai_plan, ai_credits
) values
  ('humzasherwani@anexomail.com','Humza Sherwani','brother','business_pro','',0),
  ('raanasherwani@anexomail.com','Raana Sherwani','mother','business_pro','ai_executive',10000),
  ('masoodsherwani@anexomail.com','Masood Sherwani','father','pro','',0)
on conflict (email) do update
  set display_name = excluded.display_name,
      relation     = excluded.relation,
      plan         = excluded.plan,
      ai_plan      = excluded.ai_plan,
      ai_credits   = excluded.ai_credits,
      founder_data_access = false,
      awam_rules   = true;

insert into public.mailboxes (address, display_name, box_type, alias_target, purpose, is_public)
values
  ('masoodsherwani@anexomail.com','Masood Sherwani','mailbox',null,'Family account — aam user, Pro',false)
on conflict (address) do update
  set display_name = excluded.display_name,
      box_type = excluded.box_type,
      purpose = excluded.purpose,
      active = true;

do $$
begin
  if exists (select 1 from information_schema.columns
              where table_schema='public' and table_name='mailboxes' and column_name='unified_target') then
    update public.mailboxes
       set founder_owned = false, unified_target = null
     where address in (
       'humzasherwani@anexomail.com',
       'raanasherwani@anexomail.com',
       'masoodsherwani@anexomail.com'
     );
  end if;
end $$;

create or replace function public.family_grants_apply()
returns integer
language plpgsql
security definer
set search_path = public, extensions
as $$
declare r record; n integer := 0; has_ai_plan boolean;
begin
  select exists (select 1 from information_schema.columns
                  where table_schema='public' and table_name='entitlement_state'
                    and column_name='ai_plan') into has_ai_plan;

  for r in select f.*, u.id as uid
             from public.family_accounts f
             join auth.users u on lower(u.email) = lower(f.email)
  loop
    if to_regclass('public.entitlement_state') is not null then
      insert into public.entitlement_state (user_id, plan, seats, support_active, active_until)
      values (r.uid, r.plan, 1, true, now() + interval '10 years')
      on conflict (user_id) do update
        set plan = r.plan, seats = greatest(1, entitlement_state.seats),
            support_active = true,
            active_until = greatest(coalesce(entitlement_state.active_until, now()), now() + interval '10 years'),
            revision = entitlement_state.revision + 1,
            updated_at = now();
      if has_ai_plan then
        if r.ai_plan is null or btrim(r.ai_plan) = '' then
          execute 'update public.entitlement_state set ai_plan = null where user_id = $1'
            using r.uid;
        else
          execute 'update public.entitlement_state set ai_plan = $2 where user_id = $1'
            using r.uid, r.ai_plan;
        end if;
      end if;
    end if;

    if to_regclass('public.ai_credit_wallets') is not null
       and r.ai_plan is not null and btrim(r.ai_plan) <> '' then
      insert into public.ai_credit_wallets (workspace_id, owner_id, plan_id, subscription_credits, renews_at)
      values (r.uid, r.uid, r.ai_plan, r.ai_credits, now() + interval '1 month')
      on conflict (workspace_id) do update
        set owner_id = r.uid, plan_id = r.ai_plan,
            subscription_credits = greatest(ai_credit_wallets.subscription_credits, r.ai_credits),
            updated_at = now();
    end if;

    if to_regclass('public.trial_accounts') is not null then
      insert into public.trial_accounts (user_id, social_email, social_provider, status, plan, trial_ends_at, passkey_set, recovery_set)
      values (r.uid, r.email, 'email', 'active', r.plan, now() + interval '10 years', false, true)
      on conflict (user_id) do update
        set status = 'active',
            plan = r.plan,
            trial_ends_at = greatest(trial_accounts.trial_ends_at, now() + interval '10 years'),
            recovery_set = true,
            updated_at = now();
    end if;

    n := n + 1;
  end loop;
  return n;
end $$;

revoke all on function public.family_grants_apply() from public, anon, authenticated;
grant execute on function public.family_grants_apply() to service_role;

-- ── 4) Har family user ki apni org — F3 list (FK parent = organisations OR orgs)
create or replace function public.family_workspaces_apply()
returns integer
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  r record;
  n int := 0;
  oid uuid;
  role_udt text;
  parent_table text;
  has_status boolean;
begin
  if to_regclass('public.org_members') is null then
    return 0;
  end if;

  if to_regclass('public.organisations') is not null then
    parent_table := 'organisations';
  elsif to_regclass('public.orgs') is not null then
    parent_table := 'orgs';
  else
    return 0;
  end if;

  select c.udt_name into role_udt
    from information_schema.columns c
   where c.table_schema = 'public' and c.table_name = 'org_members' and c.column_name = 'role';

  select exists (
    select 1 from information_schema.columns
     where table_schema = 'public' and table_name = 'org_members' and column_name = 'status'
  ) into has_status;

  for r in
    select f.email, f.display_name, u.id as uid
      from public.family_accounts f
      join auth.users u on lower(u.email) = lower(f.email)
  loop
    oid := null;

    if to_regclass('public.mail_accounts') is not null then
      execute format(
        $q$
        select m.org_id
          from public.mail_accounts m
          join public.%I p on p.id = m.org_id
         where lower(m.address) = lower($1)
         limit 1
        $q$, parent_table)
        into oid
        using r.email;
    end if;

    if oid is null then
      execute format(
        $q$
        select m.org_id
          from public.org_members m
          join public.%I p on p.id = m.org_id
         where m.user_id = $1
         limit 1
        $q$, parent_table)
        into oid
        using r.uid;
    end if;

    if oid is null then
      if parent_table = 'organisations' then
        begin
          insert into public.organisations (name)
          values (r.display_name || ' workspace')
          returning id into oid;
        exception when others then
          begin
            insert into public.organisations (name, slug)
            values (
              r.display_name || ' workspace',
              'family-' || substr(replace(r.uid::text, '-', ''), 1, 12)
            )
            returning id into oid;
          exception when others then
            insert into public.organisations (id, name)
            values (gen_random_uuid(), r.display_name || ' workspace')
            returning id into oid;
          end;
        end;
      else
        insert into public.orgs (name)
        values (r.display_name || ' workspace')
        returning id into oid;
      end if;
    end if;

    if role_udt = 'org_role' then
      if has_status then
        insert into public.org_members (org_id, user_id, email, role, status)
        values (oid, r.uid, r.email, 'owner'::public.org_role, 'active')
        on conflict (org_id, user_id) do update
          set email = excluded.email, status = 'active';
      else
        insert into public.org_members (org_id, user_id, email, role)
        values (oid, r.uid, r.email, 'owner'::public.org_role)
        on conflict (org_id, user_id) do update
          set email = excluded.email;
      end if;
    else
      if has_status then
        insert into public.org_members (org_id, user_id, email, role, status)
        values (oid, r.uid, r.email, 'owner', 'active')
        on conflict (org_id, user_id) do update
          set email = excluded.email, status = 'active';
      else
        insert into public.org_members (org_id, user_id, email, role)
        values (oid, r.uid, r.email, 'owner')
        on conflict (org_id, user_id) do update
          set email = excluded.email;
      end if;
    end if;

    if to_regclass('public.mail_accounts') is not null then
      insert into public.mail_accounts (org_id, address)
      values (oid, r.email)
      on conflict (address) do update set org_id = excluded.org_id;
    end if;

    if to_regclass('public.account_organisations') is not null then
      insert into public.account_organisations (name, slug, domain, created_by)
      values (
        r.display_name || ' workspace',
        'family-' || substr(replace(r.uid::text, '-', ''), 1, 12),
        'anexomail.com',
        r.uid
      )
      on conflict (slug) do nothing;
      insert into public.account_org_members (org_id, user_id, role)
      select a.id, r.uid, 'owner'
        from public.account_organisations a
       where a.slug = 'family-' || substr(replace(r.uid::text, '-', ''), 1, 12)
      on conflict (org_id, user_id) do nothing;
    end if;

    n := n + 1;
  end loop;
  return n;
end $$;

revoke all on function public.family_workspaces_apply() from public, anon, authenticated;
grant execute on function public.family_workspaces_apply() to service_role;

select public.family_grants_apply() as family_grants;
select public.family_workspaces_apply() as family_workspaces;

select email, relation, plan, ai_plan, ai_credits from public.family_accounts order by relation;
