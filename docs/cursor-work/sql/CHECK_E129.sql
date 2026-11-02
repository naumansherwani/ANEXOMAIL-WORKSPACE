-- CHECK E129 — sirf padhta hai.
select item, ok from (
  select 1 as o, 'E129 organisations has the new columns (name_source, domain_verified_at, deleted_at, ...)' as item,
         (select count(*) from information_schema.columns where table_schema='public' and table_name='organisations'
            and column_name in ('name_source','updated_at','domain_claimed_at','domain_verified_at','domain_grandfathered','deleted_at','delete_after')) = 7 as ok
  union all select 2, 'E129 guard trigger on organisations (blank name -> default, domain cleaned)',
         exists (select 1 from pg_trigger where tgrelid='public.organisations'::regclass and tgname='organisations_guard_biu' and not tgisinternal)
  union all select 3, 'E129 limits trigger (5 owned / 3 per 24 h)',
         exists (select 1 from pg_trigger where tgrelid='public.organisations'::regclass and tgname='organisations_limits_bi' and not tgisinternal)
  union all select 4, 'E129 org_events exists, RLS on, anon/authenticated have no privilege',
         to_regclass('public.org_events') is not null
         and (select relrowsecurity from pg_class where oid='public.org_events'::regclass)
         and not has_table_privilege('anon','public.org_events','select') and not has_table_privilege('authenticated','public.org_events','select')
  union all select 5, 'E129 org_events is append-only (update/delete trigger present)',
         exists (select 1 from pg_trigger where tgrelid='public.org_events'::regclass and tgname='org_events_no_change' and not tgisinternal)
  union all select 6, 'E129 org_events has NO foreign key (organisation delete never collides with the chain)',
         not exists (select 1 from pg_constraint where conrelid='public.org_events'::regclass and contype='f')
  union all select 7, 'E129 org_domain_claims exists, RLS on, no anon/authenticated access',
         to_regclass('public.org_domain_claims') is not null
         and (select relrowsecurity from pg_class where oid='public.org_domain_claims'::regclass)
         and not has_table_privilege('authenticated','public.org_domain_claims','select')
  union all select 8, 'E129 last-owner protection trigger on org_members',
         exists (select 1 from pg_trigger where tgrelid='public.org_members'::regclass and tgname='org_members_last_owner' and not tgisinternal)
  union all select 9, 'E129 case-insensitive unique domain index (or no collision data to block it)',
         exists (select 1 from pg_indexes where schemaname='public' and indexname='organisations_domain_ci_uq')
  union all select 10, 'E129 every E129 function has a pinned search_path and is not executable by anon/authenticated',
         not exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
                      where n.nspname='public' and p.proname in ('org_guard_biu','org_limits_bi','org_events_immutable','org_events_trg','org_last_owner_guard','org_event_append',
                        'org_events_verify','org_domain_release_stale','org_domain_claim_start','org_domain_claim_confirm','org_soft_delete','org_restore','org_purge_due',
                        'org_ensure_default','org_integrity_report','org_repair_owner_member')
                        and (p.proconfig is null or not exists (select 1 from unnest(p.proconfig) c where c like 'search_path=%')
                             or has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute')))
  union all select 11, 'E129 org_integrity_report() finds NO problem except people who have not created an organisation yet (listed below)',
         not exists (select 1 from public.org_integrity_report() where problem <> 'user_without_organisation')
  union all select 12, 'E129 every organisation hash chain verifies',
         not exists (select 1 from (select distinct org_id from public.org_events) e where not public.org_events_verify(e.org_id))
) x order by o;

-- info (not a pass/fail): every open problem, one row each
select 'INFO ' || problem as problem, org_id, detail from public.org_integrity_report() order by 1 limit 30;
