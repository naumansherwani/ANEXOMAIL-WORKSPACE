

-- E133 — G5c REPAIR R1: OpenTimestamps pending commitments of any valid length (founder 3 Nov 05:52 "sab green kero, fix ker ke do, super advance level").
-- Live paste (3 Nov 05:20): all three calendars ended "calendar commitment is not 32 bytes" and 12 anchoring jobs died. The format (opentimestamps.org, MAX_MSG_LENGTH 4096) does not fix the
-- length at 32; the Rust core already handles any length. Two places insisted on 32: server/founder/src/anchors.rs (fixed in the same commit) and this table guard (replaced here).
-- The Bitcoin stage keeps 32 bytes on purpose: a block merkle root is exactly 32 bytes. E124 is not edited (E130/E132 pattern: a later file replaces the function). Additive, idempotent.
create or replace function public._fm_anchor_evidence_guard() returns trigger language plpgsql as $$
declare j public.founder_anchor_jobs%rowtype; pr public.founder_anchor_providers%rowtype; pol public.founder_anchor_policy%rowtype;
        v_sig_ms bigint; v_dig text; v_prev text; v_ver integer; v_now bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint; v_gen bigint; v_last_gen bigint; v_btc_ms bigint;
begin
  if tg_op <> 'INSERT' then raise exception 'founder_anchor_evidence is append-only (% blocked)', tg_op using errcode = '42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended('founder_anchor:evidence', 0));
  select * into pol from public.founder_anchor_policy where id;
  select * into j from public.founder_anchor_jobs where id = new.job_id;
  if not found then raise exception 'E124: no such job' using errcode = '23503'; end if;
  select * into pr from public.founder_anchor_providers where id = j.provider_id;
  if new.cp_id <> j.cp_id or new.provider_id <> j.provider_id then raise exception 'E124: evidence does not belong to this job' using errcode = '22023'; end if;
  if (pr.kind = 'rfc3161') <> (new.stage = 'tsa_token') then raise exception 'E124: stage % does not fit a % provider', new.stage, pr.kind using errcode = '22023'; end if;
  select signed_ms into v_sig_ms from public.founder_audit_signed_checkpoints where cp_id = new.cp_id;
  if v_sig_ms is null then raise exception 'E124: that seal has no signed note' using errcode = '23503'; end if;
  v_dig := public._fm_anchor_digest(new.cp_id);
  if new.digest_hex <> v_dig then raise exception 'E124: the digest is not sha256 of the stored signed note' using errcode = '22023'; end if;
  if new.evidence_sha256 <> encode(extensions.digest(new.evidence, 'sha256'), 'hex') then raise exception 'E124: evidence_sha256 does not match the evidence bytes' using errcode = '22023'; end if;
  if abs(new.recorded_ms - v_now) > 60000 then raise exception 'E124: recorded_ms must be now' using errcode = '22023'; end if;
  select coalesce(max(version), 0) + 1 into v_ver from public.founder_anchor_evidence where job_id = new.job_id;
  if new.version <> v_ver then raise exception 'E124: version must be % (got %)', v_ver, new.version using errcode = '22023'; end if;
  if jsonb_typeof(new.parsed) <> 'object' then raise exception 'E124: parsed must be an object' using errcode = '22023'; end if;

  if new.stage = 'tsa_token' then
    if jsonb_typeof(new.parsed -> 'gen_time_ms') <> 'number' or (new.parsed ->> 'signer_pin') !~ '^[0-9a-f]{64}$' or coalesce(new.parsed ->> 'serial', '') !~ '^[0-9a-f]{2,80}$' then
      raise exception 'E124: a TSA token needs gen_time_ms, serial (hex) and signer_pin' using errcode = '22023'; end if;
    if position(decode(v_dig, 'hex') in new.evidence) = 0 then raise exception 'E124: the token does not contain the digest it claims to stamp' using errcode = '22023'; end if;
    v_gen := (new.parsed ->> 'gen_time_ms')::bigint;
    if v_gen < v_sig_ms - pol.skew_secs * 1000 then raise exception 'E124: the TSA time (%) is BEFORE the note was signed (%): impossible', v_gen, v_sig_ms using errcode = '22023'; end if;
    if v_gen > new.recorded_ms + pol.skew_secs * 1000 then raise exception 'E124: the TSA time is in the future' using errcode = '22023'; end if;
    -- a provider's clock never goes backwards across checkpoints
    select max((e.parsed ->> 'gen_time_ms')::bigint) into v_last_gen from public.founder_anchor_evidence e where e.provider_id = new.provider_id and e.stage = 'tsa_token' and e.cp_id < new.cp_id;
    if v_last_gen is not null and v_gen < v_last_gen - pol.skew_secs * 1000 then raise exception 'E124: time went backwards for this TSA (% < %)', v_gen, v_last_gen using errcode = '22023'; end if;
  elsif new.stage = 'ots_pending' then
    -- E133 (G5c R1): the OpenTimestamps format allows a commitment of ANY length from 1 to 4096 bytes at a pending leaf (a calendar that appends before its last hash hands out a longer one).
    -- Whole bytes only, and when the server states commit_len it must be the real length.
    if coalesce(new.parsed ->> 'commit_hex', '') !~ '^[0-9a-f]+$' or length(new.parsed ->> 'commit_hex') not between 2 and 8192 or length(new.parsed ->> 'commit_hex') % 2 <> 0 or coalesce(new.parsed ->> 'calendar', '') = '' then raise exception 'E133: a pending proof needs commit_hex (1 to 4096 whole bytes) and calendar' using errcode = '22023'; end if;
    if new.parsed ? 'commit_len' and (jsonb_typeof(new.parsed -> 'commit_len') <> 'number' or (new.parsed ->> 'commit_len')::integer <> length(new.parsed ->> 'commit_hex') / 2) then
      raise exception 'E133: commit_len does not match commit_hex' using errcode = '22023'; end if;
  else
    if (new.parsed ->> 'commit_hex') !~ '^[0-9a-f]{64}$' or jsonb_typeof(new.parsed -> 'btc_height') <> 'number' or (new.parsed ->> 'btc_height')::bigint not between 1 and 20000000 then
      raise exception 'E124: a Bitcoin proof needs commit_hex and a sane btc_height' using errcode = '22023'; end if;
    if new.parsed ? 'btc_time_ms' then
      v_btc_ms := (new.parsed ->> 'btc_time_ms')::bigint;
      if v_btc_ms < v_sig_ms - pol.btc_time_slack_secs * 1000 then raise exception 'E124: the Bitcoin block time (%) is before the note was signed (%)', v_btc_ms, v_sig_ms using errcode = '22023'; end if;
      if v_btc_ms > new.recorded_ms + pol.btc_time_slack_secs * 1000 then raise exception 'E124: the Bitcoin block time is in the future' using errcode = '22023'; end if;
    end if;
  end if;
  select hash into v_prev from public.founder_anchor_evidence order by id desc limit 1;
  new.prev_hash := coalesce(v_prev, repeat('0', 64));
  new.hash := public._fm_anchor_hash(new.prev_hash, new.job_id, new.cp_id, new.stage, new.digest_hex, new.evidence_sha256, new.recorded_ms, new.version);
  return new;
