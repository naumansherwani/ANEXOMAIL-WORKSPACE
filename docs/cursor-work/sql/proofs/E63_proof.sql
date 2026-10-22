-- E63 behaviour proof (sandbox/test DB ONLY — real rows likhta hai aur ROLLBACK karta hai). Server par nahi chalti.
-- Chalao: psql -v ON_ERROR_STOP=1 -f E63_proof.sql   (E63 laga hua ho)
begin;
create temp table r (ord int, item text, ok boolean) on commit drop;
do $$
declare org uuid := gen_random_uuid(); ev uuid;
begin
  insert into public.calendar_events (org_id, title, starts_at, ends_at) values (org, 'proof', now(), now() + interval '1 hour') returning id into ev;
  insert into r select 1, 'default: naya event open, goal NULL, goal_state_at NULL',
    (select goal is null and goal_state = 'open' and goal_state_at is null from public.calendar_events where id = ev);

  update public.calendar_events set goal = 'Contract signed' where id = ev;
  insert into r values (2, 'goal likhna theek', (select goal = 'Contract signed' from public.calendar_events where id = ev));

  update public.calendar_events set goal_state = 'achieved', goal_state_at = now() where id = ev;
  insert into r values (3, 'achieved + waqt theek', (select goal_state = 'achieved' from public.calendar_events where id = ev));
  update public.calendar_events set goal_state = 'missed', goal_state_at = now() where id = ev;
  insert into r values (4, 'missed + waqt theek (galti sudhar sakte hain)', (select goal_state = 'missed' from public.calendar_events where id = ev));
  update public.calendar_events set goal_state = 'open', goal_state_at = null where id = ev;
  insert into r values (5, 'wapas open (waqt NULL) theek', (select goal_state = 'open' from public.calendar_events where id = ev));

  begin update public.calendar_events set goal_state = 'achieved' where id = ev; insert into r values (6, 'achieved bina waqt REJECT', false);
  exception when check_violation then insert into r values (6, 'achieved bina waqt REJECT', true); end;
  begin update public.calendar_events set goal_state_at = now() where id = ev; insert into r values (7, 'open ke saath waqt REJECT', false);
  exception when check_violation then insert into r values (7, 'open ke saath waqt REJECT', true); end;
  begin update public.calendar_events set goal_state = 'done', goal_state_at = now() where id = ev; insert into r values (8, 'anjaan halat "done" REJECT', false);
  exception when check_violation then insert into r values (8, 'anjaan halat "done" REJECT', true); end;
  begin update public.calendar_events set goal = '   ' where id = ev; insert into r values (9, 'khali (spaces) goal REJECT', false);
  exception when check_violation then insert into r values (9, 'khali (spaces) goal REJECT', true); end;
  begin update public.calendar_events set goal = repeat('x', 2001) where id = ev; insert into r values (10, '2001 harf goal REJECT', false);
  exception when check_violation then insert into r values (10, '2001 harf goal REJECT', true); end;
  begin update public.calendar_events set goal = E'a\x07b' where id = ev; insert into r values (11, 'control character (bell) wala goal REJECT', false);
  exception when check_violation then insert into r values (11, 'control character (bell) wala goal REJECT', true); end;
  update public.calendar_events set goal = E'Line one\nLine two\n' || repeat('y', 1900) where id = ev;
  insert into r values (14, 'multi-line goal (~1900 harf) theek', (select goal like E'Line one\nLine two%' from public.calendar_events where id = ev));
  begin update public.calendar_events set goal_state = null where id = ev; insert into r values (12, 'goal_state NULL REJECT (NOT NULL)', false);
  exception when not_null_violation then insert into r values (12, 'goal_state NULL REJECT (NOT NULL)', true); end;
  update public.calendar_events set goal = null where id = ev;
  insert into r values (13, 'goal wapas NULL (hatana) theek', (select goal is null from public.calendar_events where id = ev));
end $$;
select ord, item, ok from r order by ord;
rollback;
