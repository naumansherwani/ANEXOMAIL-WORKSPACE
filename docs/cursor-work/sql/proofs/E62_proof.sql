-- E62 behaviour proof (sandbox/test DB ONLY — real rows likhta hai aur ROLLBACK karta hai). Server par nahi chalti (sql-run.sh ka hissa nahi).
-- Chalao: psql -v ON_ERROR_STOP=1 -f E62_proof.sql   (org_members + awam_ui_pref + calendar_* maujood hon)
begin;
create temp table r (ord int, item text, ok boolean) on commit drop;
do $$
declare
  org uuid := gen_random_uuid(); me uuid := gen_random_uuid(); bob uuid := gen_random_uuid(); gone uuid := gen_random_uuid(); stranger uuid := gen_random_uuid(); legacy uuid := gen_random_uuid();
  ev uuid := gen_random_uuid(); res jsonb; m jsonb;
begin
  -- test DB mein awam_ui_pref.user_id ka FK auth.users par hai: stub users (rollback ke saath jaate hain)
  insert into auth.users (id) select u from unnest(array[me, bob, gone]) u on conflict do nothing;
  insert into auth.users (id, email) values (legacy, 'Legacy@X.test') on conflict do nothing;
  insert into public.org_members (org_id, user_id, role, status, email) values
    (org, me, 'owner', 'active', 'me@x.test'), (org, bob, 'member', 'active', 'Bob@X.test'), (org, gone, 'member', 'revoked', 'gone@x.test'), (org, legacy, 'member', 'active', null);
  insert into public.awam_ui_pref (user_id, extra) values
    (bob, jsonb_build_object('work_hours', jsonb_build_object('tz','Asia/Tokyo','days', (select jsonb_agg(jsonb_build_object('on', i < 5, 'start','09:00','end','18:00')) from generate_series(0,6) i)),
                             'ooo', jsonb_build_array(jsonb_build_object('from', to_char(current_date + 1,'YYYY-MM-DD'), 'to', to_char(current_date + 2,'YYYY-MM-DD'), 'note', 'SECRET-medical'),
                                                      jsonb_build_object('from','2020-01-01','to','2020-01-02'))));
  insert into public.awam_ui_pref (user_id, extra) values (gone, '{"clocks":["Asia/Tokyo"]}');
  insert into public.calendar_events (id, org_id, title, starts_at, ends_at) values (ev, org, 'proof', now(), now() + interval '1 hour');
  insert into public.calendar_attendees (event_id, org_id, address, display_name, timezone) values
    (ev, org, 'guest@y.test', 'Gina', 'Europe/Zurich'), (ev, org, 'badtz@y.test', null, '../etc/passwd');

  res := public.calendar_team_context(org, me, array['BOB@x.test ', 'bob@x.test', 'guest@y.test', 'badtz@y.test', 'gone@x.test', 'not-an-email', null, 'nobody@z.test']);
  insert into r values (1, 'viewer member: members list (dup+junk collapsed -> 5)', jsonb_array_length(res -> 'members') = 5 and (res ->> 'truncated') = 'false');
  m := res -> 'members' -> 0;
  insert into r values (2, 'bob = member, tz Asia/Tokyo, known, 7 days', m ->> 'kind' = 'member' and m ->> 'tz' = 'Asia/Tokyo' and (m ->> 'known')::boolean and jsonb_array_length(m -> 'work_hours' -> 'days') = 7);
  insert into r values (3, 'OOO: future kept, 2020 dropped, NOTE never leaks', jsonb_array_length(m -> 'ooo') = 1 and res::text not like '%SECRET%' and not (m -> 'ooo' -> 0 ? 'note'));
  m := res -> 'members' -> 1;
  insert into r values (4, 'guest: kind guest, tz from last meeting, not known, name', m ->> 'kind' = 'guest' and m ->> 'tz' = 'Europe/Zurich' and not (m ->> 'known')::boolean and m ->> 'name' = 'Gina' and m -> 'work_hours' = 'null'::jsonb);
  m := res -> 'members' -> 2;
  insert into r values (5, 'bad tz (../etc) never returned', m ->> 'tz' is null);
  m := res -> 'members' -> 3;
  insert into r values (6, 'revoked member treated as guest (no schedule leak)', m ->> 'kind' = 'guest' and m -> 'work_hours' = 'null'::jsonb and m ->> 'tz' is null);
  insert into r values (7, 'stranger viewer -> forbidden', public.calendar_team_context(org, stranger, array['bob@x.test']) = '{"error":"forbidden"}'::jsonb);
  insert into r values (8, 'revoked viewer -> forbidden', public.calendar_team_context(org, gone, array['bob@x.test']) = '{"error":"forbidden"}'::jsonb);
  insert into r values (9, 'other org cannot read bob', public.calendar_team_context(gen_random_uuid(), me, array['bob@x.test']) = '{"error":"forbidden"}'::jsonb);
  insert into r values (10, 'null org / null viewer -> forbidden', public.calendar_team_context(null, me, array['a@b.c']) ->> 'error' = 'forbidden' and public.calendar_team_context(org, null, array['a@b.c']) ->> 'error' = 'forbidden');
  res := public.calendar_team_context(org, me, (select array_agg('u' || i || '@z.test') from generate_series(1, 20) i));
  insert into r values (11, '20 addresses -> 12 + truncated', jsonb_array_length(res -> 'members') = 12 and (res ->> 'truncated') = 'true');
  insert into r values (12, 'empty / null list -> empty members', jsonb_array_length(public.calendar_team_context(org, me, '{}') -> 'members') = 0 and jsonb_array_length(public.calendar_team_context(org, me, null) -> 'members') = 0);
  res := public.calendar_team_context(org, me, array['legacy@x.test']);
  insert into r values (14, 'member with empty org_members.email found via auth.users', res -> 'members' -> 0 ->> 'kind' = 'member');
  res := public.calendar_team_context(org, me, array['legacy@x.test']);
  insert into r values (15, 'other org: viewer is not a member there -> forbidden', public.calendar_team_context(gen_random_uuid(), me, array['legacy@x.test']) ->> 'error' = 'forbidden');
  -- LIVE BUG 22 Oct: service_role ko auth schema ka haq na ho to function girta tha. Bina haq wale role se dobara (rollback ke saath role bhi jata hai).
  create role svc_proof nologin;
  grant usage on schema public to svc_proof;
  grant select on public.org_members, public.awam_ui_pref, public.calendar_attendees, public.calendar_events to svc_proof;
  grant execute on function public.calendar_team_context(uuid, uuid, text[]), public.calendar_team_zone_ok(text) to svc_proof;
  revoke all on auth.users from svc_proof;
  revoke usage on schema auth from svc_proof;
  set local role svc_proof;
  res := public.calendar_team_context(org, me, array['bob@x.test', 'unknown-guest@y.test']);
  reset role;
  insert into r values (16, 'role WITHOUT auth.users access: no crash, member via org_members.email, guest stays guest',
    jsonb_array_length(res -> 'members') = 2 and res -> 'members' -> 0 ->> 'kind' = 'member' and res -> 'members' -> 1 ->> 'kind' = 'guest');
  insert into r values (13, 'zone shape: ok/bad', public.calendar_team_zone_ok('Asia/Karachi') and public.calendar_team_zone_ok('Etc/GMT+5') and not public.calendar_team_zone_ok('../x') and not public.calendar_team_zone_ok('') and not public.calendar_team_zone_ok(null) and not public.calendar_team_zone_ok(repeat('a',65)));
end $$;
select ord, item, ok from r order by ord;
rollback;
