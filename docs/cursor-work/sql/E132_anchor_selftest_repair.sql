

-- E132 — repair of the E124 SELFTEST only (founder 3 Nov 05:20, G5c repair "super advance level"). Nothing the E124 doors do is changed.
-- Problem (his live paste): on the real server the selftest failed with "accepting the signer must clear the warning" because the pulse correctly warned about 12 REAL dead anchoring jobs
-- (OpenTimestamps commitment length, freetsa curve/hash). A selftest that goes red because production has a genuine problem cannot tell the two apart. It now checks the signer warning itself
-- (its own words), so it passes on a healthy AND on a degraded server and still fails if the signer logic breaks. E124 is left untouched (E130 pattern: a later file replaces the function).
create or replace function public.founder_anchor_e124_selftest() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '90s' as $$
declare r text := ''; v_uid uuid; j jsonb; v_cp jsonb; v_name text := 'selftest.example/anchor-log'; v_pub text := repeat('ab', 32); v_kid text; v_key_id bigint; v_body text; v_note text; v_raw text; v_cpid bigint; v_sig_ms bigint;
        v_dig text; v_jobs jsonb; v_tsa1 bigint; v_tsa2 bigint; v_ots1 bigint; v_ots2 bigint; v_ots3 bigint; v_ev text; b_jobs bigint; b_evi bigint; b_evt bigint; b_aud bigint; b_prov text; x jsonb; i integer;
        v_pin_a text := repeat('a', 64); v_pin_b text := repeat('b', 64);
