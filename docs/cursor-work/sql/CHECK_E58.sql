-- CHECK E58 — sirf padhta hai. Har row ok = true.
select item, ok from (
  select 'E58 calendar_events.calendar_key + remind_min' as item,
         (select count(*) from information_schema.columns where table_schema='public' and table_name='calendar_events'
            and column_name in ('calendar_key','remind_min')) = 2 as ok, 1 as o
  union all select 'E58 calendar_key/remind_min check constraints',
         (select count(*) from pg_constraint where conname in ('calendar_events_calendar_key_ck','calendar_events_remind_min_ck')) = 2, 2
  union all select 'E58 calendar_remind_ok function', to_regprocedure('public.calendar_remind_ok(integer[])') is not null, 3
  union all select 'E58 awam_ui_pref.extra limit 16 KB',
         exists (select 1 from pg_constraint where conname = 'awam_ui_pref_extra_ck' and pg_get_constraintdef(oid) like '%16384%'), 4
) t order by o;
