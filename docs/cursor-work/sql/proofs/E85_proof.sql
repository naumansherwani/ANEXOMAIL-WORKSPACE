-- E85 proof (rollback-only)
begin;
do $$
declare o uuid := gen_random_uuid(); o2 uuid := gen_random_uuid(); u1 uuid := gen_random_uuid(); u2 uuid := gen_random_uuid(); stranger uuid := gen_random_uuid();
 t uuid := gen_random_uuid(); r public.mail_threads; acc uuid := gen_random_uuid();
begin
  insert into public.org_members(org_id,user_id,status,role,email) values (o,u1,'active','admin','a@x.com'),(o,u2,'removed','member','b@x.com');
  insert into public.mail_threads(id,org_id,account_id,subject,folder,status) values (t,o,acc,'s','inbox','open');
  r := public.mail_thread_assign(t,u1,o);   assert r.assignee = u1, 'assign member';
  r := public.mail_thread_assign(t,null,o); assert r.assignee is null, 'clear with null';
  begin perform public.mail_thread_assign(t,stranger,o); assert false,'stranger must fail';
  exception when others then assert sqlerrm='assignee_not_member','stranger: '||sqlerrm; end;
  begin perform public.mail_thread_assign(t,u2,o); assert false,'removed member must fail';
  exception when others then assert sqlerrm='assignee_not_member','removed: '||sqlerrm; end;
  begin perform public.mail_thread_assign(t,u1,o2); assert false,'foreign org must fail';
  exception when others then assert sqlerrm in ('assignee_not_member','thread_not_found_or_not_owned'),'foreign: '||sqlerrm; end;
  assert (select count(*) from pg_proc where proname='mail_thread_assign' and pronamespace='public'::regnamespace)=1,'one overload';
end $$;
rollback;
