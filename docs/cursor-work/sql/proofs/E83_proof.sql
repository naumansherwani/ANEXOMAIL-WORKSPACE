-- E83 proof (rollback-only)
begin;
do $$
declare o uuid := gen_random_uuid(); o2 uuid := gen_random_uuid(); adm uuid := gen_random_uuid(); mem uuid := gen_random_uuid();
 e1 uuid := gen_random_uuid(); e2 uuid := gen_random_uuid(); e3 uuid := gen_random_uuid(); r jsonb; rid uuid; addr text; t0 timestamptz := '2031-01-01 10:00+00'; ok boolean;
begin
  insert into public.org_members(org_id,user_id,status,role,email) values (o,adm,'active','admin','a@x.com'),(o,mem,'active','member','m@x.com');
  r := public.calendar_room_create(o,adm,'Hall','room',5,null); rid := (r->>'id')::uuid; addr := r->>'address';
  insert into public.calendar_events(id,org_id,starts_at,ends_at,organiser,created_by,title) values
    (e1,o,t0,t0+interval '1 hour','m@x.com',mem,'a'),(e2,o,t0+interval '30 min',t0+interval '90 min','m@x.com',mem,'b'),(e3,o,t0+interval '3 hour',t0+interval '4 hour','m@x.com',mem,'c');
  perform public.calendar_room_book(o,mem,e1,rid);
  -- 1) haath se room address guest likhna, overlapping waqt par
  begin insert into public.calendar_attendees(event_id,org_id,address) values (e2,o,addr); assert false,'manual insert must fail';
  exception when sqlstate 'AX083' then assert sqlerrm='room_busy','manual: '||sqlerrm; end;
  -- 2) khali waqt par haath se likhna theek
  insert into public.calendar_attendees(event_id,org_id,address) values (e3,o,addr);
  -- 3) booked e3 ko e1 ke upar reschedule karna band
  begin update public.calendar_events set starts_at=t0+interval '10 min', ends_at=t0+interval '50 min' where id=e3; assert false,'reschedule must fail';
  exception when sqlstate 'AX083' then assert sqlerrm='room_busy','resched: '||sqlerrm; end;
  -- 4) khali jagah par reschedule theek
  update public.calendar_events set starts_at=t0+interval '5 hour', ends_at=t0+interval '6 hour' where id=e3;
  -- 5) doosri org ka / banaya hua nahi room address
  begin insert into public.calendar_attendees(event_id,org_id,address) values (e2,o,'room-ffffffffffff@rooms.anexomail.com'); assert false,'unknown room';
  exception when sqlstate 'AX083' then assert sqlerrm='no_room','unknown: '||sqlerrm; end;
  -- 6) cancelled meeting room nahi rokti; normal guest par asar nahi
  update public.calendar_events set cancelled_at=now() where id=e1;
  insert into public.calendar_attendees(event_id,org_id,address) values (e2,o,addr);
  insert into public.calendar_attendees(event_id,org_id,address) values (e2,o,'someone@example.com');
  raise notice 'E83 PROOF: ALL PASS';
end $$;
rollback;
