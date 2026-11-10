
-- ==============================================================================================================================
-- E152 (G-MIX 2b, 10 Nov 2026 18:40 PKT) - FOUNDER: the sign-in is ONE-FACTOR BY HIS WORD, and a PASSKEY may sign in on its own.
-- Founder order 10 Nov 2026 18:26 (verbatim gist): "mujhe apne liye 2fa nahi chaiye". E151 forced a second step as soon as the founder had a
-- passkey or a TOTP factor; that would have turned every passkey he enrols into a hidden 2FA on his password login. This file fixes that,
-- WITHOUT weakening anything that must stay hard:
--   1) founder_signin_policy.second_step  'off' (default, his choice) | 'required'. A CHECK keeps the two words, a trigger writes every change to
--      the hash-chained event ledger (kind 'policy'), so the setting is never changed silently. 'required' stays available for the day he wants it.
--   2) a new first-step method 'passkey': the browser proves a passkey (user verification, checked in Rust by passkey.rs); the ticket is born OPEN and
--      the ONLY thing that completes it is founder_signin_factor(... 'passkey' ...) with a credential that is HIS and not revoked. A passkey is
--      "something you have + something you are" in one step, so it is a first factor, not a second one.
--   3) a magic link STILL never opens the founder alone (frozen, E151): with second_step 'off' the link is refused outright, exactly as before.
--   4) the doors keep their E151 signatures (Rust does not change); only the rule inside founder_signin_open moves.
-- Never edit E151 (GREEN). This file only ALTERs and CREATE OR REPLACEs, and is safe to run twice.
-- ==============================================================================================================================

do $$
begin
  perform pg_advisory_xact_lock(hashtextextended('founder_signin:ddl152', 0));

  -- 1 the policy word
  alter table public.founder_signin_policy add column if not exists second_step text not null default 'off';
  if not exists (select 1 from pg_constraint where conname = 'founder_signin_policy_second_step_words' and conrelid = 'public.founder_signin_policy'::regclass) then
    alter table public.founder_signin_policy add constraint founder_signin_policy_second_step_words check (second_step in ('off', 'required'));
  end if;

  -- 2 the ledger learns the word 'policy' (rebuilt with every old kind kept)
  alter table public.founder_signin_events drop constraint if exists founder_signin_events_kind_check;
  alter table public.founder_signin_events add constraint founder_signin_events_kind_check
    check (kind in ('opened', 'completed', 'released', 'denied', 'expired', 'factor_ok', 'factor_fail', 'locked', 'magic_issued', 'magic_landed',
                    'magic_refused', 'reject_ip', 'reject_double_release', 'reject_state', 'reject_shape', 'test', 'policy'));

  -- 3 tickets and hand-offs may carry the method 'passkey'
  alter table public.founder_signin_tickets drop constraint if exists founder_signin_tickets_method_check;
  alter table public.founder_signin_tickets add constraint founder_signin_tickets_method_check check (method in ('password', 'magic_link', 'passkey'));
  alter table public.founder_signin_handoffs drop constraint if exists founder_signin_handoffs_method_check;
  alter table public.founder_signin_handoffs add constraint founder_signin_handoffs_method_check check (method in ('password', 'magic_link', 'passkey'));

  -- 4 a passkey ticket always carries the passkey as the step it needs (it can never be born complete)
  if not exists (select 1 from pg_constraint where conname = 'founder_signin_passkey_needs_passkey' and conrelid = 'public.founder_signin_tickets'::regclass) then
    alter table public.founder_signin_tickets add constraint founder_signin_passkey_needs_passkey
      check (method <> 'passkey' or state = 'denied' or (second_required and 'passkey' = any (need_any)));
  end if;
end $$;

-- every change of the word is written to the chained ledger (who changed it is the database role; the value is in the facts)
create or replace function public._signin_policy_audit() returns trigger language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
begin
  if new.second_step is distinct from old.second_step then
    perform public._signin_log(null, 'policy', null, null, jsonb_build_object('second_step_from', old.second_step, 'second_step_to', new.second_step));
  end if;
  return new;
