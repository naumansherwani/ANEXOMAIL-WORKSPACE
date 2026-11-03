
-- E131 — G5d: PIN PORTABILITY. A brand-new browser (no remembered pin, no history) can verify the ledger from scratch.
-- Founder order 3 Nov 04:50: "shuru kero ... sql likhna hai" (quality law: super advanced code, SQL above super advanced).
--
-- The problem G4/G5 left open (limit 1): the pin lives in ONE browser. A new browser/device has nothing to compare with, so a server that rewrites history
--   can show it a consistent fake. No outside witnesses exist (founder decision G5-D: no signups), so the outside fact we CAN use is the TIME ANCHOR of G5c.
--
-- THE IDEA ("derived pin"): the oldest signed checkpoint that carries independent outside time evidence is a pin that needs no browser memory.
--   * An RFC 3161 token (>= policy.min_tsa DIFFERENT authorities) or a Bitcoin attestation proves "this exact signed note existed by time T".
--   * A server that rewrites history AFTER T cannot produce a different note with a valid outside timestamp dated T.
--   * So a fresh browser verifies, with the WASM kernel and nothing else: (1) the signed note of the horizon (Ed25519, kernel checkpoint@1),
--     (2) its anchor evidence (kernel anchor@1), (3) ONE RFC 9162 consistency proof from the horizon to the newest signed checkpoint (kernel merkle@2),
--     (4) the newest signed note. If all four hold: "everything since T is the history that existed at T, extended without change".
--   Honest limits (never over-claimed): entries BEFORE the horizon are not covered; a server can withhold early evidence, so the page always shows the
--   horizon time, how many seals lie before it and whether the horizon ever moved LATER (that is flagged below); the TSA signature itself is checked by the
--   founder server (ring) and the kernel checks the digest binding and the signer pin (as G5c says); nothing here is "witnessed".
--
-- What this file adds (additive, idempotent; needs E107, E120, E121, E122, E123, E124):
--   1) founder_portable_policy        : singleton knobs (min independent TSAs, how many un-anchored seals before the horizon are tolerated, observe throttle).
--   2) founder_portable_horizon_log   : APPEND-ONLY, hash-chained, computed BY THE TRIGGER (the caller only names the horizon): best_cp = the earliest horizon ever seen;
--                                       a horizon that moves LATER than best_cp is stored as regressed=true (= outside evidence disappeared = alarm), never refused, never hidden.
--   3) _fm_portable_cp_anchor(cp)     : what outside evidence a checkpoint holds (distinct TSAs, distinct Bitcoin attestations, earliest outside time).
--   4) founder_portable_horizon()     : the oldest signed checkpoint with enough outside evidence.
--   5) founder_portable_bundle()      : EVERYTHING a fresh browser needs in ONE read (horizon note + evidence + head note + one consistency proof + keys + coverage).
--   6) founder_portable_observe()     : writes the log row (called by the Rust tick; throttled).   7) founder_portable_pulse() : one honest level for the gauge.
--   8) founder_portable_verify()      : re-checks the stored state (chain, digest binding, the proof inside SQL).   9) selftest (rolls back) + CHECK_E131.

-- 1) policy -----------------------------------------------------------------------------------------------------------------------------------
do $$ begin
  perform pg_advisory_xact_lock(hashtextextended('founder_portable:ddl', 0));
  create table if not exists public.founder_portable_policy (
    id               boolean primary key default true check (id),
    min_tsa          integer not null default 2 check (min_tsa between 1 and 5),         -- independent Time-Stamp Authorities needed for a horizon (a Bitcoin attestation alone also counts)
    max_skipped      integer not null default 10 check (max_skipped between 0 and 1000), -- signed checkpoints before the horizon that lack evidence: more than this = warn
    observe_secs     integer not null default 300 check (observe_secs between 30 and 86400), -- the log gets one row per this many seconds at most (unless the horizon changed)
    max_proof_leaves integer not null default 20000 check (max_proof_leaves between 100 and 100000)
  );
  insert into public.founder_portable_policy (id) values (true) on conflict (id) do nothing;
  alter table public.founder_portable_policy enable row level security;
  revoke all on public.founder_portable_policy from public, anon, authenticated;
  grant select on public.founder_portable_policy to service_role;
  revoke insert, update, delete, truncate, references, trigger on public.founder_portable_policy from service_role;   -- changed only by editing this file (audited by git), never by a door at runtime
end $$;

