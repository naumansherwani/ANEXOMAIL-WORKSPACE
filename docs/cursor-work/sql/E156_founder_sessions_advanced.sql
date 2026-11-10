
-- ==============================================================================================================================
-- E156 (D2a, 10 Nov 2026) - FOUNDER: Devices & Sessions, the ADVANCED upgrade of E155. E155 stays INTACT (green on his server, sha 7138217396e7e0b1);
-- this file is additive and idempotent: it widens E155's tables and replaces only two E155 doors (founder_session_register, founder_sessions_board) with
-- stronger versions of the SAME signature. Loophole hunt against OWASP Session Management + ASVS V3 + NIST 800-63B (plan docs/claude/G-MIX-D2-PLAN-10NOV.md):
--   L1 founder_session_check: a stolen token is re-checked on EVERY verified request (country lock, identity drift: user-agent family / engine family / proven device key)
--   L2 network-flap detector: one session used from several networks inside 10 minutes = 'net_flapping' in the chain, optional auto-revoke 'session_shared'
--   L3 change logs are rate-limited (30 s per session): a stranger cannot flood the chain
--   L4 idle + absolute lifetime in the policy (ASVS V3), enforced in check, revoke 'expired'
--   L5 concurrent-session cap: register evicts the longest-idle live sessions ('replaced' + 'session_cap')
--   L6 integrity failure streak ends the session ('integrity_fail')
--   L7 board verifies the LATEST chain rows (verify_tail), not only the first 2000
--   L8 cross-chain ANCHOR: the ledger head (id, hash, row count) is written into an append-only anchors table AND the founder audit chain (E102);
--      anchor_check proves the head still exists unchanged, so a deleted or rewritten tail is caught even by someone who can bypass triggers
--   L9 policy_set_v2 carries every knob (keeps the lock-out guard, absolute >= idle, every change in the chain)
-- HONEST LIMITS (kept in the board answer): hardware identity = device-key fingerprint; a VPN inside an allowed country passes the location lock; integrity = last real
-- verification time; the device key is only compared on requests where Rust actually verified its proof (a request without a proof never counts as a mismatch).
-- PRIVACY (Rule 69): hashes, fingerprints, ids, counts, times, two-letter countries only. Needs E155 (and E102 for the audit anchor). Idempotent: safe to run twice.
-- ==============================================================================================================================
set lock_timeout = '5s';
set statement_timeout = '60s';

do $$ begin
  perform pg_advisory_xact_lock(hashtextextended('founder_session:ddl156', 0));
  if to_regclass('public.founder_session_registry') is null or to_regprocedure('public.founder_session_selftest155()') is null then raise exception 'E155 pehle chalao' using errcode = '55000'; end if;
end $$;

-- ------------------------------------------------------------------------------------------------------------------------------
-- 1) widen what E155 allows (constraints are replaced by name, never dropped without a new one in place)
-- ------------------------------------------------------------------------------------------------------------------------------
do $$ declare c text; begin
  perform pg_advisory_xact_lock(hashtextextended('founder_session:ddl156', 1));
  for c in select conname from pg_constraint where conrelid = 'public.founder_session_ledger'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%''registered''%' loop
    execute format('alter table public.founder_session_ledger drop constraint %I', c); end loop;
  alter table public.founder_session_ledger add constraint founder_session_ledger_kind_ck check (kind in ('registered', 'seen', 'protocol_changed', 'kernel_changed', 'net_changed', 'spoof_alert',
    'spoof_blocked', 'geo_observed', 'geo_refused', 'integrity_fail', 'revoked', 'nuke_others', 'policy_changed', 'expired', 'net_flapping', 'identity_drift', 'geo_moved', 'session_cap', 'anchored'));
  for c in select conname from pg_constraint where conrelid = 'public.founder_session_registry'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%''founder_nuke''%' loop
    execute format('alter table public.founder_session_registry drop constraint %I', c); end loop;
  alter table public.founder_session_registry add constraint founder_session_registry_revoke_reason_ck check (revoke_reason is null or revoke_reason in
    ('founder_nuke', 'founder_nuke_others', 'integrity_fail', 'replaced', 'expired', 'selftest', 'geo_moved', 'session_shared'));
  alter table public.founder_session_registry add column if not exists net_flips integer not null default 0;
  alter table public.founder_session_registry add column if not exists flip_window_at timestamptz;
  alter table public.founder_session_registry add column if not exists fail_streak integer not null default 0;
  if not exists (select 1 from pg_constraint where conrelid = 'public.founder_session_registry'::regclass and conname = 'founder_session_registry_counters_ck') then
    alter table public.founder_session_registry add constraint founder_session_registry_counters_ck check (net_flips >= 0 and fail_streak >= 0); end if;
  alter table public.founder_session_policy add column if not exists max_live     integer not null default 20;
  alter table public.founder_session_policy add column if not exists fail_limit   integer not null default 10;
  alter table public.founder_session_policy add column if not exists flap_limit   integer not null default 4;
  alter table public.founder_session_policy add column if not exists flap_action  text    not null default 'alert';
  alter table public.founder_session_policy add column if not exists idle_s       integer not null default 86400;
  alter table public.founder_session_policy add column if not exists absolute_s   integer not null default 604800;
  if not exists (select 1 from pg_constraint where conrelid = 'public.founder_session_policy'::regclass and conname = 'founder_session_policy_limits_ck') then
    alter table public.founder_session_policy add constraint founder_session_policy_limits_ck check (max_live between 2 and 200 and fail_limit between 3 and 100 and flap_limit between 2 and 50
      and flap_action in ('alert', 'revoke') and idle_s between 300 and 2592000 and absolute_s between 3600 and 7776000 and absolute_s >= idle_s); end if;

  -- cross-chain anchors: append-only, closed to direct writes like every E155 table
  create table if not exists public.founder_session_anchors (
    id         bigint generated always as identity primary key,
    ts_ms      bigint      not null check (ts_ms > 0),
    head_id    bigint      not null check (head_id > 0),
    head_hash  text        not null check (public._sess_h64(head_hash)),
    ledger_rows bigint     not null check (ledger_rows > 0),
    audit_seq  bigint,
    audit_hash text        check (audit_hash is null or public._sess_h64(audit_hash)),
    unique (head_id)
  );
  alter table public.founder_session_anchors enable row level security;
  revoke all on public.founder_session_anchors from public, anon, authenticated, service_role;
  grant select on public.founder_session_anchors to service_role;
end $$;
drop trigger if exists founder_session_anchors_stop on public.founder_session_anchors;
create trigger founder_session_anchors_stop before update or delete on public.founder_session_anchors for each row execute function public._sess_stop();
drop trigger if exists founder_session_anchors_stop_trunc on public.founder_session_anchors;
create trigger founder_session_anchors_stop_trunc before truncate on public.founder_session_anchors for each statement execute function public._sess_stop();

