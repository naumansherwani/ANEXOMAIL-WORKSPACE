-- E64 behaviour proof (sandbox/test DB ONLY — real rows likhta hai aur ROLLBACK karta hai). Server par nahi chalti.
-- Chalao: psql -v ON_ERROR_STOP=1 -f E64_proof.sql   (E63 + E64 laga ho; org_members maujood — /tmp/e62_stubs.sql jaisa)
begin;
create temp table r (ord int, item text, ok boolean) on commit drop;
create table public.work_notes (id uuid primary key default gen_random_uuid(), org_id uuid not null, body text not null default '', thread_id uuid, event_id uuid);
do $$
declare
  org uuid := gen_random_uuid(); other uuid := gen_random_uuid();
  me uuid := gen_random_uuid(); gone uuid := gen_random_uuid(); stranger uuid := gen_random_uuid();
  e1 uuid := gen_random_uuid(); e2 uuid := gen_random_uuid(); e3 uuid := gen_random_uuid(); e4 uuid := gen_random_uuid(); e5 uuid := gen_random_uuid(); eo uuid := gen_random_uuid();
  res jsonb; i int;
begin
  insert into auth.users (id) select u from unnest(array[me, gone, stranger]) u on conflict do nothing;
  insert into public.org_members (org_id, user_id, role, status, email) values
    (org, me, 'owner', 'active', 'me@x.test'), (org, gone, 'member', 'revoked', 'gone@x.test'), (other, stranger, 'owner', 'active', 'str@y.test');

  insert into public.calendar_events (id, org_id, title, agenda, location, goal, starts_at, ends_at, organiser) values
    (e1, org, 'Contract review with Acme', 'We will go through the Contract clauses and sign off the pricing annex.', 'Zurich office', 'Contract signed', '2006-03-14 10:00+00', '2006-03-14 11:00+00', 'me@x.test'),
    (e2, org, 'Weekly sync', 'Roadmap and hiring.', null, null, '2019-07-01 09:00+00', '2019-07-01 09:30+00', 'me@x.test'),
    (e3, org, 'Budget 100% planning', 'Underscore_test and percent % sign.', 'Karachi', null, '2024-01-10 12:00+00', '2024-01-10 13:00+00', 'me@x.test'),
    (e4, org, 'Cancelled workshop', 'workshop agenda', null, null, '2025-05-05 08:00+00', '2025-05-05 09:00+00', 'me@x.test'),
    (eo, other, 'Contract secret of another company', 'must never leak', null, null, '2020-01-01 10:00+00', '2020-01-01 11:00+00', 'str@y.test');
  update public.calendar_events set cancelled_at = now() where id = e4;
  insert into public.calendar_events (id, org_id, title, starts_at, ends_at, organiser, rrule) values (e5, org, 'Daily standup', '2022-02-01 08:00+00', '2022-02-01 08:15+00', 'me@x.test', 'FREQ=DAILY');
  insert into public.calendar_attendees (event_id, org_id, address, display_name) values
    (e1, org, 'gina@acme.test', 'Gina Keller'), (e1, org, 'me@x.test', 'Me'), (e2, org, 'bob@y.test', 'Bob'), (eo, other, 'zed@z.test', 'Zed');
  insert into public.work_notes (org_id, event_id, body) values (org, e2, 'Decided to postpone the migration to Q3'), (other, eo, 'Contract details of other org');

  res := public.calendar_history(org, stranger, 'contract', null, null, null);
  insert into r values (1, 'dusre org ka member -> forbidden', res ->> 'error' = 'forbidden');
  res := public.calendar_history(org, gone, 'contract', null, null, null);
  insert into r values (2, 'revoked member -> forbidden', res ->> 'error' = 'forbidden');
  res := public.calendar_history(org, null, 'contract', null, null, null);
  insert into r values (3, 'viewer NULL -> forbidden', res ->> 'error' = 'forbidden');
  res := public.calendar_history(org, me, null, null, null, null);
  insert into r values (4, 'bilkul khaali sawal -> empty_query (poori history nahi)', res ->> 'error' = 'empty_query');
  res := public.calendar_history(org, me, 'x', null, null, null);
  insert into r values (5, 'ek harf ka matn khaali maana jata hai -> empty_query', res ->> 'error' = 'empty_query');
  res := public.calendar_history(org, me, 'abc', '2024-01-01', '2020-01-01', null);
  insert into r values (6, 'ulti range -> bad_range', res ->> 'error' = 'bad_range');

  res := public.calendar_history(org, me, 'contract', null, null, null);
  insert into r values (7, 'matn "contract": sirf apne org ki 1 meeting (2006, 20 saal purani), dusre org ki nahi',
    jsonb_array_length(res -> 'events') = 1 and res -> 'events' -> 0 ->> 'id' = e1::text and res::text not like '%another company%');
  insert into r values (8, 'matched = title+agenda+aim; snippet mein lafz marker ke saath',
    (res -> 'events' -> 0 -> 'matched') @> '["title","agenda","aim"]'::jsonb and (res -> 'events' -> 0 ->> 'snippet') like '%' || chr(1) || '%' || chr(2) || '%');
  res := public.calendar_history(org, me, 'CONTR', null, null, null);
  insert into r values (9, 'aadha, bade harf mein "CONTR" bhi mil jata hai (ILIKE)', jsonb_array_length(res -> 'events') = 1);
  res := public.calendar_history(org, me, 'zurich', null, null, null);
  insert into r values (10, 'location mein milne par matched = location', (res -> 'events' -> 0 -> 'matched') ? 'location');
  res := public.calendar_history(org, me, 'Gina', null, null, null);
  insert into r values (11, 'guest ka naam: matched = guest', jsonb_array_length(res -> 'events') = 1 and (res -> 'events' -> 0 -> 'matched') ? 'guest');
  res := public.calendar_history(org, me, 'migration', null, null, null);
  insert into r values (12, 'event note ke andar ka lafz: matched = notes (event e2)', res -> 'events' -> 0 ->> 'id' = e2::text and (res -> 'events' -> 0 -> 'matched') ? 'notes');

  res := public.calendar_history(org, me, '0%', null, null, null);
  insert into r values (13, 'matn "0%": % harfi matlab mein — sirf e3 (100%); "%%" sab kuch NAHI lata',
    jsonb_array_length(res -> 'events') = 1 and res -> 'events' -> 0 ->> 'id' = e3::text
    and jsonb_array_length(public.calendar_history(org, me, '%%', null, null, null) -> 'events') = 0);
  res := public.calendar_history(org, me, 'underscore_test', null, null, null);
  insert into r values (14, 'underscore (LIKE wildcard) harfi matlab mein', jsonb_array_length(res -> 'events') = 1);
  res := public.calendar_history(org, me, $s$'; drop table public.calendar_events; --$s$, null, null, null);
  insert into r values (15, 'SQL injection jaisa matn bas matn hai (table salamat)', res ? 'events' and to_regclass('public.calendar_events') is not null);
  res := public.calendar_history(org, me, '"weekly sync" -hiring', null, null, null);
  insert into r values (16, 'websearch quotes/minus crash nahi karte', res ? 'events');

  res := public.calendar_history(org, me, null, '2022-01-01', '2025-01-01', null);
  insert into r values (17, 'sirf tareekh range (2022..2025): e5 + e3, naye pehle', jsonb_array_length(res -> 'events') = 2 and res -> 'events' -> 0 ->> 'id' = e3::text);
  res := public.calendar_history(org, me, null, '2000-01-01', '2030-01-01', null, 'oldest');
  insert into r values (18, 'oldest order: sab se purani (2006) pehle', res -> 'events' -> 0 ->> 'id' = e1::text);
  res := public.calendar_history(org, me, null, null, null, 'bob@y.test');
  insert into r values (19, 'banda (email): sirf us ki meeting e2', jsonb_array_length(res -> 'events') = 1 and res -> 'events' -> 0 ->> 'id' = e2::text);
  res := public.calendar_history(org, me, null, null, null, 'keller');
  insert into r values (20, 'banda (naam ka hissa): e1', res -> 'events' -> 0 ->> 'id' = e1::text);
  res := public.calendar_history(org, me, 'contract', '2000-01-01', '2010-01-01', 'gina');
  insert into r values (21, 'matn + range + banda saath', jsonb_array_length(res -> 'events') = 1);
  res := public.calendar_history(org, me, 'contract', '2010-01-01', '2030-01-01', null);
  insert into r values (22, 'range bahar ho to khaali', jsonb_array_length(res -> 'events') = 0 and not (res ->> 'has_more')::boolean);

  res := public.calendar_history(org, me, 'workshop', null, null, null);
  insert into r values (23, 'cancelled meeting aati hai, status = cancelled', res -> 'events' -> 0 ->> 'status' = 'cancelled');
  res := public.calendar_history(org, me, 'standup', null, null, null);
  insert into r values (24, 'dohrane wali meeting: recurring = true, EK hi row', (res -> 'events' -> 0 ->> 'recurring')::boolean and jsonb_array_length(res -> 'events') = 1);
  res := public.calendar_history(org, me, 'contract', null, null, null, 'relevance');
  insert into r values (25, 'relevance order chalta hai', res ->> 'order' = 'relevance' and jsonb_array_length(res -> 'events') = 1);
  res := public.calendar_history(org, me, null, '2000-01-01', '2030-01-01', null, 'bogus');
  insert into r values (26, 'anjaan order -> recent', res ->> 'order' = 'recent');

  -- pagination: 60 meetings
  for i in 1..60 loop
    insert into public.calendar_events (org_id, title, starts_at, ends_at, organiser) values (org, 'Bulk meeting ' || i, '2015-01-01 00:00+00'::timestamptz + (i || ' days')::interval, '2015-01-01 01:00+00'::timestamptz + (i || ' days')::interval, 'me@x.test');
  end loop;
  res := public.calendar_history(org, me, 'bulk meeting', null, null, null, 'recent', 20, 0);
  insert into r values (27, 'page 1: 20 row, has_more = true', jsonb_array_length(res -> 'events') = 20 and (res ->> 'has_more')::boolean);
  res := public.calendar_history(org, me, 'bulk meeting', null, null, null, 'recent', 20, 40);
  insert into r values (28, 'aakhri page: 20 row, has_more = false', jsonb_array_length(res -> 'events') = 20 and not (res ->> 'has_more')::boolean);
  res := public.calendar_history(org, me, 'bulk meeting', null, null, null, 'recent', 9999, 0);
  insert into r values (29, 'limit 50 par clamp', (res ->> 'limit')::int = 50 and jsonb_array_length(res -> 'events') = 50);
  res := public.calendar_history(org, me, 'bulk meeting', null, null, null, 'recent', 5, 999999);
  insert into r values (30, 'offset 1000 par clamp (crash nahi)', (res ->> 'offset')::int = 1000);
  res := public.calendar_history(org, me, repeat('a', 5000), null, null, null);
  insert into r values (31, 'bohat lamba matn 200 par kat jata hai', char_length(res ->> 'q') = 200);
  res := public.calendar_history(org, me, E'con\x01tract', null, null, null);
  insert into r values (32, 'control character space ban jata hai (crash nahi)', res ? 'events');
end $$;
select ord, item, ok from r order by ord;
rollback;
