
-- =============================================================================
-- E32 — Tenant lock (18 Oct 2026): ek customer doosre customer ka data public database API se na padh sake, na likh sake.
--
-- Wajah (SQL files padh kar mili, LIVE par `rls-open-check.sh` se confirm hoti hai):
--   phase52 / phase60 / phase61 / phase62 / phase64_crm_locale ne in tables par `authenticated` ko
--   `using (true)` policies di hain (read) aur kaheen `for all ... with check (true)` (write bhi).
--   Browser mein publishable key hoti hi hai (chat realtime ke liye) aur har logged-in customer ke paas apna JWT hota hai,
--   yaani koi bhi customer `https://<project>.supabase.co/rest/v1/mail_messages` seedha kholkar SAB organisations ki mail,
--   contacts, calendar, tasks, CRM padh sakta tha — aur `org_members` mein khud ko kisi bhi organisation mein likh sakta tha.
--   Ham ka apna server (Brain + Rust) service_role se jata hai (RLS bypass) aur har route khud organisation check karta hai,
--   is liye in tables par `anon`/`authenticated` ka koi kaam hai hi nahi.
--
-- Kya karta hai (sirf neeche ki list, har table sirf agar maujood ho):
--   1. anon / authenticated / public ki SAB policies hata deta hai,
--   2. in roles se table ke sab huqooq (select/insert/update/delete) wapas le leta hai,
--   3. service_role ke grant + policy yaqeeni banata hai (app ko kuch nahi hota).
-- Kya NAHI karta: chat tables, auth/billing/payment tables, public config tables (setting_defs, storage_plans,
-- reserved_handles, locale_registry, ui_copy, billing_price_book …), kisi row ya column ko, kisi function ko.
-- Idempotent. Dobara chalane se kuch nahi bigadta. Fail ho to: usi file ko shuru se theek karo (naya naam banned).
-- Wapas lene ka rasta: koi nahi chahiye — app service_role par hai; (agar kabhi kuch toote to table ka naam bata dein).
-- =============================================================================

begin;

do $$
declare
  t text;
  pol record;
  v_done int := 0;
  v_skip int := 0;
  tables text[] := array[
    -- mail
    'mail_domains','mailboxes','mail_threads','mail_messages','mail_attachments','mail_inbound_raw','mail_outbox_log',
    -- organisations / people in them
    'orgs','org_members','mail_accounts',
    -- calendar + work
    'calendar_events','calendar_attendees','calendar_focus_windows','work_tasks','work_promises','work_notes','mail_thread_events',
    -- contacts
    'companies','contacts','contact_stats','contact_tags','contact_tag_map',
    -- CRM
    'crm_leads','crm_deals','crm_activities','crm_audit','crm_shared_items','crm_mentions','crm_approvals',
    'crm_permissions','crm_graph_edges','crm_evidence',
    -- delivery checks
    'delivery_checks','delivery_blocklists',
    -- founder-only data
    'release_checklist','deployments','release_locks','roadmap_items','subscription_pipeline','movein_transitions','movein_capacity'
  ];
begin
  foreach t in array tables loop
    if to_regclass('public.' || quote_ident(t)) is null then
      v_skip := v_skip + 1;
      continue;
    end if;
    begin
      execute format('alter table public.%I enable row level security', t);
      for pol in
        select policyname from pg_policies
         where schemaname = 'public' and tablename = t
           and (roles && array['anon', 'authenticated', 'public']::name[])
      loop
        execute format('drop policy %I on public.%I', pol.policyname, t);
      end loop;
      execute format('revoke all on table public.%I from anon, authenticated', t);
      execute format('grant all on table public.%I to service_role', t);
      execute format('drop policy if exists service_role_internal_access on public.%I', t);
      execute format('create policy service_role_internal_access on public.%I for all to service_role using (true) with check (true)', t);
      v_done := v_done + 1;
    exception when others then
      raise notice 'E32 table % skip: %', t, sqlerrm;
    end;
  end loop;
  raise notice 'E32: % tables locked, % not present in this database', v_done, v_skip;
end $$;

-- self-test: nothing in the list may remain readable/writable by anon or authenticated
do $$
declare
  r record;
  v_bad text := '';
begin
  for r in
    select c.relname
      from pg_class c join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind = 'r'
       and c.relname = any (array[
         'mail_domains','mailboxes','mail_threads','mail_messages','mail_attachments','mail_inbound_raw','mail_outbox_log',
         'orgs','org_members','mail_accounts',
         'calendar_events','calendar_attendees','calendar_focus_windows','work_tasks','work_promises','work_notes','mail_thread_events',
         'companies','contacts','contact_stats','contact_tags','contact_tag_map',
         'crm_leads','crm_deals','crm_activities','crm_audit','crm_shared_items','crm_mentions','crm_approvals',
         'crm_permissions','crm_graph_edges','crm_evidence',
         'delivery_checks','delivery_blocklists',
         'release_checklist','deployments','release_locks','roadmap_items','subscription_pipeline','movein_transitions','movein_capacity'
       ])
  loop
    if has_table_privilege('authenticated', format('public.%I', r.relname), 'select,insert,update,delete')
       or has_table_privilege('anon', format('public.%I', r.relname), 'select,insert,update,delete')
       or has_table_privilege('authenticated', format('public.%I', r.relname), 'select')
       or has_table_privilege('anon', format('public.%I', r.relname), 'select')
       or exists (select 1 from pg_policies p where p.schemaname = 'public' and p.tablename = r.relname
                   and (p.roles && array['anon', 'authenticated', 'public']::name[])) then
      v_bad := v_bad || ' ' || r.relname;
    end if;
  end loop;
  if v_bad <> '' then
    raise exception 'E32 FAILED: still reachable by customers:%', v_bad;
  end if;
end $$;

commit;

-- read-only proof (run after, or use docs/cursor-work/server/rls-open-check.sh):
--   select tablename, policyname, roles, cmd from pg_policies
--    where schemaname = 'public' and roles && array['anon','authenticated','public']::name[] and (qual = 'true' or with_check = 'true');
