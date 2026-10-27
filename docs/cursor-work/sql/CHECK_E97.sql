
-- CHECK E97 — sirf padhta hai. Har row ok = true.
select item, ok from (
select 'E97 commitment_ledger + keys + economics tables maujood' as item,
       to_regclass('public.commitment_ledger') is not null and to_regclass('public.commitment_keys') is not null
       and to_regclass('public.thread_economics_log') is not null and to_regclass('public.org_attention_rates') is not null as ok, 1 as n
union all select 'E97 sab functions maujood',
       to_regprocedure('public.commitment_record(uuid,uuid,text,text,text,date,uuid,text,boolean,numeric,text,text[],boolean,text)') is not null
       and to_regprocedure('public.commitment_set_status(uuid,uuid,uuid,text,date)') is not null
       and to_regprocedure('public.commitment_verify(uuid)') is not null
       and to_regprocedure('public.attention_cost(integer,integer,integer,integer)') is not null
       and to_regprocedure('public.attention_estimate(uuid,integer,integer)') is not null
       and to_regprocedure('public.thread_economics_record(uuid,uuid,uuid,integer,integer,boolean)') is not null, 2
union all select 'E97 RLS on (4 naye table)',
       (select count(*) from pg_class where oid in ('public.commitment_ledger'::regclass,'public.commitment_keys'::regclass,
          'public.thread_economics_log'::regclass,'public.org_attention_rates'::regclass) and relrowsecurity) = 4, 3
union all select 'E97 anon/authenticated ko koi access nahi',
       not has_table_privilege('anon','public.commitment_ledger','select') and not has_table_privilege('authenticated','public.commitment_ledger','select')
       and not has_table_privilege('authenticated','public.commitment_keys','select')
       and not has_function_privilege('anon','public.commitment_record(uuid,uuid,text,text,text,date,uuid,text,boolean,numeric,text,text[],boolean,text)','execute')
       and not has_function_privilege('authenticated','public.commitment_verify(uuid)','execute'), 4
union all select 'E97 ledger append-only trigger laga hai',
       (select count(*) from pg_trigger where tgrelid='public.commitment_ledger'::regclass and not tgisinternal
          and tgname in ('commitment_ledger_no_change','commitment_ledger_no_truncate')) = 2, 5
union all select 'E97 attention_cost parity (400w x10 @ 10000 = 3278, 1500w = 11611)',
       (select cost_minor from public.attention_cost(400,10,10000,220)) = 3278
       and (select cost_minor from public.attention_cost(1500,10,10000,220)) = 11611, 6
union all select 'E97 work_promises naye column',
       (select count(*) from information_schema.columns where table_schema='public' and table_name='work_promises'
          and column_name in ('ledger_id','promised_to','due_exact','lang','dedupe_key','event_id','settled_at','source','commit_state','thread_subject','created_by')) = 11, 7
union all select 'E97 dedupe unique index',
       to_regclass('public.work_promises_dedupe_uq') is not null, 8
union all select 'E97 views maujood',
       to_regclass('public.v_commitments_open') is not null and to_regclass('public.v_commitment_kept_rate') is not null
       and to_regclass('public.v_thread_economics_monthly') is not null and to_regclass('public.v_commitments_due_soon') is not null, 9
union all select 'E97 selftest ki chain theek (verify ok)',
       coalesce((public.commitment_verify('00000000-0000-4000-8000-0000000e9700'::uuid)->>'ok')::boolean, false), 10
) t order by n;
