
-- CHECK E56 — sirf padhta hai. Har row ok = true.
select item, ok from (
  select 'E56 5 naye columns' as item,
         (select count(*) from information_schema.columns where table_schema='public' and table_name='calendar_events'
            and column_name in ('rrule','exdates','series_id','recurrence_id','tz_offset_min')) = 5 as ok, 1 as o
  union all select 'E56 calendar_busy_masters maujood', to_regprocedure('public.calendar_busy_masters(uuid,text[],timestamptz)') is not null, 2
  union all select 'E56 calendar_busy maujood', to_regprocedure('public.calendar_busy(uuid,text[],timestamptz,timestamptz)') is not null, 3
  union all select 'E56 band: anon/authenticated nahi chala sakte',
         not (has_function_privilege('anon','public.calendar_busy_masters(uuid,text[],timestamptz)','execute')
              or has_function_privilege('authenticated','public.calendar_busy_masters(uuid,text[],timestamptz)','execute')), 4
  union all select 'E56 service_role chala sakta hai', has_function_privilege('service_role','public.calendar_busy_masters(uuid,text[],timestamptz)','execute'), 5
  union all select 'E56 exception unique index', to_regclass('public.calendar_events_exception_uq') is not null, 6
) t order by o;