-- ------------------------------------------------------------------------------------------------------------------------------
-- 2) effective policy (defaults filled in) and the one internal kill switch
-- ------------------------------------------------------------------------------------------------------------------------------
create or replace function public._sess_pol(p_uid uuid) returns jsonb
language sql stable security definer set search_path = pg_catalog, public as $$
  select jsonb_build_object('geo_mode', coalesce(p.geo_mode, 'off'), 'countries', to_jsonb(coalesce(p.countries, '{}'::text[])), 'spoof_action', coalesce(p.spoof_action, 'alert'),
    'stale_after_s', coalesce(p.stale_after_s, 900), 'max_live', coalesce(p.max_live, 20), 'fail_limit', coalesce(p.fail_limit, 10), 'flap_limit', coalesce(p.flap_limit, 4),
    'flap_action', coalesce(p.flap_action, 'alert'), 'idle_s', coalesce(p.idle_s, 86400), 'absolute_s', coalesce(p.absolute_s, 604800))
  from (select 1) x left join public.founder_session_policy p on p.user_id = p_uid
$$;

-- the one place a session is killed by the system: registry row + chain row + the device-bound key of that device (E149), same transaction
create or replace function public._sess_kill(p_sid text, p_reason text) returns boolean
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare r record;
begin
  update public.founder_session_registry set revoked_at = now(), revoke_reason = p_reason where sid_hash = p_sid and revoked_at is null
  returning user_id, device_hash, net_hash, kernel_version, protocol, country into r;
  if not found then return false; end if;
  perform public._sess_log(r.user_id, p_sid, 'revoked', r.net_hash, r.kernel_version, r.protocol, r.country, jsonb_build_object('reason', p_reason, 'by', 'system'));
  if to_regprocedure('public.founder_dbsc_revoke(uuid,text,text)') is not null
     and not exists (select 1 from public.founder_session_registry k where k.user_id = r.user_id and k.device_hash = r.device_hash and k.revoked_at is null) then
    perform public.founder_dbsc_revoke(r.user_id, r.device_hash, 'founder_revoked'); end if;
  return true;
end $$;

-- ------------------------------------------------------------------------------------------------------------------------------
-- 3) the hot path: founder_session_check runs on EVERY verified request (L1, L2, L3, L4, L6)
--    state: live | revoked | unknown | shape | expired | drift_revoked | geo_outside | flapping_revoked | integrity_revoked   (only 'live' means: serve the request)
--    p_key_fp is passed ONLY when Rust verified the device-key proof on this request (otherwise null: a request without a proof is never a mismatch).
-- ------------------------------------------------------------------------------------------------------------------------------
create or replace function public.founder_session_check(p_sid_hash text, p_net_hash text, p_protocol text, p_kernel text, p_verified boolean, p_ua_family text, p_hint_family text,
                                                        p_key_fp text, p_country text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '5s' as $$
declare
  r public.founder_session_registry%rowtype; pol jsonb; v_drift text[] := '{}'; v_logged boolean := false; v_quiet boolean; v_flips integer; v_win timestamptz; v_streak integer;
  v_kill text := null; v_state text := 'live'; v_score integer; v_reasons text[];
begin
  if not public._sess_h64(p_sid_hash) or not public._sess_h64(p_net_hash) or coalesce(p_protocol, '') not in ('quic', 'h2', 'h1', 'unknown') or not public._sess_kernel_ok(p_kernel) or p_verified is null
     or not public._sess_family(p_ua_family) or not public._sess_family(p_hint_family) or (p_key_fp is not null and not public._sess_h64(p_key_fp)) or (p_country is not null and p_country !~ '^[A-Z]{2}$') then
    return jsonb_build_object('ok', false, 'state', 'shape'); end if;
  select * into r from public.founder_session_registry where sid_hash = p_sid_hash for update;
  if not found then return jsonb_build_object('ok', false, 'state', 'unknown'); end if;
  if r.revoked_at is not null then return jsonb_build_object('ok', false, 'state', 'revoked'); end if;
  pol := public._sess_pol(r.user_id);
  v_quiet := r.last_ledger_at > now() - interval '30 seconds';                                      -- L3: noisy change logs at most every 30 s per session

  -- L4 idle + absolute lifetime
  if r.created_at < now() - make_interval(secs => (pol ->> 'absolute_s')::integer) or r.last_seen_at < now() - make_interval(secs => (pol ->> 'idle_s')::integer) then
    perform public._sess_kill(p_sid_hash, 'expired'); return jsonb_build_object('ok', false, 'state', 'expired'); end if;

  -- L1 identity drift: what this session claimed / proved at sign-in must not change mid-session
  if p_ua_family <> 'unknown' and r.ua_family <> 'unknown' and p_ua_family <> r.ua_family then v_drift := array_append(v_drift, 'user_agent_changed'); end if;
  if p_hint_family <> 'unknown' and r.hint_family <> 'unknown' and p_hint_family <> r.hint_family then v_drift := array_append(v_drift, 'engine_changed'); end if;
  if p_key_fp is not null and r.key_fp is not null and p_key_fp <> r.key_fp then v_drift := array_append(v_drift, 'device_key_changed'); end if;
  if cardinality(v_drift) > 0 then
    if not exists (select 1 from public.founder_session_ledger where sid_hash = p_sid_hash and kind = 'identity_drift' and ts_ms > (extract(epoch from now() - interval '60 seconds') * 1000)::bigint) then
      perform public._sess_log(r.user_id, p_sid_hash, 'identity_drift', p_net_hash, p_kernel, p_protocol, p_country, jsonb_build_object('what', to_jsonb(v_drift))); v_logged := true; end if;
    v_score := greatest(r.spoof_score, 80); v_reasons := (select coalesce(array_agg(distinct x), '{}') from unnest(r.spoof_reasons || array['identity_drift_mid_session']) x);
    update public.founder_session_registry set spoof_score = v_score, spoof_level = 'spoof', spoof_reasons = v_reasons[1:8] where sid_hash = p_sid_hash;
    if pol ->> 'spoof_action' = 'block' then v_kill := 'integrity_fail'; v_state := 'drift_revoked'; end if;
  end if;

  -- L1 location lock on every request: a stolen token used outside the allowed countries is refused and the session is closed
  if v_kill is null and pol ->> 'geo_mode' = 'enforce' and p_country is not null and not (p_country = any (array(select jsonb_array_elements_text(pol -> 'countries')))) then
    perform public._sess_log(r.user_id, p_sid_hash, 'geo_moved', p_net_hash, p_kernel, p_protocol, p_country, jsonb_build_object('mode', 'enforce', 'was', r.country)); v_logged := true;
    v_kill := 'geo_moved'; v_state := 'geo_outside';
  end if;

  -- L2 two machines on one session: the network keeps flipping
  v_flips := r.net_flips; v_win := r.flip_window_at;
  if r.net_hash <> p_net_hash then
    if v_win is null or v_win < now() - interval '10 minutes' then v_flips := 1; v_win := now(); else v_flips := v_flips + 1; end if;
    if not v_quiet then
      perform public._sess_log(r.user_id, p_sid_hash, 'net_changed', p_net_hash, p_kernel, p_protocol, p_country,
             jsonb_build_object('known_net', exists (select 1 from public.founder_signin_nets n where n.user_id = r.user_id and n.net_hash = p_net_hash), 'flips', v_flips)); v_logged := true; end if;
    if v_flips = (pol ->> 'flap_limit')::integer then
      perform public._sess_log(r.user_id, p_sid_hash, 'net_flapping', p_net_hash, p_kernel, p_protocol, p_country, jsonb_build_object('flips', v_flips, 'window_s', 600)); v_logged := true;
      if v_kill is null and pol ->> 'flap_action' = 'revoke' then v_kill := 'session_shared'; v_state := 'flapping_revoked'; end if;
    end if;
  end if;
  if not v_quiet and r.protocol <> p_protocol and p_protocol <> 'unknown' then
    perform public._sess_log(r.user_id, p_sid_hash, 'protocol_changed', p_net_hash, p_kernel, p_protocol, p_country, jsonb_build_object('from', r.protocol, 'to', p_protocol)); v_logged := true; end if;
  if not v_quiet and r.kernel_version <> p_kernel and p_kernel <> 'unknown' then
    perform public._sess_log(r.user_id, p_sid_hash, 'kernel_changed', p_net_hash, p_kernel, p_protocol, p_country, jsonb_build_object('from', r.kernel_version, 'to', p_kernel)); v_logged := true; end if;

  -- L6 integrity streak
  v_streak := case when p_verified then 0 else r.fail_streak + 1 end;
  if not p_verified then
    if v_streak = (pol ->> 'fail_limit')::integer or r.last_fail_at is null or r.last_fail_at < now() - interval '60 seconds' then
      perform public._sess_log(r.user_id, p_sid_hash, 'integrity_fail', p_net_hash, p_kernel, p_protocol, p_country, jsonb_build_object('streak', v_streak, 'limit', (pol ->> 'fail_limit')::integer)); v_logged := true; end if;
    if v_kill is null and v_streak >= (pol ->> 'fail_limit')::integer then v_kill := 'integrity_fail'; v_state := 'integrity_revoked'; end if;
  end if;
  if not v_logged and r.last_ledger_at < now() - interval '5 minutes' then
    perform public._sess_log(r.user_id, p_sid_hash, 'seen', p_net_hash, p_kernel, p_protocol, p_country, '{}'::jsonb); v_logged := true; end if;

  update public.founder_session_registry set
         net_hash = p_net_hash, protocol = case when p_protocol = 'unknown' then protocol else p_protocol end, kernel_version = case when p_kernel = 'unknown' then kernel_version else p_kernel end,
         last_seen_at = greatest(now(), last_seen_at), last_ledger_at = case when v_logged then now() else last_ledger_at end,
         last_verified_at = case when p_verified then now() else last_verified_at end, verified_ok = verified_ok + (case when p_verified then 1 else 0 end),
         verified_fail = verified_fail + (case when p_verified then 0 else 1 end), last_fail_at = case when p_verified then last_fail_at else now() end,
         net_flips = v_flips, flip_window_at = v_win, fail_streak = v_streak,
         country = coalesce(p_country, country)
   where sid_hash = p_sid_hash;
  if v_kill is not null then perform public._sess_kill(p_sid_hash, v_kill); end if;
  return jsonb_build_object('ok', v_state = 'live', 'state', v_state, 'drift', to_jsonb(v_drift));
end $$;

-- ------------------------------------------------------------------------------------------------------------------------------
-- 4) L7 + L8: verify the LATEST rows, and anchor the head into two places so a deleted or rewritten tail is caught
-- ------------------------------------------------------------------------------------------------------------------------------
create or replace function public.founder_session_ledger_verify_tail(p_n integer default 500) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare r record; v_prev text; v_first boolean := true; v_cnt integer := 0; v_head bigint; v_hhash text;
begin
  for r in select * from (select * from public.founder_session_ledger order by id desc limit least(greatest(coalesce(p_n, 500), 1), 50000)) t order by id asc loop
    if v_first then
      select hash into v_prev from public.founder_session_ledger where id < r.id order by id desc limit 1;
      v_prev := coalesce(v_prev, repeat('0', 64)); v_first := false;
    end if;
    if r.prev_hash <> v_prev then return jsonb_build_object('ok', false, 'broken_at', r.id, 'why', 'prev_hash'); end if;
    if r.hash <> public._sess_event_hash(r.prev_hash, r.ts_ms, r.user_id, r.sid_hash, r.kind, r.net_hash, r.kernel_version, r.protocol, r.country, r.facts) then
      return jsonb_build_object('ok', false, 'broken_at', r.id, 'why', 'hash'); end if;
    v_prev := r.hash; v_cnt := v_cnt + 1; v_head := r.id; v_hhash := r.hash;
  end loop;
  return jsonb_build_object('ok', true, 'checked', v_cnt, 'head_id', v_head, 'head_hash', v_hhash);