-- the policy is fixed at runtime: even a definer function cannot change it. A future migration file that wants new knobs sets `app.portable_policy_edit = 'on'` for its own transaction (visible in git).
create or replace function public._fm_portable_policy_guard() returns trigger language plpgsql as $$
begin
  if coalesce(current_setting('app.portable_policy_edit', true), '') = 'on' and tg_op <> 'TRUNCATE' then return coalesce(new, old); end if;
  raise exception 'E131: the portable policy is read-only at runtime' using errcode = '42501';
end $$;
drop trigger if exists founder_portable_policy_guard on public.founder_portable_policy;
create trigger founder_portable_policy_guard before update or delete on public.founder_portable_policy for each row execute function public._fm_portable_policy_guard();
drop trigger if exists founder_portable_policy_guard_trunc on public.founder_portable_policy;
create trigger founder_portable_policy_guard_trunc before truncate on public.founder_portable_policy for each statement execute function public._fm_portable_policy_guard();

-- 2) the horizon log (append-only, hash-chained, no foreign key: E107's selftest truncates the seals table) -----------------------------------------
do $$ begin
  perform pg_advisory_xact_lock(hashtextextended('founder_portable:ddl', 0));
  create table if not exists public.founder_portable_horizon_log (
    id          bigint generated always as identity primary key,
    ts_ms       bigint  not null check (ts_ms > 0),
    horizon_cp  bigint  not null check (horizon_cp >= 1),
    best_cp     bigint  not null check (best_cp >= 1),
    regressed   boolean not null,
    anchored_ms bigint  not null check (anchored_ms > 0),
    prev_hash   text    not null check (prev_hash ~ '^[0-9a-f]{64}$'),
    hash        text    not null unique check (hash ~ '^[0-9a-f]{64}$'),
    constraint founder_portable_log_regress check (regressed = (horizon_cp > best_cp))
  );
  alter table public.founder_portable_horizon_log enable row level security;
  revoke all on public.founder_portable_horizon_log from public, anon, authenticated;
  grant select, insert on public.founder_portable_horizon_log to service_role;
  revoke update, delete, truncate, references, trigger on public.founder_portable_horizon_log from service_role;
end $$;

create or replace function public._fm_portable_hash(p_prev text, p_ts bigint, p_h bigint, p_best bigint, p_reg boolean, p_anch bigint) returns text
language sql immutable set search_path = pg_catalog, public, extensions as $$
  select encode(extensions.digest(convert_to(p_prev || '|' || p_ts || '|' || p_h || '|' || p_best || '|' || p_reg::text || '|' || p_anch, 'UTF8'), 'sha256'), 'hex')
$$;

-- A transaction-local "floor" (setting app.portable_floor): only checkpoints ABOVE it are looked at. It is 0 in real use and set ONLY by the selftest, so the selftest
-- works on a live ledger that already holds real anchored checkpoints without touching them. It lives and dies with the transaction; service_role only.
create or replace function public._fm_portable_floor() returns bigint language sql stable set search_path = pg_catalog, public as $$
  select coalesce(nullif(current_setting('app.portable_floor', true), '')::bigint, 0)
$$;

-- The trigger FILLS prev_hash, best_cp, regressed and hash itself: a caller can only name the horizon, so nobody can write a clean-looking row.
create or replace function public._fm_portable_log_guard() returns trigger language plpgsql set search_path = pg_catalog, public, extensions as $$
declare p public.founder_portable_horizon_log%rowtype;
begin
  if tg_op <> 'INSERT' then raise exception 'E131: horizon log is append-only' using errcode = '42501'; end if;
  select * into p from public.founder_portable_horizon_log order by id desc limit 1;
  new.prev_hash := coalesce(p.hash, repeat('0', 64));
  new.best_cp   := least(new.horizon_cp, coalesce((select min(l.horizon_cp) from public.founder_portable_horizon_log l where l.horizon_cp > public._fm_portable_floor()), new.horizon_cp));
  new.regressed := new.horizon_cp > new.best_cp;
  new.hash      := public._fm_portable_hash(new.prev_hash, new.ts_ms, new.horizon_cp, new.best_cp, new.regressed, new.anchored_ms);
  return new;
end $$;
create or replace function public._fm_portable_log_stop() returns trigger language plpgsql as $$ begin raise exception 'E131: horizon log is append-only' using errcode = '42501'; end $$;
drop trigger if exists founder_portable_log_guard on public.founder_portable_horizon_log;
create trigger founder_portable_log_guard before insert on public.founder_portable_horizon_log for each row execute function public._fm_portable_log_guard();
drop trigger if exists founder_portable_log_stop on public.founder_portable_horizon_log;
create trigger founder_portable_log_stop before update or delete on public.founder_portable_horizon_log for each row execute function public._fm_portable_log_stop();
drop trigger if exists founder_portable_log_stop_trunc on public.founder_portable_horizon_log;
create trigger founder_portable_log_stop_trunc before truncate on public.founder_portable_horizon_log for each statement execute function public._fm_portable_log_stop();

-- 3) what outside evidence does one checkpoint hold? (distinct providers, so one authority stamping twice counts once) ---------------------------
create or replace function public._fm_portable_cp_anchor(p_cp bigint) returns jsonb
language sql stable security definer set search_path = pg_catalog, public as $$
  select jsonb_build_object(
    'tsa',         count(distinct provider_id) filter (where stage = 'tsa_token'),
    'bitcoin',     count(distinct provider_id) filter (where stage = 'ots_bitcoin'),
    'anchored_ms', min(case stage when 'tsa_token' then (parsed ->> 'gen_time_ms')::bigint when 'ots_bitcoin' then (parsed ->> 'btc_time_ms')::bigint end)
                     filter (where stage in ('tsa_token', 'ots_bitcoin')))
  from public.founder_anchor_evidence where cp_id = p_cp