end $$;
drop trigger if exists founder_signin_policy_audit on public.founder_signin_policy;
create trigger founder_signin_policy_audit after update on public.founder_signin_policy for each row execute function public._signin_policy_audit();

-- step 1 done (password right / magic link landed / a passkey was proven by Rust). Opens a ticket. Same signature as E151.
-- p_totp = the identity service says a verified TOTP factor exists (only matters when the policy says 'required').
create or replace function public.founder_signin_open(p_uid uuid, p_ticket_hash text, p_net_hash text, p_device_hash text, p_method text, p_totp boolean default false) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '8s' as $$
declare v_pol public.founder_signin_policy%rowtype; v_keys integer; v_need text[] := '{}'; v_second boolean; v_lock jsonb; v_exp timestamptz; v_state text;
begin
  if p_uid is null or not public._signin_h64(p_ticket_hash) or not public._signin_h64(p_net_hash) or (p_device_hash is not null and not public._signin_h64(p_device_hash))
     or p_method is null or p_method not in ('password', 'magic_link', 'passkey') then
    perform public._signin_log(p_uid, 'reject_shape', null, case when public._signin_h64(p_net_hash) then p_net_hash end, jsonb_build_object('door', 'open'));
    return jsonb_build_object('ok', false, 'error', 'shape'); end if;
  if not exists (select 1 from public.founder_accounts where user_id = p_uid) then
    perform public._signin_log(null, 'denied', p_ticket_hash, p_net_hash, jsonb_build_object('why', 'not_founder'));
    return jsonb_build_object('ok', false, 'error', 'denied'); end if;
  perform pg_advisory_xact_lock(hashtextextended('founder_signin:uid:' || p_uid::text, 0));
  select * into v_pol from public.founder_signin_policy;
  v_lock := public.founder_signin_locked(p_uid, p_net_hash);
  if (v_lock ->> 'locked')::boolean then
    perform public._signin_log(p_uid, 'locked', p_ticket_hash, p_net_hash, jsonb_build_object('fails', v_lock -> 'fails'));
    return jsonb_build_object('ok', false, 'error', 'locked', 'retry_s', v_lock -> 'retry_s'); end if;
  select count(*)::integer into v_keys from public.founder_passkeys where user_id = p_uid and revoked_at is null;
  if v_keys > 0 then v_need := v_need || 'passkey'::text; end if;
  if coalesce(p_totp, false) then v_need := v_need || 'totp'::text; end if;
  if exists (select 1 from public.founder_recovery_requests where user_id = p_uid and state = 'ready' and expires_at > now()) then v_need := v_need || 'recovery'::text; end if;

  if p_method = 'passkey' then
    -- the passkey IS the step: it needs a live passkey of his, and nothing else is offered
    if v_keys = 0 then
      perform public._signin_log(p_uid, 'denied', p_ticket_hash, p_net_hash, jsonb_build_object('why', 'no_passkey'));
      return jsonb_build_object('ok', false, 'error', 'denied'); end if;
    v_need := array['passkey']::text[]; v_second := true;
  else
    -- his word: second step only when the policy says 'required' AND he has a factor enrolled
    v_second := v_pol.second_step = 'required' and ((v_keys > 0) or coalesce(p_totp, false));
    -- a mailbox alone never opens the founder (frozen): with no second step on, the link is refused outright
    if p_method = 'magic_link' and not v_second then
      perform public._signin_log(p_uid, 'denied', p_ticket_hash, p_net_hash, jsonb_build_object('why', 'magic_alone'));
      return jsonb_build_object('ok', false, 'error', 'denied'); end if;
    if not v_second then v_need := '{}'; end if;     -- one-factor: nothing is offered, the password is enough
  end if;

  v_exp := now() + make_interval(secs => v_pol.ticket_ttl_s);
  v_state := case when v_second then 'open' else 'complete' end;
  insert into public.founder_signin_tickets (ticket_hash, user_id, method, net_hash, device_hash, need_any, second_required, state, expires_at, completed_at)
  values (p_ticket_hash, p_uid, p_method, p_net_hash, p_device_hash, v_need, v_second, v_state, v_exp, case when v_second then null else now() end)
  on conflict do nothing;
  if not found then
    perform public._signin_log(p_uid, 'reject_state', p_ticket_hash, p_net_hash, jsonb_build_object('why', 'ticket_reused'));
    return jsonb_build_object('ok', false, 'error', 'denied'); end if;
  perform public._signin_log(p_uid, 'opened', p_ticket_hash, p_net_hash, jsonb_build_object('method', p_method, 'need', to_jsonb(v_need), 'second', v_second, 'policy', v_pol.second_step));
  if v_state = 'complete' then perform public._signin_log(p_uid, 'completed', p_ticket_hash, p_net_hash, jsonb_build_object('second', false)); end if;
  return jsonb_build_object('ok', true, 'state', v_state, 'second_required', v_second, 'need', to_jsonb(v_need), 'expires_ms', (extract(epoch from v_exp) * 1000)::bigint);
