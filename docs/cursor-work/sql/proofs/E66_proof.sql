-- E66 behaviour proof (sandbox ONLY, rollback). Chalao: cd docs/cursor-work/sql/proofs && psql -v ON_ERROR_STOP=1 -f E66_proof.sql
begin;
create temp table r (ord int, item text, ok boolean) on commit drop;
do $$
declare
  a uuid := gen_random_uuid(); b uuid := gen_random_uuid(); c uuid := gen_random_uuid(); d uuid := gen_random_uuid(); e uuid := gen_random_uuid();
  h text := repeat('a', 64); k text := repeat('b', 64); em text := repeat('c', 64); sh text := repeat('d', 64); nw text := repeat('e', 64); fresh text := repeat('f', 64);
  res jsonb; n int; raised boolean;
  sigs_a jsonb := jsonb_build_array(jsonb_build_object('kind','device_key','hmac',repeat('a',64)), jsonb_build_object('kind','email','hmac',repeat('c',64)),
                   jsonb_build_object('kind','device_shape','hmac',repeat('d',64)), jsonb_build_object('kind','network','hmac',repeat('e',64)));
begin
  insert into auth.users (id) select u from unnest(array[a, b, c, d, e]) u on conflict do nothing;

  res := public.identity_signup_check(jsonb_build_array(jsonb_build_object('kind','device_key','hmac',fresh)));
  insert into r values (1, 'bilkul naye nishan => allow', res ->> 'decision' = 'allow');

  res := public.identity_register(a, sigs_a);
  insert into r values (2, 'register: 4 nishan likhe, decision allow', (res ->> 'registered')::int = 4 and res ->> 'decision' = 'allow');
  res := public.identity_register(a, sigs_a);
  insert into r values (3, 'dobara register: duplicate nahi (4 hi row), seen_count badha',
    (select count(*) from public.identity_signals where account_id = a) = 4 and (select max(seen_count) from public.identity_signals where account_id = a) = 2);
  insert into r values (4, 'email ka retain_until NULL, device_key/network ka finite',
    (select retain_until is null from public.identity_signals where account_id = a and kind = 'email')
    and (select retain_until is not null from public.identity_signals where account_id = a and kind = 'device_key')
    and (select retain_until < now() + interval '31 days' from public.identity_signals where account_id = a and kind = 'network'));

  -- DB constraint: email par retain_until likhna mana
  raised := false;
  begin insert into public.identity_signals (account_id, kind, hmac, retain_until) values (a, 'email', decode(fresh, 'hex'), now() + interval '1 day');
  exception when check_violation then raised := true; end;
  insert into r values (5, 'email par retain_until likhna DB constraint se mana', raised);
  raised := false;
  begin insert into public.identity_signals (account_id, kind, hmac) values (a, 'network', decode(fresh, 'hex'));
  exception when check_violation then raised := true; end;
  insert into r values (6, 'network bina retain_until mana', raised);

  -- ban
  res := public.identity_ban_account(a, 'abuse', false, null);
  insert into r values (7, 'ban: 4 nishan blacklist mein', (res ->> 'banned')::int = 4);
  delete from auth.users where id = a;
  insert into r values (8, 'account delete => signals khud mit gaye, bans bache', (select count(*) from public.identity_signals where account_id = a) = 0
    and (select count(*) from public.identity_bans where source_ref = a) = 4);

  res := public.identity_signup_check(jsonb_build_array(jsonb_build_object('kind','email','hmac',em)));
  insert into r values (9, 'wahi email dobara => DENY (account delete ke baad bhi)', res ->> 'decision' = 'deny' and res -> 'matched' = '["email"]'::jsonb);
  res := public.identity_signup_check(jsonb_build_array(jsonb_build_object('kind','device_key','hmac',h)));
  insert into r values (10, 'wahi browser key => DENY', res ->> 'decision' = 'deny');
  insert into r values (11, 'jawab mein hash ya account kahin nahi', res::text not like '%' || h || '%' and res::text not like '%' || a::text || '%');

  res := public.identity_signup_check(jsonb_build_array(jsonb_build_object('kind','device_shape','hmac',sh)));
  insert into r values (12, 'sirf ek kamzor milan => allow (ek jaise device wale bekasoor nahi rukte)', res ->> 'decision' = 'allow');
  res := public.identity_signup_check(jsonb_build_array(jsonb_build_object('kind','device_shape','hmac',sh), jsonb_build_object('kind','network','hmac',nw)));
  insert into r values (13, 'do kamzor milan => REVIEW, deny nahi', res ->> 'decision' = 'review');

  res := public.identity_register(b, jsonb_build_array(jsonb_build_object('kind','email','hmac',em), jsonb_build_object('kind','device_key','hmac',fresh)));
  insert into r values (14, 'register par bhi deny; kuch likha nahi', res ->> 'decision' = 'deny' and (select count(*) from public.identity_signals where account_id = b) = 0);

  -- appeal
  res := public.identity_ban_lift(a, d);
  insert into r values (15, 'appeal manzoor: abuse ban hat gaye', (res ->> 'lifted')::int = 4
    and (public.identity_signup_check(jsonb_build_array(jsonb_build_object('kind','email','hmac',em))) ->> 'decision') = 'allow');

  -- severe: hamesha + appeal nahi
  perform public.identity_register(c, jsonb_build_array(jsonb_build_object('kind','payment','hmac',k)));
  perform public.identity_ban_account(c, 'severe_pattern', false, null);
  insert into r values (16, 'severe: expires NULL (hamesha), appealable false', (select expires_at is null and not appealable from public.identity_bans where source_ref = c limit 1));
  res := public.identity_ban_lift(c, d);
  insert into r values (17, 'severe ban appeal se nahi hatta', (res ->> 'lifted')::int = 0
    and (public.identity_signup_check(jsonb_build_array(jsonb_build_object('kind','payment','hmac',k))) ->> 'decision') = 'deny');

  -- shared device_key (3 accounts)
  perform public.identity_register(d, jsonb_build_array(jsonb_build_object('kind','device_key','hmac',fresh)));
  perform public.identity_register(e, jsonb_build_array(jsonb_build_object('kind','device_key','hmac',fresh)));
  res := public.identity_signup_check(jsonb_build_array(jsonb_build_object('kind','device_key','hmac',fresh)));
  insert into r values (18, '2 accounts ek key par: abhi allow', res ->> 'decision' = 'allow');
  perform public.identity_register(b, jsonb_build_array(jsonb_build_object('kind','device_key','hmac',fresh)));
  res := public.identity_signup_check(jsonb_build_array(jsonb_build_object('kind','device_key','hmac',fresh)));
  insert into r values (19, '3 accounts ek browser key par => REVIEW (shared_device)', res ->> 'decision' = 'review' and res ->> 'reason' = 'shared_device');

  -- shape validation
  raised := false; begin perform public.identity_signup_check('[{"kind":"email","hmac":"XYZ"}]'::jsonb); exception when sqlstate '22023' then raised := true; end;
  insert into r values (20, 'ghalat hmac => bad_signals', raised);
  raised := false; begin perform public.identity_signup_check(('[{"kind":"fingerprint","hmac":"' || repeat('a', 64) || '"}]')::jsonb); exception when sqlstate '22023' then raised := true; end;
  insert into r values (21, 'anjaan kind => bad_signals', raised);
  raised := false; begin perform public.identity_signup_check('{}'::jsonb); exception when sqlstate '22023' then raised := true; end;
  insert into r values (22, 'array nahi => bad_signals', raised);
  raised := false; begin perform public.identity_ban_account(d, 'because', false, null); exception when sqlstate '22023' then raised := true; end;
  insert into r values (23, 'ghalat wajah => bad_reason', raised);

  -- purge
  update public.identity_signals set retain_until = now() - interval '1 day' where account_id = d;
  insert into public.identity_bans (kind, hmac, reason, expires_at) values ('email', decode(repeat('9', 64), 'hex'), 'spam', now() - interval '40 days');
  res := public.identity_vault_purge();
  insert into r values (24, 'purge: expiry guzre signals aur purane ban saaf, baqi salamat', (res ->> 'signals')::int >= 1 and (res ->> 'bans')::int >= 1
    and (select count(*) from public.identity_bans where source_ref = c) >= 1);

  -- privileges + RLS
  insert into r values (25, 'anon/authenticated kuch nahi chala sakte; service_role chala sakta hai',
    not has_function_privilege('anon', 'public.identity_signup_check(jsonb)', 'execute') and not has_function_privilege('authenticated', 'public.identity_register(uuid,jsonb)', 'execute')
    and has_function_privilege('service_role', 'public.identity_ban_account(uuid,text,boolean,uuid)', 'execute')
    and not has_table_privilege('authenticated', 'public.identity_bans', 'select') and not has_table_privilege('anon', 'public.identity_signals', 'select'));
  insert into r values (26, 'chaaron tables par RLS ON', (select count(*) from pg_class where relname in ('identity_vault_policy','identity_signals','identity_bans','identity_vault_audit') and relrowsecurity) = 4);
  insert into r values (27, 'audit mein hash nahi: sirf ginti/kind', not exists (select 1 from public.identity_vault_audit where detail::text ~ '[0-9a-f]{40}'));
end $$;
select ord, item, ok from r order by ord;
rollback;
