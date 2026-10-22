-- E73 proof: calendar subscriptions. psql -v ON_ERROR_STOP=1 -f E73_proof.sql (E73 pehle lagi ho). Har assert fail par exception.
set search_path = public;
do $$
declare
  u1 uuid := gen_random_uuid(); u2 uuid := gen_random_uuid();
  h text := repeat('a', 64); r jsonb; id1 uuid; id2 uuid; n int; due jsonb; i int;
begin
  -- 1 add ok, URL list mein nahi
  r := cal_sub_add(u1, 'https://calendar.example.com/secret-token-xyz/basic.ics', h, 'PSL', '#112233', 60);
  assert (r->>'ok')::boolean, '1 add';
  id1 := (r->>'id')::uuid;
  r := cal_sub_list(u1);
  assert jsonb_array_length(r) = 1 and r->0->>'host' = 'calendar.example.com', '2 host';
  assert position('secret-token' in r::text) = 0, '3 URL list mein leak';
  -- 4 duplicate, bad input
  assert cal_sub_add(u1, 'https://calendar.example.com/secret-token-xyz/basic.ics', h, 'x', '#fff', 60)->>'error' = 'already_added', '4 dup';
  assert cal_sub_add(u1, 'http://x.example.com/a', repeat('b', 64), '', '', 60)->>'error' = 'bad_input', '5 http rad';
  assert cal_sub_add(u1, 'https://x.example.com/a', 'short', '', '', 60)->>'error' = 'bad_input', '6 hash';
  -- 7 doosra user alag
  assert (cal_sub_add(u2, 'https://calendar.example.com/secret-token-xyz/basic.ics', h, '', '', 60)->>'ok')::boolean, '7 same url doosra user';
  assert jsonb_array_length(cal_sub_list(u2)) = 1, '8 isolation';
  -- 9 limit 10
  for i in 1..9 loop perform cal_sub_add(u1, 'https://f' || i || '.example.com/a.ics', md5(i::text) || md5((i+100)::text), '', '', 60); end loop;
  assert cal_sub_add(u1, 'https://f99.example.com/a.ics', repeat('c', 64), '', '', 60)->>'error' = 'limit_reached', '9 limit';
  -- 10 refresh clamp + color fallback
  r := cal_sub_add(u2, 'https://clamp.example.com/a.ics', repeat('d', 64), '', 'red', 1);
  id2 := (r->>'id')::uuid;
  assert (select refresh_minutes from calendar_subscriptions where id = id2) = 15 and (select color from calendar_subscriptions where id = id2) = '#64748b', '10 clamp';
  -- 11 due: lease
  due := cal_sub_due(u1, null, 3);
  assert jsonb_array_length(due) = 3, '11 due 3';
  assert jsonb_array_length(cal_sub_due(u1, null, 3)) = 3, '12 agle 3 (lease ne pehle wale hataye)';
  assert (select count(*) from calendar_subscriptions where user_id = u1 and next_fetch_at > now()) = 6, '13 lease laga';
  -- 14 doosre user ke feed due mein nahi
  assert not exists (select 1 from jsonb_array_elements(cal_sub_due(u1, null, 5)) x where x->>'id' = id2::text), '14 cross-user';
  -- 15 apply
  r := cal_sub_apply(u1, id1, 'etag1', 'Wed, 21 Oct 2026 07:28:00 GMT', 'PSL 2026',
        '[{"uid":"a","rid":0,"title":"Match","start_ts":1793000000,"duration_s":5400,"tzid":"UTC","rrule":"","exdates":[]},
          {"uid":"w","rid":0,"title":"Weekly","start_ts":1793000000,"duration_s":3600,"tzid":"Asia/Karachi","rrule":"FREQ=WEEKLY","exdates":[1793604800]},
          {"uid":"w","rid":1793609600,"title":"Moved","start_ts":1793613200,"duration_s":3600,"tzid":"UTC"}]'::jsonb, '{"found":3}');
  assert (r->>'ok')::boolean and (r->>'event_count')::int = 3, '15 apply';
  assert (select name from calendar_subscriptions where id = id1) = 'PSL', '16 naam khali tha to feed ka naam; pehle wala naam bachta hai';
  assert (select etag from calendar_subscriptions where id = id1) = 'etag1' and (select fail_count from calendar_subscriptions where id = id1) = 0, '17 meta';
  assert (select exdates from calendar_subscription_events where sub_id = id1 and uid = 'w' and rid = 0) = array[1793604800::bigint], '18 exdates';
  -- 19 dobara apply poora badalta hai
  r := cal_sub_apply(u1, id1, 'etag2', null, '', '[{"uid":"only","title":"One","start_ts":1793000000,"duration_s":0}]'::jsonb, '{}');
  assert (select count(*) from calendar_subscription_events where sub_id = id1) = 1, '19 replace';
  -- 20 doosre user ka id apply nahi
  assert cal_sub_apply(u2, id1, 'x', null, '', '[]'::jsonb, '{}')->>'error' = 'not_found', '20 cross-user apply';
  -- 21 bahut events
  assert cal_sub_apply(u1, id1, 'x', null, '', (select jsonb_agg(jsonb_build_object('uid', 'e' || g, 'title', 't', 'start_ts', 1, 'duration_s', 0)) from generate_series(1, 2001) g), '{}')->>'error' = 'too_many_events', '21 cap';
  assert (select count(*) from calendar_subscription_events where sub_id = id1) = 1, '22 fail par purane events bache';
  -- 23 fail + backoff + auto disable
  r := cal_sub_fail(u1, id1, 'feed_not_found', 120);
  assert (r->>'fail_count')::int = 1 and not (r->>'disabled')::boolean, '23 fail';
  assert (select next_fetch_at > now() + interval '100 minutes' from calendar_subscriptions where id = id1), '24 backoff';
  for i in 1..29 loop perform cal_sub_fail(u1, id1, 'feed_not_found', 60); end loop;
  assert not (select enabled from calendar_subscriptions where id = id1) and (select last_error from calendar_subscriptions where id = id1) = 'disabled_too_many_failures', '25 auto disable';
  -- 26 dobara enable: fail ginti saaf
  perform cal_sub_update(u1, id1, null, null, true, null);
  assert (select enabled and fail_count = 0 and last_error is null and next_fetch_at <= now() from calendar_subscriptions where id = id1), '26 re-enable';
  -- 27 notmodified
  perform cal_sub_fail(u1, id1, 'feed_server_error', 60);
  perform cal_sub_notmodified(u1, id1);
  assert (select fail_count = 0 and last_error is null from calendar_subscriptions where id = id1), '27 304';
  -- 28 update validation
  perform cal_sub_update(u1, id1, 'Naya', '#abcdef', null, 5);
  assert (select name = 'Naya' and color = '#abcdef' and refresh_minutes = 15 from calendar_subscriptions where id = id1), '28 update';
  assert cal_sub_update(u2, id1, 'hack', null, null, null)->>'error' = 'not_found', '29 cross-user update';
  -- 30 events range
  perform cal_sub_apply(u1, id1, null, null, '', '[{"uid":"a","title":"in","start_ts":1000000,"duration_s":100},{"uid":"b","title":"far","start_ts":900000000,"duration_s":100},
        {"uid":"c","title":"rec","start_ts":1,"duration_s":100,"rrule":"FREQ=DAILY"}]'::jsonb, '{}');
  r := cal_sub_events(u1, 999000, 1100000);
  assert jsonb_array_length(r->'events') = 2 and jsonb_array_length(r->'subs') >= 1, '30 range: in + recurring, far nahi';
  assert jsonb_array_length(cal_sub_events(u2, 0, 9999999999)->'events') = 0, '31 isolation';
  -- 32 disabled feed ke events nahi
  perform cal_sub_update(u1, id1, null, null, false, null);
  assert jsonb_array_length(cal_sub_events(u1, 0, 9999999999)->'events') = 0, '32 disabled';
  -- 33 remove cascade
  r := cal_sub_remove(u1, id1);
  assert (r->>'ok')::boolean, '33 remove';
  assert not exists (select 1 from calendar_subscription_events where sub_id = id1), '33b cascade';
  assert cal_sub_remove(u1, id1)->>'error' = 'not_found', '34 dobara remove';
  -- 35 anon/authenticated seedha table/function nahi chhoo sakte
  assert not has_table_privilege('authenticated', 'calendar_subscriptions', 'select') and not has_function_privilege('authenticated', 'cal_sub_list(uuid)', 'execute'), '35 grants';
  -- 36 purge_deleted: auth.users nahi to 0 (crash nahi)
  assert calendar_sub_purge_deleted(10) >= 0, '36 purge';
  -- 37 sort/safai
  delete from calendar_subscriptions where user_id in (u1, u2);
  raise notice 'E73 proof: ALL OK';
end $$;
