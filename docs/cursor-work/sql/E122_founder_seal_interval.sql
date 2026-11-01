-- E122 — G5a live proof + ADVANCED sealing (founder 2 Nov 04:36 "G5a bhi fix kero", 04:39 "sql E122 advance likho").
-- Problem: the ledger has ~28 entries and the first seal waited for 50 new entries, so the browser had nothing to pin and the
--   RFC 9162 consistency check (G5a) could never run live. Also a quiet ledger could stay unsealed for days.
-- What this does (all additive, idempotent, re-runnable; nothing is deleted):
--   1) seal interval 50 -> 20 entries (through the audited door founder_audit_merkle_policy_set).
--   2) TIME RULE: an unsealed entry may wait at most seal_max_age_secs (default 600 = 10 min), then the pulse says "due" and the
--      existing Rust tick (every ~60 s) seals. Only REAL entries count: a seal writes its own audit row ('audit.checkpoint'), and that
--      row must never trigger the next seal (otherwise the ledger would seal itself forever). No Rust change: auto_seal reads pulse.due.
--   3) the stall alarm (E120) now fires on the same "due" (count OR time), so a dead sealer is caught for a quiet ledger too.
--      seal_max_age_secs must stay below stall_secs (constraint), else the alarm could never be reached.
--   4) own selftest (rolls back): time rule, no seal loop, stall on time-due, constraints, policy untouched.
alter table public.founder_audit_merkle_policy add column if not exists seal_max_age_secs integer not null default 600;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'founder_audit_policy_e122') then
    alter table public.founder_audit_merkle_policy add constraint founder_audit_policy_e122
      check (seal_max_age_secs between 120 and 86400 and seal_max_age_secs < stall_secs);
  end if;
end $$;


-- 1) the interval (audited door; skipped if already 20 or lower, or if there is no founder account yet)
do $$
declare v_actor uuid; v_pol public.founder_audit_merkle_policy%rowtype;
begin
  select * into v_pol from public.founder_audit_merkle_policy where id;
  if not found then raise notice 'E122 SKIP interval: no merkle policy row (E107 not applied)'; return; end if;
  if v_pol.every_rows <= 20 then raise notice 'E122: interval already %, nothing to do', v_pol.every_rows; return; end if;
  select user_id into v_actor from public.founder_accounts order by 1 limit 1;
  if v_actor is null then raise notice 'E122 SKIP interval: no founder account yet'; return; end if;
  perform public.founder_audit_merkle_policy_set(v_actor, 20, v_pol.warn_lag_rows, v_pol.fail_lag_rows,
          'E122: seal every 20 entries (and at most 10 minutes) so the browser consistency proof (G5a) can run live');
  raise notice 'E122: seal interval % -> 20', v_pol.every_rows;
end $$;

-- 2+3) the pulse with the time rule (replaces the E120 pulse; same shape plus real_lag_rows and policy.seal_max_age_secs)
create or replace function public._fm_pulse_at(p_now_ms bigint) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
declare
  v_head bigint; v_last public.founder_audit_checkpoints%rowtype; v_pol public.founder_audit_merkle_policy%rowtype; v_run public.founder_audit_verify_runs%rowtype;
  v_lag bigint; v_oldest bigint; v_real_lag bigint := 0; v_real_oldest bigint; v_due boolean := false; v_stalled boolean := false; v_level text := 'ok'; v_reasons jsonb := '[]'::jsonb; v_run_age bigint; v_run_stale boolean := false; v_checker text := 'ok';
