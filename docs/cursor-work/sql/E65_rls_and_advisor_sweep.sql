
-- E65 — RLS ON + Security Advisor warnings SAAF, ek hi script (22 Oct 2026). Rule 43: ab se har SQL RLS-on hogi; yeh script purani/chhooti hui sab ko barabar karti hai.
-- Dobara chalana safe (jitni baar chalao natija wahi). Koi DROP TABLE/COLUMN nahi, koi data nahi chhoota. E14 ka jaanasheen: chup-chaap error nahi nigalta, extension nahi hilata.
-- Advance level (Rule 38 + 42):
--   * TABLES (public, ordinary + partitioned parents; extension-owned aur partition-bachche chhod kar): RLS ON. Lock retry: har table par lock_timeout 3s, 4 koshishein — live traffic kabhi 3s se zyada nahi atakti.
--   * Jis table par ek bhi policy nahi: anon/authenticated ke sab haq wapas (default-deny, privilege bhi band) + ek hi service_role policy. Backend (Rust/Bun) service_role hai — RLS bypass + yeh policy, to site par asar nahi.
--     Jis table par policy pehle se hai (jaise auth.uid() wali) use CHHUA NAHI jata — woh founder/pichle SQL ka design hai.
--   * VIEWS: security_invoker = on (Postgres 15+; us se purani par chhoda jata hai aur WARNING aati hai). MATVIEWS: Data API (anon/authenticated) se bahar.
--   * FUNCTIONS (public, extension-owned nahi): search_path pin (pg_catalog, public, extensions) jahan pin nahi; SECURITY DEFINER par execute public/anon se wapas (authenticated ka jo haq pehle tha wahi rehta hai, service_role ko hamesha).
--   * EVENT TRIGGER `ax_rls_auto_enable`: aaj ke baad public mein jo bhi nayi table bane (kisi bhi SQL se) foran RLS ON. Body har galti pakad kar sirf WARNING deti hai — kisi DDL ko kabhi fail nahi karti. Superuser na ho to script WARNING deti hai (Rule 43 phir haath se).
--   * POST-CONDITION: koi public table RLS-off reh gayi to script FAIL (aadha kaam chup-chaap nahi). Baqi cheezein CHECK_E65 batata hai.
--   * Extensions ko public se NAHI hilata (indexes/opclass toot sakte hain) — advisor ka yeh ek warning alag, soch-samajh kar.
--   * WAPAS LENA (haath se): drop event trigger if exists ax_rls_auto_enable; drop function if exists public.ax_rls_auto_enable(); RLS wapas band karna mana hai (Rule 43).
set lock_timeout = '3s';
set statement_timeout = '120s';

-- ---- 1. event trigger ka function (nayi table => RLS ON) ---------------------------------------------------------------------
create or replace function public.ax_rls_auto_enable()
returns event_trigger language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  cmd record;
begin
  for cmd in
    select * from pg_event_trigger_ddl_commands()
     where command_tag in ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO') and object_type in ('table', 'partitioned table')
  loop
    begin
      if cmd.schema_name = 'public'
         and exists (select 1 from pg_class c where c.oid = cmd.objid and c.relkind in ('r', 'p') and not c.relispartition and c.relpersistence <> 't' and not c.relrowsecurity)
         and not exists (select 1 from pg_depend d where d.classid = 'pg_class'::regclass and d.objid = cmd.objid and d.deptype = 'e') then
        execute format('alter table %s enable row level security', cmd.object_identity);
      end if;
    exception when others then
      raise warning 'ax_rls_auto_enable: % ke liye RLS ON nahi ho saka (%): haath se chalao', cmd.object_identity, sqlerrm;
    end;
  end loop;
exception when others then
  raise warning 'ax_rls_auto_enable: %', sqlerrm;
end $$;
revoke all on function public.ax_rls_auto_enable() from public, anon, authenticated;

do $$
begin
  if not exists (select 1 from pg_event_trigger where evtname = 'ax_rls_auto_enable') then
    create event trigger ax_rls_auto_enable on ddl_command_end
      when tag in ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO') execute function public.ax_rls_auto_enable();
  end if;
exception when insufficient_privilege then
  raise warning 'E65: event trigger banane ka haq nahi (superuser chahiye) — naye tables par RLS haath se ON karna hoga (Rule 43)';
end $$;

-- ---- 2. TABLES: RLS ON (lock retry) --------------------------------------------------------------------------------------------
do $$
declare
  t record; n int; done boolean;