end $$;

-- ------------------------------------------------------------------------------------------------------------------------------
-- behaviour selftest (rolled back by a sentinel exception, nothing persists)
-- ------------------------------------------------------------------------------------------------------------------------------
create or replace function public.founder_signin_selftest152() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare
  v_uid uuid; v_net text := encode(extensions.digest('e152-net', 'sha256'), 'hex');
  v_t1 text := encode(extensions.digest('e152-t1', 'sha256'), 'hex'); v_t2 text := encode(extensions.digest('e152-t2', 'sha256'), 'hex');
  v_t3 text := encode(extensions.digest('e152-t3', 'sha256'), 'hex'); v_t4 text := encode(extensions.digest('e152-t4', 'sha256'), 'hex');
  v_t5 text := encode(extensions.digest('e152-t5', 'sha256'), 'hex'); v_t6 text := encode(extensions.digest('e152-t6', 'sha256'), 'hex');
  v_cred text := 'e152selftestcredential01'; v_other text := 'e152selftestcredential99'; v_r jsonb; v_msg text := 'E152 selftest FAIL: unknown'; v_n integer;
begin
  select user_id into v_uid from public.founder_accounts order by user_id limit 1;
  if v_uid is null then return 'E152 selftest SKIP - no founder account'; end if;
  begin
    -- 0 the default is HIS choice: one factor
    if (select second_step from public.founder_signin_policy) <> 'off' then raise exception 'the default is not off'; end if;
    -- 1 no passkey: a passkey ticket is refused, a password ticket completes at once
    delete from public.founder_passkeys where user_id = v_uid and credential_id in (v_cred, v_other);
    -- his real passkeys (he has enrolled some) must not leak into the test: park them as revoked INSIDE this rolled-back block
    update public.founder_passkeys set revoked_at = now(), revoked_reason = 'e152 selftest park' where user_id = v_uid and revoked_at is null;
    if public.founder_signin_open(v_uid, v_t1, v_net, null, 'passkey', false) ->> 'ok' = 'true' then raise exception 'a passkey ticket opened with no passkey'; end if;
    v_r := public.founder_signin_open(v_uid, v_t2, v_net, null, 'password', false);
    if v_r ->> 'state' <> 'complete' or (v_r ->> 'second_required')::boolean then raise exception 'password did not complete alone: %', v_r; end if;
    -- 2 enrol a passkey: with the word off, the password login STILL completes alone (the hidden-2FA bug E151 had)
    insert into public.founder_passkeys (user_id, credential_id, passkey, label) values (v_uid, v_cred, '{}'::jsonb, 'e152 selftest');
    v_r := public.founder_signin_open(v_uid, v_t3, v_net, null, 'password', false);
    if v_r ->> 'state' <> 'complete' or (v_r ->> 'second_required')::boolean or jsonb_array_length(v_r -> 'need') <> 0 then raise exception 'a passkey forced a second step: %', v_r; end if;
    -- 3 a magic link is still refused with the word off, even with a passkey enrolled
    v_r := public.founder_signin_open(v_uid, v_t4, v_net, null, 'magic_link', false);
    if v_r ->> 'ok' = 'true' then raise exception 'a magic link opened the founder alone'; end if;
    -- 4 passkey as the first step: born open, only a passkey of HIS completes it, a foreign credential is refused, then released once
    v_r := public.founder_signin_open(v_uid, v_t5, v_net, null, 'passkey', false);
    if v_r ->> 'state' <> 'open' or not ((v_r -> 'need') ? 'passkey') or jsonb_array_length(v_r -> 'need') <> 1 then raise exception 'passkey ticket shape: %', v_r; end if;
    if public.founder_signin_release(v_t5, v_net) ->> 'ok' = 'true' then raise exception 'an open passkey ticket was released'; end if;
    if public.founder_signin_factor(v_t5, v_net, 'passkey', true, v_other) ->> 'ok' = 'true' then raise exception 'a foreign credential completed a passkey ticket'; end if;
    if public.founder_signin_factor(v_t5, v_net, 'passkey', false, v_cred) ->> 'ok' = 'true' then raise exception 'a rejected proof completed a passkey ticket'; end if;
    v_r := public.founder_signin_factor(v_t5, v_net, 'passkey', true, v_cred);
    if v_r ->> 'state' <> 'complete' then raise exception 'passkey did not complete: %', v_r; end if;
    if public.founder_signin_release(v_t5, v_net) ->> 'ok' <> 'true' then raise exception 'complete passkey ticket not released'; end if;
    if public.founder_signin_release(v_t5, v_net) ->> 'ok' = 'true' then raise exception 'passkey ticket released twice'; end if;
    -- 5 a revoked passkey cannot open a passkey ticket
    update public.founder_passkeys set revoked_at = now(), revoked_reason = 'e152 selftest' where user_id = v_uid and credential_id = v_cred;
    if public.founder_signin_open(v_uid, v_t6, v_net, null, 'passkey', false) ->> 'ok' = 'true' then raise exception 'a revoked passkey opened a ticket'; end if;
    update public.founder_passkeys set revoked_at = null, revoked_reason = null where user_id = v_uid and credential_id = v_cred;
    -- 6 the word is checked and every change is chained: bad word refused, 'required' brings the E151 behaviour back, the change is in the ledger
    begin update public.founder_signin_policy set second_step = 'sometimes'; raise exception 'bad word accepted'; exception when check_violation then null; end;
    select count(*) into v_n from public.founder_signin_events where kind = 'policy';
    update public.founder_signin_policy set second_step = 'required';
    if (select count(*) from public.founder_signin_events where kind = 'policy') <> v_n + 1 then raise exception 'the policy change was not chained'; end if;
    v_r := public.founder_signin_open(v_uid, encode(extensions.digest('e152-t7', 'sha256'), 'hex'), v_net, null, 'password', false);
    if v_r ->> 'state' <> 'open' or not (v_r ->> 'second_required')::boolean then raise exception 'required did not bring the second step back: %', v_r; end if;
    -- 7 the ledger still verifies
    if public.founder_signin_verify(100000) ->> 'ok' <> 'true' then raise exception 'chain does not verify: %', public.founder_signin_verify(100000); end if;
    v_msg := 'E152 selftest PASS (one factor by default, passkey never forces a second step, passkey signs in alone, foreign/revoked refused, magic never alone, word checked + chained)';
    raise exception 'e152_rollback' using errcode = 'P0001';
  exception when others then
    if sqlerrm = 'e152_rollback' then null; else v_msg := 'E152 selftest FAIL: ' || sqlerrm; end if;
  end;
  return v_msg;
