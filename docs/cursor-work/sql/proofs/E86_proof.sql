-- E86 proof (rollback-only)
begin;
do $$
declare o uuid := gen_random_uuid(); u uuid := gen_random_uuid(); d uuid := gen_random_uuid(); t uuid := gen_random_uuid(); n int;
begin
  insert into public.organisations(id) values (o);
  insert into public.mail_threads(id,org_id,account_id,subject,folder,status) values (t,o,gen_random_uuid(),'s','inbox','open');
  -- follow-up: valid, bad status refused, thread delete cascades
  insert into public.mail_followups(org_id,user_id,thread_id,subject,remind_at) values (o,u,t,'s',now()+interval '1 day');
  begin insert into public.mail_followups(org_id,user_id,remind_at,status) values (o,u,now(),'zzz'); assert false,'bad status';
  exception when check_violation then null; end;
  begin insert into public.mail_followups(org_id,user_id,remind_at) values (o,u,null); assert false,'remind_at required';
  exception when not_null_violation then null; end;
  delete from public.mail_threads where id = t;
  select count(*) into n from public.mail_followups where org_id = o and subject = 's'; assert n = 0, 'cascade: followup goes with its thread';
  -- draft versions: second insert with same (draft, version) refused
  insert into public.mail_drafts_versions(org_id,draft_id,user_id,version) values (o,d,u,1);
  begin insert into public.mail_drafts_versions(org_id,draft_id,user_id,version) values (o,d,u,1); assert false,'dup version';
  exception when unique_violation then null; end;
  insert into public.mail_drafts_versions(org_id,draft_id,user_id,version) values (o,d,u,2);
end $$;
rollback;
