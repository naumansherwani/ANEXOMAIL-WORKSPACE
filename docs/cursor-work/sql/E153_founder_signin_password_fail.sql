
-- ==============================================================================================================================
-- E153 (G-MIX 2b / S6 loophole fix L1, 10 Nov 2026) - FOUNDER: a wrong PASSWORD from a network goes into the sign-in ledger.
-- Before: only second-step failures (passkey) fed the database lock; wrong passwords were counted only in Rust memory, which forgets on every restart,
-- and the lock was asked only AFTER the identity service had already checked the password. Now Rust asks founder_signin_locked(null, network) FIRST and
-- writes every wrong password here, so 5 wrong passwords from one network inside the window lock THAT NETWORK (not the founder: the row carries no user id,
-- so a stranger can never lock the founder out of his own known network). Append-only, hash-chained, reject spam from one network capped at 60 an hour (E151).
-- No password, no email, no address is stored: only the network hash and the word 'bad_password'.
-- Needs E151 + E152 first. Idempotent: safe to run twice.
-- ==============================================================================================================================
set lock_timeout = '5s';
set statement_timeout = '60s';

do $$ begin
  perform pg_advisory_xact_lock(hashtextextended('founder_signin:ddl153', 0));
  if to_regclass('public.founder_signin_events') is null or to_regprocedure('public.founder_signin_selftest152()') is null then
    raise exception 'E151 + E152 pehle chalao' using errcode = '55000'; end if;
end $$;

create or replace function public.founder_signin_password_fail(p_net_hash text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '5s' as $$
begin
  if not public._signin_h64(p_net_hash) then return jsonb_build_object('ok', false, 'error', 'shape'); end if;
  perform public._signin_log(null, 'reject_ip', null, p_net_hash, jsonb_build_object('why', 'bad_password'));
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.founder_signin_selftest153() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare v_net text := encode(extensions.digest('e153-net', 'sha256'), 'hex'); v_other text := encode(extensions.digest('e153-other', 'sha256'), 'hex');
        v_msg text := 'E153 selftest FAIL: unknown'; v_i integer; v_uid uuid; v_before bigint;
begin
  select user_id into v_uid from public.founder_accounts order by user_id limit 1;
  begin
    if public.founder_signin_password_fail('not-a-hash') ->> 'ok' = 'true' then raise exception 'a malformed network hash was accepted'; end if;
    if public.founder_signin_locked(null, v_net) ->> 'locked' = 'true' then raise exception 'locked before any failure'; end if;
    for v_i in 1..4 loop perform public.founder_signin_password_fail(v_net); end loop;
    if public.founder_signin_locked(null, v_net) ->> 'locked' = 'true' then raise exception 'locked after only 4'; end if;
    perform public.founder_signin_password_fail(v_net);
    if public.founder_signin_locked(null, v_net) ->> 'locked' <> 'true' then raise exception 'five wrong passwords did not lock the network'; end if;
    if public.founder_signin_locked(null, v_other) ->> 'locked' = 'true' then raise exception 'another network was locked'; end if;
    if v_uid is not null and public.founder_signin_locked(v_uid, v_other) ->> 'locked' = 'true' then raise exception 'the founder himself was locked by a stranger network'; end if;
    select count(*) into v_before from public.founder_signin_events where net_hash = v_net and facts ->> 'why' = 'bad_password';
    if v_before <> 5 then raise exception 'the ledger holds % rows, not 5', v_before; end if;
    if exists (select 1 from public.founder_signin_events where net_hash = v_net and (user_id is not null or ticket is not null)) then raise exception 'a password failure carried an id'; end if;
    if public.founder_signin_verify(100000) ->> 'ok' <> 'true' then raise exception 'chain does not verify'; end if;
    v_msg := 'E153 selftest PASS (malformed refused, 5 wrong passwords lock the network only, the founder never locked by a stranger, no id stored, chain verifies)';
    raise exception 'e153_rollback' using errcode = 'P0001';
  exception when others then
    if sqlerrm = 'e153_rollback' then null; else v_msg := 'E153 selftest FAIL: ' || sqlerrm; end if;
  end;
  return v_msg;
end $$;

revoke all on function public.founder_signin_password_fail(text), public.founder_signin_selftest153() from public, anon, authenticated;
grant execute on function public.founder_signin_password_fail(text), public.founder_signin_selftest153() to service_role;