end $$;

create or replace function public.founder_session_anchor(p_uid uuid) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '20s' as $$
declare v_head public.founder_session_ledger%rowtype; v_rows bigint; v_a jsonb := null; v_seq bigint := null; v_ah text := null; v_last bigint;
begin
  if p_uid is null or not exists (select 1 from public.founder_accounts where user_id = p_uid) then return jsonb_build_object('ok', false, 'error', 'not_a_founder'); end if;
  perform pg_advisory_xact_lock(hashtextextended('founder_session:chain', 0));
  select * into v_head from public.founder_session_ledger order by id desc limit 1;
  if not found then return jsonb_build_object('ok', true, 'anchored', false, 'why', 'empty'); end if;
  select max(head_id) into v_last from public.founder_session_anchors;
  if v_last is not null and v_last = v_head.id then return jsonb_build_object('ok', true, 'anchored', false, 'why', 'unchanged', 'head_id', v_head.id); end if;
  select count(*) into v_rows from public.founder_session_ledger where id <= v_head.id;
  if to_regprocedure('public.founder_audit_append(uuid,text,text,text,jsonb)') is not null then
    begin
      v_a := public.founder_audit_append(p_uid, 'session.ledger_anchor', 'head:' || v_head.id, 'session ledger head anchored into the audit chain',
                                         jsonb_build_object('head_id', v_head.id, 'head_hash', v_head.hash, 'rows', v_rows));
      v_seq := (v_a ->> 'seq')::bigint; v_ah := v_a ->> 'hash';
    exception when others then v_seq := null; v_ah := null; end;
  end if;
  insert into public.founder_session_anchors (ts_ms, head_id, head_hash, ledger_rows, audit_seq, audit_hash)
  values ((extract(epoch from clock_timestamp()) * 1000)::bigint, v_head.id, v_head.hash, v_rows, v_seq, v_ah);
  return jsonb_build_object('ok', true, 'anchored', true, 'head_id', v_head.id, 'rows', v_rows, 'audit_seq', v_seq);
end $$;

