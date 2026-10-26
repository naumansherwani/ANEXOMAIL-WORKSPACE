
-- CHECK E88 — sirf padhta hai. Har row ok = true (last column ok, sql-run.sh ' | f' dhoondta hai).
select item, ok from (
select 'E88 pro storage 300GiB/10 mailboxes/35MiB' as item,
       exists (select 1 from public.storage_plans where plan_id='pro' and per_mailbox_bytes is null and pooled_bytes=322122547200
                   and mailbox_limit=10 and max_send_bytes=36700160) as ok, 1 as n
union all select 'basic untouched (E87)',
       exists (select 1 from public.storage_plans where plan_id='basic' and pooled_bytes=16106127360 and mailbox_limit=3 and max_send_bytes=26214400), 2
union all select 'seat cap pro=20 basic=5',
       (public.team_seat_calc('pro',0,0,0)->>'seats')::int=20 and (public.team_seat_calc('basic',0,0,0)->>'seats')::int=5, 3
union all select 'booking_links entitlement 1/3/20/null',
       (select count(*) from public.chat_phase_entitlements where feature='booking_links') >= 4
       and (select limit_value from public.chat_phase_entitlements where plan='basic' and feature='booking_links')=1
       and (select limit_value from public.chat_phase_entitlements where plan='pro' and feature='booking_links')=3
       and (select limit_value from public.chat_phase_entitlements where plan='business' and feature='booking_links')=20
       and (select limit_value from public.chat_phase_entitlements where plan='business_pro' and feature='booking_links') is null, 4
union all select 'unique(user_id) hata, cap trigger laga',
       to_regclass('public.booking_pages_user_uq') is null
       and exists (select 1 from pg_trigger where tgname='booking_pages_cap_trg' and not tgisinternal), 5
union all select 'device cap 2/4 already real',
       (select limit_value from public.chat_phase_entitlements where plan='basic' and feature='device_vault')=2
       and (select limit_value from public.chat_phase_entitlements where plan='pro' and feature='device_vault')=4, 6

) q order by n;
