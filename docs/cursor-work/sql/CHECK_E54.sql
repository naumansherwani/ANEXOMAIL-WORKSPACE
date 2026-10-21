-- CHECK E54 — sirf padhta hai. Har row ok = true.
select item, ok from (
  select 'E54 claimed_at column' as item,
         exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'mail_scheduled' and column_name = 'claimed_at') as ok, 1 as o
  union all select 'E54 mail_queue_claim maujood', to_regprocedure('public.mail_queue_claim(integer,integer)') is not null, 2
  union all select 'E54 mail_queue_release maujood', to_regprocedure('public.mail_queue_release()') is not null, 3
  union all select 'E54 mail_queue_cancel maujood', to_regprocedure('public.mail_queue_cancel(uuid,uuid,uuid)') is not null, 4
  union all select 'E54 nakli cancel = false', public.mail_queue_cancel('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000') = false, 5
  union all select 'E54 band: anon/authenticated nahi chala sakte',
         not (has_function_privilege('anon', 'public.mail_queue_claim(integer,integer)', 'execute') or has_function_privilege('authenticated', 'public.mail_queue_claim(integer,integer)', 'execute')
              or has_function_privilege('authenticated', 'public.mail_queue_cancel(uuid,uuid,uuid)', 'execute')), 6
  union all select 'E54 service_role chala sakta hai', has_function_privilege('service_role', 'public.mail_queue_claim(integer,integer)', 'execute'), 7
) t order by o;