begin
  select coalesce(max(seq), 0) into v_head from public.founder_audit;
  select * into v_last from public.founder_audit_checkpoints order by id desc limit 1;
  select * into v_pol from public.founder_audit_merkle_policy where id;
  select * into v_run from public.founder_audit_verify_runs order by ran_ms desc, id desc limit 1;
  v_lag := v_head - coalesce(v_last.upto_seq, 0);
  if v_lag > 0 then select ts_ms into v_oldest from public.founder_audit where seq = coalesce(v_last.upto_seq, 0) + 1; end if;
  -- E122 time rule: entries that are not seals themselves (a seal writes its own audit row, which must never trigger the next seal)
  select count(*), min(ts_ms) into v_real_lag, v_real_oldest from public.founder_audit where seq > coalesce(v_last.upto_seq, 0) and action <> 'audit.checkpoint';
  v_due := v_lag >= v_pol.every_rows or (v_real_lag >= 1 and p_now_ms - v_real_oldest >= v_pol.seal_max_age_secs::bigint * 1000);
  v_stalled := v_due and v_oldest is not null and p_now_ms - v_oldest > v_pol.stall_secs::bigint * 1000;
  if v_run.id is not null then
    v_run_age := greatest(0, (p_now_ms - v_run.ran_ms) / 1000);
    v_run_stale := v_run_age > v_pol.verify_stale_secs;
  end if;
  -- fail
  if v_run.id is not null and not v_run.chain_ok then v_level := 'fail'; v_reasons := v_reasons || to_jsonb('the audit chain is broken at entry ' || v_run.chain_bad_seq); end if;
  if v_run.id is not null and not v_run.cp_ok then v_level := 'fail'; v_reasons := v_reasons || to_jsonb('seal ' || v_run.cp_bad_id || ' no longer matches the ledger'); end if;
  if v_lag >= v_pol.fail_lag_rows then v_level := 'fail'; v_reasons := v_reasons || to_jsonb(v_lag || ' entries have no seal'); end if;
  -- warn
  if v_level <> 'fail' and v_lag >= v_pol.warn_lag_rows then v_level := 'warn'; v_reasons := v_reasons || to_jsonb(v_lag || ' entries have no seal'); end if;
  if v_stalled then
    if v_level = 'ok' then v_level := 'warn'; end if;
    v_reasons := v_reasons || to_jsonb('a seal is due but nothing sealed it for ' || ((p_now_ms - v_oldest) / 60000) || ' minutes (automatic sealer stalled?)');
  end if;
  -- the CHECKER's own health is a separate field: `level` keeps the E107 meaning (so the E107 selftests stay green on any server), the UI shows warn when checker <> 'ok'
  if v_run.id is null then
    v_checker := 'never'; v_reasons := v_reasons || to_jsonb('no full ledger check has run yet'::text);
  elsif v_run_stale then
    v_checker := 'stale'; v_reasons := v_reasons || to_jsonb('the last full ledger check is ' || (v_run_age / 60) || ' minutes old (checker stalled?)');
  end if;
  return jsonb_build_object('level', v_level, 'checker', v_checker, 'reasons', v_reasons, 'rows', v_head, 'lag_rows', v_lag, 'every_rows', v_pol.every_rows,
    'due', v_due, 'real_lag_rows', v_real_lag, 'now_ms', p_now_ms, 'sealer_stalled', v_stalled, 'oldest_unsealed_ms', v_oldest,
    'last_checkpoint', case when v_last.id is null then null
      else jsonb_build_object('id', v_last.id, 'upto_seq', v_last.upto_seq, 'root', v_last.root, 'cp_hash', v_last.cp_hash, 'created_ms', v_last.created_ms,
                              'age_s', greatest(0, (p_now_ms - v_last.created_ms) / 1000)) end,
    'full_check', case when v_run.id is null then null
      else jsonb_build_object('ran_ms', v_run.ran_ms, 'age_s', v_run_age, 'stale', v_run_stale, 'rows', v_run.rows_checked, 'chain_ok', v_run.chain_ok,
                              'chain_bad_seq', v_run.chain_bad_seq, 'cp_ok', v_run.cp_ok, 'cp_bad_id', v_run.cp_bad_id, 'took_ms', v_run.took_ms) end,
    'policy', jsonb_build_object('seal_max_age_secs', v_pol.seal_max_age_secs, 'stall_secs', v_pol.stall_secs, 'verify_every_secs', v_pol.verify_every_secs, 'verify_stale_secs', v_pol.verify_stale_secs));
end $$;

