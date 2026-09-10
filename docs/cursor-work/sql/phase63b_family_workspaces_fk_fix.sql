-- =============================================================================
-- F3 A patch — family_workspaces_apply FK fix
-- Live: org_members.org_id → public.organisations (NOT orgs)
-- Supabase #4: poori file paste → Run. Idempotent.
-- =============================================================================
set search_path = public, extensions;

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

  -- Live schema: organisations. Phase60 may also have orgs — FK wins.
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

    -- Prefer existing mail_accounts.org_id ONLY if it exists in the FK parent table
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

    -- Existing membership already valid?
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
        -- organisations columns vary — try name-only insert, then name+slug
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

    -- org_members insert — cast role to live type
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

select public.family_workspaces_apply() as family_workspaces;