end $$;

-- the two E151 selftests assert the second-step behaviour; they keep doing so by switching the word to 'required' inside their own rolled-back block
create or replace function public.founder_signin_selftest() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare
  v_uid uuid; v_net text := encode(extensions.digest('e151-net', 'sha256'), 'hex'); v_net2 text := encode(extensions.digest('e151-net2', 'sha256'), 'hex');
  v_t1 text := encode(extensions.digest('e151-t1', 'sha256'), 'hex'); v_t2 text := encode(extensions.digest('e151-t2', 'sha256'), 'hex');
  v_t3 text := encode(extensions.digest('e151-t3', 'sha256'), 'hex'); v_t4 text := encode(extensions.digest('e151-t4', 'sha256'), 'hex');
  v_m1 text := encode(extensions.digest('e151-m1', 'sha256'), 'hex'); v_cred text := 'e151selftestcredential01'; v_cred2 text := 'e151selftestcredential02';
  v_r jsonb; v_msg text := 'E151 selftest FAIL: unknown'; v_i integer;
begin
  select user_id into v_uid from public.founder_accounts order by user_id limit 1;
  if v_uid is null then return 'E151 selftest SKIP - no founder account'; end if;
  begin
    update public.founder_signin_policy set second_step = 'required';   -- E152: this E151 test proves the two-step rules, so it asks for them (rolled back with everything else)
    -- 1 no second factor enrolled: password alone completes at once, release works once, the second release is refused
    update public.founder_passkeys set revoked_at = now(), revoked_reason = 'e151 selftest hold' where user_id = v_uid and revoked_at is null;
    v_r := public.founder_signin_open(v_uid, v_t1, v_net, null, 'password', false);
    if v_r ->> 'state' <> 'complete' or (v_r ->> 'second_required')::boolean then raise exception 'no-factor password did not complete: %', v_r; end if;
    if public.founder_signin_release(v_t1, v_net2) ->> 'ok' = 'true' then raise exception 'release from another network accepted'; end if;
    if (select state from public.founder_signin_tickets where ticket_hash = v_t1) <> 'denied' then raise exception 'net change did not deny the ticket'; end if;
    -- 2 a fresh ticket releases once
    v_r := public.founder_signin_open(v_uid, v_t2, v_net, null, 'password', false);
    if public.founder_signin_release(v_t2, v_net) ->> 'ok' <> 'true' then raise exception 'complete ticket not released'; end if;
    if public.founder_signin_release(v_t2, v_net) ->> 'ok' = 'true' then raise exception 'double release accepted'; end if;
    -- 3 magic link with no second factor: refused outright (a mailbox alone never opens the founder)
    v_r := public.founder_signin_open(v_uid, v_t3, v_net, null, 'magic_link', false);
    if v_r ->> 'ok' = 'true' then raise exception 'magic link alone was accepted'; end if;
    -- 4 enrol a passkey: the second step is now required
    insert into public.founder_passkeys (user_id, credential_id, passkey, label) values (v_uid, v_cred, '{}'::jsonb, 'e151 selftest');
    v_r := public.founder_signin_open(v_uid, v_t3, v_net, null, 'password', false);
    if v_r ->> 'state' <> 'open' or not (v_r ->> 'second_required')::boolean or not ((v_r -> 'need') ? 'passkey') then raise exception 'second step not required: %', v_r; end if;
    if public.founder_signin_release(v_t3, v_net) ->> 'ok' = 'true' then raise exception 'open ticket released without a second step'; end if;
    -- 5 wrong credential refused, factor not offered refused, then the right one completes
    if public.founder_signin_factor(v_t3, v_net, 'passkey', true, v_cred2) ->> 'ok' = 'true' then raise exception 'foreign credential accepted'; end if;
    if public.founder_signin_factor(v_t3, v_net, 'totp', true, null) ->> 'ok' = 'true' then raise exception 'a factor that was not offered was accepted'; end if;
    if public.founder_signin_factor(v_t3, v_net, 'passkey', false, v_cred) ->> 'ok' = 'true' then raise exception 'a rejected proof was accepted'; end if;
    v_r := public.founder_signin_factor(v_t3, v_net, 'passkey', true, v_cred);
    if v_r ->> 'ok' <> 'true' or v_r ->> 'state' <> 'complete' then raise exception 'good passkey did not complete: %', v_r; end if;
    if public.founder_signin_release(v_t3, v_net) ->> 'ok' <> 'true' then raise exception 'second-step ticket not released'; end if;
    -- 6 revoked credential no longer counts
    update public.founder_passkeys set revoked_at = now(), revoked_reason = 'e151 selftest revoke' where credential_id = v_cred;
    -- 7 magic link single use
    insert into public.founder_passkeys (user_id, credential_id, passkey, label) values (v_uid, v_cred2, '{}'::jsonb, 'e151 selftest 2');
    if public.founder_magic_issue(v_uid, v_m1, v_net) ->> 'send' <> 'true' then raise exception 'magic link not issued'; end if;
    if public.founder_magic_land(v_m1, v_net) ->> 'ok' <> 'true' then raise exception 'magic link did not land'; end if;
    if public.founder_magic_land(v_m1, v_net) ->> 'ok' = 'true' then raise exception 'magic link used twice'; end if;
    -- 8 frozen cores, forward-only, append-only
    begin update public.founder_signin_tickets set net_hash = v_net2 where ticket_hash = v_t3; raise exception 'ticket core changed'; exception when sqlstate '42501' then null; end;
    begin update public.founder_signin_tickets set state = 'open' where ticket_hash = v_t3; raise exception 'ticket went back'; exception when sqlstate '42501' then null; end;
    begin delete from public.founder_signin_tickets where ticket_hash = v_t3; raise exception 'ticket deleted'; exception when sqlstate '42501' then null; end;
    begin update public.founder_signin_events set kind = 'test' where id = (select max(id) from public.founder_signin_events); raise exception 'event update allowed'; exception when sqlstate '42501' then null; end;
    begin delete from public.founder_magic_links where token_hash = v_m1; raise exception 'young link deleted'; exception when sqlstate '42501' then null; end;
    begin delete from public.founder_signin_policy; raise exception 'policy deleted'; exception when sqlstate '42501' then null; end;
    begin update public.founder_signin_policy set magic_needs_second = false; raise exception 'magic_needs_second switched off'; exception when check_violation then null; end;
    -- 9 lockout: five failed second steps from one network lock the founder and the network
    v_r := public.founder_signin_open(v_uid, v_t4, v_net2, null, 'password', false);
    for v_i in 1..5 loop perform public._signin_log(v_uid, 'factor_fail', v_t4, v_net2, '{"factor":"passkey","reason":"proof_rejected"}'::jsonb); end loop;
    if public.founder_signin_locked(v_uid, v_net2) ->> 'locked' <> 'true' then raise exception 'five failures did not lock'; end if;
    if public.founder_signin_open(v_uid, encode(extensions.digest('e151-t5', 'sha256'), 'hex'), v_net2, null, 'password', false) ->> 'error' <> 'locked' then raise exception 'a locked founder opened a ticket'; end if;
    -- 10 the chain verifies and the report reads
    if public.founder_signin_verify(100000) ->> 'ok' <> 'true' then raise exception 'chain does not verify: %', public.founder_signin_verify(100000); end if;
    if public.founder_signin_report(v_uid, 24) -> 'counts' is null then raise exception 'report empty'; end if;
    v_msg := 'E151 selftest PASS (open, factor, release once, magic never alone, single-use link, frozen cores, lockout, chain)';
    raise exception 'e151_rollback' using errcode = 'P0001';
  exception when others then
    if sqlerrm = 'e151_rollback' then null; else v_msg := 'E151 selftest FAIL: ' || sqlerrm; end if;
  end;
  return v_msg;