-- every anchor must still be in the ledger with the same hash and the same number of rows before it
create or replace function public.founder_session_anchor_check() returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare a record; v_n integer := 0; v_cnt bigint; v_h text;
begin
  for a in select * from public.founder_session_anchors order by id desc limit 200 loop
    select hash into v_h from public.founder_session_ledger where id = a.head_id;
    if v_h is null or v_h <> a.head_hash then return jsonb_build_object('ok', false, 'anchor', a.id, 'why', 'anchored_row_missing_or_changed'); end if;
    select count(*) into v_cnt from public.founder_session_ledger where id <= a.head_id;
    if v_cnt <> a.ledger_rows then return jsonb_build_object('ok', false, 'anchor', a.id, 'why', 'rows_before_head_differ', 'expected', a.ledger_rows, 'found', v_cnt); end if;
    if a.audit_seq is not null and to_regclass('public.founder_audit') is not null then
      if not exists (select 1 from public.founder_audit where seq = a.audit_seq and hash = a.audit_hash) then return jsonb_build_object('ok', false, 'anchor', a.id, 'why', 'audit_anchor_missing'); end if;
    end if;
    v_n := v_n + 1;
  end loop;
  return jsonb_build_object('ok', true, 'anchors_checked', v_n);
end $$;

-- ------------------------------------------------------------------------------------------------------------------------------
-- 5) L9 policy_set_v2: every knob, lock-out guard kept, absolute >= idle, every change in the chain
-- ------------------------------------------------------------------------------------------------------------------------------
create or replace function public.founder_session_policy_set_v2(p_uid uuid, p_geo_mode text, p_countries text[], p_spoof_action text, p_stale_after_s integer, p_max_live integer,
    p_fail_limit integer, p_flap_limit integer, p_flap_action text, p_idle_s integer, p_absolute_s integer, p_current_country text, p_reason text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '8s' as $$
declare v_old jsonb; v_c text[];
begin
  if p_uid is null or coalesce(p_geo_mode, '') not in ('off', 'observe', 'enforce') or coalesce(p_spoof_action, '') not in ('alert', 'block') or coalesce(p_flap_action, '') not in ('alert', 'revoke')
     or p_stale_after_s is null or p_stale_after_s not between 30 and 86400 or p_max_live is null or p_max_live not between 2 and 200 or p_fail_limit is null or p_fail_limit not between 3 and 100
     or p_flap_limit is null or p_flap_limit not between 2 and 50 or p_idle_s is null or p_idle_s not between 300 and 2592000 or p_absolute_s is null or p_absolute_s not between 3600 and 7776000
     or p_absolute_s < p_idle_s or not public._sess_countries_ok(coalesce(p_countries, '{}'::text[])) or (p_current_country is not null and p_current_country !~ '^[A-Z]{2}$')
     or p_reason is null or length(btrim(p_reason)) not between 8 and 200 or p_reason ~ '[\x00-\x1f\x7f<>]' then
    return jsonb_build_object('ok', false, 'error', 'shape'); end if;
  if not exists (select 1 from public.founder_accounts where user_id = p_uid) then return jsonb_build_object('ok', false, 'error', 'not_a_founder'); end if;
  v_c := coalesce(p_countries, '{}'::text[]);
  if p_geo_mode = 'enforce' then
    if cardinality(v_c) = 0 then return jsonb_build_object('ok', false, 'error', 'enforce_needs_a_country'); end if;
    if p_current_country is null or not (p_current_country = any (v_c)) then return jsonb_build_object('ok', false, 'error', 'would_lock_you_out'); end if;
  end if;
  perform pg_advisory_xact_lock(hashtextextended('founder_session:pol:' || p_uid::text, 0));
  v_old := public._sess_pol(p_uid);
  insert into public.founder_session_policy (user_id, geo_mode, countries, spoof_action, stale_after_s, max_live, fail_limit, flap_limit, flap_action, idle_s, absolute_s, updated_at)
  values (p_uid, p_geo_mode, v_c, p_spoof_action, p_stale_after_s, p_max_live, p_fail_limit, p_flap_limit, p_flap_action, p_idle_s, p_absolute_s, now())
  on conflict (user_id) do update set geo_mode = excluded.geo_mode, countries = excluded.countries, spoof_action = excluded.spoof_action, stale_after_s = excluded.stale_after_s,
     max_live = excluded.max_live, fail_limit = excluded.fail_limit, flap_limit = excluded.flap_limit, flap_action = excluded.flap_action, idle_s = excluded.idle_s, absolute_s = excluded.absolute_s, updated_at = now();
  perform public._sess_log(p_uid, null, 'policy_changed', null, null, null, p_current_country,
         jsonb_build_object('geo_mode', p_geo_mode, 'countries', to_jsonb(v_c), 'spoof_action', p_spoof_action, 'max_live', p_max_live, 'fail_limit', p_fail_limit, 'flap_limit', p_flap_limit,
                            'flap_action', p_flap_action, 'idle_s', p_idle_s, 'absolute_s', p_absolute_s, 'was_geo', v_old ->> 'geo_mode', 'reason', btrim(p_reason)));
  return jsonb_build_object('ok', true, 'policy', public._sess_pol(p_uid));
end $$;

-- ------------------------------------------------------------------------------------------------------------------------------
-- 6) E155 doors replaced by stronger versions of the SAME signature: register (+ session cap, L5) and board (+ tail verify, anchor, full policy, flap counters; L7, L8)
-- ------------------------------------------------------------------------------------------------------------------------------
create or replace function public.founder_session_register(p_uid uuid, p_sid_hash text, p_device_hash text, p_net_hash text, p_method text, p_protocol text, p_kernel text,
                                                          p_key_source text, p_key_fp text, p_ua_family text, p_hint_family text, p_country text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '8s' as $$
declare v_pol2 jsonb; v_live integer; v_old text; v_geo jsonb; v_sp jsonb; v_pol public.founder_session_policy%rowtype; v_state text; v_existing public.founder_session_registry%rowtype;
begin
  if p_uid is null or not public._sess_h64(p_sid_hash) or not public._sess_h64(p_device_hash) or not public._sess_h64(p_net_hash)
     or p_method is null or p_method not in ('password', 'passkey', 'magic_link') or coalesce(p_protocol, '') not in ('quic', 'h2', 'h1', 'unknown')
     or not public._sess_kernel_ok(p_kernel) or coalesce(p_key_source, '') not in ('dbsc', 'webcrypto', 'none')
     or (p_key_source = 'none' and p_key_fp is not null) or (p_key_source <> 'none' and not public._sess_h64(p_key_fp))
     or not public._sess_family(p_ua_family) or not public._sess_family(p_hint_family) or (p_country is not null and p_country !~ '^[A-Z]{2}$') then
    return jsonb_build_object('ok', false, 'error', 'shape'); end if;
  if not exists (select 1 from public.founder_accounts where user_id = p_uid) then return jsonb_build_object('ok', false, 'error', 'not_a_founder'); end if;
  perform pg_advisory_xact_lock(hashtextextended('founder_session:reg:' || p_uid::text, 0));
  select * into v_existing from public.founder_session_registry where sid_hash = p_sid_hash;
  if found then
    if v_existing.user_id <> p_uid then return jsonb_build_object('ok', false, 'error', 'shape'); end if;
    return jsonb_build_object('ok', true, 'decision', case when v_existing.revoked_at is null then 'allow' else 'deny' end, 'existing', true, 'spoof', jsonb_build_object('level', v_existing.spoof_level, 'score', v_existing.spoof_score));
  end if;

  v_geo := public.founder_session_geo_check(p_uid, p_country, p_device_hash);
  if v_geo ->> 'decision' = 'deny' then
    perform public._sess_log(p_uid, p_sid_hash, 'geo_refused', p_net_hash, p_kernel, p_protocol, p_country, jsonb_build_object('why', v_geo ->> 'why', 'mode', v_geo ->> 'mode', 'method', p_method));
    return jsonb_build_object('ok', true, 'decision', 'deny', 'reason', 'location', 'geo', v_geo);
  end if;

  v_sp := public._sess_spoof(p_uid, p_device_hash, p_key_source, p_key_fp, p_ua_family, p_hint_family);
  select * into v_pol from public.founder_session_policy where user_id = p_uid;
  if v_sp ->> 'level' = 'spoof' and found and v_pol.spoof_action = 'block' then
    perform public._sess_log(p_uid, p_sid_hash, 'spoof_blocked', p_net_hash, p_kernel, p_protocol, p_country, jsonb_build_object('score', (v_sp ->> 'score')::integer, 'reasons', v_sp -> 'reasons'));
    return jsonb_build_object('ok', true, 'decision', 'deny', 'reason', 'spoof', 'spoof', v_sp);
  end if;

  -- L5 concurrent-session cap (ASVS V3): when the founder is at the limit, the longest-idle live sessions are closed ('replaced') and the chain says so
  v_pol2 := public._sess_pol(p_uid);
  select count(*) into v_live from public.founder_session_registry where user_id = p_uid and revoked_at is null;
  while v_live >= (v_pol2 ->> 'max_live')::integer loop
    select sid_hash into v_old from public.founder_session_registry where user_id = p_uid and revoked_at is null order by last_seen_at asc limit 1;
    exit when v_old is null;
    perform public._sess_kill(v_old, 'replaced');
    perform public._sess_log(p_uid, v_old, 'session_cap', p_net_hash, p_kernel, p_protocol, p_country, jsonb_build_object('limit', (v_pol2 ->> 'max_live')::integer, 'by_new_session', left(p_sid_hash, 12)));
    v_live := v_live - 1;
  end loop;

  v_state := coalesce(v_geo ->> 'state', 'off');
  insert into public.founder_session_registry (sid_hash, user_id, device_hash, net_hash, method, protocol, kernel_version, key_source, key_fp, ua_family, hint_family,
                                               spoof_score, spoof_level, spoof_reasons, country, geo_state)
  values (p_sid_hash, p_uid, p_device_hash, p_net_hash, p_method, p_protocol, p_kernel, p_key_source, p_key_fp, p_ua_family, p_hint_family,
          (v_sp ->> 'score')::integer, v_sp ->> 'level', coalesce(array(select jsonb_array_elements_text(v_sp -> 'reasons')), '{}'), p_country, v_state);
  perform public._sess_log(p_uid, p_sid_hash, 'registered', p_net_hash, p_kernel, p_protocol, p_country,
                           jsonb_build_object('method', p_method, 'key_source', p_key_source, 'key', left(coalesce(p_key_fp, ''), 16), 'ua', p_ua_family, 'hint', p_hint_family));
  if v_sp ->> 'level' <> 'ok' then
    perform public._sess_log(p_uid, p_sid_hash, 'spoof_alert', p_net_hash, p_kernel, p_protocol, p_country, jsonb_build_object('score', (v_sp ->> 'score')::integer, 'level', v_sp ->> 'level', 'reasons', v_sp -> 'reasons'));
  end if;
  if v_state = 'observed_outside' then
    perform public._sess_log(p_uid, p_sid_hash, 'geo_observed', p_net_hash, p_kernel, p_protocol, p_country, jsonb_build_object('mode', v_geo ->> 'mode', 'known_device', (v_geo ->> 'known_device')::boolean));
  end if;
  return jsonb_build_object('ok', true, 'decision', 'allow', 'existing', false, 'spoof', v_sp, 'geo', v_geo);
end $$;

create or replace function public.founder_sessions_board(p_uid uuid, p_current_sid_hash text default null) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '10s' as $$
declare v_pol public.founder_session_policy%rowtype; v_stale integer; v_rows jsonb; v_live integer; v_spoof integer; v_chain jsonb;
begin
  if p_uid is null then return jsonb_build_object('ok', false, 'error', 'shape'); end if;
  select * into v_pol from public.founder_session_policy where user_id = p_uid;
  v_stale := coalesce(v_pol.stale_after_s, 900);
  select coalesce(jsonb_agg(x order by (x ->> 'live')::boolean desc, x ->> 'last_seen_at' desc), '[]'::jsonb) into v_rows from (
    select jsonb_build_object(
      'sid', left(r.sid_hash, 12), 'sid_hash', r.sid_hash, 'current', (p_current_sid_hash is not null and r.sid_hash = p_current_sid_hash),
      'live', r.revoked_at is null, 'method', r.method,
      'device', left(r.device_hash, 12), 'key_source', r.key_source, 'key_fp', left(coalesce(r.key_fp, ''), 16),
      'claimed_browser', r.ua_family, 'proven_browser', r.hint_family,
      'spoof', jsonb_build_object('level', r.spoof_level, 'score', r.spoof_score, 'reasons', to_jsonb(r.spoof_reasons)),
      'protocol', r.protocol, 'path_badge', public._sess_path_badge(r.protocol), 'kernel', r.kernel_version,
      'integrity', jsonb_build_object('state', public._sess_integrity(r.last_verified_at, r.last_fail_at, v_stale), 'last_verified_at', r.last_verified_at, 'ok', r.verified_ok, 'fail', r.verified_fail),
      'country', r.country, 'geo_state', r.geo_state, 'net_flips', r.net_flips, 'fail_streak', r.fail_streak, 'created_at', r.created_at, 'last_seen_at', r.last_seen_at,
      'age_s', greatest(0, extract(epoch from now() - r.created_at))::bigint,
      'revoked_at', r.revoked_at, 'revoke_reason', r.revoke_reason) as x
    from public.founder_session_registry r
    where r.user_id = p_uid and (r.revoked_at is null or r.revoked_at > now() - interval '7 days')
    order by (r.revoked_at is null) desc, r.last_seen_at desc limit 60) q;
  select count(*) filter (where revoked_at is null), count(*) filter (where revoked_at is null and spoof_level <> 'ok') into v_live, v_spoof from public.founder_session_registry where user_id = p_uid;
  v_chain := public.founder_session_ledger_verify_tail(500);
  return jsonb_build_object('ok', true, 'sessions', v_rows, 'live', v_live, 'live_with_alert', v_spoof,
    'policy', public._sess_pol(p_uid), 'anchor', public.founder_session_anchor_check(),
    'ledger_chain', v_chain,
    'limits', jsonb_build_array('hardware_identity_is_the_device_key_fingerprint', 'vpn_inside_an_allowed_country_passes_the_location_lock', 'integrity_is_the_last_real_verification_time'));
end $$;

-- housekeeping: also expire by the policy lifetimes (idle / absolute), bounded and cheap
create or replace function public.founder_session_tick() returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '20s' as $$
declare r record; v_n integer := 0;
begin
  for r in select g.sid_hash from public.founder_session_registry g where g.revoked_at is null
            and (g.last_seen_at < now() - make_interval(secs => (public._sess_pol(g.user_id) ->> 'idle_s')::integer)
              or g.created_at   < now() - make_interval(secs => (public._sess_pol(g.user_id) ->> 'absolute_s')::integer) or g.last_seen_at < now() - interval '30 days')
          order by g.last_seen_at limit 200 for update skip locked loop
    if public._sess_kill(r.sid_hash, 'expired') then v_n := v_n + 1; end if;
  end loop;
  return jsonb_build_object('expired', v_n);
end $$;

-- ------------------------------------------------------------------------------------------------------------------------------
-- 7) grants
-- ------------------------------------------------------------------------------------------------------------------------------
revoke all on function public._sess_pol(uuid), public._sess_kill(text, text), public.founder_session_check(text, text, text, text, boolean, text, text, text, text),
  public.founder_session_ledger_verify_tail(integer), public.founder_session_anchor(uuid), public.founder_session_anchor_check(),
  public.founder_session_policy_set_v2(uuid, text, text[], text, integer, integer, integer, integer, text, integer, integer, text, text), public.founder_session_tick() from public, anon, authenticated;
