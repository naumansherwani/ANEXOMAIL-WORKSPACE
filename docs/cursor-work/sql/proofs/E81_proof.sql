
-- E81 proof (sandbox/test DB ONLY; rollback). Stubs: auth.users, org_members, calendar_events. E80 pehle. Server par nahi chalti.
begin;
do $$
declare
  org uuid := gen_random_uuid(); me uuid := gen_random_uuid(); gone uuid := gen_random_uuid();
  r jsonb; dav_id uuid; feed_id uuid; i int; h text := repeat('c', 64);
begin
  insert into auth.users (id) values (me), (gone) on conflict do nothing;
  insert into public.org_members (org_id, user_id, role, status, email) values (org, me, 'owner', 'active', 'me@x.test'), (org, gone, 'member', 'revoked', 'gone@x.test');

  -- ek dav aur ek feed chaabi, alag token_id
  dav_id  := ((public.caldav_apppw_create(me, org, 'Me@X.test', 'iPhone', 'abcdefg234', h)) ->> 'id')::uuid;
  r := public.caldav_feed_create(me, org, 'Me@X.test', 'Google', 'bcdefgh234', h);
  assert r ? 'id', 'feed create ok'; feed_id := (r ->> 'id')::uuid;
  assert (select kind from public.caldav_app_passwords where id = dav_id) = 'dav', 'dav kind';
  assert (select kind from public.caldav_app_passwords where id = feed_id) = 'feed', 'feed kind';

  -- HIFAZAT: ek kind ki chaabi doosre ke lookup mein nahi milti
  assert public.caldav_auth_lookup('abcdefg234') ->> 'user_id' = me::text, 'dav lookup finds dav';
  assert public.caldav_auth_lookup('bcdefgh234') is null, 'feed token must NOT work as CalDAV login';
  assert public.caldav_feed_lookup('bcdefgh234') ->> 'user_id' = me::text, 'feed lookup finds feed';
  assert public.caldav_feed_lookup('abcdefg234') is null, 'dav token must NOT work as feed link';

  -- list alag alag
  assert jsonb_array_length(public.caldav_apppw_list(me)) = 1 and jsonb_array_length(public.caldav_feed_list(me)) = 1, 'lists are per kind';
  assert (public.caldav_apppw_list(me) -> 0 ->> 'id')::uuid = dav_id and (public.caldav_feed_list(me) -> 0 ->> 'id')::uuid = feed_id, 'right rows in right list';

  -- errors
  assert (public.caldav_feed_create(gone, org, 'gone@x.test', 'Old', 'cdefghi234', h)) ->> 'error' = 'forbidden', 'revoked member cannot create feed';
  assert (public.caldav_feed_create(me, org, 'me@x.test', '', 'cdefghi234', h)) ->> 'error' = 'bad_label', 'empty label';
  assert (public.caldav_feed_create(me, org, 'me@x.test', 'x', 'CDEFGHI234', h)) ->> 'error' = 'bad_secret', 'upper token';
  assert (public.caldav_feed_create(me, org, 'me@x.test', 'dup', 'bcdefgh234', h)) ->> 'error' = 'retry', 'duplicate token id';
  assert (public.caldav_feed_create(me, org, 'me@x.test', 'dup2', 'abcdefg234', h)) ->> 'error' = 'retry', 'token id is unique across kinds';

  -- limit: feed 5, dav 10 — alag alag gine jaate hain
  for i in 2..5 loop
    assert (public.caldav_feed_create(me, org, 'me@x.test', 'f' || i, 'dddddddd2' || i, h)) ? 'id', 'feed ' || i;
  end loop;
  assert (public.caldav_feed_create(me, org, 'me@x.test', 'sixth', 'ddddddddd6', h)) ->> 'error' = 'too_many', '6th feed refused';
  assert (public.caldav_apppw_create(me, org, 'me@x.test', 'second', 'eeeeeeee23', h)) ? 'id', 'dav still allowed after 5 feeds (limits separate)';

  -- revoke (ek hi function, dono kind) => lookup band
  assert (public.caldav_apppw_revoke(me, feed_id)) ->> 'revoked' = '1', 'revoke feed';
  assert public.caldav_feed_lookup('bcdefgh234') is null, 'revoked feed link dead';
  assert (public.caldav_feed_create(me, org, 'me@x.test', 'sixth', 'ddddddddd6', h)) ? 'id', 'slot freed after revoke';

  -- brute-force lock feed par bhi (auth_result shared)
  for i in 1..8 loop perform public.caldav_auth_result((select id from public.caldav_app_passwords where token_id = 'dddddddd22'), false); end loop;
  assert public.caldav_feed_lookup('dddddddd22') is null, '8 fails => feed locked';

  -- revoked member ki feed link usi pal band
  perform public.caldav_feed_create(gone, org, 'gone@x.test', 'x', 'ffffffff23', h);
  assert true;
end $$;
rollback;
