\set ON_ERROR_STOP on
create temp table res(name text, ok boolean, got text);
create or replace function pg_temp.chk(n text, cond boolean, got text default '') returns void language sql as $$ insert into res values (n, coalesce(cond,false), got) $$;

insert into auth.users(id,email) values
 ('00000000-0000-0000-0000-0000000000a1','a@x'),('00000000-0000-0000-0000-0000000000b2','b@x'),
 ('00000000-0000-0000-0000-0000000000c3','c@x'),('00000000-0000-0000-0000-0000000000d4','d@x');
-- O1 = basic (owner A, member C revoked later), O2 = business (owner B), O3 = founder org (D)
insert into org_members values
 ('11111111-1111-1111-1111-111111111111','00000000-0000-0000-0000-0000000000a1','owner','active'),
 ('11111111-1111-1111-1111-111111111111','00000000-0000-0000-0000-0000000000c3','member','active'),
 ('22222222-2222-2222-2222-222222222222','00000000-0000-0000-0000-0000000000b2','owner','active'),
 ('33333333-3333-3333-3333-333333333333','00000000-0000-0000-0000-0000000000d4','owner','active');
insert into entitlement_state values ('00000000-0000-0000-0000-0000000000a1','basic'),('00000000-0000-0000-0000-0000000000b2','business');
insert into founder_accounts values ('00000000-0000-0000-0000-0000000000d4');

select pg_temp.chk('ctx basic cap 7MB', (public.mail_attach_ctx('00000000-0000-0000-0000-0000000000a1')->>'message_cap_bytes')::bigint = 7000000, public.mail_attach_ctx('00000000-0000-0000-0000-0000000000a1')::text);
select pg_temp.chk('ctx business plan', public.mail_attach_ctx('00000000-0000-0000-0000-0000000000b2')->>'plan' = 'business');
select pg_temp.chk('ctx founder => business_pro', public.mail_attach_ctx('00000000-0000-0000-0000-0000000000d4')->>'plan' = 'business_pro');
select pg_temp.chk('ctx unknown user', public.mail_attach_ctx('00000000-0000-0000-0000-00000000ffff')->>'error' = 'unauthorized');
select pg_temp.chk('ctx wrong requested org falls back to own', public.mail_attach_ctx('00000000-0000-0000-0000-0000000000a1','22222222-2222-2222-2222-222222222222')->>'org_id' = '11111111-1111-1111-1111-111111111111');

-- register
\set sha1 '''aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'''
select set_config('t.r1', public.mail_attach_register('00000000-0000-0000-0000-0000000000a1','11111111-1111-1111-1111-111111111111',:sha1,1000,'report.pdf','application/pdf','11111111-1111-1111-1111-111111111111/aa/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-0123abcd','{"clamd":"clean"}'::jsonb)::text, false);
select pg_temp.chk('register ok not deduped', (current_setting('t.r1')::jsonb->>'ok')='true' and (current_setting('t.r1')::jsonb->>'deduped')='false', current_setting('t.r1'));
select set_config('t.r2', public.mail_attach_register('00000000-0000-0000-0000-0000000000c3','11111111-1111-1111-1111-111111111111',:sha1,1000,'copy.pdf','application/pdf','11111111-1111-1111-1111-111111111111/aa/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-ffffffff','{}'::jsonb)::text, false);
select pg_temp.chk('same org same hash => deduped, original path kept', (current_setting('t.r2')::jsonb->>'deduped')='true' and current_setting('t.r2')::jsonb->>'rel_path' like '%-0123abcd', current_setting('t.r2'));
select pg_temp.chk('one blob row for dedup', (select count(*) from org_attachment_blobs where sha256=:sha1)=1);
select set_config('t.r3', public.mail_attach_register('00000000-0000-0000-0000-0000000000b2','22222222-2222-2222-2222-222222222222',:sha1,1000,'report.pdf','application/pdf','22222222-2222-2222-2222-222222222222/aa/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-11112222','{}'::jsonb)::text, false);
select pg_temp.chk('DIFFERENT org same hash => NOT deduped (cross-org forbidden)', (current_setting('t.r3')::jsonb->>'deduped')='false', current_setting('t.r3'));
select pg_temp.chk('two blob rows total (one per org)', (select count(*) from org_attachment_blobs where sha256=:sha1)=2);
select pg_temp.chk('too large', public.mail_attach_register('00000000-0000-0000-0000-0000000000a1','11111111-1111-1111-1111-111111111111',repeat('b',64),7000001,'big.bin',null,'11111111-1111-1111-1111-111111111111/bb/'||repeat('b',64)||'-01234567','{}'::jsonb)->>'error' = 'file_too_large');
select pg_temp.chk('bad path rejected', public.mail_attach_register('00000000-0000-0000-0000-0000000000a1','11111111-1111-1111-1111-111111111111',repeat('c',64),10,'x.txt',null,'../../etc/passwd','{}'::jsonb)->>'error' = 'bad_path');
select pg_temp.chk('bad hash rejected', public.mail_attach_register('00000000-0000-0000-0000-0000000000a1','11111111-1111-1111-1111-111111111111','XYZ',10,'x.txt',null,'x','{}'::jsonb)->>'error' = 'bad_hash');
select pg_temp.chk('register into org I am not in => wrong_org', public.mail_attach_register('00000000-0000-0000-0000-0000000000a1','22222222-2222-2222-2222-222222222222',repeat('d',64),10,'x.txt',null,'22222222-2222-2222-2222-222222222222/dd/'||repeat('d',64)||'-01234567','{}'::jsonb)->>'error' = 'wrong_org');
-- quota: shrink basic plan to 1500 bytes; org O1 already holds 1000
update storage_plans set per_mailbox_bytes=1500, mailbox_limit=1 where plan_id='basic';
select pg_temp.chk('org quota full', public.mail_attach_register('00000000-0000-0000-0000-0000000000a1','11111111-1111-1111-1111-111111111111',repeat('e',64),600,'q.bin',null,'11111111-1111-1111-1111-111111111111/ee/'||repeat('e',64)||'-01234567','{}'::jsonb)->>'error' = 'org_quota_full');
select pg_temp.chk('dedup does not need quota', (public.mail_attach_register('00000000-0000-0000-0000-0000000000a1','11111111-1111-1111-1111-111111111111',:sha1,1000,'again.pdf',null,'11111111-1111-1111-1111-111111111111/aa/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-99999999','{}'::jsonb)->>'ok')='true');
update storage_plans set per_mailbox_bytes=5368709120, mailbox_limit=3 where plan_id='basic';

