-- E82 proof: rollback-only. Chalane par har check 'PASS' ya exception.
begin;
do $$
declare o uuid := gen_random_uuid(); adm uuid := gen_random_uuid(); mem uuid := gen_random_uuid(); oth uuid := gen_random_uuid();
 e1 uuid := gen_random_uuid(); e2 uuid := gen_random_uuid(); r jsonb; rid uuid; t0 timestamptz := '2030-01-01 10:00+00'; n int;
begin
  insert into public.org_members(org_id,user_id,status,role,email) values (o,adm,'active','admin','a@x.com'),(o,mem,'active','member','m@x.com'),(o,oth,'active','member','o@x.com');
  r := public.calendar_room_create(o,mem,'Board',null,10,'3rd floor'); assert r->>'error'='forbidden','member must not create';
  r := public.calendar_room_create(o,adm,'Board','room',2,'3rd floor'); assert r->>'id' is not null,'create'; rid := (r->>'id')::uuid;
  assert (public.calendar_room_create(o,adm,' board ','room',2,null))->>'error'='name_taken','dup name';
  assert (public.calendar_room_create(o,adm,'X','bogus',null,null))->>'error'='bad_kind','kind';
  insert into public.calendar_events(id,org_id,starts_at,ends_at,organiser,created_by,title) values (e1,o,t0,t0+interval '1 hour','m@x.com',mem,'secret title'),(e2,o,t0+interval '30 min',t0+interval '90 min','o@x.com',oth,'other');
  assert (public.calendar_room_book(o,oth,e1,rid))->>'error'='not_organiser','not organiser';
  r := public.calendar_room_book(o,mem,e1,rid); assert (r->>'booked')::bool,'book'; assert (r->>'over_capacity')::bool=false,'cap';
  assert (public.calendar_room_book(o,oth,e2,rid))->>'error'='room_busy','overlap must be busy';
  assert (public.calendar_room_state(o,t0,t0+interval '1 hour'))->0->>'busy'='true','state busy';
  assert (public.calendar_room_state(o,t0,t0+interval '1 hour',e1))->0->>'busy'='false','exclude self';
  assert (public.calendar_room_state(o,t0,t0+interval '1 hour',e1))->0->>'mine'='true','mine flag';
  assert (public.calendar_room_state(o,t0,t0+interval '1 hour',e2))->0->>'mine'='false','not mine';
  assert (public.calendar_room_state(o,t0+interval '1 hour',t0+interval '2 hour'))->0->>'busy'='false','adjacent free';
  assert position('secret' in (public.calendar_room_schedule(o,rid,t0-interval '1 day',t0+interval '1 day'))::text)=0,'privacy: no title';
  select count(*) into n from public.calendar_attendees where event_id=e1; assert n=1,'one attendee';
  perform public.calendar_room_book(o,mem,e1,rid); select count(*) into n from public.calendar_attendees where event_id=e1; assert n=1,'idempotent';
  assert (public.calendar_room_release(o,oth,e1,rid))->>'error'='not_organiser','release forbidden';
  assert (public.calendar_room_release(o,mem,e1,rid))->>'released'='1','release';
  assert (select location from public.calendar_events where id=e1) is null,'release clears auto location';
  assert (public.calendar_room_book(o,oth,e2,rid))->>'booked'='true','free after release';
  perform public.calendar_room_archive(o,adm,rid); assert (public.calendar_room_book(o,mem,e1,rid))->>'error'='no_room','archived not bookable';
  raise notice 'E82 PROOF: ALL PASS';
end $$;
rollback;