grant execute on function public.founder_session_check(text, text, text, text, boolean, text, text, text, text), public.founder_session_ledger_verify_tail(integer),
  public.founder_session_anchor(uuid), public.founder_session_anchor_check(),
  public.founder_session_policy_set_v2(uuid, text, text[], text, integer, integer, integer, integer, text, integer, integer, text, text), public.founder_session_tick() to service_role;
-- E155 grants survive create-or-replace (same signature); the internal helpers stay closed even to service_role
revoke all on function public._sess_pol(uuid), public._sess_kill(text, text) from service_role;

-- ------------------------------------------------------------------------------------------------------------------------------
-- 8) posture156, read from the catalogs
-- ------------------------------------------------------------------------------------------------------------------------------
create or replace function public.founder_session_posture156() returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions as $$
declare
  v_doors text[] := array['public.founder_session_check(text,text,text,text,boolean,text,text,text,text)', 'public.founder_session_ledger_verify_tail(integer)', 'public.founder_session_anchor(uuid)',
    'public.founder_session_anchor_check()', 'public.founder_session_policy_set_v2(uuid,text,text[],text,integer,integer,integer,integer,text,integer,integer,text,text)', 'public.founder_session_tick()'];
  d text; v_sr boolean := true; v_open boolean := false; v_def boolean := true; v_pin boolean := true; v_oid oid;