-- 4) selftest: scenarios with a moving clock, then ROLLBACK.
create or replace function public.founder_audit_e122_selftest() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '60s' as $$
declare r text := ''; v_uid uuid; b_aud bigint; b_cp bigint; j jsonb; v_now bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint; v_pol public.founder_audit_merkle_policy%rowtype; i integer;
begin
  select user_id into v_uid from public.founder_accounts limit 1;
  if v_uid is null then return 'E122 selftest SKIP (no founder account yet)'; end if;
  select count(*) into b_aud from public.founder_audit;
  select count(*) into b_cp from public.founder_audit_checkpoints;
  select * into v_pol from public.founder_audit_merkle_policy where id;
  begin
    if not public._fs_fails($q$update public.founder_audit_merkle_policy set seal_max_age_secs = 60$q$) then raise exception 'a 60 s seal age was accepted'; end if;
    if not public._fs_fails($q$update public.founder_audit_merkle_policy set seal_max_age_secs = stall_secs$q$) then raise exception 'a seal age not below the stall limit was accepted'; end if;
    r := r || 'validation OK; ';
    update public.founder_audit_merkle_policy set every_rows = 20, warn_lag_rows = greatest(warn_lag_rows, 20), fail_lag_rows = greatest(fail_lag_rows, 2000) where id;
    perform public.founder_audit_checkpoint(v_uid, 'selftest seal of the existing rows');
    -- a sealed ledger that only holds its own seal row is NOT due, even days later (no seal loop)
    j := public._fm_pulse_at(v_now + 10 * 86400 * 1000);
    if (j ->> 'due')::boolean or (j ->> 'sealer_stalled')::boolean or (j ->> 'real_lag_rows')::int <> 0 then raise exception 'the seal own row made the ledger due (seal loop): %', j; end if;
    r := r || 'no-seal-loop OK; ';
    -- one real entry: not due when fresh, due after seal_max_age_secs, stalled only after stall_secs
    perform public.founder_audit_append(v_uid, 'e122.selftest', 'row-1', 'selftest entry', '{}'::jsonb);
    j := public._fm_pulse_at((extract(epoch from clock_timestamp()) * 1000)::bigint);
    if (j ->> 'due')::boolean then raise exception 'a fresh single entry was already due: %', j; end if;
    j := public._fm_pulse_at(v_now + (v_pol.seal_max_age_secs + 60) * 1000);
    if not (j ->> 'due')::boolean or (j ->> 'sealer_stalled')::boolean then raise exception 'an entry older than seal_max_age must be due but not yet stalled: %', j; end if;
    j := public._fm_pulse_at(v_now + (v_pol.stall_secs + 120) * 1000);
    if not (j ->> 'due')::boolean or not (j ->> 'sealer_stalled')::boolean or j ->> 'level' = 'ok' then raise exception 'a time-due entry nobody sealed was not flagged as a stall: %', j; end if;
    r := r || 'time-rule + time-stall OK; ';
    perform public.founder_audit_checkpoint(v_uid, 'selftest seal after the time rule');
    j := public._fm_pulse_at(v_now + (v_pol.stall_secs + 120) * 1000);
    if (j ->> 'due')::boolean or (j ->> 'sealer_stalled')::boolean then raise exception 'sealing did not clear due/stall: %', j; end if;
    r := r || 'sealed-clears OK; ';
    -- the count rule still works (20 entries are due at once)
    for i in 1 .. 20 loop perform public.founder_audit_append(v_uid, 'e122.selftest', 'cnt-' || i, 'selftest count entry ' || i, '{}'::jsonb); end loop;
    j := public._fm_pulse_at((extract(epoch from clock_timestamp()) * 1000)::bigint);
    if not (j ->> 'due')::boolean then raise exception '20 fresh entries were not due by count: %', j; end if;
    r := r || 'count-rule OK; ';
    raise exception 'ROLLBACK_SELFTEST';
  exception when others then
    if sqlerrm <> 'ROLLBACK_SELFTEST' then raise exception 'E122 selftest FAIL: %', sqlerrm; end if;
  end;
  if (select count(*) from public.founder_audit) <> b_aud or (select count(*) from public.founder_audit_checkpoints) <> b_cp then raise exception 'E122 selftest left rows behind'; end if;
  if (select every_rows from public.founder_audit_merkle_policy where id) <> v_pol.every_rows or (select seal_max_age_secs from public.founder_audit_merkle_policy where id) <> v_pol.seal_max_age_secs then
    raise exception 'E122 selftest changed the policy'; end if;
  return 'E122 selftest OK — ' || r || 'rollback clean';
end $$;
revoke all on function public.founder_audit_e122_selftest() from public, anon, authenticated;
grant execute on function public.founder_audit_e122_selftest() to service_role;

do $$ begin raise notice '%', public.founder_audit_e122_selftest(); raise notice '%', public.founder_audit_g4_selftest(); end $$;

-- RUNBOOK: bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E122_founder_seal_interval CHECK_E122  (after fetch). Needs E107 + E120.
-- Undo:  select public.founder_audit_merkle_policy_set(<founder uuid>, 50, 200, 2000, 'undo E122'); alter table public.founder_audit_merkle_policy drop constraint founder_audit_policy_e122;
--        then re-run the pulse section of E120 (section 4) to restore the old pulse.