end $$;

revoke all on function public._fm_anchor_evidence_guard() from public, anon, authenticated;


create or replace function public.founder_anchor_e133_selftest() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '60s' as $$
declare r text := ''; v_uid uuid; v_name text := 'selftest.example/e133'; v_pub text := encode(extensions.digest(convert_to(clock_timestamp()::text || random()::text, 'UTF8'), 'sha256'), 'hex'); v_kid text; v_key_id bigint; v_cp jsonb; v_cpid bigint; v_note text; v_sig_ms bigint; v_dig text; v_ev text; v_j bigint; j jsonb;
        b_evi bigint; b_jobs bigint; b_aud bigint; b_evt bigint;
begin
  select user_id into v_uid from public.founder_accounts limit 1;
  if v_uid is null then return 'E133 selftest SKIP (no founder account yet)'; end if;
  select count(*) into b_evi from public.founder_anchor_evidence; select count(*) into b_jobs from public.founder_anchor_jobs; select count(*) into b_aud from public.founder_audit; select count(*) into b_evt from public.founder_anchor_events;
  begin
    update public.founder_audit_log_keys set status = 'retired', retired_ms = greatest(created_ms, (extract(epoch from clock_timestamp()) * 1000)::bigint) where status = 'active';
    v_kid := substr(encode(extensions.digest(convert_to(v_name, 'UTF8') || '\x0a01'::bytea || decode(v_pub, 'hex'), 'sha256'), 'hex'), 1, 8);
    perform public.founder_audit_log_key_register(v_uid, v_name, v_pub, v_kid);
    select id into v_key_id from public.founder_audit_log_keys where status = 'active';
    perform public.founder_audit_append(v_uid, 'e133.selftest', 'row-1', 'selftest entry', '{}'::jsonb);
    perform public.founder_audit_checkpoint(v_uid, 'selftest seal e133');
    v_cp := (public.founder_audit_signed_cp_pending(50)) -> -1; v_cpid := (v_cp ->> 'cp_id')::bigint;
    v_note := v_name || E'\n' || (v_cp ->> 'size') || E'\n' || encode(decode(v_cp ->> 'root', 'hex'), 'base64') || E'\n' || E'\n' || E'— ' || v_name || ' '
              || replace(encode(decode(v_kid, 'hex') || decode(repeat('44', 64), 'hex'), 'base64'), E'\n', '') || E'\n';
    perform public.founder_audit_signed_cp_add(v_cpid, v_key_id, v_note);
    select signed_ms into v_sig_ms from public.founder_audit_signed_checkpoints where cp_id = v_cpid;
    v_dig := public._fm_anchor_digest(v_cpid);
    v_ev := encode('\x3082'::bytea || decode(v_dig, 'hex') || '\x0102030405'::bytea, 'hex');
    perform public.founder_anchor_enqueue(); update public.founder_anchor_jobs set next_try_ms = 0 where cp_id = v_cpid; perform public.founder_anchor_next(60);
    select id into v_j from public.founder_anchor_jobs where cp_id = v_cpid and provider_id = (select id from public.founder_anchor_providers where name = 'ots-alice');
    -- bad shapes are refused
    if not public._fs_fails(format($q$select public.founder_anchor_record_ots(%s, 'ots_pending', %L, %L::jsonb)$q$, v_j, v_ev, jsonb_build_object('commit_hex', repeat('c', 63), 'calendar', 'https://a.example')::text)) then raise exception 'an odd-length commitment was accepted'; end if;
    if not public._fs_fails(format($q$select public.founder_anchor_record_ots(%s, 'ots_pending', %L, %L::jsonb)$q$, v_j, v_ev, jsonb_build_object('commit_hex', repeat('c', 8194), 'calendar', 'https://a.example')::text)) then raise exception 'a commitment longer than 4096 bytes was accepted'; end if;
    if not public._fs_fails(format($q$select public.founder_anchor_record_ots(%s, 'ots_pending', %L, %L::jsonb)$q$, v_j, v_ev, jsonb_build_object('commit_hex', repeat('c', 104), 'commit_len', 32, 'calendar', 'https://a.example')::text)) then raise exception 'a wrong commit_len was accepted'; end if;
    if not public._fs_fails(format($q$select public.founder_anchor_record_ots(%s, 'ots_pending', %L, %L::jsonb)$q$, v_j, v_ev, jsonb_build_object('commit_hex', '', 'calendar', 'https://a.example')::text)) then raise exception 'an empty commitment was accepted'; end if;
    r := r || 'bad shapes refused; ';
    -- a 52-byte commitment (digest + 20 appended bytes) is the shape the live calendars use
    j := public.founder_anchor_record_ots(v_j, 'ots_pending', v_ev, jsonb_build_object('commit_hex', repeat('c', 104), 'commit_len', 52, 'calendar', 'https://alice.btc.calendar.opentimestamps.org'));
    if not (j ->> 'recorded')::boolean then raise exception 'a 52-byte pending commitment was refused: %', j; end if;
    -- the Bitcoin stage still needs exactly 32 bytes (a block merkle root)
    if not public._fs_fails(format($q$select public.founder_anchor_record_ots(%s, 'ots_bitcoin', %L, %L::jsonb)$q$, v_j, v_ev, jsonb_build_object('commit_hex', repeat('c', 104), 'btc_height', 800000, 'btc_time_ms', v_sig_ms + 3600000)::text)) then raise exception 'a Bitcoin proof with a 52-byte commitment was accepted'; end if;
    j := public.founder_anchor_record_ots(v_j, 'ots_bitcoin', v_ev, jsonb_build_object('commit_hex', repeat('d', 64), 'btc_height', 800000, 'btc_time_ms', v_sig_ms + 3600000));
    if not (j ->> 'recorded')::boolean then raise exception 'the Bitcoin stage refused a 32-byte commitment: %', j; end if;
    if not (public.founder_anchor_verify(500) ->> 'ok')::boolean then raise exception 'verify failed on the new rows: %', public.founder_anchor_verify(500); end if;
    r := r || '52-byte pending + 32-byte bitcoin OK; ';
    raise exception 'ROLLBACK_SELFTEST';
  exception when others then
    if sqlerrm <> 'ROLLBACK_SELFTEST' then raise exception 'E133 selftest FAIL: %', sqlerrm; end if;
  end;
  if (select count(*) from public.founder_anchor_evidence) <> b_evi or (select count(*) from public.founder_anchor_jobs) <> b_jobs or (select count(*) from public.founder_audit) <> b_aud
     or (select count(*) from public.founder_anchor_events) <> b_evt then raise exception 'E133 selftest left rows behind'; end if;
  return 'E133 selftest OK — ' || r || 'rollback clean';
end $$;
revoke all on function public.founder_anchor_e133_selftest() from public, anon, authenticated;
grant execute on function public.founder_anchor_e133_selftest() to service_role;

do $$ begin raise notice '%', public.founder_anchor_e133_selftest(); end $$;

-- RUNBOOK: bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E133_anchor_pending_any_length CHECK_E133  (needs E124). Founder-install (Rust) goes AFTER this.
-- Undo: re-run the _fm_anchor_evidence_guard() block of E124.