begin
  foreach d in array v_doors loop
    v_oid := to_regprocedure(d);
    if v_oid is null then v_sr := false; v_def := false; v_pin := false; continue; end if;
    if not has_function_privilege('service_role', v_oid, 'execute') then v_sr := false; end if;
    if has_function_privilege('anon', v_oid, 'execute') or has_function_privilege('authenticated', v_oid, 'execute') then v_open := true; end if;
    if not (select p.prosecdef from pg_proc p where p.oid = v_oid) then v_def := false; end if;
    if not coalesce((select p.proconfig::text like '%search_path=%' from pg_proc p where p.oid = v_oid), false) then v_pin := false; end if;
  end loop;
  return jsonb_build_object(
    'doors_service_role_only', v_sr and not v_open, 'doors_definer', v_def, 'doors_search_path_pinned', v_pin,
    'ledger_kinds_widened', exists (select 1 from pg_constraint where conrelid = 'public.founder_session_ledger'::regclass and conname = 'founder_session_ledger_kind_ck' and pg_get_constraintdef(oid) like '%identity_drift%'),
    'policy_limits_enforced', exists (select 1 from pg_constraint where conrelid = 'public.founder_session_policy'::regclass and conname = 'founder_session_policy_limits_ck'),
    'anchors_append_only', (select count(*) from pg_trigger t where t.tgrelid = 'public.founder_session_anchors'::regclass and not t.tgisinternal and t.tgname in ('founder_session_anchors_stop', 'founder_session_anchors_stop_trunc')) = 2
        and not has_table_privilege('service_role', 'public.founder_session_anchors', 'insert') and not has_table_privilege('service_role', 'public.founder_session_anchors', 'update')
        and not has_table_privilege('service_role', 'public.founder_session_anchors', 'delete'),
    'internal_helpers_closed', not has_function_privilege('service_role', 'public._sess_kill(text,text)', 'execute') and not has_function_privilege('service_role', 'public._sess_pol(uuid)', 'execute'),
    'ledger_tail_verifies', (public.founder_session_ledger_verify_tail(500) ->> 'ok')::boolean,
    'anchors_match_ledger', (public.founder_session_anchor_check() ->> 'ok')::boolean);
end $$;

-- ------------------------------------------------------------------------------------------------------------------------------
-- 9) selftest156: rolled-back end-to-end proof of every loophole fix (his real rows are never touched; nothing persists)
-- ------------------------------------------------------------------------------------------------------------------------------
create or replace function public.founder_session_selftest156() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '45s' as $$
declare
  v_msg text := 'E156 selftest FAIL: unknown'; v_uid uuid; j jsonb; v_n integer;
  s1 text := encode(extensions.digest('e156-s1', 'sha256'), 'hex'); s2 text := encode(extensions.digest('e156-s2', 'sha256'), 'hex'); s3 text := encode(extensions.digest('e156-s3', 'sha256'), 'hex');
  s4 text := encode(extensions.digest('e156-s4', 'sha256'), 'hex'); s5 text := encode(extensions.digest('e156-s5', 'sha256'), 'hex'); s6 text := encode(extensions.digest('e156-s6', 'sha256'), 'hex');
  s7 text := encode(extensions.digest('e156-s7', 'sha256'), 'hex'); s8 text := encode(extensions.digest('e156-s8', 'sha256'), 'hex'); s9 text := encode(extensions.digest('e156-s9', 'sha256'), 'hex');
  s10 text := encode(extensions.digest('e156-s10', 'sha256'), 'hex'); s11 text := encode(extensions.digest('e156-s11', 'sha256'), 'hex');
  d1 text := encode(extensions.digest('e156-d1', 'sha256'), 'hex'); d2 text := encode(extensions.digest('e156-d2', 'sha256'), 'hex'); d3 text := encode(extensions.digest('e156-d3', 'sha256'), 'hex');
  d4 text := encode(extensions.digest('e156-d4', 'sha256'), 'hex'); d5 text := encode(extensions.digest('e156-d5', 'sha256'), 'hex'); d6 text := encode(extensions.digest('e156-d6', 'sha256'), 'hex');
  d7 text := encode(extensions.digest('e156-d7', 'sha256'), 'hex'); d8 text := encode(extensions.digest('e156-d8', 'sha256'), 'hex'); d9 text := encode(extensions.digest('e156-d9', 'sha256'), 'hex');
  d10 text := encode(extensions.digest('e156-d10', 'sha256'), 'hex'); d11 text := encode(extensions.digest('e156-d11', 'sha256'), 'hex');
  n1 text := encode(extensions.digest('e156-n1', 'sha256'), 'hex'); n2 text := encode(extensions.digest('e156-n2', 'sha256'), 'hex'); n3 text := encode(extensions.digest('e156-n3', 'sha256'), 'hex');
  k1 text := encode(extensions.digest('e156-k1', 'sha256'), 'hex'); k2 text := encode(extensions.digest('e156-k2', 'sha256'), 'hex');
