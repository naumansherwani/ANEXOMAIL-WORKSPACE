
-- E77 proof (sandbox, sab rollback): overlap / back-to-back / declined / cancelled / doosra org / titles leak nahi.
begin;
do $$
declare org1 uuid := gen_random_uuid(); org2 uuid := gen_random_uuid();
  ev uuid := gen_random_uuid(); tok uuid := gen_random_uuid(); r jsonb; t0 timestamptz := date_trunc('hour', now()) + interval '2 days';
  e2 uuid := gen_random_uuid(); e3 uuid := gen_random_uuid(); e4 uuid := gen_random_uuid(); e5 uuid := gen_random_uuid(); e6 uuid := gen_random_uuid();
begin
  insert into public.calendar_events (id, org_id, title, starts_at, ends_at) values (ev, org1, 'Target', t0, t0 + interval '1 hour');
  insert into public.calendar_attendees (event_id, address, rsvp_token) values (ev, 'Guest@X.com', tok);
  insert into public.calendar_events (id, org_id, title, starts_at, ends_at) values (e2, org1, 'SECRET TITLE', t0 + interval '30 min', t0 + interval '90 min');
  insert into public.calendar_attendees (event_id, address) values (e2, 'guest@x.com');
  insert into public.calendar_events (id, org_id, title, starts_at, ends_at) values (e3, org1, 'b2b', t0 + interval '1 hour', t0 + interval '2 hours');
  insert into public.calendar_attendees (event_id, address) values (e3, 'guest@x.com');
  insert into public.calendar_events (id, org_id, title, starts_at, ends_at) values (e4, org1, 'declined', t0, t0 + interval '1 hour');
  insert into public.calendar_attendees (event_id, address, response) values (e4, 'guest@x.com', 'declined');
  insert into public.calendar_events (id, org_id, title, starts_at, ends_at, cancelled_at) values (e5, org1, 'cancelled', t0, t0 + interval '1 hour', now());
  insert into public.calendar_attendees (event_id, address) values (e5, 'guest@x.com');
  insert into public.calendar_events (id, org_id, title, starts_at, ends_at) values (e6, org2, 'other org', t0, t0 + interval '1 hour');
  insert into public.calendar_attendees (event_id, address) values (e6, 'guest@x.com');
  r := public.calendar_rsvp_conflicts(tok);
  assert (r ->> 'count')::int = 1, 'sirf ek asli conflict: ' || r::text;
  assert jsonb_array_length(r -> 'overlaps') = 1, 'overlaps len';
  assert r::text not like '%SECRET%' and r::text not like '%title%', 'title leak';
  update public.calendar_events set cancelled_at = now() where id = ev;
  assert (public.calendar_rsvp_conflicts(tok) ->> 'count')::int = 0, 'cancelled target';
  raise notice 'E77 proof ALL OK';
end $$;
rollback;
