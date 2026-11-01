-- E120 — Founder step G4 (blueprint letter G): the "Ledger seal" gauge on the Dashboard, HARDENED (founder 2 Nov 2026 03:14, "har ek choti si choti loophole cover ho jaye").
-- The gauge itself already exists and is GREEN (step 5a, E107 pulse). This file does NOT add a second gauge. It closes the loopholes of the first one:
--   L1  A dead sealer was invisible when the ledger was quiet or only a little behind. Now: "sealer stalled" = a seal is DUE (lag >= every_rows) AND the oldest
--       unsealed entry is older than stall_secs. A quiet ledger (lag below the seal size) is NOT a stall, so there is no false alarm.
--   L2  The full chain + seal re-hash ran only when someone opened the Audit page. Now the Rust tick records a FULL check every verify_every_secs into
--       founder_audit_verify_runs, and the gauge shows the latest result and its age. No run for verify_stale_secs = warn. A broken chain/seal = fail.
--   L3  The pulse did not carry cp_hash, so the browser could not remember a seal. Now it does: the browser pins {id, root, cp_hash} and a server that
--       rolls back or rewrites history shows up as a mismatch (the UI half of this loophole).
--   L4  Age and staleness used the browser clock. Now the server sends now_ms; every age is computed from ONE clock.
-- Technology: SQL (Supabase Postgres, RLS on). Safe to run again. The selftest rolls back everything it writes.

do $$
begin
  if to_regprocedure('public.founder_audit_merkle_pulse()') is null or to_regprocedure('public.founder_audit_checkpoint_verify(integer)') is null then
    raise exception 'E120 needs E107 first (sql-run.sh E107_founder_audit_merkle)';
  end if;
  if to_regprocedure('public._fs_fails(text)') is null then raise exception 'E120 needs E113 first (helper _fs_fails)'; end if;
end $$;

-- 1) policy: three new knobs, bounded (a typo cannot switch the alarm off)
alter table public.founder_audit_merkle_policy add column if not exists stall_secs        integer not null default 900;
alter table public.founder_audit_merkle_policy add column if not exists verify_every_secs integer not null default 1800;
alter table public.founder_audit_merkle_policy add column if not exists verify_stale_secs integer not null default 7200;
do $$
begin
  perform pg_advisory_xact_lock(hashtextextended('founder_merkle:ddl', 0));
  if not exists (select 1 from pg_constraint where conname = 'founder_audit_policy_g4' and conrelid = 'public.founder_audit_merkle_policy'::regclass) then
    alter table public.founder_audit_merkle_policy add constraint founder_audit_policy_g4
      check (stall_secs between 60 and 86400 and verify_every_secs between 300 and 86400
             and verify_stale_secs >= verify_every_secs * 2 and verify_stale_secs <= 604800);
  end if;
end $$;

-- 2) the ledger of FULL checks. Rows exist only when a check really ran.
create table if not exists public.founder_audit_verify_runs (
  id            bigint generated always as identity primary key,
  ran_ms        bigint  not null check (ran_ms > 0),
  rows_checked  bigint  not null check (rows_checked >= 0),
  chain_ok      boolean not null,
  chain_bad_seq bigint,
  cp_ok         boolean not null,
  cp_bad_id     bigint,
  took_ms       integer not null check (took_ms >= 0),
  source        text    not null default 'rust' check (source in ('rust','manual')),
  constraint founder_verify_runs_shape check (chain_ok = (chain_bad_seq is null) and cp_ok = (cp_bad_id is null))
);
create index if not exists founder_audit_verify_runs_latest on public.founder_audit_verify_runs (ran_ms desc, id desc);
alter table public.founder_audit_verify_runs enable row level security;
revoke all on public.founder_audit_verify_runs from public, anon, authenticated, service_role;
grant select on public.founder_audit_verify_runs to service_role;
comment on table public.founder_audit_verify_runs is 'E120: full ledger re-hash results. Written only through founder_audit_verify_record.';

