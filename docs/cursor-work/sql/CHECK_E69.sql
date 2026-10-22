
-- CHECK E69 — sirf padhta hai. Har row ok = true.
select item, ok from (
  select 'E69 identity_health + identity_cursors maujood + RLS ON + anon/authenticated band' as item,
         (select count(*) from pg_class where oid in (to_regclass('public.identity_health'), to_regclass('public.identity_cursors')) and relrowsecurity) = 2
         and not has_table_privilege('anon', 'public.identity_health', 'select') and not has_table_privilege('authenticated', 'public.identity_cursors', 'select') as ok, 1 as o
  union all select 'E69 identity_bans.changed_at + index + NOTIFY/touch triggers',
         exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'identity_bans' and column_name = 'changed_at')
         and to_regclass('public.identity_bans_changed_idx') is not null
         and (select count(*) from pg_trigger where tgname in ('identity_bans_notify_ai', 'identity_bans_touch_bi') and not tgisinternal) = 2, 2
  union all select 'E69 feed/health/cursor/payment functions: execute sirf service_role',
         has_function_privilege('service_role', 'public.identity_ban_feed(timestamptz,bigint,integer)', 'execute')
         and has_function_privilege('service_role', 'public.identity_payment_pending(timestamptz,integer)', 'execute')
         and has_function_privilege('service_role', 'public.identity_health_report(text,integer,integer,integer,integer,text)', 'execute')
         and not has_function_privilege('anon', 'public.identity_ban_feed(timestamptz,bigint,integer)', 'execute')
         and not has_function_privilege('authenticated', 'public.identity_payment_pending(timestamptz,integer)', 'execute'), 3
  union all select 'E69 feed sirf padhta hai aur shape theek (rows/cursor_t/cursor_id/more/full)',
         (select (j ? 'rows') and (j ? 'cursor_id') and (j ? 'more') and (j ? 'full') and (j ->> 'full')::boolean from (select public.identity_ban_feed(null, 0, 5) j) x), 4
  union all select 'E69 parity vector (SQL = JS = Rust): hmac(email, a@b.com, k)',
         public.identity_hmac_hex('email', 'a@b.com', 'k') = '63421a113608fece1cb4ee68e688cce63c4fa2fec389a00b32f99f3d493452b6'
         and public.identity_hmac_hex('device_key', 'dk-1', 'k') = 'ff7275b6820ec180d412d136d6db70aa3b438b4bc0c62dea759db9e1d2ed326f'
         and public.identity_canon_email('Ali.Khan+x@GoogleMail.com') = 'alikhan@gmail.com', 5
  union all select 'E69 cursor: peeche nahi jata',
         public.identity_cursor_get('check-e69-none') = 'epoch'::timestamptz, 6
  union all select 'E69 functions search_path pinned (identity_*)',
         not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname like 'identity\_%' and p.proconfig is null), 7
) t order by o;
