
-- CHECK E64 — sirf padhta hai (koi write nahi). Har row ok = true. Behaviour ka asli saboot proofs/E64_proof.sql (sandbox, rollback).
select item, ok from (
  select 'E64 helper functions maujood: calendar_search_text / _doc / calendar_guest_text / calendar_org_member / calendar_history' as item,
         to_regprocedure('public.calendar_search_text(text,text,text,text)') is not null
         and to_regprocedure('public.calendar_search_doc(text,text,text,text)') is not null
         and to_regprocedure('public.calendar_guest_text(text,text)') is not null
         and to_regprocedure('public.calendar_org_member(uuid,uuid)') is not null
         and to_regprocedure('public.calendar_history(uuid,uuid,text,timestamptz,timestamptz,text,text,integer,integer)') is not null as ok, 1 as o
  union all select 'E64 index-wale functions IMMUTABLE + PARALLEL SAFE + pinned search_path',
         (select count(*) from pg_proc where oid in (to_regprocedure('public.calendar_search_text(text,text,text,text)'), to_regprocedure('public.calendar_search_doc(text,text,text,text)'),
                to_regprocedure('public.calendar_guest_text(text,text)'))
                and provolatile = 'i' and proparallel = 's' and array_to_string(proconfig, ',') like '%search_path=pg_catalog, public%') = 3, 2
  union all select 'E64 calendar_history: STABLE + pinned search_path + statement_timeout 8s',
         exists (select 1 from pg_proc where oid = to_regprocedure('public.calendar_history(uuid,uuid,text,timestamptz,timestamptz,text,text,integer,integer)')
                   and provolatile = 's' and array_to_string(proconfig, ',') like '%search_path=pg_catalog, public%' and array_to_string(proconfig, ',') like '%statement_timeout=8s%'), 3
  union all select 'E64 indexes: events FTS + (org_id, starts_at desc) saari rows',
         to_regclass('public.calendar_events_search_fts_idx') is not null and to_regclass('public.calendar_events_org_start_all_idx') is not null, 4
  union all select 'E64 trigram indexes (events matn + guests) — pg_trgm ho to; na ho to n/a (search dheema par chalta)',
         not exists (select 1 from pg_extension where extname = 'pg_trgm')
         or (to_regclass('public.calendar_events_search_trgm_idx') is not null and to_regclass('public.calendar_attendees_guest_trgm_idx') is not null), 5
  union all select 'E64 work_notes FTS index (table ho to) — event notes mein search',
         to_regclass('public.work_notes') is null or to_regclass('public.work_notes_search_idx') is not null, 6
  union all select 'E64 execute sirf service_role: anon/authenticated nahi',
         has_function_privilege('service_role', 'public.calendar_history(uuid,uuid,text,timestamptz,timestamptz,text,text,integer,integer)', 'execute')
         and not has_function_privilege('anon', 'public.calendar_history(uuid,uuid,text,timestamptz,timestamptz,text,text,integer,integer)', 'execute')
         and not has_function_privilege('authenticated', 'public.calendar_history(uuid,uuid,text,timestamptz,timestamptz,text,text,integer,integer)', 'execute'), 7
  union all select 'E64 deewar: anjaan viewer -> forbidden, khaali sawal member ko empty_query',
         (public.calendar_history(gen_random_uuid(), gen_random_uuid(), 'contract', null, null, null) ->> 'error') = 'forbidden'
         and coalesce((select public.calendar_history(m.org_id, m.user_id, null, null, null, null) ->> 'error'
                         from public.org_members m where coalesce(m.status::text, 'active') <> 'revoked' limit 1) = 'empty_query', true), 8
  union all select 'E64 matn ki definition: lowercase guest text, tsvector bante hain',
         public.calendar_guest_text('Gina@Acme.test', 'Gina Keller') = 'gina@acme.test gina keller'
         and public.calendar_search_doc('Contract review', 'Pricing annex', null, null) @@ websearch_to_tsquery('simple', 'pricing'), 9
  union all select 'E64 LIVE PATH: asli member par 1-din ki range bina error chalti hai (sirf padhta hai)',
         coalesce((select public.calendar_history(m.org_id, m.user_id, 'a', now() - interval '1 day', now(), null) ? 'events'
                     or (public.calendar_history(m.org_id, m.user_id, 'ab', now() - interval '1 day', now(), null) ? 'events')
                     from public.org_members m
                    where coalesce(m.status::text, 'active') <> 'revoked' limit 1), true), 10
) t order by o;