end $$;

create or replace function public.founder_signin_selftest2() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare
  v_uid uuid; v_net text := encode(extensions.digest('e151b-net', 'sha256'), 'hex'); v_net3 text := encode(extensions.digest('e151b-net3', 'sha256'), 'hex');
  v_a text := encode(extensions.digest('e151b-a', 'sha256'), 'hex'); v_b text := encode(extensions.digest('e151b-b', 'sha256'), 'hex');
  v_c text := encode(extensions.digest('e151b-c', 'sha256'), 'hex'); v_d text := encode(extensions.digest('e151b-d', 'sha256'), 'hex');
  v_cred text := 'e151btestcredential001'; v_r jsonb; v_req uuid; v_msg text := 'E151 selftest2 FAIL: unknown'; v_risk jsonb;
begin
  select user_id into v_uid from public.founder_accounts order by user_id limit 1;
  if v_uid is null then return 'E151 selftest2 SKIP - no founder account'; end if;
  begin
    update public.founder_signin_policy set second_step = 'required';   -- E152: this E151 test proves the two-step rules, so it asks for them (rolled back with everything else)
    update public.founder_passkeys set revoked_at = now(), revoked_reason = 'e151b selftest hold' where user_id = v_uid and revoked_at is null;
    -- 1 shapes are refused and logged, a stranger (not a founder) gets the generic denial
    if public.founder_signin_open(v_uid, 'nothex', v_net, null, 'password', false) ->> 'error' <> 'shape' then raise exception 'bad ticket hash accepted'; end if;
    if public.founder_signin_open(v_uid, v_a, v_net, null, 'sms', false) ->> 'error' <> 'shape' then raise exception 'unknown method accepted'; end if;
    if public.founder_signin_open('22222222-2222-2222-2222-222222222222', v_a, v_net, null, 'password', false) ->> 'error' <> 'denied' then raise exception 'non-founder not denied'; end if;
    -- 2 a ticket hash is single use
    v_r := public.founder_signin_open(v_uid, v_a, v_net, null, 'password', false);
    if v_r ->> 'ok' <> 'true' then raise exception 'open failed: %', v_r; end if;
    if public.founder_signin_open(v_uid, v_a, v_net, null, 'password', false) ->> 'ok' = 'true' then raise exception 'ticket hash reused'; end if;
    -- 3 hand-off: first release comes from a NEW network, the second from a KNOWN one
    v_r := public.founder_signin_release_v2(v_a, v_net);
    if v_r ->> 'ok' <> 'true' or (v_r ->> 'new_net')::boolean is not true then raise exception 'first release not marked new: %', v_r; end if;
    v_r := public.founder_signin_open(v_uid, v_b, v_net, null, 'password', false);
    v_r := public.founder_signin_release_v2(v_b, v_net);
    if (v_r ->> 'new_net')::boolean is not false then raise exception 'second release still new: %', v_r; end if;
    if (select releases from public.founder_signin_nets where user_id = v_uid and net_hash = v_net) <> 2 then raise exception 'release counter wrong'; end if;
    if (select count(*) from public.founder_signin_handoffs where user_id = v_uid) <> 2 then raise exception 'hand-off rows missing'; end if;
    begin update public.founder_signin_handoffs set risk = 0 where ticket_hash = v_a; raise exception 'hand-off changed'; exception when sqlstate '42501' then null; end;
    begin delete from public.founder_signin_nets where user_id = v_uid; raise exception 'network deleted'; exception when sqlstate '42501' then null; end;
    -- 4 risk reading is deterministic and ordered
    v_risk := public.founder_signin_risk(v_uid, v_net3, 'magic_link', array['recovery']::text[], 3);
    if (v_risk ->> 'score')::integer < 60 or v_risk ->> 'level' <> 'high' then raise exception 'worst case not high: %', v_risk; end if;
    if (public.founder_signin_risk(v_uid, v_net, 'password', array['passkey']::text[], 0) ->> 'level') <> 'low' then raise exception 'known network not low'; end if;
    -- 5 naming a network
    if public.founder_signin_net_label(v_uid, v_net, 'home') ->> 'ok' <> 'true' then raise exception 'label refused'; end if;
    if public.founder_signin_net_label(v_uid, v_net3, 'x') ->> 'error' <> 'unknown' then raise exception 'unknown network labelled'; end if;
    if public.founder_signin_net_label(v_uid, v_net, E'<script>') ->> 'ok' = 'true' then raise exception 'markup in a label accepted'; end if;
    -- 6 recovery path: a READY recovery request is the second step and is completed by the door
    insert into public.founder_passkeys (user_id, credential_id, passkey, label) values (v_uid, v_cred, '{}'::jsonb, 'e151b selftest');
    insert into public.founder_recovery_requests (user_id, channel, state, ready_at, expires_at) values (v_uid, 'code', 'ready', now(), now() + interval '1 hour') returning id into v_req;
    v_r := public.founder_signin_open(v_uid, v_c, v_net, null, 'password', false);
    if not ((v_r -> 'need') ? 'recovery') then raise exception 'ready recovery not offered: %', v_r; end if;
    v_r := public.founder_signin_factor(v_c, v_net, 'recovery', true, null);
    if v_r ->> 'ok' <> 'true' then raise exception 'recovery step refused: %', v_r; end if;
    if (select state from public.founder_recovery_requests where id = v_req) <> 'completed' then raise exception 'recovery request not completed'; end if;
    if public.founder_signin_release(v_c, v_net) ->> 'ok' <> 'true' then raise exception 'recovery ticket not released'; end if;
    -- 7 explicit denial closes a ticket for good
    v_r := public.founder_signin_open(v_uid, v_d, v_net, null, 'password', false);
    if public.founder_signin_deny(v_d, v_net, 'not_founder_session') ->> 'ok' <> 'true' then raise exception 'deny refused'; end if;
    if public.founder_signin_factor(v_d, v_net, 'passkey', true, v_cred) ->> 'ok' = 'true' then raise exception 'denied ticket accepted a factor'; end if;
    -- 8 expiry: an open ticket past its time cannot take a factor, and tick marks the rest
    update public.founder_signin_policy set ticket_ttl_s = 30;
    v_r := public.founder_signin_open(v_uid, encode(extensions.digest('e151b-e', 'sha256'), 'hex'), v_net, null, 'password', false);
    set constraints all immediate;
    -- (the ticket window is fixed at birth; moving time is not possible in one transaction, so tick is checked on an empty queue)
    if (public.founder_signin_tick() ->> 'expired')::integer < 0 then raise exception 'tick broken'; end if;
    -- 9 report and chain
    if (public.founder_signin_report(v_uid, 1) -> 'second_factor_on')::boolean is not true then raise exception 'report says no second factor'; end if;
    if public.founder_signin_verify(100000) ->> 'ok' <> 'true' then raise exception 'chain does not verify'; end if;
    v_msg := 'E151 selftest2 PASS (shapes, single-use ticket, hand-off, new network, risk, label, recovery path, denial, tick, chain)';
    raise exception 'e151b_rollback' using errcode = 'P0001';
  exception when others then
    if sqlerrm = 'e151b_rollback' then null; else v_msg := 'E151 selftest2 FAIL: ' || sqlerrm; end if;
  end;
  return v_msg;
end $$;

revoke all on function public._signin_policy_audit(), public.founder_signin_selftest152() from public, anon, authenticated;
revoke all on function public.founder_signin_open(uuid, text, text, text, text, boolean) from public, anon, authenticated;
grant execute on function public.founder_signin_open(uuid, text, text, text, text, boolean), public.founder_signin_selftest152() to service_role;
