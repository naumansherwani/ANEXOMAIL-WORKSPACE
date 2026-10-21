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
 union all select 'E58 index calendar_events_remind_idx (ya cancelled_at/org_id column nahi to n/a)',
         to_regclass('public.calendar_events_remind_idx') is not null
         or not exists (select 1 from information_schema.columns where table_schema='public' and table_name='calendar_events' and column_name='cancelled_at'), 5
  union all select 'E58 constraints VALIDATED (convalidated)',
         not exists (select 1 from pg_constraint where conname in ('calendar_events_calendar_key_ck','calendar_events_remind_min_ck','awam_ui_pref_extra_ck') and not convalidated), 6
  union all select 'E58 awam_ui_extra_ok accepts good shape',
         public.awam_ui_extra_ok('{"calendars":[{"id":"main","name":"Work","color":"#3b82f6"}],"ooo":[{"from":"2026-10-30","to":"2026-11-02","note":"Eid"}]}'::jsonb), 7
  union all select 'E58 awam_ui_extra_ok rejects: unknown key / dup id / bad colour / reversed ooo / 6-day week',
         not public.awam_ui_extra_ok('{"x":1}'::jsonb)
         and not public.awam_ui_extra_ok('{"calendars":[{"id":"a","name":"A","color":"#ffffff"},{"id":"a","name":"B","color":"#ffffff"}]}'::jsonb)
         and not public.awam_ui_extra_ok('{"calendars":[{"id":"a","name":"A","color":"#fff"}]}'::jsonb)
         and not public.awam_ui_extra_ok('{"ooo":[{"from":"2026-11-02","to":"2026-10-30"}]}'::jsonb)
         and not public.awam_ui_extra_ok('{"work_hours":{"days":[{"on":true},{"on":true},{"on":true},{"on":true},{"on":true},{"on":false}]}}'::jsonb), 8
  union all select 'E58 calendar_remind_ok: 10 ok, -1 / 99999 / 6 values rejected',
         public.calendar_remind_ok(array[10]) and not public.calendar_remind_ok(array[-1]) and not public.calendar_remind_ok(array[99999])
         and not public.calendar_remind_ok(array[1,2,3,4,5,6]), 9
) t order by o;
