-- CHECK E62 — sirf padhta hai (koi write nahi). Har row ok = true. (Asli member/guest/OOO behaviour ka saboot: proofs/E62_proof.sql, test DB par.)
select item, ok from (
  select 'E62 functions maujood' as item,
         to_regprocedure('public.calendar_team_zone_ok(text)') is not null
         and to_regprocedure('public.calendar_team_context(uuid,uuid,text[])') is not null as ok, 1 as o
  union all select 'E62 context: invoker + STABLE + parallel safe + search_path pinned',
         (select not p.prosecdef and p.provolatile = 's' and p.proparallel = 's' and coalesce(p.proconfig::text, '') like '%search_path%'
            from pg_proc p where p.oid = 'public.calendar_team_context(uuid,uuid,text[])'::regprocedure), 2
  union all select 'E62 execute: sirf service_role (anon/authenticated/PUBLIC nahi)',
         has_function_privilege('service_role', 'public.calendar_team_context(uuid,uuid,text[])', 'execute')
         and not has_function_privilege('anon', 'public.calendar_team_context(uuid,uuid,text[])', 'execute')
         and not has_function_privilege('authenticated', 'public.calendar_team_context(uuid,uuid,text[])', 'execute')
         and not exists (select 1 from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
                          where p.oid = 'public.calendar_team_context(uuid,uuid,text[])'::regprocedure and a.grantee = 0), 3
  union all select 'E62 zone shape: Asia/Karachi + Etc/GMT+5 ok; ../x, khali, NULL, 65 harf rad',
         public.calendar_team_zone_ok('Asia/Karachi') and public.calendar_team_zone_ok('Etc/GMT+5')
         and not public.calendar_team_zone_ok('../x') and not public.calendar_team_zone_ok('')
         and not public.calendar_team_zone_ok(null) and not public.calendar_team_zone_ok(repeat('a', 65)), 4
  union all select 'E62 anjaan viewer / NULL -> forbidden (kuch leak nahi)',
         public.calendar_team_context(gen_random_uuid(), gen_random_uuid(), array['a@b.cc']) = '{"error":"forbidden"}'::jsonb
         and public.calendar_team_context(null, null, array['a@b.cc']) ->> 'error' = 'forbidden', 5
  union all select 'E62 index org_members(org_id, lower(email)) (org_members na ho to n/a)',
         to_regclass('public.org_members_org_email_lc_idx') is not null or to_regclass('public.org_members') is null, 6
  union all select 'E62 attendee lookup index (lower(address), event_id) maujood',
         exists (select 1 from pg_indexes where schemaname = 'public' and tablename = 'calendar_attendees' and indexdef ilike '%lower(address)%event_id%'), 7
) t order by o;