$$;

-- 4) the horizon = the OLDEST signed checkpoint that holds enough outside evidence ----------------------------------------------------------------
create or replace function public.founder_portable_horizon() returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '10s' as $$
declare pol public.founder_portable_policy%rowtype; s public.founder_audit_signed_checkpoints%rowtype; a jsonb; v_first bigint; v_skipped bigint;
begin
  select * into pol from public.founder_portable_policy where id;
  select min(cp_id) into v_first from public.founder_audit_signed_checkpoints where cp_id > public._fm_portable_floor();
  select c.* into s from public.founder_audit_signed_checkpoints c
   where c.cp_id > public._fm_portable_floor() and exists (select 1 from public.founder_anchor_evidence e where e.cp_id = c.cp_id and e.stage in ('tsa_token', 'ots_bitcoin'))
     and ((public._fm_portable_cp_anchor(c.cp_id) ->> 'tsa')::int >= pol.min_tsa or (public._fm_portable_cp_anchor(c.cp_id) ->> 'bitcoin')::int >= 1)
   order by c.cp_id limit 1;
  if not found then return jsonb_build_object('found', false, 'first_signed_cp', v_first, 'min_tsa', pol.min_tsa); end if;
  a := public._fm_portable_cp_anchor(s.cp_id);
  select count(*) into v_skipped from public.founder_audit_signed_checkpoints where cp_id < s.cp_id and cp_id > public._fm_portable_floor();
  return jsonb_build_object('found', true, 'cp_id', s.cp_id, 'size', s.size, 'root', s.root, 'origin', s.origin, 'note', s.note, 'signed_ms', s.signed_ms, 'key_id', s.key_id,
    'tsa', (a ->> 'tsa')::int, 'bitcoin', (a ->> 'bitcoin')::int, 'anchored_ms', (a ->> 'anchored_ms')::bigint,
    'first_signed_cp', v_first, 'skipped', v_skipped, 'min_tsa', pol.min_tsa, 'digest_hex', public._fm_anchor_digest(s.cp_id));
end $$;

-- 5) observe: the Rust tick calls this; it only ever APPENDS, throttled; the trigger decides best/regressed ---------------------------------------
create or replace function public.founder_portable_observe() returns jsonb
language plpgsql volatile security definer set search_path = pg_catalog, public, extensions set statement_timeout = '10s' as $$
declare h jsonb; pol public.founder_portable_policy%rowtype; l public.founder_portable_horizon_log%rowtype; v_now bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint; n public.founder_portable_horizon_log%rowtype;
begin
  perform pg_advisory_xact_lock(hashtextextended('founder_portable:log', 0));
  select * into pol from public.founder_portable_policy where id;
  h := public.founder_portable_horizon();
  if not (h ->> 'found')::boolean then return jsonb_build_object('observed', false, 'why', 'no checkpoint has enough outside time evidence yet'); end if;
  select * into l from public.founder_portable_horizon_log where horizon_cp > public._fm_portable_floor() order by id desc limit 1;
  if found and l.horizon_cp = (h ->> 'cp_id')::bigint and v_now - l.ts_ms < pol.observe_secs * 1000 then
    return jsonb_build_object('observed', false, 'why', 'same horizon, inside the throttle window', 'horizon_cp', l.horizon_cp, 'regressed', l.regressed);
  end if;
  insert into public.founder_portable_horizon_log (ts_ms, horizon_cp, best_cp, regressed, anchored_ms, prev_hash, hash)
    values (v_now, (h ->> 'cp_id')::bigint, (h ->> 'cp_id')::bigint, false, (h ->> 'anchored_ms')::bigint, repeat('0', 64), repeat('0', 64)) returning * into n;   -- the trigger overwrites best/regressed/prev/hash
  return jsonb_build_object('observed', true, 'horizon_cp', n.horizon_cp, 'best_cp', n.best_cp, 'regressed', n.regressed);
