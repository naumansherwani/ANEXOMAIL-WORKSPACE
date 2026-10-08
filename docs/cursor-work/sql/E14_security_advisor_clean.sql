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
--   7) Extension in Public          → extensions schema mein move
-- Har statement apni exception guard mein — ek table/view fail ho to baqi chalta hai.
-- =============================================================================
set search_path = public, extensions;

-- ---------------------------------------------------------------------------
-- 0) Pichle run ka event trigger hatao (har DDL par chalta tha — 42P01 ka shak)
-- ---------------------------------------------------------------------------
drop event trigger if exists ax_auto_enable_rls_trg;
drop function if exists public.ax_auto_enable_rls();

-- ---------------------------------------------------------------------------
-- 1) VIEWS — security_invoker = on
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
-- 2) TABLES — RLS enable
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
    begin
      execute format('alter table public.%I enable row level security', t.relname);
      raise notice 'rls on: %', t.relname;
    exception when others then
      raise notice 'table rls skip %: %', t.relname, sqlerrm;
    end;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 3) Bina policy wali table → sirf service_role (backend) access
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
       and not exists (select 1 from pg_policy p where p.polrelid = c.oid)
  loop
    begin
      execute format('revoke all on public.%I from anon, authenticated', t.relname);
      execute format('grant all on public.%I to service_role', t.relname);
      execute format('drop policy if exists "service_role_internal_access" on public.%I', t.relname);
      execute format('create policy "service_role_internal_access" on public.%I for all to service_role using (true) with check (true)', t.relname);
      raise notice 'no-policy locked: %', t.relname;
    exception when others then
      raise notice 'policy lock skip %: %', t.relname, sqlerrm;
    end;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 4) Har public table par service_role grant
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
    begin
      execute format('grant all on public.%I to service_role', t.relname);
    exception when others then
      raise notice 'grant skip %: %', t.relname, sqlerrm;
    end;
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
    begin
      execute format('revoke all on public.%I from anon, authenticated', m.relname);
      execute format('grant select on public.%I to service_role', m.relname);
    exception when others then
      raise notice 'matview skip %: %', m.relname, sqlerrm;
    end;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 6) FUNCTIONS — search_path pin (body/permission nahi badalta)
-- ---------------------------------------------------------------------------
do $$
declare f record;
begin
  for f in
    select p.proname,
           pg_get_function_identity_arguments(p.oid) as args
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.prokind in ('f','p')
       and (p.proconfig is null
            or array_to_string(p.proconfig, ' ') not like '%search_path=%')
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

-- ---------------------------------------------------------------------------
-- 7) EXTENSION IN PUBLIC → extensions schema
-- ---------------------------------------------------------------------------
do $$
declare e record;
begin
  for e in
    select x.extname
      from pg_extension x
      join pg_namespace n on n.oid = x.extnamespace
     where n.nspname = 'public' and x.extname <> 'plpgsql'
  loop
    begin
      execute format('alter extension %I set schema extensions', e.extname);
    exception when others then
      raise notice 'extension skip %: %', e.extname, sqlerrm;
    end;
  end loop;
end $$;

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
   and (c.reloptions is null
        or not (c.reloptions && array['security_invoker=on','security_invoker=true','security_invoker=1']))
union all
select 'FUNCTIONS WITHOUT SEARCH_PATH', count(*)
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.prokind in ('f','p')
   and (p.proconfig is null
        or array_to_string(p.proconfig, ' ') not like '%search_path=%')
union all
select 'RLS WITHOUT POLICY', count(*)
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public' and c.relkind = 'r' and c.relrowsecurity = true
   and not exists (select 1 from pg_policy p where p.polrelid = c.oid);
