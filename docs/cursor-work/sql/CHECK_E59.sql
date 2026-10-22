-- CHECK E59 — sirf padhta hai (koi write nahi). Har row ok = true.
select item, ok from (
  select 'E59 tables booking_pages + bookings' as item,
         to_regclass('public.booking_pages') is not null and to_regclass('public.bookings') is not null as ok, 1 as o
  union all select 'E59 RLS ON dono tables par',
         (select count(*) from pg_class where oid in ('public.booking_pages'::regclass, 'public.bookings'::regclass) and relrowsecurity) = 2, 2
  union all select 'E59 anon/authenticated ko koi hak nahi (tables)',
         not exists (select 1 from information_schema.role_table_grants where table_schema = 'public' and table_name in ('booking_pages', 'bookings') and grantee in ('anon', 'authenticated', 'PUBLIC')), 3
  union all select 'E59 6 functions sirf service_role ke liye (anon/authenticated/public execute nahi)',
         (select count(*) from pg_proc where proname in ('booking_book', 'booking_context', 'booking_manage', 'booking_cancel', 'booking_reschedule', 'booking_slot_problem')) = 6
         and not exists (select 1 from pg_proc p where p.proname in ('booking_book', 'booking_context', 'booking_manage', 'booking_cancel', 'booking_reschedule', 'booking_slot_problem')
                           and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute'))), 4
  union all select 'E59 EXCLUDE deewar (bookings_no_overlap) — double booking DB mein namumkin',
         exists (select 1 from pg_constraint where conname = 'bookings_no_overlap' and contype = 'x'), 5
  union all select 'E59 sab constraints VALIDATED',
         not exists (select 1 from pg_constraint where conrelid in ('public.booking_pages'::regclass, 'public.bookings'::regclass) and not convalidated), 6
  union all select 'E59 indexes (handle unique, token unique, slot index)',
         to_regclass('public.booking_pages_handle_uq') is not null and to_regclass('public.bookings_token_uq') is not null and to_regclass('public.bookings_page_time_idx') is not null, 7
  union all select 'E59 handle validator: ali-khan ok; ab / admin / a--b / Capital rad',
         public.booking_handle_ok('ali-khan') and not public.booking_handle_ok('ab') and not public.booking_handle_ok('admin')
         and not public.booking_handle_ok('a--b') and not public.booking_handle_ok('Ali'), 8
  union all select 'E59 durations/tz validator: {15,30} ok; {} / {4} / {30,30} / {600} rad',
         public.booking_durations_ok(array[15, 30]) and not public.booking_durations_ok('{}') and not public.booking_durations_ok(array[4])
         and not public.booking_durations_ok(array[30, 30]) and not public.booking_durations_ok(array[600]) and public.booking_tz_ok('Asia/Karachi') and not public.booking_tz_ok('x y'), 9
  union all select 'E59 anjaan handle / anjaan token: found=false',
         (public.booking_context('no-such-handle-xyz') ->> 'found')::boolean is false and (public.booking_manage(gen_random_uuid()) ->> 'found')::boolean is false, 10
  union all select 'E59 awam_ui_pref (E57/E58) maujood',
         to_regclass('public.awam_ui_pref') is not null and to_regproc('public.awam_ui_extra_ok') is not null, 11
) t order by o;