-- stage_check
select set_config('t.ids', (select jsonb_agg(id)::text from mail_outbound_attachments where user_id='00000000-0000-0000-0000-0000000000a1'), false);
select pg_temp.chk('stage_check ok for owner', public.mail_attach_stage_check('00000000-0000-0000-0000-0000000000a1','11111111-1111-1111-1111-111111111111', array(select jsonb_array_elements_text(current_setting('t.ids')::jsonb)::uuid))->>'ok' = 'true');
select pg_temp.chk('stage_check: other user cannot use my ids', public.mail_attach_stage_check('00000000-0000-0000-0000-0000000000c3','11111111-1111-1111-1111-111111111111', array(select jsonb_array_elements_text(current_setting('t.ids')::jsonb)::uuid))->>'error' = 'attachment_not_found');
select pg_temp.chk('stage_check: random id', public.mail_attach_stage_check('00000000-0000-0000-0000-0000000000a1','11111111-1111-1111-1111-111111111111', array['99999999-9999-9999-9999-999999999999'::uuid])->>'error' = 'attachment_not_found');
update mail_attach_limits set value=1500 where key='server_ceiling_bytes';
select pg_temp.chk('stage_check: total over cap', public.mail_attach_stage_check('00000000-0000-0000-0000-0000000000a1','11111111-1111-1111-1111-111111111111', array(select jsonb_array_elements_text(current_setting('t.ids')::jsonb)::uuid))->>'error' = 'attachments_too_large');
update mail_attach_limits set value=7000000 where key='server_ceiling_bytes';
update mail_attach_limits set value=1 where key='max_files';
select pg_temp.chk('stage_check: too many files', public.mail_attach_stage_check('00000000-0000-0000-0000-0000000000a1','11111111-1111-1111-1111-111111111111', array(select jsonb_array_elements_text(current_setting('t.ids')::jsonb)::uuid))->>'error' = 'too_many_attachments');
update mail_attach_limits set value=10 where key='max_files';

