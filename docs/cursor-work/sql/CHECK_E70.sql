-- CHECK E70 — sirf padhta hai. Har row ok = true. (identity hardening: fingerprint / hold / gate / disposable)
select item, ok from (
  select 'E70 nayi tables maujood + RLS ON + anon/authenticated ko koi haq nahi' as item,
         (select count(*) from pg_class where oid in (to_regclass('public.identity_account_state'), to_regclass('public.identity_disposable_domains')) and relrowsecurity) = 2
         and not has_table_privilege('anon', 'public.identity_account_state', 'select') and not has_table_privilege('authenticated', 'public.identity_account_state', 'select')
         and not has_table_privilege('anon', 'public.identity_disposable_domains', 'select') and not has_table_privilege('authenticated', 'public.identity_disposable_domains', 'insert') as ok, 1 as o
  union all select 'E70 policy ki nayi hadein maujood (fp_match_min, fp_farm_limit, velocity_limit, signup_gate, probation_days, disposable_block, hold_expire_days)',
         (select count(*) from information_schema.columns where table_schema = 'public' and table_name = 'identity_vault_policy'
            and column_name in ('fp_match_min', 'fp_farm_limit', 'velocity_limit', 'signup_gate', 'probation_days', 'disposable_block', 'hold_expire_days', 'gate_changed_by', 'gate_changed_at')) = 9
         and (select signup_gate in ('open', 'hold_matches', 'approval_all') from public.identity_vault_policy where id = 1), 2
  union all select 'E70 kind: fp_hw/fp_gfx/fp_env kamzor-darje (akele ban nahi), purane mazboot salamat',
         public.identity_kind_strong('fp_hw') is false and public.identity_kind_strong('fp_gfx') is false and public.identity_kind_strong('fp_env') is false
         and public.identity_kind_fp('fp_env') and not public.identity_kind_fp('email')
         and public.identity_kind_strong('email') and public.identity_kind_strong('device_key') and public.identity_kind_strong('payment') and public.identity_kind_strong('recovery'), 3
  union all select 'E70 sab nayi functions maujood: execute sirf service_role',
         (select bool_and(has_function_privilege('service_role', f, 'execute') and not has_function_privilege('anon', f, 'execute') and not has_function_privilege('authenticated', f, 'execute'))
            from unnest(array[
              'public.identity_signup_decide(jsonb,text)', 'public.identity_signup_check(jsonb)', 'public.identity_register(uuid,jsonb)',
              'public.identity_hold_apply(uuid,text,text)', 'public.identity_hold_decide(uuid,uuid,text,text,boolean)', 'public.identity_hold_sweep()',
              'public.identity_gate_set(uuid,text)', 'public.identity_disposable_set(uuid,text,boolean)', 'public.identity_account_limits(uuid)',
              'public.identity_email_is_disposable(text)', 'public.identity_register_payment(uuid,text,text)', 'public.identity_admin_overview(uuid)',
              'public.identity_signals_full_raw(text,text,text,text,text,text,text,text,text)', 'public.identity_signup_decide_raw(text,text,text,text,text,text,text,text,text)'
            ]) f), 4
  union all select 'E70 disposable seed (100+) + protected provider kabhi nahi pakde jate',
         (select count(*) from public.identity_disposable_domains where active) >= 100
         and public.identity_email_is_disposable('x@mailinator.com') and public.identity_email_is_disposable('x@a.b.yopmail.com')
         and not public.identity_email_is_disposable('x@gmail.com') and not public.identity_email_is_disposable('x@outlook.com') and not public.identity_email_is_disposable('x@anexomail.com'), 5
  union all select 'E70 parity vector (SQL = JS = Rust): fp_hw/fp_gfx/fp_env hmac',
         public.identity_hmac_hex('fp_hw',  repeat('a', 64), 'k') = '89ba8aecbe0575530e8314748117334b5475e4f6e733626a973a589f7633eeb8'
         and public.identity_hmac_hex('fp_gfx', repeat('b', 64), 'k') = '4668add1d439de679c16884d906cd0120b6c7989981c4405a58083861a0457b7'
         and public.identity_hmac_hex('fp_env', repeat('c', 64), 'k') = '5208a079f758b5001657d361a7875e04f6835745a7138633b0b690a0b15d43e2'
         and public.identity_fp_canon('  ' || upper(repeat('a', 64)) || ' ') = repeat('a', 64) and public.identity_fp_canon('abc') is null, 6
  union all select 'E70 faisla sirf padhta hai: khaali network signal par allow + shape theek',
         (select (j ->> 'decision') = 'allow' and j ? 'matched' and j ? 'appealable' and j ? 'reason'
            from (select public.identity_signup_decide('[{"kind":"network","hmac":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"}]'::jsonb, 'example.org') j) x), 7
  union all select 'E70 audit ke naye events ki list DB-checked',
         exists (select 1 from pg_constraint where conrelid = 'public.identity_vault_audit'::regclass and contype = 'c' and conname = 'identity_vault_audit_event_ck'
                  and pg_get_constraintdef(oid) like '%hold%' and pg_get_constraintdef(oid) like '%approve%' and pg_get_constraintdef(oid) like '%expire%'), 8
  union all select 'E70 har identity_* function ka search_path pinned',
         not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname like 'identity\_%' and p.proconfig is null), 9
  union all select 'E70 identity_account_state: pending <=> decided_at NULL + FK auth.users cascade',
         exists (select 1 from pg_constraint where conname = 'identity_account_state_decided_ck')
         and exists (select 1 from pg_constraint where conrelid = 'public.identity_account_state'::regclass and contype = 'f' and confdeltype = 'c'), 10
  union all select 'E70 mirror feed ab bhi sirf mazboot nishan (fingerprint/kamzor nahi)',
         not exists (select 1 from jsonb_array_elements(public.identity_ban_feed(null, 0, 20000) -> 'rows') e where e ->> 'k' in ('fp_hw', 'fp_gfx', 'fp_env', 'device_shape', 'network')), 11
  union all select 'E70 GoTrue ban column maujood (auth.users.banned_until)',
         exists (select 1 from information_schema.columns where table_schema = 'auth' and table_name = 'users' and column_name = 'banned_until'), 12
  union all select 'E70 INVARIANT: har pending hold ka account GoTrue par band hai (banned_until aage)',
         not exists (select 1 from public.identity_account_state s join auth.users u on u.id = s.account_id
                      where s.state = 'pending' and (u.banned_until is null or u.banned_until < now() + interval '1 year')), 13
  union all select 'E70 INVARIANT: manzoor shuda account band nahi (approved => banned_until NULL ya guzra hua)',
         not exists (select 1 from public.identity_account_state s join auth.users u on u.id = s.account_id
                      where s.state = 'approved' and u.banned_until is not null and u.banned_until > now()), 14
  union all select 'E70 INVARIANT: rejected account band hai',
         not exists (select 1 from public.identity_account_state s join auth.users u on u.id = s.account_id
                      where s.state = 'rejected' and (u.banned_until is null or u.banned_until < now() + interval '1 year')), 15
) t order by o;
