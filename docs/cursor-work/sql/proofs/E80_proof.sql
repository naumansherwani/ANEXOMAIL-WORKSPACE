
-- E80 proof (sandbox/test DB ONLY; rollback). Stubs: auth.users, org_members, calendar_events (id, org_id). Server par nahi chalti.
begin;
do $$
declare
  org uuid := gen_random_uuid(); me uuid := gen_random_uuid(); gone uuid := gen_random_uuid();
  r jsonb; pw1 uuid; c0 bigint; c1 bigint; c2 bigint; c3 bigint; ev uuid := gen_random_uuid(); rev0 bigint; rev1 bigint; i int;
  h text := repeat('b', 64);
begin
  insert into auth.users (id) values (me), (gone) on conflict do nothing;
  insert into public.org_members (org_id, user_id, role, status, email) values (org, me, 'owner', 'active', 'me@x.test'), (org, gone, 'member', 'revoked', 'gone@x.test');

  r := public.caldav_apppw_create(me, org, 'Me@X.test', 'iPhone', 'abcdefg234', h);
  assert r ? 'id', 'create ok'; pw1 := (r ->> 'id')::uuid;
  assert (public.caldav_apppw_create(gone, org, 'gone@x.test', 'Old', 'abcdefg235', h)) ->> 'error' = 'forbidden', 'revoked member cannot create';
  assert (public.caldav_apppw_create(me, org, 'me@x.test', '', 'abcdefg236', h)) ->> 'error' = 'bad_label', 'empty label';
  assert (public.caldav_apppw_create(me, org, 'me@x.test', 'x', 'ABCDEFG236', h)) ->> 'error' = 'bad_secret', 'upper token';
  assert (public.caldav_apppw_create(me, org, 'me@x.test', 'dup', 'abcdefg234', h)) ->> 'error' = 'retry', 'duplicate token id';
  assert (select email from public.caldav_app_passwords where id = pw1) = 'me@x.test', 'email lowercased';

  assert public.caldav_auth_lookup('abcdefg234') ->> 'user_id' = me::text, 'lookup returns owner';
  assert public.caldav_auth_lookup('zzzzzzzzzz') is null, 'unknown token';

  -- 8 wrong attempts lock; success resets
  for i in 1..7 loop perform public.caldav_auth_result(pw1, false); end loop;
  assert public.caldav_auth_lookup('abcdefg234') is not null, '7 fails not locked yet';
  perform public.caldav_auth_result(pw1, true);
  assert (select fail_count from public.caldav_app_passwords where id = pw1) = 0, 'success resets counter';
  for i in 1..8 loop perform public.caldav_auth_result(pw1, false); end loop;
  assert public.caldav_auth_lookup('abcdefg234') is null, '8 fails => locked';
  update public.caldav_app_passwords set locked_until = now() - interval '1 second' where id = pw1;
  assert public.caldav_auth_lookup('abcdefg234') is not null, 'lock expires';

  -- member removed => key dead at once
  update public.org_members set status = 'revoked' where org_id = org and user_id = me;
  assert public.caldav_auth_lookup('abcdefg234') is null, 'revoked member key is dead';
  update public.org_members set status = 'active' where org_id = org and user_id = me;

  -- max 10 live keys (pw1 + 9 more = 10; the 11th is refused)
  for i in 1..9 loop
    assert public.caldav_apppw_create(me, org, 'me@x.test', 'k' || i, 'abcdefh23' || substr('abcdefgh2', i, 1), h) ? 'id', 'key ' || i;
  end loop;
  assert (public.caldav_apppw_create(me, org, 'me@x.test', 'eleventh', 'abcdefh23z', h)) ->> 'error' = 'too_many', '11th key refused';

  -- revoke
  assert (public.caldav_apppw_revoke(me, pw1)) ->> 'revoked' = '1', 'revoke';
  assert public.caldav_auth_lookup('abcdefg234') is null, 'revoked key dead';
  assert (public.caldav_apppw_revoke(gone, pw1)) ->> 'revoked' = '0', 'other user cannot revoke';
  assert jsonb_array_length(public.caldav_apppw_list(me)) >= 1 and not (public.caldav_apppw_list(me)::text like '%secret_hash%'), 'list hides hash';

  -- ctag + etag
  c0 := public.caldav_ctag(org);
  insert into public.calendar_events (id, org_id) values (ev, org);
  c1 := public.caldav_ctag(org);
  assert c1 > c0, 'insert bumps ctag';
  select dav_rev into rev0 from public.calendar_events where id = ev;
  update public.calendar_events set org_id = org where id = ev;
  select dav_rev into rev1 from public.calendar_events where id = ev;
  c2 := public.caldav_ctag(org);
  assert rev1 = rev0 + 1 and c2 > c1, 'update bumps etag and ctag';
  delete from public.calendar_events where id = ev;
  c3 := public.caldav_ctag(org);
  assert c3 > c2, 'delete bumps ctag';
  raise notice 'E80 proof ALL OK';
end $$;
rollback;
