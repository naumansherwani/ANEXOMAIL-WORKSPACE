-- CHECK E71 — sirf padhta hai. Har row ok = true. (probation ki rok + session backstop + manzoori notice)
select item, ok from (
  select 'E71 usage table maujood + RLS ON + anon/authenticated ko koi haq nahi' as item,
         coalesce((select relrowsecurity from pg_class where oid = to_regclass('public.identity_probation_usage')), false)
         and not has_table_privilege('anon', 'public.identity_probation_usage', 'select') and not has_table_privilege('authenticated', 'public.identity_probation_usage', 'insert') as ok, 1 as o
  union all select 'E71 sab nayi functions maujood: execute sirf service_role',
         (select bool_and(has_function_privilege('service_role', f, 'execute') and not has_function_privilege('anon', f, 'execute') and not has_function_privilege('authenticated', f, 'execute'))
            from unnest(array['public.identity_probation_take(uuid,text,int)', 'public.identity_probation_sweep()', 'public.identity_session_guard_status()',
                              'public.identity_notice_pending(int)', 'public.identity_notice_done(uuid,boolean)', 'public.identity_vault_purge_probation()']) f), 2
  union all select 'E71 SESSION BACKSTOP auth.sessions par laga (hold/rejected ka session DB banne hi nahi deta)',
         coalesce((public.identity_session_guard_status() ->> 'sessions')::boolean, false), 3
  union all select 'E71 SESSION BACKSTOP auth.refresh_tokens par laga',
         coalesce((public.identity_session_guard_status() ->> 'refresh_tokens')::boolean, false), 4
  union all select 'E71 notice ke columns maujood (notify_state, notified_at, notify_attempts, notify_last_at)',
         (select count(*) from information_schema.columns where table_schema = 'public' and table_name = 'identity_account_state'
            and column_name in ('notify_state', 'notified_at', 'notify_attempts', 'notify_last_at')) = 4, 5
  union all select 'E71 invariant: pending/rejected ke paas koi session nahi',
         not exists (select 1 from auth.sessions s join public.identity_account_state a on a.account_id = s.user_id where a.state in ('pending', 'rejected')), 6
  union all select 'E71 har identity_* function ka search_path pinned',
         not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname like 'identity\_%' and p.proconfig is null), 7
) q order by o;
