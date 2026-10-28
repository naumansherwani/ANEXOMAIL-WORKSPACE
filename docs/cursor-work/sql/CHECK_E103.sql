
-- CHECK E103 — sirf padhta hai (+ selftest jo khud poora rollback karta hai). Har row ok = true.
select item, ok from (
select 'E103 12 actions maujood, saare English-ASCII (title/summary)' as item,
       (select count(*) from public.founder_actions) >= 12
       and (select count(*) from public.founder_actions where not (title ~ '^[ -~]{3,60}$' and summary ~ '^[ -~]{3,200}$')) = 0 as ok, 1 as ord
union all select 'E103 koi Roman-Urdu lafz baqi nahi (title/summary)',
       (select count(*) from public.founder_actions where (title || ' ' || summary) ~* '\m(chalao|wapas|dobara|nahi|lazmi|jaanch|abhi|saaf|karna|naya|naye|band|ka|ki|ke)\M') = 0, 2
union all select 'E103 text constraint maujood aur VALIDATED',
       exists (select 1 from pg_constraint where conname = 'founder_actions_text_ascii' and convalidated), 3
union all select 'E103 safety-ratchet trigger chalu (founder_actions_guard_upd)',
       exists (select 1 from pg_trigger where tgname = 'founder_actions_guard_upd' and tgenabled = 'O' and not tgisinternal), 4
union all select 'E103 koi enabled action nahi (executor F8 tak) + high-danger sab passkey+two-tap',
       (select count(*) from public.founder_actions where enabled) = 0
       and (select count(*) from public.founder_actions where danger = 'high' and not (needs_passkey and two_tap)) = 0, 5
union all select 'E103 service_role founder_actions par delete/truncate nahi + delete/truncate triggers chalu',
       has_table_privilege('service_role', 'public.founder_actions', 'update') and not has_table_privilege('service_role', 'public.founder_actions', 'delete')
       and not has_table_privilege('service_role', 'public.founder_actions', 'truncate')
       and not has_table_privilege('authenticated', 'public.founder_actions', 'select')
       and (select count(*) from pg_trigger where tgname in ('founder_actions_no_del','founder_actions_no_trunc') and tgenabled = 'O') = 2, 6
union all select 'E103 updated_at + text_rev columns',
       (select count(*) from information_schema.columns where table_schema = 'public' and table_name = 'founder_actions' and column_name in ('updated_at', 'text_rev')) = 2, 7
union all select 'E103 behaviour: ratchet/constraint/jaiz badlav (selftest, rollback ke saath)',
       coalesce(public.founder_actions_selftest() like 'E103 selftest OK%' or public.founder_actions_selftest() like 'E103 selftest SKIP%', false), 8
) t order by ord;
