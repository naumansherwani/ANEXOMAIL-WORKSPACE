-- CHECK E42–E45 — sirf padhta hai (kuch badalta nahi). Supabase SQL editor mein paste, Run. Har row ka ok = true hona chahiye.
-- (E41 temp function hai, uska asar alag dekha jata hai: neeche aakhri query.)
select item, ok from (
  select 'E42 device_hash_v2'            as item, to_regprocedure('public.device_hash_v2(text,text)') is not null as ok, 1 as o
  union all select 'E42 device_hash_migrate_v2',  to_regprocedure('public.device_hash_migrate_v2(text)') is not null, 2
  union all select 'E43 account_recovery_codes',  to_regclass('public.account_recovery_codes') is not null, 3
  union all select 'E43 passkey_policy row',      coalesce((select count(*) = 1 from public.passkey_policy), false), 4
  union all select 'E43 passkey_status()',        to_regprocedure('public.passkey_status(uuid)') is not null, 5
  union all select 'E44 account_export_page',     to_regprocedure('public.account_export_page(uuid,text,text,integer)') is not null, 6
  union all select 'E44 ticket_issue/use',        to_regprocedure('public.account_export_ticket_issue(uuid)') is not null and to_regprocedure('public.account_export_ticket_use(text)') is not null, 7
  union all select 'E45 purge_due(_key) NAYA',    to_regprocedure('public.account_integrity_purge_due(text)') is not null, 8
  union all select 'E45 purani purge_due() HATI', to_regprocedure('public.account_integrity_purge_due()') is null, 9
  union all select 'E45 tombstones table',        to_regclass('public.account_integrity_tombstones') is not null, 10
  union all select 'E45 email_hmac_v1',           to_regprocedure('public.email_hmac_v1(text,text)') is not null, 11
  union all select 'E45 log event purge_blocked', exists (select 1 from pg_constraint where conrelid = 'public.account_integrity_log'::regclass and contype = 'c' and pg_get_constraintdef(oid) ilike '%purge_blocked%'), 12
) t order by o;

-- E41 ka asar (Humza): plan/entitlement dikhao — kuch badalta nahi
-- select u.email, e.* from auth.users u left join public.entitlements e on e.user_id = u.id where u.email = 'humzasherwani@anexomail.com';
