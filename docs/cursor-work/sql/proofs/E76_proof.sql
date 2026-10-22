
-- E76 v2 proof (sandbox): teeno deewarein behaviour se. Har assert fail par exception.
do $$
declare uid uuid := gen_random_uuid(); uid2 uuid := gen_random_uuid(); ok boolean;
begin
  -- registry + class
  perform public.register_test_account('basic.test@anexomail.com', 'proof');
  assert public.account_class('Basic.Test@anexomail.com') = 'test', 'registered = test';
  assert public.account_class('john.test@anexomail.com') = 'real', 'unregistered x.test = real';
  assert not (public.register_test_account('bad') ->> 'ok')::boolean, 'bad email';
  -- wall 1: ek class
  insert into public.founder_accounts (user_id, email) values (gen_random_uuid(), 'boss@x.com');
  insert into public.family_accounts (email, display_name, relation) values ('fam@x.com', 'F', 'bro');
  assert public.account_class('boss@x.com') = 'founder' and public.account_class('fam@x.com') = 'family', 'classes';
  begin insert into public.test_accounts (email) values ('boss@x.com'); assert false, 'founder->test allowed'; exception when check_violation then null; end;
  begin insert into public.founder_accounts (user_id, email) values (gen_random_uuid(), 'fam@x.com'); assert false, 'family->founder allowed'; exception when check_violation then null; end;
  begin insert into public.family_accounts (email, display_name, relation) values ('basic.test@anexomail.com', 'T', 'x'); assert false, 'test->family allowed'; exception when check_violation then null; end;
  assert not (public.register_test_account('fam@x.com') ->> 'ok')::boolean, 'family cannot register as test';
  -- wall 2: asli signup claim
  insert into auth.users (id, email) values (uid, 'realbuyer@gmail.com'), (uid2, 'basic.test@anexomail.com');
  begin insert into public.trial_accounts (user_id, anexomail_handle) values (uid, 'john.test'); assert false, 'real took x.test'; exception when check_violation then null; end;
  begin insert into public.trial_accounts (user_id, anexomail_handle) values (uid, 'basic.test'); assert false, 'real took registered test address'; exception when check_violation then null; end;
  begin insert into public.trial_accounts (user_id, anexomail_handle) values (uid, 'fam'); exception when others then assert false, 'normal real handle blocked: ' || sqlerrm; end;
  update public.trial_accounts set anexomail_handle = 'johnny' where user_id = uid;
  insert into public.trial_accounts (user_id, anexomail_handle) values (uid2, 'basic.test');  -- test account apna pata le sakta hai
  assert not exists (select 1 from public.account_mix_report()), 'report clean';
  raise notice 'E76 proof ALL OK';
end $$;