-- 3) the only writer: runs the REAL checks, then records what they said.
create or replace function public.founder_audit_verify_record(p_source text default 'rust') returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '60s' as $$
declare v_src text := coalesce(nullif(btrim(p_source), ''), 'rust'); v_last public.founder_audit_verify_runs%rowtype;
        v_ms bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint; v_t0 timestamptz; v_head bigint; v_chain bigint; v_cp bigint; v_id bigint;
begin
  if v_src not in ('rust','manual') then raise exception 'E120: source rust ya manual' using errcode = '22023'; end if;
  if not pg_try_advisory_xact_lock(hashtextextended('founder_merkle:verify', 0)) then return jsonb_build_object('ran', false, 'reason', 'busy'); end if;
  select * into v_last from public.founder_audit_verify_runs order by ran_ms desc, id desc limit 1;
  if v_last.id is not null and v_src = 'rust' and v_ms - v_last.ran_ms < 60000 then            -- a flood of ticks cannot hammer the database
    return jsonb_build_object('ran', false, 'reason', 'too soon', 'id', v_last.id);
  end if;
  v_t0 := clock_timestamp();
  select coalesce(max(seq), 0) into v_head from public.founder_audit;
  v_chain := public.founder_audit_verify(1);
  v_cp    := public.founder_audit_checkpoint_verify(20);
  insert into public.founder_audit_verify_runs (ran_ms, rows_checked, chain_ok, chain_bad_seq, cp_ok, cp_bad_id, took_ms, source)
    values (v_ms, v_head, v_chain is null, v_chain, v_cp is null, v_cp, (extract(epoch from clock_timestamp() - v_t0) * 1000)::integer, v_src)
    returning id into v_id;
  delete from public.founder_audit_verify_runs where id not in (select id from public.founder_audit_verify_runs order by ran_ms desc, id desc limit 2000);  -- bounded
  return jsonb_build_object('ran', true, 'id', v_id, 'rows', v_head, 'chain_ok', v_chain is null, 'chain_bad_seq', v_chain, 'cp_ok', v_cp is null, 'cp_bad_id', v_cp);
end $$;
revoke all on function public.founder_audit_verify_record(text) from public, anon, authenticated;
grant execute on function public.founder_audit_verify_record(text) to service_role;

-- 4) the pulse, with the clock as a parameter so "time passes" can be tested for real (the public door passes the real clock).
create or replace function public._fm_pulse_at(p_now_ms bigint) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
declare
  v_head bigint; v_last public.founder_audit_checkpoints%rowtype; v_pol public.founder_audit_merkle_policy%rowtype; v_run public.founder_audit_verify_runs%rowtype;
  v_lag bigint; v_oldest bigint; v_stalled boolean := false; v_level text := 'ok'; v_reasons jsonb := '[]'::jsonb; v_run_age bigint; v_run_stale boolean := false; v_checker text := 'ok';
begin
  select coalesce(max(seq), 0) into v_head from public.founder_audit;
  select * into v_last from public.founder_audit_checkpoints order by id desc limit 1;
  select * into v_pol from public.founder_audit_merkle_policy where id;
  select * into v_run from public.founder_audit_verify_runs order by ran_ms desc, id desc limit 1;
  v_lag := v_head - coalesce(v_last.upto_seq, 0);
  if v_lag > 0 then select ts_ms into v_oldest from public.founder_audit where seq = coalesce(v_last.upto_seq, 0) + 1; end if;
  v_stalled := v_lag >= v_pol.every_rows and v_oldest is not null and p_now_ms - v_oldest > v_pol.stall_secs::bigint * 1000;
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
    'due', v_lag >= v_pol.every_rows, 'now_ms', p_now_ms, 'sealer_stalled', v_stalled, 'oldest_unsealed_ms', v_oldest,
    'last_checkpoint', case when v_last.id is null then null
      else jsonb_build_object('id', v_last.id, 'upto_seq', v_last.upto_seq, 'root', v_last.root, 'cp_hash', v_last.cp_hash, 'created_ms', v_last.created_ms,
                              'age_s', greatest(0, (p_now_ms - v_last.created_ms) / 1000)) end,
    'full_check', case when v_run.id is null then null
      else jsonb_build_object('ran_ms', v_run.ran_ms, 'age_s', v_run_age, 'stale', v_run_stale, 'rows', v_run.rows_checked, 'chain_ok', v_run.chain_ok,
                              'chain_bad_seq', v_run.chain_bad_seq, 'cp_ok', v_run.cp_ok, 'cp_bad_id', v_run.cp_bad_id, 'took_ms', v_run.took_ms) end,
    'policy', jsonb_build_object('stall_secs', v_pol.stall_secs, 'verify_every_secs', v_pol.verify_every_secs, 'verify_stale_secs', v_pol.verify_stale_secs));
