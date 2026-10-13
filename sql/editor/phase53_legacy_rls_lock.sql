-- ============================================================================
-- PHASE 53 — LEGACY TABLES RLS LOCK (SQL editor mein copy-paste)
-- Wajah: sql/verify.sh mein "RLS OFF (must be 0) = 2" — dono legacy mailbox
-- tables par RLS off tha. Data delete NAHI hota; sirf lock lagta hai.
-- Idempotent: jitni dafa chalao, wahi natija.
-- ============================================================================
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
       and c.relname like '%_legacy%'
  loop
    execute format('alter table public.%I enable row level security', t.relname);
    execute format('alter table public.%I force row level security', t.relname);
    execute format('revoke all on public.%I from anon, authenticated', t.relname);
    execute format('grant all on public.%I to service_role', t.relname);
    raise notice 'legacy locked: %', t.relname;
  end loop;
end $$;

-- reading (dono ginti 0 honi chahiye)
select count(*) as rls_off_remaining
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public' and c.relkind = 'r' and c.relrowsecurity = false;