begin
  for t in
    select c.oid, c.relname from pg_class c join pg_namespace s on s.oid = c.relnamespace
     where s.nspname = 'public' and c.relkind in ('r', 'p') and not c.relispartition and not c.relrowsecurity
       and not exists (select 1 from pg_depend d where d.classid = 'pg_class'::regclass and d.objid = c.oid and d.deptype = 'e')
  loop
    done := false; n := 0;
    while not done and n < 4 loop
      n := n + 1;
      begin
        execute format('alter table public.%I enable row level security', t.relname);
        done := true;
      exception when lock_not_available then
        perform pg_sleep(0.5 * n);
      end;
    end loop;
    if not done then raise warning 'E65: public.% par lock nahi mila (RLS ON nahi hui) — dobara chalao', t.relname; end if;
  end loop;
end $$;

-- ---- 3. Bina policy wali tables: default-deny + privilege band + service_role policy --------------------------------------------
do $$
declare t record;
begin
  for t in
    select c.oid, c.relname from pg_class c join pg_namespace s on s.oid = c.relnamespace
     where s.nspname = 'public' and c.relkind in ('r', 'p') and not c.relispartition and c.relrowsecurity
       and not exists (select 1 from pg_policy p where p.polrelid = c.oid)
       and not exists (select 1 from pg_depend d where d.classid = 'pg_class'::regclass and d.objid = c.oid and d.deptype = 'e')
  loop
    execute format('revoke all on table public.%I from anon, authenticated', t.relname);
    execute format('create policy ax_service_role_only on public.%I for all to service_role using (true) with check (true)', t.relname);
  end loop;
end $$;

-- ---- 4. VIEWS (security_invoker) + MATVIEWS (Data API se bahar) ----------------------------------------------------------------
do $$
declare v record;
begin
  for v in
    select c.relname, c.relkind from pg_class c join pg_namespace s on s.oid = c.relnamespace
     where s.nspname = 'public' and c.relkind in ('v', 'm')
       and not exists (select 1 from pg_depend d where d.classid = 'pg_class'::regclass and d.objid = c.oid and d.deptype = 'e')
  loop
    if v.relkind = 'm' then
      execute format('revoke all on table public.%I from anon, authenticated', v.relname);
    elsif current_setting('server_version_num')::int >= 150000 then
      execute format('alter view public.%I set (security_invoker = on)', v.relname);
    else
      raise warning 'E65: Postgres < 15 — view public.% security_invoker nahi ho sakta', v.relname;
    end if;
  end loop;
end $$;

-- ---- 5. FUNCTIONS: search_path pin + SECURITY DEFINER execute public/anon se wapas --------------------------------------------
do $$
declare
  f record; had_auth boolean; sp text := case when exists (select 1 from pg_namespace where nspname = 'extensions') then 'pg_catalog, public, extensions' else 'pg_catalog, public' end;
begin
  for f in
    select p.oid, p.proname, p.prosecdef, pg_get_function_identity_arguments(p.oid) as args,
           (p.proconfig is null or array_to_string(p.proconfig, ' ') not like '%search_path=%') as unpinned
      from pg_proc p join pg_namespace s on s.oid = p.pronamespace
     where s.nspname = 'public' and p.prokind in ('f', 'p')
       and not exists (select 1 from pg_depend d where d.classid = 'pg_proc'::regclass and d.objid = p.oid and d.deptype = 'e')
  loop
    if f.unpinned then
      execute format('alter function public.%I(%s) set search_path = %s', f.proname, f.args, sp);
    end if;
    if f.prosecdef and has_function_privilege('anon', f.oid, 'execute') then
      had_auth := has_function_privilege('authenticated', f.oid, 'execute');
      execute format('revoke execute on function public.%I(%s) from public, anon', f.proname, f.args);   -- PUBLIC se anon bhi jata hai
      if had_auth then execute format('grant execute on function public.%I(%s) to authenticated', f.proname, f.args); end if;   -- jo haq authenticated ka tha wahi rahe
      execute format('grant execute on function public.%I(%s) to service_role', f.proname, f.args);
    end if;
  end loop;
end $$;

-- ---- 6. POST-CONDITION ------------------------------------------------------------------------------------------------------------
do $$
declare bad text;
begin
  select string_agg(c.relname, ', ') into bad
    from pg_class c join pg_namespace s on s.oid = c.relnamespace
   where s.nspname = 'public' and c.relkind in ('r', 'p') and not c.relispartition and not c.relrowsecurity
     and not exists (select 1 from pg_depend d where d.classid = 'pg_class'::regclass and d.objid = c.oid and d.deptype = 'e');
  if bad is not null then raise exception 'E65 POST-CONDITION: RLS abhi bhi OFF: %', bad using errcode = 'AX065'; end if;
end $$;

comment on function public.ax_rls_auto_enable() is 'Event-trigger helper (E65, Rule 43): every new public table gets row level security ON immediately. Never fails the DDL.';

notify pgrst, 'reload schema';
