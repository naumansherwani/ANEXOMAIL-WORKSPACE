
-- E76 proof (sandbox): registry sirf maujood rows ko test maanti hai; naya "x.test" asli user nahi.
do $$ begin
  insert into public.test_accounts(email) values ('basic.test@anexomail.com') on conflict do nothing;
  assert public.is_registered_test_account('Basic.Test@anexomail.com'), 'registered (case-insens)';
  assert not public.is_registered_test_account('john.test@anexomail.com'), 'real user with test-looking name NOT exempt';
  assert not public.is_registered_test_account(null), 'null';
  raise notice 'E76 proof ALL OK';
end $$;