begin
  select user_id into v_uid from public.founder_accounts limit 1;
  if v_uid is null then return 'E124 selftest SKIP (no founder account yet)'; end if;
  select count(*) into b_jobs from public.founder_anchor_jobs; select count(*) into b_evi from public.founder_anchor_evidence; select count(*) into b_evt from public.founder_anchor_events;
  select count(*) into b_aud from public.founder_audit; select md5(string_agg(id || ':' || enabled || ':' || coalesce(signer_pin, ''), ',' order by id)) into b_prov from public.founder_anchor_providers;
  begin
    -- a signed checkpoint to anchor (fake audit-log key; SQL does not check Ed25519, the E123 judge checks the note's shape)
    update public.founder_audit_log_keys set status = 'retired', retired_ms = greatest(created_ms, (extract(epoch from clock_timestamp()) * 1000)::bigint) where status = 'active';
    v_kid := substr(encode(extensions.digest(convert_to(v_name, 'UTF8') || '\x0a01'::bytea || decode(v_pub, 'hex'), 'sha256'), 'hex'), 1, 8);
    perform public.founder_audit_log_key_register(v_uid, v_name, v_pub, v_kid);
    select id into v_key_id from public.founder_audit_log_keys where status = 'active';
    perform public.founder_audit_append(v_uid, 'e124.selftest', 'row-1', 'selftest entry for an anchor', '{}'::jsonb);
    perform public.founder_audit_checkpoint(v_uid, 'selftest seal for the anchor test');
    v_cp := (public.founder_audit_signed_cp_pending(50)) -> -1;
    v_cpid := (v_cp ->> 'cp_id')::bigint;
    v_body := v_name || E'\n' || (v_cp ->> 'size') || E'\n' || encode(decode(v_cp ->> 'root', 'hex'), 'base64') || E'\n';
    v_raw := replace(encode(decode(v_kid, 'hex') || decode(repeat('11', 64), 'hex'), 'base64'), E'\n', '');
    v_note := v_body || E'\n' || E'— ' || v_name || ' ' || v_raw || E'\n';
    perform public.founder_audit_signed_cp_add(v_cpid, v_key_id, v_note);
    select signed_ms into v_sig_ms from public.founder_audit_signed_checkpoints where cp_id = v_cpid;
    v_dig := encode(extensions.digest(convert_to(v_note, 'UTF8'), 'sha256'), 'hex');
    if public._fm_anchor_digest(v_cpid) <> v_dig then raise exception 'SQL digest of the note is wrong'; end if;
    if public.founder_anchor_level(v_cpid) <> 'none' then raise exception 'a fresh checkpoint must have level none'; end if;
    r := r || 'setup OK; ';

    -- queue + lease
    j := public.founder_anchor_enqueue();
    if (j ->> 'queued')::int < 6 then raise exception 'enqueue made fewer jobs than providers: %', j; end if;
    if (public.founder_anchor_enqueue() ->> 'queued')::int <> 0 then raise exception 'enqueue is not idempotent'; end if;
    update public.founder_anchor_jobs set next_try_ms = 0 where cp_id = v_cpid;
    select id into v_tsa1 from public.founder_anchor_jobs where cp_id = v_cpid and provider_id = (select id from public.founder_anchor_providers where name = 'freetsa');
    select id into v_tsa2 from public.founder_anchor_jobs where cp_id = v_cpid and provider_id = (select id from public.founder_anchor_providers where name = 'digicert-tsa');
    select id into v_ots1 from public.founder_anchor_jobs where cp_id = v_cpid and provider_id = (select id from public.founder_anchor_providers where name = 'ots-alice');
    select id into v_ots2 from public.founder_anchor_jobs where cp_id = v_cpid and provider_id = (select id from public.founder_anchor_providers where name = 'ots-bob');
    select id into v_ots3 from public.founder_anchor_jobs where cp_id = v_cpid and provider_id = (select id from public.founder_anchor_providers where name = 'ots-finney');
    v_jobs := public.founder_anchor_next(30);
    if not exists (select 1 from jsonb_array_elements(v_jobs) e where (e ->> 'job_id')::bigint = v_tsa1 and e ->> 'digest_hex' = v_dig and e ->> 'kind' = 'rfc3161') then raise exception 'next did not hand out the TSA job with the right digest: %', v_jobs; end if;
    if jsonb_array_length(public.founder_anchor_next(30)) <> 0 and exists (select 1 from jsonb_array_elements(public.founder_anchor_next(30)) e where (e ->> 'job_id')::bigint = v_tsa1) then raise exception 'a leased job was handed out twice'; end if;
    r := r || 'queue + lease OK; ';

    -- RFC 3161 rules
    v_ev := encode('\x3082'::bytea || decode(v_dig, 'hex') || '\x0102030405'::bytea, 'hex');             -- stand-in token that CONTAINS the digest (real parsing/signature check is Rust + kernel)
    if not public._fs_fails(format($q$select public.founder_anchor_record_tsa(%s, %L, %L::jsonb)$q$, v_tsa1, encode(decode(repeat('42', 40), 'hex'), 'hex'), jsonb_build_object('gen_time_ms', v_sig_ms + 1000, 'serial', 'aa01', 'signer_pin', v_pin_a)::text)) then raise exception 'a token that does not contain the digest was accepted'; end if;
    if not public._fs_fails(format($q$select public.founder_anchor_record_tsa(%s, %L, %L::jsonb)$q$, v_tsa1, v_ev, jsonb_build_object('gen_time_ms', v_sig_ms - 600000, 'serial', 'aa01', 'signer_pin', v_pin_a)::text)) then raise exception 'a TSA time BEFORE the note was accepted'; end if;
    if not public._fs_fails(format($q$select public.founder_anchor_record_tsa(%s, %L, %L::jsonb)$q$, v_tsa1, v_ev, jsonb_build_object('gen_time_ms', v_sig_ms + 86400000, 'serial', 'aa01', 'signer_pin', v_pin_a)::text)) then raise exception 'a TSA time in the future was accepted'; end if;
    if not public._fs_fails(format($q$select public.founder_anchor_record_tsa(%s, %L, %L::jsonb)$q$, v_tsa1, v_ev, jsonb_build_object('gen_time_ms', v_sig_ms + 1000, 'serial', 'zz', 'signer_pin', v_pin_a)::text)) then raise exception 'a bad serial was accepted'; end if;
    if not public._fs_fails(format($q$select public.founder_anchor_record_tsa(%s, %L, %L::jsonb)$q$, v_ots1, v_ev, jsonb_build_object('gen_time_ms', v_sig_ms + 1000, 'serial', 'aa01', 'signer_pin', v_pin_a)::text)) then raise exception 'a TSA token was accepted on an OpenTimestamps job'; end if;
    j := public.founder_anchor_record_tsa(v_tsa1, v_ev, jsonb_build_object('gen_time_ms', v_sig_ms + 1000, 'serial', 'aa01', 'signer_pin', v_pin_a));
    if not (j ->> 'recorded')::boolean or (j ->> 'signer_changed')::boolean then raise exception 'a good token was refused or flagged: %', j; end if;
    if (select signer_pin from public.founder_anchor_providers where name = 'freetsa') <> v_pin_a then raise exception 'first-sight signer pin was not remembered'; end if;
    if (public.founder_anchor_record_tsa(v_tsa1, v_ev, jsonb_build_object('gen_time_ms', v_sig_ms + 1000, 'serial', 'aa01', 'signer_pin', v_pin_a)) ->> 'recorded')::boolean then raise exception 'a finished job accepted a second token'; end if;
    if public.founder_anchor_level(v_cpid) <> 'tsa' then raise exception 'level after a TSA token must be tsa'; end if;
    -- signer change is flagged, not silent
    update public.founder_anchor_providers set signer_pin = v_pin_a where name = 'digicert-tsa';
    j := public.founder_anchor_record_tsa(v_tsa2, v_ev, jsonb_build_object('gen_time_ms', v_sig_ms + 2000, 'serial', 'bb02', 'signer_pin', v_pin_b));
    if not (j ->> 'signer_changed')::boolean then raise exception 'a changed TSA signer was not flagged'; end if;
    if (public.founder_anchor_pulse() ->> 'level') <> 'warn' or (public.founder_anchor_pulse() ->> 'why') not like '%different certificate key%' then raise exception 'a changed TSA signer must make the pulse warn about the signer: %', public.founder_anchor_pulse(); end if;
    j := public.founder_anchor_signer_accept(v_uid, 'digicert-tsa', v_pin_b, 'selftest accepts the renewed signer');
    -- E132: judged on the SIGNER warning only. The live server holds real dead jobs of other checkpoints (the pulse then warns about THEM), which this test must neither need nor hide.
    if (public.founder_anchor_pulse() ->> 'why') like '%different certificate key%' then raise exception 'accepting the signer must clear the signer warning: %', public.founder_anchor_pulse(); end if;
    r := r || 'RFC3161 rules + signer pin OK; ';

    -- OpenTimestamps: pending, then Bitcoin
    if (public.founder_anchor_pulse() ->> 'time_anchored')::boolean is not true then raise exception 'tsa level must read as time-anchored'; end if;
    j := public.founder_anchor_record_ots(v_ots1, 'ots_pending', v_ev, jsonb_build_object('commit_hex', repeat('c', 64), 'calendar', 'https://alice.btc.calendar.opentimestamps.org'));
    if not (j ->> 'recorded')::boolean or (select state from public.founder_anchor_jobs where id = v_ots1) <> 'pending' then raise exception 'pending proof not recorded: %', j; end if;
    if (public.founder_anchor_record_ots(v_ots1, 'ots_pending', v_ev, jsonb_build_object('commit_hex', repeat('c', 64), 'calendar', 'x')) ->> 'recorded')::boolean then raise exception 'a second pending proof was stored'; end if;
    if not public._fs_fails(format($q$select public.founder_anchor_record_ots(%s, 'ots_bitcoin', %L, %L::jsonb)$q$, v_ots1, v_ev, jsonb_build_object('commit_hex', repeat('c', 64), 'btc_height', 0)::text)) then raise exception 'height 0 accepted'; end if;
    if not public._fs_fails(format($q$select public.founder_anchor_record_ots(%s, 'ots_bitcoin', %L, %L::jsonb)$q$, v_ots1, v_ev, jsonb_build_object('commit_hex', repeat('c', 64), 'btc_height', 800000, 'btc_time_ms', v_sig_ms - 86400000)::text)) then raise exception 'a Bitcoin block from before the note was accepted'; end if;
    j := public.founder_anchor_record_ots(v_ots1, 'ots_bitcoin', v_ev, jsonb_build_object('commit_hex', repeat('c', 64), 'btc_height', 800000, 'btc_time_ms', v_sig_ms + 3600000));
    if not (j ->> 'recorded')::boolean or (select state from public.founder_anchor_jobs where id = v_ots1) <> 'done' then raise exception 'bitcoin proof not recorded: %', j; end if;
    if public.founder_anchor_level(v_cpid) <> 'strong' then raise exception 'tsa + bitcoin must be strong, got %', public.founder_anchor_level(v_cpid); end if;
    x := public.founder_anchor_pulse();
    if not (x ->> 'strong')::boolean or (x ->> 'head_cp')::bigint <> v_cpid or (x -> 'providers') is null or jsonb_array_length(x -> 'providers') < 6 then raise exception 'pulse is wrong: %', x; end if;
    r := r || 'OpenTimestamps pending -> bitcoin + strong OK; ';

    -- failure handling: backoff, retry, dead letter
    j := public.founder_anchor_fail(v_ots2, 'calendar said 503', true);
    if (j ->> 'dead')::boolean or (j ->> 'retry_in_s')::int < 30 then raise exception 'first failure should back off: %', j; end if;
    j := public.founder_anchor_fail(v_ots2, 'calendar said 503', true);
    if (j ->> 'retry_in_s')::int < 60 then raise exception 'backoff must double: %', j; end if;
    j := public.founder_anchor_fail(v_ots3, 'bad reply: not an OpenTimestamps proof', false);
    if not (j ->> 'dead')::boolean or (select state from public.founder_anchor_jobs where id = v_ots3) <> 'dead' then raise exception 'a non-retryable failure must be dead: %', j; end if;
    if (public.founder_anchor_fail(v_ots3, 'again', true) ->> 'recorded')::boolean then raise exception 'a dead job accepted a failure'; end if;
    for i in 1 .. 12 loop perform public.founder_anchor_fail(v_ots2, 'still down', true); end loop;
    if (select state from public.founder_anchor_jobs where id = v_ots2) <> 'dead' then raise exception 'max_attempts did not kill the job'; end if;
    if (public.founder_anchor_pulse() ->> 'dead')::int < 2 then raise exception 'pulse does not count dead jobs'; end if;
    r := r || 'backoff + dead letter OK; ';

    -- guards
    if not public._fs_fails(format($q$update public.founder_anchor_jobs set state = 'queued' where id = %s$q$, v_tsa1)) then raise exception 'a finished job was reopened'; end if;
    if not public._fs_fails($q$delete from public.founder_anchor_jobs$q$) or not public._fs_fails($q$update public.founder_anchor_jobs set cp_id = cp_id + 1$q$) then raise exception 'jobs were deleted or re-pointed'; end if;
    if not public._fs_fails($q$update public.founder_anchor_evidence set evidence = '\x00'::bytea$q$) or not public._fs_fails($q$delete from public.founder_anchor_evidence$q$) or not public._fs_fails($q$truncate public.founder_anchor_evidence$q$) then raise exception 'evidence was changed'; end if;
    if not public._fs_fails($q$update public.founder_anchor_events set detail = 'x'$q$) or not public._fs_fails($q$delete from public.founder_anchor_events$q$) or not public._fs_fails($q$truncate public.founder_anchor_events$q$) then raise exception 'events were changed'; end if;
    if not public._fs_fails(format($q$insert into public.founder_anchor_evidence (job_id, cp_id, provider_id, version, stage, digest_hex, evidence, evidence_sha256, parsed, recorded_ms, prev_hash, hash)
        select %s, cp_id, provider_id, 9, 'tsa_token', %L, '\x00112233445566778899aabbccddeeff00112233'::bytea, repeat('0', 64), '{}'::jsonb, 1, repeat('0', 64), repeat('0', 64) from public.founder_anchor_jobs where id = %s$q$, v_tsa1, repeat('0', 64), v_tsa1)) then raise exception 'a forged digest went in'; end if;
    r := r || 'immutability + forged-digest OK; ';

    -- provider switch (audited) + verify + get
    j := public.founder_anchor_provider_set(v_uid, 'ots-bob', false, 'selftest switches a provider off');
    if (select enabled from public.founder_anchor_providers where name = 'ots-bob') then raise exception 'provider_set did not switch it off'; end if;
    if (select count(*) from public.founder_audit where action = 'anchor.provider') < 1 then raise exception 'provider_set was not audited'; end if;
    j := public.founder_anchor_verify(500);
    if not (j ->> 'ok')::boolean then raise exception 'verify failed on a good state: %', j; end if;
    j := public.founder_anchor_get(v_cpid);
    if not (j ->> 'found')::boolean or j ->> 'digest_hex' <> v_dig or j ->> 'level' <> 'strong' or jsonb_array_length(j -> 'evidence') < 3 or j ->> 'note' <> v_note then raise exception 'get is wrong: %', left(j::text, 300); end if;
    r := r || 'provider_set + verify + get OK; ';
    raise exception 'ROLLBACK_SELFTEST';
  exception when others then
    if sqlerrm <> 'ROLLBACK_SELFTEST' then raise exception 'E124 selftest FAIL: %', sqlerrm; end if;
  end;
  if (select count(*) from public.founder_anchor_jobs) <> b_jobs or (select count(*) from public.founder_anchor_evidence) <> b_evi or (select count(*) from public.founder_anchor_events) <> b_evt
     or (select count(*) from public.founder_audit) <> b_aud
     or (select md5(string_agg(id || ':' || enabled || ':' || coalesce(signer_pin, ''), ',' order by id)) from public.founder_anchor_providers) <> b_prov then raise exception 'E124 selftest left rows behind'; end if;
  return 'E124 selftest OK — ' || r || 'rollback clean';
end $$;

revoke all on function public.founder_anchor_e124_selftest() from public, anon, authenticated;
grant execute on function public.founder_anchor_e124_selftest() to service_role;

do $$ begin raise notice '%', public.founder_anchor_e124_selftest(); end $$;

-- RUNBOOK: bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E132_anchor_selftest_repair CHECK_E124  (needs E124).
