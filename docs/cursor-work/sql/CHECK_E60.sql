-- CHECK E60 — sirf padhta hai (koi write nahi). Har row ok = true.
select item, ok from (
  select 'E60 attendee columns rsvp_via + rsvp_sequence' as item,
         (select count(*) from information_schema.columns where table_schema = 'public' and table_name = 'calendar_attendees' and column_name in ('rsvp_via', 'rsvp_sequence')) = 2 as ok, 1 as o
  union all select 'E60 calendar_imip_log: RLS ON + anon/authenticated ko koi hak nahi',
         to_regclass('public.calendar_imip_log') is not null
         and (select relrowsecurity from pg_class where oid = 'public.calendar_imip_log'::regclass)
         and not exists (select 1 from information_schema.role_table_grants where table_schema = 'public' and table_name = 'calendar_imip_log' and grantee in ('anon', 'authenticated', 'PUBLIC')), 2
  union all select 'E60 calendar_imip_apply sirf service_role ke liye',
         to_regprocedure('public.calendar_imip_apply(text,text,text,integer,timestamptz,text,text,text)') is not null
         and has_function_privilege('service_role', 'public.calendar_imip_apply(text,text,text,integer,timestamptz,text,text,text)', 'execute')
         and not has_function_privilege('anon', 'public.calendar_imip_apply(text,text,text,integer,timestamptz,text,text,text)', 'execute')
         and not has_function_privilege('authenticated', 'public.calendar_imip_apply(text,text,text,integer,timestamptz,text,text,text)', 'execute'), 3
  union all select 'E60 message_id unique index (redelivery safe)',
         to_regclass('public.calendar_imip_log_msg_uq') is not null, 4
  union all select 'E60 constraints VALIDATED',
         not exists (select 1 from pg_constraint where conname in ('calendar_attendees_rsvp_via_ck', 'calendar_imip_log_outcome_ck') and not convalidated)
         and (select count(*) from pg_constraint where conname in ('calendar_attendees_rsvp_via_ck', 'calendar_imip_log_outcome_ck')) = 2, 5
  union all select 'E60 trigger rsvp_via=link maujood',
         exists (select 1 from pg_trigger where tgname = 'calendar_rsvp_mark_link_trg' and not tgisinternal), 6
  union all select 'E60 ghalat input: bad_input (kuch nahi likhta)',
         public.calendar_imip_apply('x', 'a@b.cc', 'ACCEPTED', 0, null, 'check-e60', null, null) ->> 'outcome' = 'bad_input', 7
) t order by o;