end $$;
revoke all on function public._fm_pulse_at(bigint) from public, anon, authenticated;

create or replace function public.founder_audit_merkle_pulse() returns jsonb
language sql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
  select public._fm_pulse_at((extract(epoch from clock_timestamp()) * 1000)::bigint)
$$;
revoke all on function public.founder_audit_merkle_pulse() from public, anon, authenticated;
grant execute on function public.founder_audit_merkle_pulse() to service_role;

-- 5) selftest: real scenarios on a populated account, then ROLLBACK (nothing stays behind).
create or replace function public.founder_audit_g4_selftest() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '60s' as $$
declare r text := ''; v_uid uuid; b_runs bigint; b_aud bigint; b_cp bigint; j jsonb; v_now bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint; i integer; v_pol public.founder_audit_merkle_policy%rowtype;
begin
  select user_id into v_uid from public.founder_accounts limit 1;
  if v_uid is null then raise exception 'E120 selftest needs one founder account'; end if;
  select count(*) into b_runs from public.founder_audit_verify_runs;
  select count(*) into b_aud from public.founder_audit;
  select count(*) into b_cp from public.founder_audit_checkpoints;
  select * into v_pol from public.founder_audit_merkle_policy where id;
  begin
    -- bad input is refused
    if not public._fs_fails($q$select public.founder_audit_verify_record('bogus')$q$) then raise exception 'an unknown source was accepted'; end if;
    if not public._fs_fails($q$update public.founder_audit_merkle_policy set stall_secs = 5$q$) then raise exception 'a stall_secs of 5 was accepted (alarm could be switched off)'; end if;
    if not public._fs_fails($q$update public.founder_audit_merkle_policy set verify_stale_secs = verify_every_secs$q$) then raise exception 'a stale limit not above 2x the interval was accepted'; end if;
    r := r || 'validation OK; ';
    -- before any full check: honest warn, no invented result
    delete from public.founder_audit_verify_runs;
    j := public._fm_pulse_at(v_now);
    if j -> 'full_check' <> 'null'::jsonb or j ->> 'checker' <> 'never' then raise exception 'no full check yet must say never: %', j; end if;
    r := r || 'never-checked OK; ';
    -- a real full check on a populated ledger
    perform public.founder_audit_append(v_uid, 'g4.selftest', 'row-1', 'selftest entry number one', '{}'::jsonb);
    j := public.founder_audit_verify_record('manual');
    if not (j ->> 'ran')::boolean or not (j ->> 'chain_ok')::boolean or not (j ->> 'cp_ok')::boolean then raise exception 'real check failed on a healthy ledger: %', j; end if;
    if public.founder_audit_verify_record('rust') ->> 'reason' <> 'too soon' then raise exception 'a second tick was not rate limited'; end if;
    j := public._fm_pulse_at((extract(epoch from clock_timestamp()) * 1000)::bigint);
    if (j -> 'full_check' ->> 'chain_ok')::boolean is not true or (j -> 'full_check' ->> 'stale')::boolean then raise exception 'fresh full check not shown: %', j; end if;
    r := r || 'full check OK; ';
    perform public.founder_audit_checkpoint(v_uid, 'selftest seal of the existing rows');   -- start from a sealed ledger so old rows on a busy account cannot colour the scenario
    -- the checker itself stops: 3 hours later it is stale and the gauge says so
    j := public._fm_pulse_at(v_now + 3 * 3600 * 1000);
    if j ->> 'checker' <> 'stale' or not (j -> 'full_check' ->> 'stale')::boolean then raise exception 'a 3-hour-old check was not flagged: %', j; end if;
    r := r || 'checker-stalled OK; ';
    -- a quiet ledger is NOT a sealer stall (lag below the seal size), even days later
    j := public._fm_pulse_at(v_now + 10 * 86400 * 1000);
    if (j ->> 'sealer_stalled')::boolean then raise exception 'a quiet ledger was called a stall: %', j; end if;
    r := r || 'quiet-ledger no false alarm OK; ';
    -- a seal is due, nobody seals it: stall after stall_secs, not before
    update public.founder_audit_merkle_policy set every_rows = 5, warn_lag_rows = 5000, fail_lag_rows = 9000 where id;
    for i in 1 .. 6 loop perform public.founder_audit_append(v_uid, 'g4.selftest', 'row-' || (i + 1), 'selftest entry number ' || (i + 1), '{}'::jsonb); end loop;
    j := public._fm_pulse_at((extract(epoch from clock_timestamp()) * 1000)::bigint);
    if (j ->> 'sealer_stalled')::boolean or not (j ->> 'due')::boolean then raise exception 'a seal due 1 second ago is not a stall yet: %', j; end if;
    j := public._fm_pulse_at(v_now + 2 * 3600 * 1000);
    if not (j ->> 'sealer_stalled')::boolean or j ->> 'level' = 'ok' then raise exception 'a stalled sealer was not flagged: %', j; end if;
    perform public.founder_audit_checkpoint(v_uid, 'selftest seal after the stall');
    j := public._fm_pulse_at(v_now + 2 * 3600 * 1000);
    if (j ->> 'sealer_stalled')::boolean then raise exception 'sealing did not clear the stall: %', j; end if;
    if j -> 'last_checkpoint' ->> 'cp_hash' !~ '^[0-9a-f]{64}$' then raise exception 'the pulse does not carry cp_hash: %', j; end if;
    r := r || 'sealer-stalled OK; cp_hash OK; ';
    -- a failed full check turns the gauge to fail and names the entry
    insert into public.founder_audit_verify_runs (ran_ms, rows_checked, chain_ok, chain_bad_seq, cp_ok, cp_bad_id, took_ms, source)
      values (v_now + 1000, 9, false, 3, true, null, 1, 'manual');
    j := public._fm_pulse_at(v_now + 2000);
    if j ->> 'level' <> 'fail' or j::text not like '%broken at entry 3%' then raise exception 'a broken chain was not a fail: %', j; end if;
    r := r || 'broken-chain fail OK; ';
    raise exception 'ROLLBACK_SELFTEST';
  exception when others then
    if sqlerrm <> 'ROLLBACK_SELFTEST' then raise exception 'E120 selftest FAIL: %', sqlerrm; end if;
  end;
  if (select count(*) from public.founder_audit_verify_runs) <> b_runs or (select count(*) from public.founder_audit) <> b_aud
     or (select count(*) from public.founder_audit_checkpoints) <> b_cp then raise exception 'E120 selftest left rows behind'; end if;
  if (select stall_secs from public.founder_audit_merkle_policy where id) <> v_pol.stall_secs or (select every_rows from public.founder_audit_merkle_policy where id) <> v_pol.every_rows then
    raise exception 'E120 selftest changed the policy'; end if;
  return 'E120 selftest OK — ' || r || 'rollback clean';
end $$;
revoke all on function public.founder_audit_g4_selftest() from public, anon, authenticated;
grant execute on function public.founder_audit_g4_selftest() to service_role;
