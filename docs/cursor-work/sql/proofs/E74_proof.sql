
-- E74 proof: meeting par files. psql -v ON_ERROR_STOP=1 -f E74_proof.sql (E48 + E74 pehle lagi hon). Har assert fail par exception.
set search_path = public;
do $$
declare
  org uuid := gen_random_uuid(); org2 uuid := gen_random_uuid();
  uo uuid := gen_random_uuid(); ug uuid := gen_random_uuid(); us uuid := gen_random_uuid(); ux uuid := gen_random_uuid(); ub uuid := gen_random_uuid();
  ev uuid; ev2 uuid; evc uuid; reg jsonb; r jsonb; fid uuid; fid2 uuid; i int; sha text; paths jsonb; cnt int;
begin
  insert into auth.users (id, email) values (uo, 'owner@x.test'), (ug, 'Guest@x.test'), (us, 'stranger@x.test'), (ux, 'other@y.test'), (ub, 'blocked@x.test');
  insert into org_members (user_id, org_id) values (uo, org), (ug, org), (us, org), (ux, org2), (ub, org);
  insert into calendar_events (org_id, organiser, title) values (org, 'owner@x.test', 'Kickoff') returning id into ev;
  insert into calendar_events (org_id, organiser, title) values (org, 'owner@x.test', 'Other') returning id into ev2;
  insert into calendar_events (org_id, organiser, title, cancelled_at) values (org, 'owner@x.test', 'Gone', now()) returning id into evc;
  insert into calendar_attendees (event_id, address) values (ev, 'guest@x.test'), (evc, 'guest@x.test');

  -- 1 organiser: upload (register) -> event se jodna
  sha := repeat('a', 64);
  reg := mail_attach_register(uo, org, sha, 1000, 'agenda.pdf', 'application/pdf', org || '/aa/' || sha || '-12345678', '{"scanned":true}');
  assert (reg->>'ok')::boolean, '1 register';
  r := cal_file_attach(uo, org, ev, (reg->>'id')::uuid);
  assert (r->>'ok')::boolean and r->>'filename' = 'agenda.pdf', '2 attach';
  fid := (r->>'id')::uuid;
  assert not exists (select 1 from mail_outbound_attachments where id = (reg->>'id')::uuid), '3 staged row khatam';
  -- 4 wahi file dobara (naya upload, dedup) -> already_attached, staged saaf
  reg := mail_attach_register(uo, org, sha, 1000, 'agenda-copy.pdf', 'application/pdf', org || '/aa/' || sha || '-87654321', '{}');
  assert (reg->>'deduped')::boolean, '4a dedup';
  assert cal_file_attach(uo, org, ev, (reg->>'id')::uuid)->>'error' = 'already_attached', '4 already_attached';
  assert not exists (select 1 from mail_outbound_attachments where id = (reg->>'id')::uuid), '5 dup staged saaf';
  -- 6 guest jodne ki koshish -> organiser_only; stranger -> not_found; doosre org ka -> no_workspace; blocked
  reg := mail_attach_register(ug, org, repeat('b', 64), 10, 'g.txt', 'text/plain', org || '/bb/' || repeat('b', 64) || '-11111111', '{}');
  assert cal_file_attach(ug, org, ev, (reg->>'id')::uuid)->>'error' = 'organiser_only', '6 guest jod nahi sakta';
  assert cal_file_attach(us, org, ev, gen_random_uuid())->>'error' = 'organiser_only', '7 stranger';
  assert cal_file_attach(ux, org, ev, gen_random_uuid())->>'error' = 'no_workspace', '8 doosre org ka';
  -- 9 kisi aur ki staged file apni meeting par nahi lagti
  assert cal_file_attach(uo, org, ev, (reg->>'id')::uuid)->>'error' = 'attachment_not_found', '9 doosre ki staged file';
  -- 10 list: organiser can_add, guest sirf dekhe, stranger not_found
  r := cal_file_list(uo, org, ev);
  assert (r->>'can_add')::boolean and jsonb_array_length(r->'files') = 1 and (r->'files'->0->>'can_remove')::boolean, '10 organiser list';
  r := cal_file_list(ug, org, ev);
  assert not (r->>'can_add')::boolean and jsonb_array_length(r->'files') = 1 and not (r->'files'->0->>'can_remove')::boolean, '11 guest list';
  assert cal_file_list(us, org, ev)->>'error' = 'not_found', '12 stranger list';
  assert cal_file_list(ux, org, ev)->>'error' = 'no_workspace', '13 doosra org list';
  -- 14 guest hatane ki koshish
  assert cal_file_remove(ug, org, ev, fid)->>'error' = 'not_found', '14 guest remove';
  -- 15 download (resolve): organiser + guest ok, stranger nahi
  assert (mail_attach_resolve(uo, fid)->>'ok')::boolean and mail_attach_resolve(uo, fid)->>'filename' = 'agenda.pdf', '15 organiser resolve';
  assert (mail_attach_resolve(ug, fid)->>'ok')::boolean, '16 guest resolve';
  assert mail_attach_resolve(us, fid)->>'error' = 'not_found', '17 stranger resolve';
  assert mail_attach_resolve(ux, fid)->>'error' = 'not_found', '18 doosre org resolve';
  -- 19 GC: purani blob, par event ki file hai => KABHI nahi mitti
  update org_attachment_blobs set touched_at = now() - interval '30 days' where org_id = org;
  paths := mail_attach_gc()->'paths';
  assert not (paths ? (select rel_path from org_attachment_blobs where org_id = org and sha256 = sha)) , '19 GC ne event ki file mita di';
  assert exists (select 1 from org_attachment_blobs where org_id = org and sha256 = sha), '20 blob maujood';
  -- 21 hatane ke baad GC ke qabil
  assert (cal_file_remove(uo, org, ev, fid)->>'ok')::boolean, '21 organiser remove';
  assert cal_file_remove(uo, org, ev, fid)->>'error' = 'not_found', '22 dobara remove';
  update org_attachment_blobs set touched_at = now() - interval '30 days' where org_id = org and sha256 = sha;
  paths := mail_attach_gc()->'paths';
  assert jsonb_array_length(paths) >= 1 and not exists (select 1 from org_attachment_blobs where org_id = org and sha256 = sha), '23 ab GC ne saaf ki';
  -- 24 limit 10
  for i in 1..10 loop
    reg := mail_attach_register(uo, org, md5(i::text) || md5((i + 50)::text), 5, 'f' || i, 'text/plain', org || '/' || substr(md5(i::text), 1, 2) || '/' || md5(i::text) || md5((i + 50)::text) || '-22222222', '{}');
    r := cal_file_attach(uo, org, ev2, (reg->>'id')::uuid);
    assert (r->>'ok')::boolean, '24 file ' || i;
  end loop;
  reg := mail_attach_register(uo, org, repeat('c', 64), 5, 'f11', 'text/plain', org || '/cc/' || repeat('c', 64) || '-33333333', '{}');
  assert cal_file_attach(uo, org, ev2, (reg->>'id')::uuid)->>'error' = 'too_many_files', '25 limit 10';
  -- 26 cancelled meeting par jodna band, dekhna chalta hai
  assert cal_file_attach(uo, org, evc, (reg->>'id')::uuid)->>'error' = 'event_cancelled', '26 cancelled';
  assert (cal_file_list(ug, org, evc)->>'ok')::boolean, '27 cancelled list ok';
  -- 28 account blocked
  insert into account_integrity (user_id, state) values (ug, 'blocked');
  assert cal_file_list(ug, org, ev)->>'error' = 'account_blocked', '28 blocked list';
  assert mail_attach_resolve(ug, fid)->>'error' = 'account_blocked', '29 blocked resolve';
  -- 30 meeting delete => files rows saaf
  delete from calendar_events where id = ev2;
  select count(*) into cnt from calendar_event_files where event_id = ev2;
  assert cnt = 0, '30 cascade';
  -- 31 mail wali resolve (staged + bheji hui) ab bhi chalti hai
  assert (mail_attach_resolve(uo, (reg->>'id')::uuid)->>'ok')::boolean, '31 staged resolve abhi bhi';
  raise notice 'E74 proof: ALL OK';
  -- safai
  delete from calendar_event_files; delete from mail_outbound_attachments; delete from org_attachment_blobs; delete from calendar_events; delete from account_integrity;
  delete from org_members where org_id in (org, org2); delete from auth.users where id in (uo, ug, us, ux, ub);
end $$;