end $$;

-- 6) the bundle a fresh browser needs ------------------------------------------------------------------------------------------------------------
create or replace function public.founder_portable_bundle() returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare h jsonb; hd jsonb; pol public.founder_portable_policy%rowtype; pr jsonb := null; v_why text := null; l public.founder_portable_horizon_log%rowtype; v_reg bigint; v_rows bigint;
begin
  select * into pol from public.founder_portable_policy where id;
  h := public.founder_portable_horizon();
  hd := public.founder_audit_signed_cp_get(null);
  if not (h ->> 'found')::boolean then
    return jsonb_build_object('found', false, 'why', 'no signed checkpoint holds enough outside time evidence yet', 'min_tsa', pol.min_tsa, 'first_signed_cp', h -> 'first_signed_cp'); end if;
  if not coalesce((hd ->> 'found')::boolean, false) then return jsonb_build_object('found', false, 'why', 'no signed head checkpoint'); end if;
  if (hd ->> 'size')::bigint < (h ->> 'size')::bigint then
    return jsonb_build_object('found', false, 'why', 'the newest signed checkpoint is SMALLER than the anchored horizon: the history went backwards'); end if;
  if (hd ->> 'size')::bigint = (h ->> 'size')::bigint then
    if hd ->> 'root' <> h ->> 'root' then return jsonb_build_object('found', false, 'why', 'two different roots for the same size'); end if;
    pr := jsonb_build_object('first', (h ->> 'size')::bigint, 'second', (h ->> 'size')::bigint, 'first_root', h ->> 'root', 'second_root', hd ->> 'root', 'proof', '[]'::jsonb);
  elsif (hd ->> 'size')::bigint > pol.max_proof_leaves then v_why := 'the ledger is larger than the proof limit; raise max_proof_leaves after review';
  else
    begin pr := public.founder_audit_consistency_proof((h ->> 'size')::bigint, (hd ->> 'size')::bigint);
    exception when others then v_why := 'the consistency proof could not be built: ' || sqlerrm; end;
  end if;
  select * into l from public.founder_portable_horizon_log where horizon_cp > public._fm_portable_floor() order by id desc limit 1;
  select count(*) into v_reg from public.founder_portable_horizon_log where regressed and horizon_cp > public._fm_portable_floor();
  select coalesce(max(seq), 0) into v_rows from public.founder_audit;
  return jsonb_build_object('found', true,
    'horizon', h - 'digest_hex' || jsonb_build_object('digest_hex', h -> 'digest_hex', 'evidence', coalesce(public.founder_anchor_get((h ->> 'cp_id')::bigint) -> 'evidence', '[]'::jsonb)),
    'head', jsonb_build_object('cp_id', hd -> 'cp_id', 'size', hd -> 'size', 'root', hd -> 'root', 'origin', hd -> 'origin', 'note', hd -> 'note', 'signed_ms', hd -> 'signed_ms', 'key_id', hd -> 'key_id'),
    'keys', hd -> 'keys', 'proof', pr, 'proof_problem', v_why,
    'coverage', jsonb_build_object('ledger_rows', v_rows, 'horizon_size', (h ->> 'size')::bigint, 'head_size', (hd ->> 'size')::bigint,
                                   'not_covered_rows', (h ->> 'size')::bigint, 'skipped_checkpoints', (h ->> 'skipped')::bigint, 'first_signed_cp', h -> 'first_signed_cp'),
    'horizon_log', jsonb_build_object('best_cp', l.best_cp, 'current_regressed', coalesce(l.regressed, false), 'regressions_ever', v_reg, 'observed', l.id is not null));
end $$;

