
-- E52: calendar_attendees.response — live table par purana CHECK (calendar_attendees_response_check) tha jo
-- 'accepted'/'needs_action' ko rokta tha => /rpc/calendar.create 500 ("Calendar failed"). Live saboot 21 Oct 2026
-- (CHECK_CAL_CREATE: 23514 calendar_attendees_response_check). Ab: ek saaf constraint, 4 sach ke maane + purane naam migrate.
-- Idempotent. Editor-safe (koi psql command nahi).
do $$
declare r record;
begin
  -- har purana CHECK jo response column par ho hata do
  for r in select c.conname from pg_constraint c
            where c.conrelid = 'public.calendar_attendees'::regclass and c.contype = 'c'
              and pg_get_constraintdef(c.oid) ilike '%response%'
  loop
    execute format('alter table public.calendar_attendees drop constraint %I', r.conname);
  end loop;
  -- purane naam jo kabhi chale ho sakte hain -> naye 4 mein
  update public.calendar_attendees set response = case lower(response)
      when 'pending' then 'needs_action' when 'invited' then 'needs_action' when 'none' then 'needs_action'
      when 'yes' then 'accepted' when 'accept' then 'accepted' when 'going' then 'accepted'
      when 'no' then 'declined' when 'decline' then 'declined'
      when 'maybe' then 'tentative' else response end
   where response is not null and response not in ('needs_action','accepted','tentative','declined');
  -- jo ab bhi anjaan ho use bhi needs_action (data nahi khota, sirf label)
  update public.calendar_attendees set response = 'needs_action'
   where response is null or response not in ('needs_action','accepted','tentative','declined');
  alter table public.calendar_attendees alter column response set default 'needs_action';
  alter table public.calendar_attendees add constraint calendar_attendees_response_check
    check (response in ('needs_action','accepted','tentative','declined'));
end $$;

-- self-test: asli insert, phir rollback ke liye exception se wapas
do $$
declare o uuid; e uuid; v_ok boolean := false;
begin
  begin
    select org_id into o from public.calendar_events limit 1;
    if o is null then select id into o from public.orgs limit 1; end if;
    insert into public.calendar_events(org_id,title,starts_at,ends_at) values (o,'E52 selftest',now(),now()+interval '5 min') returning id into e;
    insert into public.calendar_attendees(event_id,org_id,address,response,invite_status) values (e,o,'e52@selftest.test','accepted','not_sent');
    insert into public.calendar_attendees(event_id,org_id,address,response,invite_status) values (e,o,'e52b@selftest.test','needs_action','not_sent');
    begin
      insert into public.calendar_attendees(event_id,org_id,address,response) values (e,o,'e52c@selftest.test','banana');
      raise exception 'E52 FAILED: ghalat response chal gaya';
    exception when check_violation then v_ok := true; end;
    if v_ok then raise exception 'E52_ROLLBACK_OK'; end if;
  exception when others then
    if sqlerrm <> 'E52_ROLLBACK_OK' then raise exception 'E52 FAILED: %', sqlerrm; end if;
  end;
  raise notice 'E52 OK: accepted + needs_action chalte hain, banana nahi';
end $$;
notify pgrst, 'reload schema';
