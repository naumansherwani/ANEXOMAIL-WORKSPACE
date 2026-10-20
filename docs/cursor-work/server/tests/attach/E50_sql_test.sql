-- E50 SQL test (db e48 par: stubs + seed + E48 + E50). Har check ek row: PASS/FAIL.
\set ON_ERROR_STOP off
create temp table res(n text, ok boolean);
create or replace function pg_temp.chk(n text, ok boolean) returns void language sql as $$ insert into res values (n, coalesce(ok,false)) $$;
\set o1 '11111111-1111-1111-1111-111111111111'
\set o2 '22222222-2222-2222-2222-222222222222'
insert into mail_messages(id, org_id) values ('aaaaaaaa-0000-0000-0000-000000000001', :'o1'), ('bbbbbbbb-0000-0000-0000-000000000002', :'o2');
-- ingest ne ek row (naam+size) pehle se banayi hai
insert into mail_attachments(message_id, filename, mime_type, size_bytes) values ('aaaaaaaa-0000-0000-0000-000000000001', 'q.pdf', 'application/pdf', 10);
select pg_temp.chk('org limit basic = 5 GB x 3 mailboxes', public.mail_attach_org_limit(:'o1') = 16106127360);
select pg_temp.chk('org limit business larger', public.mail_attach_org_limit(:'o2') > 5368709120);

create temp table r1 as select public.mail_attach_inbound_register(:'o1','aaaaaaaa-0000-0000-0000-000000000001',0,'q.pdf','application/pdf',10,
  repeat('a',64), :'o1'||'/aa/'||repeat('a',64)||'-0123abcd', '{"clamd":"clean"}') as j;
select pg_temp.chk('register ok stored, not deduped', (select (j->>'ok')='true' and (j->>'stored')='true' and (j->>'deduped')='false' from r1));
select pg_temp.chk('existing metadata row got linked (no duplicate)', (select count(*) = 1 from mail_attachments where message_id='aaaaaaaa-0000-0000-0000-000000000001'));
select pg_temp.chk('row has sha256 + disk_path + org', (select sha256 = repeat('a',64) and disk_path like '%/aa/%' and org_id = :'o1' from mail_attachments where message_id='aaaaaaaa-0000-0000-0000-000000000001'));
select pg_temp.chk('blob row created', (select count(*) = 1 from org_attachment_blobs where org_id=:'o1' and sha256=repeat('a',64)));

-- dobara chalana (retry): nayi row nahi banti, dedup bataya jata hai
create temp table r2 as select public.mail_attach_inbound_register(:'o1','aaaaaaaa-0000-0000-0000-000000000001',0,'q.pdf','application/pdf',10,
  repeat('a',64), :'o1'||'/aa/'||repeat('a',64)||'-ffff0000', '{"clamd":"clean"}') as j;
select pg_temp.chk('retry: still one row, deduped, original path kept', (select (j->>'deduped')='true' and j->>'rel_path' like '%-0123abcd' from r2)
  and (select count(*) = 1 from mail_attachments where message_id='aaaaaaaa-0000-0000-0000-000000000001'));

-- row na ho to nayi banti hai
select public.mail_attach_inbound_register(:'o1','aaaaaaaa-0000-0000-0000-000000000001',0,'other.png','image/png',5, repeat('b',64), :'o1'||'/bb/'||repeat('b',64)||'-11112222','{}');
select pg_temp.chk('no pre-row => inserted', (select count(*) = 1 from mail_attachments where message_id='aaaaaaaa-0000-0000-0000-000000000001' and filename='other.png' and sha256 = repeat('b',64)));

-- same naam do dafa (ordinal 0 aur 1) => do alag rows
select public.mail_attach_inbound_register(:'o1','aaaaaaaa-0000-0000-0000-000000000001',0,'dup.txt','text/plain',3, repeat('c',64), :'o1'||'/cc/'||repeat('c',64)||'-aaaa0000','{}');
select public.mail_attach_inbound_register(:'o1','aaaaaaaa-0000-0000-0000-000000000001',1,'dup.txt','text/plain',4, repeat('d',64), :'o1'||'/dd/'||repeat('d',64)||'-bbbb0000','{}');
select pg_temp.chk('same filename twice => two rows with different sha', (select count(distinct sha256) = 2 and count(*) = 2 from mail_attachments where message_id='aaaaaaaa-0000-0000-0000-000000000001' and filename='dup.txt'));