-- 7) pulse: ONE honest level. off = no claim at all ----------------------------------------------------------------------------------------------
create or replace function public.founder_portable_pulse() returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '10s' as $$
declare b jsonb; pol public.founder_portable_policy%rowtype; l public.founder_portable_horizon_log%rowtype; v_level text := 'ok'; v_why text := null; v_ok boolean := true;
begin
  select * into pol from public.founder_portable_policy where id;
  b := public.founder_portable_bundle();
  if not (b ->> 'found')::boolean then
    return jsonb_build_object('level', case when b ->> 'why' ilike '%backwards%' or b ->> 'why' ilike '%different roots%' then 'fail' else 'off' end, 'why', b ->> 'why', 'portable', false); end if;
  select * into l from public.founder_portable_horizon_log where horizon_cp > public._fm_portable_floor() order by id desc limit 1;
  if l.id is not null and l.regressed then v_level := 'fail'; v_why := 'the outside time evidence of an earlier checkpoint disappeared: the horizon moved later than ever before'; v_ok := false;
  elsif b ->> 'proof_problem' is not null then v_level := 'warn'; v_why := b ->> 'proof_problem'; v_ok := false;
  elsif (b #>> '{coverage,skipped_checkpoints}')::bigint > pol.max_skipped then v_level := 'warn'; v_why := 'many early checkpoints have no outside time evidence'; end if;
  return jsonb_build_object('level', v_level, 'why', v_why, 'portable', v_ok, 'horizon_cp', (b #>> '{horizon,cp_id}')::bigint, 'anchored_ms', (b #>> '{horizon,anchored_ms}')::bigint,
    'not_covered_rows', (b #>> '{coverage,not_covered_rows}')::bigint, 'head_cp', (b #>> '{head,cp_id}')::bigint);
end $$;

-- 8) re-check what is STORED (the SQL witness of what the kernel does in the browser) -------------------------------------------------------------
create or replace function public.founder_portable_verify(p_last integer default 500) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare b jsonb; r record; v_probs jsonb := '[]'::jsonb; v_prev text; v_first boolean := true; v_n integer := 0; v_best bigint;
begin
  b := public.founder_portable_bundle();
  if (b ->> 'found')::boolean then
    if (b #>> '{horizon,digest_hex}') <> coalesce(public._fm_anchor_digest((b #>> '{horizon,cp_id}')::bigint), '') then
      v_probs := v_probs || jsonb_build_array(jsonb_build_object('problem', 'the horizon digest is no longer the sha256 of its signed note')); end if;
    if b -> 'proof' is not null and not public._fm_consistency_check((b #>> '{proof,first}')::bigint, (b #>> '{proof,second}')::bigint, b #>> '{proof,first_root}', b #>> '{proof,second_root}', b #> '{proof,proof}') then
      v_probs := v_probs || jsonb_build_array(jsonb_build_object('problem', 'the consistency proof from the horizon to the head does not verify')); end if;
    if b #>> '{proof,first_root}' is distinct from b #>> '{horizon,root}' or b #>> '{proof,second_root}' is distinct from b #>> '{head,root}' then
      if b -> 'proof' is not null then v_probs := v_probs || jsonb_build_array(jsonb_build_object('problem', 'the proof roots are not the roots of the signed horizon and head notes')); end if; end if;
    if jsonb_array_length(coalesce(b #> '{horizon,evidence}', '[]'::jsonb)) < 1 then v_probs := v_probs || jsonb_build_array(jsonb_build_object('problem', 'the horizon carries no evidence rows')); end if;
  end if;
  for r in select * from (select * from public.founder_portable_horizon_log order by id desc limit greatest(1, least(coalesce(p_last, 500), 5000))) q order by id loop
    v_n := v_n + 1;
    if not v_first and r.prev_hash <> v_prev then v_probs := v_probs || jsonb_build_array(jsonb_build_object('log_id', r.id, 'problem', 'the horizon log chain is broken here')); end if;
    if r.hash <> public._fm_portable_hash(r.prev_hash, r.ts_ms, r.horizon_cp, r.best_cp, r.regressed, r.anchored_ms) then
      v_probs := v_probs || jsonb_build_array(jsonb_build_object('log_id', r.id, 'problem', 'a horizon log hash does not match its row')); end if;
    if v_best is not null and public._fm_portable_floor() = 0 and r.best_cp <> least(v_best, r.horizon_cp) then v_probs := v_probs || jsonb_build_array(jsonb_build_object('log_id', r.id, 'problem', 'best_cp is not the running minimum')); end if;
    v_first := false; v_prev := r.hash; v_best := r.best_cp;
  end loop;
  return jsonb_build_object('checked_log_rows', v_n, 'ok', jsonb_array_length(v_probs) = 0, 'problems', v_probs);
end $$;

-- 9) selftest (all inside a block that ends in ROLLBACK) -----------------------------------------------------------------------------------------
create or replace function public.founder_portable_e131_selftest() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '90s' as $$
declare r text := ''; v_uid uuid; j jsonb; v_name text := 'selftest.example/portable-log'; v_pub text := repeat('cd', 32); v_kid text; v_key_id bigint; v_cp jsonb; v_c1 bigint; v_c2 bigint; v_c3 bigint;
        v_note text; v_sig_ms bigint; v_dig text; v_ev text; v_j1 bigint; v_j2 bigint; v_j3 bigint; b jsonb; i integer; b_log bigint; b_aud bigint; b_evi bigint; b_jobs bigint; b_evt bigint; v_before bigint;
begin
  select user_id into v_uid from public.founder_accounts limit 1;
  if v_uid is null then return 'E131 selftest SKIP (no founder account yet)'; end if;
  select count(*) into b_log from public.founder_portable_horizon_log; select count(*) into b_aud from public.founder_audit; select count(*) into b_evi from public.founder_anchor_evidence;
  select count(*) into b_jobs from public.founder_anchor_jobs; select count(*) into b_evt from public.founder_anchor_events;
  begin
    -- nothing anchored yet -> no claim
    update public.founder_audit_log_keys set status = 'retired', retired_ms = greatest(created_ms, (extract(epoch from clock_timestamp()) * 1000)::bigint) where status = 'active';
    v_kid := substr(encode(extensions.digest(convert_to(v_name, 'UTF8') || '\x0a01'::bytea || decode(v_pub, 'hex'), 'sha256'), 'hex'), 1, 8);
    perform public.founder_audit_log_key_register(v_uid, v_name, v_pub, v_kid);
    select id into v_key_id from public.founder_audit_log_keys where status = 'active';
    perform set_config('app.portable_floor', coalesce((select max(id) from public.founder_audit_checkpoints), 0)::text, true);   -- only checkpoints made BELOW are ignored: real evidence on a live ledger is never touched

    -- three seals; sign all three (fake signature bytes: SQL checks the SHAPE, Rust and the kernel check Ed25519)
    for i in 1 .. 3 loop
      perform public.founder_audit_append(v_uid, 'e131.selftest', 'row-' || i, 'selftest entry ' || i, '{}'::jsonb);
      perform public.founder_audit_checkpoint(v_uid, 'selftest seal ' || i);
      v_cp := (public.founder_audit_signed_cp_pending(50)) -> -1;
      v_note := v_name || E'\n' || (v_cp ->> 'size') || E'\n' || encode(decode(v_cp ->> 'root', 'hex'), 'base64') || E'\n' || E'\n' || E'— ' || v_name || ' '
                || replace(encode(decode(v_kid, 'hex') || decode(repeat('22', 64), 'hex'), 'base64'), E'\n', '') || E'\n';
      perform public.founder_audit_signed_cp_add((v_cp ->> 'cp_id')::bigint, v_key_id, v_note);
      if i = 1 then v_c1 := (v_cp ->> 'cp_id')::bigint; elsif i = 2 then v_c2 := (v_cp ->> 'cp_id')::bigint; else v_c3 := (v_cp ->> 'cp_id')::bigint; end if;
    end loop;
    if (public.founder_portable_horizon() ->> 'found')::boolean then raise exception 'a horizon exists without any outside evidence'; end if;
    b := public.founder_portable_bundle();
    if (b ->> 'found')::boolean then raise exception 'a bundle was made without any outside evidence'; end if;
    if public.founder_portable_pulse() ->> 'level' <> 'off' then raise exception 'no evidence must read as off, got %', public.founder_portable_pulse(); end if;
    if (public.founder_portable_observe() ->> 'observed')::boolean then raise exception 'observe logged a horizon that does not exist'; end if;
    r := r || 'no evidence = no claim OK; ';

    -- anchor seal 2 only (seal 1 stays bare): one TSA is NOT enough (min_tsa = 2), two TSAs are
    perform public.founder_anchor_enqueue();
    update public.founder_anchor_jobs set next_try_ms = 0;
    select id into v_j1 from public.founder_anchor_jobs where cp_id = v_c2 and provider_id = (select id from public.founder_anchor_providers where name = 'freetsa');
    select id into v_j2 from public.founder_anchor_jobs where cp_id = v_c2 and provider_id = (select id from public.founder_anchor_providers where name = 'digicert-tsa');
    select id into v_j3 from public.founder_anchor_jobs where cp_id = v_c2 and provider_id = (select id from public.founder_anchor_providers where name = 'sectigo-tsa');
    perform public.founder_anchor_next(60);
    select signed_ms into v_sig_ms from public.founder_audit_signed_checkpoints where cp_id = v_c2;
    v_dig := public._fm_anchor_digest(v_c2);
    v_ev := encode('\x3082'::bytea || decode(v_dig, 'hex') || '\x0102030405'::bytea, 'hex');
    perform public.founder_anchor_record_tsa(v_j1, v_ev, jsonb_build_object('gen_time_ms', v_sig_ms + 1000, 'serial', 'a1', 'signer_pin', repeat('a', 64)));
    if (public.founder_portable_horizon() ->> 'found')::boolean then raise exception 'one TSA must not be enough for a horizon (min_tsa = 2)'; end if;
    perform public.founder_anchor_record_tsa(v_j2, v_ev, jsonb_build_object('gen_time_ms', v_sig_ms + 2000, 'serial', 'b2', 'signer_pin', repeat('b', 64)));
    j := public.founder_portable_horizon();
    if not (j ->> 'found')::boolean or (j ->> 'cp_id')::bigint <> v_c2 then raise exception 'seal 2 with two TSAs must be the horizon: %', j; end if;
    if (j ->> 'skipped')::int <> 1 or (j ->> 'tsa')::int <> 2 or (j ->> 'anchored_ms')::bigint <> v_sig_ms + 1000 then raise exception 'horizon facts are wrong: %', j; end if;
    r := r || 'horizon needs min_tsa independent authorities OK; ';

    -- the bundle: horizon = seal 2, head = seal 3, ONE proof that the SQL verifier accepts
    b := public.founder_portable_bundle();
    if not (b ->> 'found')::boolean or (b #>> '{horizon,cp_id}')::bigint <> v_c2 or (b #>> '{head,cp_id}')::bigint <> v_c3 then raise exception 'bundle is wrong: %', b; end if;
    if jsonb_array_length(b #> '{horizon,evidence}') < 2 or b ->> 'proof_problem' is not null then raise exception 'bundle lacks evidence or has a proof problem: %', b; end if;
    if not public._fm_consistency_check((b #>> '{proof,first}')::bigint, (b #>> '{proof,second}')::bigint, b #>> '{proof,first_root}', b #>> '{proof,second_root}', b #> '{proof,proof}') then raise exception 'the bundled proof does not verify'; end if;
    if b #>> '{proof,first_root}' <> b #>> '{horizon,root}' or b #>> '{proof,second_root}' <> b #>> '{head,root}' then raise exception 'proof roots are not the signed roots'; end if;
    -- a changed proof hash, swapped roots and an empty proof must all be refused
    if public._fm_consistency_check((b #>> '{proof,first}')::bigint, (b #>> '{proof,second}')::bigint, b #>> '{proof,first_root}', b #>> '{proof,second_root}', jsonb_set(b #> '{proof,proof}', '{0}', to_jsonb(repeat('0', 64)))) then raise exception 'a changed proof hash was accepted'; end if;
    if public._fm_consistency_check((b #>> '{proof,first}')::bigint, (b #>> '{proof,second}')::bigint, b #>> '{proof,second_root}', b #>> '{proof,first_root}', b #> '{proof,proof}') then raise exception 'swapped roots were accepted'; end if;
    if (b #>> '{coverage,not_covered_rows}')::bigint <> (b #>> '{horizon,size}')::bigint or (b #>> '{coverage,skipped_checkpoints}')::int <> 1 then raise exception 'coverage is wrong: %', b -> 'coverage'; end if;
    r := r || 'bundle + one consistency proof OK; ';

    -- head == horizon (nothing newer signed): empty proof, same root
    -- observe: one row, throttled, then pulse ok
    j := public.founder_portable_observe();
    if not (j ->> 'observed')::boolean or (j ->> 'regressed')::boolean then raise exception 'first observe must log a clean row: %', j; end if;
    if (public.founder_portable_observe() ->> 'observed')::boolean then raise exception 'observe is not throttled'; end if;
    if (public.founder_portable_pulse() ->> 'level') <> 'ok' then raise exception 'pulse should be ok: %', public.founder_portable_pulse(); end if;
    r := r || 'observe + throttle + pulse OK; ';

    -- the log: append-only, trigger-computed, a LATER horizon is stored as regressed (never hidden, never refused)
    v_before := (select count(*) from public.founder_portable_horizon_log);
    insert into public.founder_portable_horizon_log (ts_ms, horizon_cp, best_cp, regressed, anchored_ms, prev_hash, hash) values (1, v_c3, v_c3, false, 1, repeat('f', 64), repeat('f', 64));   -- the caller lies about best/regressed/prev/hash
    if not (select regressed from public.founder_portable_horizon_log order by id desc limit 1) then raise exception 'a later horizon was not flagged as regressed (the trigger must compute it)'; end if;
    if (select best_cp from public.founder_portable_horizon_log order by id desc limit 1) <> v_c2 then raise exception 'best_cp must stay the earliest horizon ever seen'; end if;
    if (select prev_hash from public.founder_portable_horizon_log order by id desc limit 1) = repeat('f', 64) then raise exception 'a caller-chosen prev_hash was kept'; end if;
    if (public.founder_portable_pulse() ->> 'level') <> 'fail' then raise exception 'a regressed horizon must make the pulse fail: %', public.founder_portable_pulse(); end if;
    if not public._fs_fails($q$update public.founder_portable_horizon_log set horizon_cp = 1$q$) or not public._fs_fails($q$delete from public.founder_portable_horizon_log$q$)
       or not public._fs_fails($q$truncate public.founder_portable_horizon_log$q$) then raise exception 'the horizon log is not append-only'; end if;
    if not public._fs_fails($q$insert into public.founder_portable_policy (id) values (false)$q$) or not public._fs_fails($q$update public.founder_portable_policy set min_tsa = 1$q$) then raise exception 'the policy can be changed at runtime'; end if;
    j := public.founder_portable_verify(500);
    if not (j ->> 'ok')::boolean then raise exception 'verify failed on a good state: %', j; end if;
    r := r || 'append-only + regression flag + verify OK; ';

    -- a Bitcoin attestation alone also makes a horizon (seal 1, earlier than seal 2): the horizon moves EARLIER
    select signed_ms into v_sig_ms from public.founder_audit_signed_checkpoints where cp_id = v_c1;
    v_dig := public._fm_anchor_digest(v_c1);
    v_ev := encode('\x3082'::bytea || decode(v_dig, 'hex') || '\x0102030405'::bytea, 'hex');
    select id into v_j3 from public.founder_anchor_jobs where cp_id = v_c1 and provider_id = (select id from public.founder_anchor_providers where name = 'ots-alice');
    update public.founder_anchor_jobs set next_try_ms = 0 where id = v_j3;
    perform public.founder_anchor_next(60);
    perform public.founder_anchor_record_ots(v_j3, 'ots_pending', v_ev, jsonb_build_object('commit_hex', repeat('c', 64), 'calendar', 'https://alice.btc.calendar.opentimestamps.org'));
    perform public.founder_anchor_record_ots(v_j3, 'ots_bitcoin', v_ev, jsonb_build_object('commit_hex', repeat('c', 64), 'btc_height', 800000, 'btc_time_ms', v_sig_ms + 3600000));
    j := public.founder_portable_horizon();
    if (j ->> 'cp_id')::bigint <> v_c1 or (j ->> 'bitcoin')::int <> 1 or (j ->> 'skipped')::int <> 0 then raise exception 'a Bitcoin attestation must make seal 1 the horizon: %', j; end if;
    j := public.founder_portable_observe();
    if not (j ->> 'observed')::boolean or (j ->> 'regressed')::boolean or (j ->> 'best_cp')::bigint <> v_c1 then raise exception 'an EARLIER horizon must be logged clean with best_cp moving back: %', j; end if;
    r := r || 'bitcoin-only horizon moves earlier OK; ';
    raise exception 'ROLLBACK_SELFTEST';
  exception when others then
    if sqlerrm <> 'ROLLBACK_SELFTEST' then raise exception 'E131 selftest FAIL: %', sqlerrm; end if;
  end;
  perform set_config('app.portable_floor', '', true);
  if (select count(*) from public.founder_portable_horizon_log) <> b_log or (select count(*) from public.founder_audit) <> b_aud or (select count(*) from public.founder_anchor_evidence) <> b_evi
     or (select count(*) from public.founder_anchor_jobs) <> b_jobs or (select count(*) from public.founder_anchor_events) <> b_evt then raise exception 'E131 selftest left rows behind'; end if;
  return 'E131 selftest OK — ' || r || 'rollback clean';
end $$;

do $$ declare f text; begin
  foreach f in array array['public._fm_portable_hash(text,bigint,bigint,bigint,boolean,bigint)', 'public._fm_portable_floor()', 'public._fm_portable_policy_guard()', 'public._fm_portable_log_guard()', 'public._fm_portable_log_stop()', 'public._fm_portable_cp_anchor(bigint)',
    'public.founder_portable_horizon()', 'public.founder_portable_observe()', 'public.founder_portable_bundle()', 'public.founder_portable_pulse()', 'public.founder_portable_verify(integer)',
    'public.founder_portable_e131_selftest()'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

do $$ begin raise notice '%', public.founder_portable_e131_selftest(); end $$;

-- RUNBOOK: bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E131_founder_portable_verify CHECK_E131  (after fetch). Needs E102 + E107 + E120 + E121 + E122 + E123 + E124.
-- Undo (nothing else depends on it): drop the founder_portable_* tables and functions; the signed checkpoints, anchors and the ledger are untouched.
