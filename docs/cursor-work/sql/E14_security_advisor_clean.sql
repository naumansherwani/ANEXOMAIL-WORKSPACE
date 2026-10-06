-- =============================================================================
-- E14 — SECURITY ADVISOR CLEAN (errors + warnings)
-- Supabase #4 SQL Editor: poori file paste → Run. Idempotent (jitni dafa chalao,
-- wahi natija). Data DELETE nahi hota. Business/Phase/E-series purana SQL NO TOUCH.
--
-- Kya theek hota hai:
--   1) Security Definer View errors  → har public view par security_invoker = on
--   2) RLS Disabled in Public errors → har public table par RLS enable
--   3) Bina policy wali table       → service_role-only lock (anon/authenticated revoke)
--   4) Function Search Path Mutable → har public function par search_path pin
--   5) Materialized View in API     → anon/authenticated se revoke
--   6) Missing GRANT (Data API)     → service_role grant hamesha maujood
-- =============================================================================
set search_path = public, extensions;

-- ---------------------------------------------------------------------------
-- 1) VIEWS — SECURITY DEFINER error khatam (security_invoker = on)
--    Iske baad view caller ki RLS se chalti hai, owner ki nahi.
-- ---------------------------------------------------------------------------
do $$
declare v record;
begin
  for v in
    select c.relname
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public'
       and c.relkind = 'v'
  loop
    begin
      execute format('alter view public.%I set (security_invoker = on)', v.relname);
    exception when others then
      raise notice 'view skip %: %', v.relname, sqlerrm;
    end;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 2) TABLES — RLS enable (jahan off hai)
-- ---------------------------------------------------------------------------
do $$
declare t record;
begin
  for t in
    select c.relname
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public'
       and c.relkind = 'r'
       and c.relrowsecurity = false
  loop
    execute format('alter table public.%I enable row level security', t.relname);
    raise notice 'rls on: %', t.relname;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 3) Bina kisi policy wali table = band darwaza. Client role hata do, taake
--    "RLS enabled but no policy" ka silent-empty masla clear rahe aur
--    service_role (backend) hamesha kaam kare. Jis table ko awam ke liye
--    kholna ho, uski apni policy alag SQL mein likhi jaye.
-- ---------------------------------------------------------------------------
do $$
declare t record;
begin
  for t in
    select c.relname
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public'
       and c.relkind = 'r'
       and not exists (
         select 1 from pg_policy p where p.polrelid = c.oid
       )
  loop
    execute format('revoke all on public.%I from anon, authenticated', t.relname);
    execute format('grant all on public.%I to service_role', t.relname);
    execute format('drop policy if exists "service_role_internal_access" on public.%I', t.relname);
    execute format('create policy "service_role_internal_access" on public.%I for all to service_role using (true) with check (true)', t.relname);
    raise notice 'no-policy locked: %', t.relname;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 4) Har public table ke liye service_role grant (Data API missing GRANT warning)
-- ---------------------------------------------------------------------------
do $$
declare t record;
begin
  for t in
    select c.relname
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind = 'r'
  loop
    execute format('grant all on public.%I to service_role', t.relname);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 5) MATERIALIZED VIEWS — Data API se bahar
-- ---------------------------------------------------------------------------
do $$
declare m record;
begin
  for m in
    select c.relname
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind = 'm'
  loop
    execute format('revoke all on public.%I from anon, authenticated', m.relname);
    execute format('grant select on public.%I to service_role', m.relname);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 6) FUNCTIONS — Function Search Path Mutable warning khatam
--    Sirf search_path pin hota hai; function ka body/permission nahi badalta.
-- ---------------------------------------------------------------------------
do $$
declare f record;
begin
  for f in
    select p.oid,
           p.proname,
           pg_get_function_identity_arguments(p.oid) as args
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.prokind in ('f','p')
        and not exists (
          select 1 from unnest(coalesce(p.proconfig, array[]::text[])) as u(cfg)
           where u.cfg like 'search_path=%'
        )
  loop
    begin
      execute format(
        'alter function public.%I(%s) set search_path = public, extensions',
        f.proname, f.args
      );
    exception when others then
      raise notice 'function skip %(%): %', f.proname, f.args, sqlerrm;
    end;
  end loop;
end $$;

-- 6b) EXTENSION IN PUBLIC warning -> extensions schema mein move
do $$
declare ext record;
begin
  for ext in
    select e.extname
      from pg_extension e
      join pg_namespace n on n.oid = e.extnamespace
     where n.nspname = 'public' and e.extname <> 'plpgsql'
  loop
    begin
      execute format('alter extension %I set schema extensions', ext.extname);
    exception when others then
      raise notice 'extension skip %: %', ext.extname, sqlerrm;
    end;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 7) RLS HAMESHA ON — event trigger: public schema mein jo bhi nayi table bane,
--    usi waqt RLS khud enable ho jata hai (kabhi off nahi rehti).
-- ---------------------------------------------------------------------------
create or replace function public.ax_auto_enable_rls()
returns event_trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare obj record;
begin
  for obj in
    select t.object_identity as obj_id
      from pg_event_trigger_ddl_commands() as t
     where t.command_tag in ('CREATE TABLE','CREATE TABLE AS','SELECT INTO')
       and t.schema_name = 'public'
       and t.object_type = 'table'
  loop
    execute format('alter table %s enable row level security', obj.obj_id);
  end loop;
end $$;

revoke all on function public.ax_auto_enable_rls() from public, anon, authenticated;

drop event trigger if exists ax_auto_enable_rls_trg;
create event trigger ax_auto_enable_rls_trg
  on ddl_command_end
  when tag in ('CREATE TABLE','CREATE TABLE AS','SELECT INTO')
  execute function public.ax_auto_enable_rls();

-- ---------------------------------------------------------------------------
-- READING — chaaron ginti 0 honi chahiye
-- ---------------------------------------------------------------------------
select 'RLS OFF' as check_name, count(*) as value
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public' and c.relkind = 'r' and c.relrowsecurity = false
union all
select 'SECURITY DEFINER VIEWS', count(*)
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public' and c.relkind = 'v'
   and coalesce((select o.option_value from pg_options_to_table(c.reloptions) as o
                  where o.option_name = 'security_invoker'), 'false') <> 'true'
union all
select 'FUNCTIONS WITHOUT SEARCH_PATH', count(*)
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.prokind in ('f','p')
   and not exists (
     select 1 from unnest(coalesce(p.proconfig, array[]::text[])) as u(cfg)
      where u.cfg like 'search_path=%'
   )
union all
select 'RLS WITHOUT POLICY', count(*)
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public' and c.relkind = 'r' and c.relrowsecurity = true
   and not exists (select 1 from pg_policy p where p.polrelid = c.oid);