-- commit + resolve
insert into mail_messages(id,org_id) values ('aaaaaaaa-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111');
select pg_temp.chk('commit', public.mail_attach_commit('00000000-0000-0000-0000-0000000000a1','11111111-1111-1111-1111-111111111111', array(select jsonb_array_elements_text(current_setting('t.ids')::jsonb)::uuid), 'aaaaaaaa-0000-0000-0000-000000000001')->>'ok' = 'true');
select pg_temp.chk('mail_attachments rows written with sha+org', (select count(*) from mail_attachments where message_id='aaaaaaaa-0000-0000-0000-000000000001' and sha256 is not null and org_id='11111111-1111-1111-1111-111111111111')>=1);
select pg_temp.chk('staged rows removed after commit', (select count(*) from mail_outbound_attachments where user_id='00000000-0000-0000-0000-0000000000a1')=0);
select pg_temp.chk('commit refuses message of another org', public.mail_attach_commit('00000000-0000-0000-0000-0000000000a1','11111111-1111-1111-1111-111111111111','{}','aaaaaaaa-0000-0000-0000-000000000009'::uuid)->>'error' = 'message_not_in_org');
select set_config('t.aid', (select id::text from mail_attachments where message_id='aaaaaaaa-0000-0000-0000-000000000001' limit 1), false);
select pg_temp.chk('resolve: org member C can download', public.mail_attach_resolve('00000000-0000-0000-0000-0000000000c3', current_setting('t.aid')::uuid)->>'ok' = 'true');
select pg_temp.chk('resolve: other org B cannot', public.mail_attach_resolve('00000000-0000-0000-0000-0000000000b2', current_setting('t.aid')::uuid)->>'error' = 'not_found');
update org_members set status='revoked' where user_id='00000000-0000-0000-0000-0000000000c3';
select pg_temp.chk('resolve: revoked member cannot', public.mail_attach_resolve('00000000-0000-0000-0000-0000000000c3', current_setting('t.aid')::uuid)->>'error' = 'not_found');
update account_integrity set state='clean' where false;
insert into account_integrity(user_id,state) values ('00000000-0000-0000-0000-0000000000a1','blocked');
select pg_temp.chk('resolve: blocked account denied', public.mail_attach_resolve('00000000-0000-0000-0000-0000000000a1', current_setting('t.aid')::uuid)->>'error' = 'account_blocked');
select pg_temp.chk('ctx: blocked account denied', public.mail_attach_ctx('00000000-0000-0000-0000-0000000000a1')->>'error' = 'account_blocked');
delete from account_integrity;

-- gc
select public.mail_attach_register('00000000-0000-0000-0000-0000000000b2','22222222-2222-2222-2222-222222222222',repeat('f',64),50,'old.txt','text/plain','22222222-2222-2222-2222-222222222222/ff/'||repeat('f',64)||'-aaaaaaaa','{}'::jsonb);
select public.mail_attach_register('00000000-0000-0000-0000-0000000000b2','22222222-2222-2222-2222-222222222222',repeat('1',64),50,'sched.txt','text/plain','22222222-2222-2222-2222-222222222222/11/'||repeat('1',64)||'-bbbbbbbb','{}'::jsonb);
update mail_outbound_attachments set created_at = now() - interval '30 hours' where user_id='00000000-0000-0000-0000-0000000000b2';
insert into mail_scheduled(status, attachment_ids) select 'holding', array[id] from mail_outbound_attachments where filename='sched.txt';
select set_config('t.gc1', public.mail_attach_gc()::text, false);
select pg_temp.chk('gc: expired staged removed, scheduled one kept', (select count(*) from mail_outbound_attachments where filename='old.txt')=0 and (select count(*) from mail_outbound_attachments where filename='sched.txt')=1, current_setting('t.gc1'));
select pg_temp.chk('gc: blob kept inside grace days', (current_setting('t.gc1')::jsonb->'paths') = '[]'::jsonb);
update org_attachment_blobs set touched_at = now() - interval '3 days';
select set_config('t.gc2', public.mail_attach_gc()::text, false);
select pg_temp.chk('gc: unreferenced old blob row deleted + its path returned', (current_setting('t.gc2')::jsonb->'paths')::text like '%-aaaaaaaa%' and (select count(*) from org_attachment_blobs where sha256=repeat('f',64))=0, current_setting('t.gc2'));
select pg_temp.chk('gc: referenced (scheduled) blob survives', (select count(*) from org_attachment_blobs where sha256=repeat('1',64))=1);
select pg_temp.chk('gc: blob referenced by sent mail survives', (select count(*) from org_attachment_blobs where sha256=:sha1 and org_id='11111111-1111-1111-1111-111111111111')=1);
select pg_temp.chk('anon/authenticated cannot execute', not has_function_privilege('authenticated','public.mail_attach_ctx(uuid,uuid)','execute') and not has_function_privilege('anon','public.mail_attach_register(uuid,uuid,text,bigint,text,text,text,jsonb)','execute'));
select pg_temp.chk('tables not readable by authenticated', not has_table_privilege('authenticated','public.org_attachment_blobs','select'));

select case when ok then 'PASS' else 'FAIL' end as r, name, case when ok then '' else got end from res order by ok, name;
select count(*) filter (where not ok) as failed, count(*) as total from res;
