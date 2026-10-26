
-- CHECK E87 — sirf padhta hai. Har row ok = true. Business Basic v6: 15 GB shared, 3 mailboxes, user cap 5.
select item, ok from (
  select 'E87 storage_plans basic = 15 GiB pool, per-mailbox null, 3 mailboxes, send 25 MB' as item,
         exists (select 1 from public.storage_plans where plan_id = 'basic' and per_mailbox_bytes is null
                   and pooled_bytes = 16106127360 and mailbox_limit = 3 and max_send_bytes = 26214400) as ok, 1 as n
  union all select 'E87 baqi plans (pro/business/business_pro) pehle jaise',
         (select count(*) from public.storage_plans where plan_id in ('pro','business','business_pro')) = 3, 2
  union all select 'E87 team_seat_calc basic cap 5 (3 used + 1 pending => 1 free)',
         (public.team_seat_calc('basic', 0, 3, 1)->>'seats')::int = 5 and (public.team_seat_calc('basic', 0, 3, 1)->>'free')::int = 1, 3
  union all select 'E87 team_seat_calc business_pro abhi bhi unlimited',
         (public.team_seat_calc('business_pro', 3, 900, 5)->>'unlimited')::boolean, 4
  union all select 'E87 get_billing_subscription maujood',
         to_regprocedure('public.get_billing_subscription(uuid)') is not null, 5
) q order by n;
