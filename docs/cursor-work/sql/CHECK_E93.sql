
-- CHECK E93 — sirf padhta hai.
select item, ok from (
select 'E93 server ceiling 35 MiB' as item,
       (select value from public.mail_attach_limits where key='server_ceiling_bytes') = 36700160 as ok, 1 as n
union all select 'E93 Pro asli attachment 35 MiB',
       (select least(max_send_bytes,(select value from public.mail_attach_limits where key='server_ceiling_bytes')) from public.storage_plans where plan_id='pro') = 36700160, 2
union all select 'E93 Basic asli attachment 25 MiB',
       (select least(max_send_bytes,(select value from public.mail_attach_limits where key='server_ceiling_bytes')) from public.storage_plans where plan_id='basic') = 26214400, 3
) t order by n;