-- virus: bytes nahi, row par scan
select public.mail_attach_inbound_register(:'o1','aaaaaaaa-0000-0000-0000-000000000001',0,'evil.zip','application/zip',7, null, null, '{"clamd":"found","signature":"Eicar-Test-Signature"}');
select pg_temp.chk('infected: row exists, no sha/disk_path, scan says found', (select sha256 is null and disk_path is null and scan->>'clamd'='found' and scan->>'reason'='infected' from mail_attachments where filename='evil.zip'));
select pg_temp.chk('infected: no blob created', (select count(*) = 0 from org_attachment_blobs where org_id=:'o1' and sha256 is null));

-- cross-org: doosri org ki mail mein wahi sha => alag blob (dedup sirf org ke andar)
select public.mail_attach_inbound_register(:'o2','bbbbbbbb-0000-0000-0000-000000000002',0,'q.pdf','application/pdf',10, repeat('a',64), :'o2'||'/aa/'||repeat('a',64)||'-9999aaaa','{}');
select pg_temp.chk('cross-org same sha => separate blob', (select count(*) = 2 from org_attachment_blobs where sha256=repeat('a',64)));

-- galat input
select pg_temp.chk('message of another org refused', (public.mail_attach_inbound_register(:'o2','aaaaaaaa-0000-0000-0000-000000000001',0,'x','x',1,repeat('e',64),:'o2'||'/ee/'||repeat('e',64)||'-12345678','{}')->>'error') = 'message_not_in_org');
select pg_temp.chk('path of another org refused', (public.mail_attach_inbound_register(:'o1','aaaaaaaa-0000-0000-0000-000000000001',0,'x','x',1,repeat('e',64),:'o2'||'/ee/'||repeat('e',64)||'-12345678','{}')->>'error') = 'bad_path');
select pg_temp.chk('traversal path refused', (public.mail_attach_inbound_register(:'o1','aaaaaaaa-0000-0000-0000-000000000001',0,'x','x',1,repeat('e',64),'../../etc/passwd','{}')->>'error') = 'bad_path');
select pg_temp.chk('bad hash refused', (public.mail_attach_inbound_register(:'o1','aaaaaaaa-0000-0000-0000-000000000001',0,'x','x',1,'zz',:'o1'||'/ee/'||repeat('e',64)||'-12345678','{}')->>'error') = 'bad_hash');

-- quota: org ki hadd chhoti kar ke
update storage_plans set pooled_bytes = 100, per_mailbox_bytes = 100 where plan_id = 'basic';
select public.mail_attach_inbound_register(:'o1','aaaaaaaa-0000-0000-0000-000000000001',0,'huge.bin','application/octet-stream',999999, repeat('f',64), :'o1'||'/ff/'||repeat('f',64)||'-cafe0000','{}');
select pg_temp.chk('quota full: row says stored=false/org_quota_full, no blob', (select sha256 is null and scan->>'reason'='org_quota_full' from mail_attachments where filename='huge.bin')
  and (select count(*)=0 from org_attachment_blobs where sha256=repeat('f',64)));

-- grants
select pg_temp.chk('anon/authenticated cannot execute', not has_function_privilege('anon','public.mail_attach_inbound_register(uuid,uuid,int,text,text,bigint,text,text,jsonb)','execute')
  and not has_function_privilege('authenticated','public.mail_attach_org_limit(uuid)','execute'));
select pg_temp.chk('service_role can execute', has_function_privilege('service_role','public.mail_attach_inbound_register(uuid,uuid,int,text,text,bigint,text,text,jsonb)','execute'));

select case when ok then 'PASS' else 'FAIL' end as r, n from res;
select count(*) filter (where ok) || '/' || count(*) as total from res;