begin
  select user_id into v_uid from public.founder_accounts order by user_id limit 1;
  if v_uid is null then return 'E156 selftest SKIP: no founder account yet'; end if;
  begin
    -- policy_set_v2 shape and the lock-out guard
    if public.founder_session_policy_set_v2(v_uid, 'off', '{}', 'alert', 900, 3, 3, 3, 'alert', 86400, 3600, 'PK', 'selftest absolute below idle') ->> 'error' <> 'shape' then raise exception 'absolute < idle was accepted'; end if;
    if public.founder_session_policy_set_v2(v_uid, 'enforce', array['PK'], 'alert', 900, 3, 3, 3, 'alert', 3600, 86400, 'US', 'selftest lockout guard') ->> 'error' <> 'would_lock_you_out' then raise exception 'enforce that locks the founder out was accepted'; end if;
    if public.founder_session_policy_set_v2(v_uid, 'off', '{}', 'alert', 900, 1, 3, 3, 'alert', 3600, 86400, 'PK', 'selftest cap too small') ->> 'error' <> 'shape' then raise exception 'a session cap of 1 was accepted'; end if;
    if public.founder_session_policy_set_v2(v_uid, 'off', '{}', 'alert', 900, 3, 3, 3, 'alert', 3600, 86400, 'PK', 'selftest cap three') ->> 'ok' <> 'true' then raise exception 'a valid policy was refused'; end if;

    -- L5 session cap: the 4th session closes exactly one older one, and the chain says so
    perform public.founder_session_register(v_uid, s1, d1, n1, 'passkey', 'quic', 'k-1', 'none', null, 'chrome', 'chrome', 'PK');
    perform public.founder_session_register(v_uid, s2, d2, n1, 'passkey', 'quic', 'k-1', 'none', null, 'chrome', 'chrome', 'PK');
    perform public.founder_session_register(v_uid, s3, d3, n1, 'passkey', 'quic', 'k-1', 'none', null, 'chrome', 'chrome', 'PK');
    perform public.founder_session_register(v_uid, s4, d4, n1, 'passkey', 'quic', 'k-1', 'none', null, 'chrome', 'chrome', 'PK');
    select count(*) into v_n from public.founder_session_registry where user_id = v_uid and sid_hash in (s1, s2, s3, s4) and revoked_at is null;
    if v_n <> 3 then raise exception 'the cap of 3 left % live sessions', v_n; end if;
    if (select count(*) from public.founder_session_ledger where kind = 'session_cap' and sid_hash in (s1, s2, s3, s4)) <> 1 then raise exception 'the session cap is not in the ledger exactly once'; end if;
    perform public.founder_session_revoke_others(v_uid, s4);
    if public.founder_session_policy_set_v2(v_uid, 'off', '{}', 'alert', 900, 20, 3, 3, 'alert', 3600, 86400, 'PK', 'selftest cap twenty') ->> 'ok' <> 'true' then raise exception 'policy reset failed'; end if;

    -- L1 identity drift mid-session: alert mode records and marks, block mode closes
    perform public.founder_session_register(v_uid, s5, d5, n1, 'passkey', 'quic', 'k-1', 'dbsc', k1, 'chrome', 'chrome', 'PK');
    j := public.founder_session_check(s5, n1, 'quic', 'k-1', true, 'firefox', 'chrome', null, 'PK');
    if j ->> 'state' <> 'live' or j -> 'drift' ->> 0 <> 'user_agent_changed' then raise exception 'a user-agent change was not reported as drift: %', j; end if;
    if not exists (select 1 from public.founder_session_ledger where sid_hash = s5 and kind = 'identity_drift') or (select spoof_level from public.founder_session_registry where sid_hash = s5) <> 'spoof' then
      raise exception 'drift is not in the ledger or not marked on the session'; end if;
    j := public.founder_session_check(s5, n1, 'quic', 'k-1', true, 'chrome', 'chrome', k2, 'PK');
    if j -> 'drift' ->> 0 <> 'device_key_changed' then raise exception 'a different proven device key was not reported: %', j; end if;
    j := public.founder_session_check(s5, n1, 'quic', 'k-1', true, 'chrome', 'chrome', null, 'PK');
    if jsonb_array_length(j -> 'drift') <> 0 then raise exception 'a request without a key proof was counted as a mismatch'; end if;
    perform public.founder_session_policy_set_v2(v_uid, 'off', '{}', 'block', 900, 20, 3, 3, 'alert', 3600, 86400, 'PK', 'selftest spoof block');
    j := public.founder_session_check(s5, n1, 'quic', 'k-1', true, 'chrome', 'safari', null, 'PK');
    if j ->> 'state' <> 'drift_revoked' or (select revoked_at from public.founder_session_registry where sid_hash = s5) is null then raise exception 'block mode did not close a drifting session: %', j; end if;
    if public.founder_session_check(s5, n1, 'quic', 'k-1', true, 'chrome', 'chrome', null, 'PK') ->> 'state' <> 'revoked' then raise exception 'a closed session still answered live'; end if;

    -- L1 location lock on every request: a stolen token outside the countries is refused and closed; an unresolved country never kills an admitted session
    perform public.founder_session_policy_set_v2(v_uid, 'enforce', array['PK'], 'alert', 900, 20, 3, 3, 'alert', 3600, 86400, 'PK', 'selftest enforce pakistan');
    perform public.founder_session_register(v_uid, s6, d6, n1, 'passkey', 'quic', 'k-1', 'none', null, 'chrome', 'chrome', 'PK');
    perform public.founder_session_register(v_uid, s7, d7, n1, 'passkey', 'quic', 'k-1', 'none', null, 'chrome', 'chrome', 'PK');
    if public.founder_session_check(s7, n1, 'quic', 'k-1', true, 'chrome', 'chrome', null, null) ->> 'state' <> 'live' then raise exception 'an unresolved country closed an admitted session'; end if;
    j := public.founder_session_check(s6, n1, 'quic', 'k-1', true, 'chrome', 'chrome', null, 'US');
    if j ->> 'state' <> 'geo_outside' or (select revoke_reason from public.founder_session_registry where sid_hash = s6) <> 'geo_moved' or not exists (select 1 from public.founder_session_ledger where sid_hash = s6 and kind = 'geo_moved') then
      raise exception 'a token used outside the allowed country was not refused and closed: %', j; end if;

    -- L2 + L3 network flapping: logged once at the limit, change logs rate-limited; revoke mode closes the session
    perform public.founder_session_policy_set_v2(v_uid, 'off', '{}', 'alert', 900, 20, 3, 3, 'alert', 3600, 86400, 'PK', 'selftest flap alert');
    perform public.founder_session_register(v_uid, s8, d8, n1, 'password', 'h2', 'k-1', 'none', null, 'chrome', 'chrome', 'PK');
    perform public.founder_session_check(s8, n2, 'h2', 'k-1', true, 'chrome', 'chrome', null, 'PK');
    perform public.founder_session_check(s8, n3, 'h2', 'k-1', true, 'chrome', 'chrome', null, 'PK');
    j := public.founder_session_check(s8, n2, 'h2', 'k-1', true, 'chrome', 'chrome', null, 'PK');
    if j ->> 'state' <> 'live' or (select count(*) from public.founder_session_ledger where sid_hash = s8 and kind = 'net_flapping') <> 1 then raise exception 'flapping was not written exactly once at the limit'; end if;
    if (select count(*) from public.founder_session_ledger where sid_hash = s8 and kind = 'net_changed') > 1 then raise exception 'network-change logs were not rate-limited (L3)'; end if;
    perform public.founder_session_policy_set_v2(v_uid, 'off', '{}', 'alert', 900, 20, 3, 3, 'revoke', 3600, 86400, 'PK', 'selftest flap revoke');
    perform public.founder_session_register(v_uid, s9, d9, n1, 'password', 'h2', 'k-1', 'none', null, 'chrome', 'chrome', 'PK');
    perform public.founder_session_check(s9, n2, 'h2', 'k-1', true, 'chrome', 'chrome', null, 'PK');
    perform public.founder_session_check(s9, n3, 'h2', 'k-1', true, 'chrome', 'chrome', null, 'PK');
    j := public.founder_session_check(s9, n2, 'h2', 'k-1', true, 'chrome', 'chrome', null, 'PK');
    if j ->> 'state' <> 'flapping_revoked' or (select revoke_reason from public.founder_session_registry where sid_hash = s9) <> 'session_shared' then raise exception 'a shared session was not closed: %', j; end if;

    -- L6 integrity streak: the third failure in a row closes the session; one success resets the streak
    perform public.founder_session_register(v_uid, s10, d10, n1, 'password', 'h2', 'k-1', 'none', null, 'chrome', 'chrome', 'PK');
    perform public.founder_session_check(s10, n1, 'h2', 'k-1', false, 'chrome', 'chrome', null, 'PK');
    perform public.founder_session_check(s10, n1, 'h2', 'k-1', false, 'chrome', 'chrome', null, 'PK');
    perform public.founder_session_check(s10, n1, 'h2', 'k-1', true, 'chrome', 'chrome', null, 'PK');
    if (select fail_streak from public.founder_session_registry where sid_hash = s10) <> 0 then raise exception 'a success did not reset the failure streak'; end if;
    perform public.founder_session_check(s10, n1, 'h2', 'k-1', false, 'chrome', 'chrome', null, 'PK');
    perform public.founder_session_check(s10, n1, 'h2', 'k-1', false, 'chrome', 'chrome', null, 'PK');
    j := public.founder_session_check(s10, n1, 'h2', 'k-1', false, 'chrome', 'chrome', null, 'PK');
    if j ->> 'state' <> 'integrity_revoked' then raise exception 'three failures in a row did not close the session: %', j; end if;

    -- L4 lifetimes: a session idle longer than the policy is closed as expired
    perform public.founder_session_policy_set_v2(v_uid, 'off', '{}', 'alert', 900, 20, 3, 3, 'alert', 3600, 86400, 'PK', 'selftest idle one hour');
    insert into public.founder_session_registry (sid_hash, user_id, device_hash, net_hash, method, created_at, last_seen_at) values (s11, v_uid, d11, n1, 'password', now() - interval '2 days', now() - interval '2 days');
    if public.founder_session_check(s11, n1, 'h2', 'k-1', true, 'chrome', 'chrome', null, 'PK') ->> 'state' <> 'expired' then raise exception 'an idle session was not expired'; end if;

    -- L7 + L8 tail verify and the cross-chain anchor: a deleted tail is caught
    if public.founder_session_ledger_verify_tail(50) ->> 'ok' <> 'true' then raise exception 'the tail does not verify'; end if;
    if public.founder_session_anchor(v_uid) ->> 'anchored' <> 'true' then raise exception 'the head was not anchored'; end if;
    if public.founder_session_anchor(v_uid) ->> 'why' <> 'unchanged' then raise exception 'an unchanged head was anchored twice'; end if;
    if public.founder_session_anchor_check() ->> 'ok' <> 'true' then raise exception 'a fresh anchor does not match the ledger'; end if;
    alter table public.founder_session_ledger disable trigger founder_session_ledger_stop;
    delete from public.founder_session_ledger where id = (select max(id) from public.founder_session_ledger);
    alter table public.founder_session_ledger enable trigger founder_session_ledger_stop;
    if public.founder_session_anchor_check() ->> 'ok' = 'true' then raise exception 'a deleted ledger tail was NOT caught by the anchor'; end if;

    -- the board shows the new facts
    j := public.founder_sessions_board(v_uid, s4);
    if j ->> 'ok' <> 'true' or j #>> '{policy,max_live}' <> '20' or not (j ? 'anchor') or (j #>> '{ledger_chain,ok}') is null then raise exception 'the board lacks the E156 facts: %', left(j::text, 200); end if;
    if (public.founder_session_posture156() ->> 'anchors_append_only')::boolean is not true or (public.founder_session_posture156() ->> 'ledger_kinds_widened')::boolean is not true then raise exception 'the posture reading is wrong'; end if;

    v_msg := 'E156 selftest PASS (cap, per-request drift + location lock, flapping, change-log rate limit, failure streak, idle expiry, tail verify, cross-chain anchor catches a deleted tail)';
    raise exception 'e156_rollback' using errcode = 'P0001';
  exception when others then
    if sqlerrm = 'e156_rollback' then null; else v_msg := 'E156 selftest FAIL: ' || sqlerrm; end if;
  end;
  return v_msg;
end $$;

revoke all on function public.founder_session_posture156(), public.founder_session_selftest156() from public, anon, authenticated;
grant execute on function public.founder_session_posture156(), public.founder_session_selftest156() to service_role;
comment on table public.founder_session_anchors is 'E156: append-only anchors of the session ledger head (also written into the founder audit chain). A deleted or rewritten tail is caught by founder_session_anchor_check().';
