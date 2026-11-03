
-- E134 — G5c REPAIR R1 (part 2): an audited door that re-queues anchoring jobs which DIED OF A KNOWN, FIXED CAUSE (founder 3 Nov 06:41 "R1 green kero ... ek bhi nahi bachay").
-- Why: a dead job is final (E124 by design: a failure is never swallowed). The 12 OpenTimestamps jobs of seals 1-4 died of "calendar commitment is not 32 bytes" (a Rust + SQL bug, fixed by E133 + anchors.rs).
-- The E124 job guard already allows exactly one exit from 'dead': back to 'queued'. This is the door for it. It is NOT a blanket "retry everything":
--   * founder only (founder_accounts), a reason of 8+ characters, and the CAUSE must be named (p_error_like, 4+ characters, matched case-insensitively against last_error) - so only jobs that died of that cause are touched;
--   * only providers that are switched ON; a done / pending / queued job is never touched; attempts restart at 0, the old error is kept inside the new last_error ("requeued: ...");
--   * one 'requeued' event per job in the hash-chained event log, one audit entry for the whole call; zero matches = no audit row (no noise), so a second run is a no-op.
-- E124 is not edited (E130/E132/E133 pattern). The events CHECK list gains 'requeued'. Additive, idempotent. A requeued job whose evidence is still needed gets REAL evidence from the real service (nothing is invented).

do $$ declare v_c text; begin
  perform pg_advisory_xact_lock(hashtextextended('founder_anchor:ddl', 0));
  if to_regclass('public.founder_anchor_events') is null then raise exception 'E134: run E124 first'; end if;
  for v_c in select conname from pg_constraint where conrelid = 'public.founder_anchor_events'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%provider_set%' loop
    execute format('alter table public.founder_anchor_events drop constraint %I', v_c);
  end loop;
  if not exists (select 1 from pg_constraint where conrelid = 'public.founder_anchor_events'::regclass and conname = 'founder_anchor_events_event_check') then
    alter table public.founder_anchor_events add constraint founder_anchor_events_event_check check (event in
      ('enqueued', 'submitted', 'tsa_ok', 'ots_pending', 'ots_bitcoin', 'failed', 'dead', 'signer_changed', 'signer_accepted', 'provider_set', 'verified', 'requeued'));
  end if;
end $$;

create or replace function public.founder_anchor_requeue(p_actor uuid, p_provider text, p_error_like text, p_reason text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '20s' as $$
declare r record; v_n integer := 0; v_ms bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint; v_cause text := lower(btrim(coalesce(p_error_like, ''))); v_ids bigint[] := '{}';
begin
  if p_actor is null or not exists (select 1 from public.founder_accounts where user_id = p_actor) then raise exception 'E134: actor is not a founder' using errcode = '42501'; end if;
  if length(btrim(coalesce(p_reason, ''))) < 8 then raise exception 'E134: reason needs 8 characters' using errcode = '22023'; end if;
  if length(v_cause) < 4 then raise exception 'E134: name the cause (4+ characters of the stored error) - no blanket requeue' using errcode = '22023'; end if;
  if p_provider is not null and not exists (select 1 from public.founder_anchor_providers where name = p_provider) then raise exception 'E134: no such provider' using errcode = '23503'; end if;
  perform pg_advisory_xact_lock(hashtextextended('founder_anchor:requeue', 0));
  for r in
    select j.id, j.cp_id, j.provider_id, j.last_error, p.name from public.founder_anchor_jobs j join public.founder_anchor_providers p on p.id = j.provider_id
    where j.state = 'dead' and p.enabled and (p_provider is null or p.name = p_provider) and position(v_cause in lower(coalesce(j.last_error, ''))) > 0
    order by j.id for update of j
  loop
    update public.founder_anchor_jobs set state = 'queued', attempts = 0, next_try_ms = 0, updated_ms = v_ms, last_error = left('requeued: ' || coalesce(r.last_error, ''), 400) where id = r.id;
    perform public._fm_anchor_ev('requeued', r.cp_id, r.provider_id, 'was dead: ' || left(coalesce(r.last_error, ''), 300));
    v_n := v_n + 1; v_ids := v_ids || r.id;
  end loop;
  if v_n > 0 then
    perform public.founder_audit_append(p_actor, 'anchor.requeue', 'provider:' || coalesce(p_provider, 'all'), btrim(p_reason), jsonb_build_object('requeued', v_n, 'cause', left(v_cause, 80)));
  end if;
  return jsonb_build_object('requeued', v_n, 'job_ids', to_jsonb(v_ids));
end $$;
revoke all on function public.founder_anchor_requeue(uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.founder_anchor_requeue(uuid, text, text, text) to service_role;

create or replace function public.founder_anchor_e134_selftest() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '60s' as $$
declare r text := ''; v_uid uuid; v_name text := 'selftest.example/e134'; v_pub text := encode(extensions.digest(convert_to(clock_timestamp()::text || random()::text, 'UTF8'), 'sha256'), 'hex'); v_kid text; v_key_id bigint; v_cp jsonb; v_cpid bigint; v_note text;
        v_a bigint; v_b bigint; v_c bigint; v_d bigint; j jsonb; v_pre integer; v_ev0 bigint; v_rq0 bigint; b_jobs bigint; b_aud bigint; b_evt bigint; b_evi bigint; v_aud0 bigint;
begin
  select user_id into v_uid from public.founder_accounts limit 1;
  if v_uid is null then return 'E134 selftest SKIP (no founder account yet)'; end if;
  select count(*) into b_jobs from public.founder_anchor_jobs; select count(*) into b_aud from public.founder_audit; select count(*) into b_evt from public.founder_anchor_events; select count(*) into b_evi from public.founder_anchor_evidence;
  begin
    update public.founder_audit_log_keys set status = 'retired', retired_ms = greatest(created_ms, (extract(epoch from clock_timestamp()) * 1000)::bigint) where status = 'active';
    v_kid := substr(encode(extensions.digest(convert_to(v_name, 'UTF8') || '\x0a01'::bytea || decode(v_pub, 'hex'), 'sha256'), 'hex'), 1, 8);
    perform public.founder_audit_log_key_register(v_uid, v_name, v_pub, v_kid);
    select id into v_key_id from public.founder_audit_log_keys where status = 'active';
    perform public.founder_audit_append(v_uid, 'e134.selftest', 'row-1', 'selftest entry', '{}'::jsonb);
    perform public.founder_audit_checkpoint(v_uid, 'selftest seal e134');
    v_cp := (public.founder_audit_signed_cp_pending(50)) -> -1; v_cpid := (v_cp ->> 'cp_id')::bigint;
    v_note := v_name || E'\n' || (v_cp ->> 'size') || E'\n' || encode(decode(v_cp ->> 'root', 'hex'), 'base64') || E'\n' || E'\n' || E'— ' || v_name || ' '
              || replace(encode(decode(v_kid, 'hex') || decode(repeat('44', 64), 'hex'), 'base64'), E'\n', '') || E'\n';
    perform public.founder_audit_signed_cp_add(v_cpid, v_key_id, v_note);
    perform public.founder_anchor_enqueue(); update public.founder_anchor_jobs set next_try_ms = 0 where cp_id = v_cpid; perform public.founder_anchor_next(60);
    select id into v_a from public.founder_anchor_jobs where cp_id = v_cpid and provider_id = (select id from public.founder_anchor_providers where name = 'ots-alice');
    select id into v_b from public.founder_anchor_jobs where cp_id = v_cpid and provider_id = (select id from public.founder_anchor_providers where name = 'ots-bob');
    select id into v_c from public.founder_anchor_jobs where cp_id = v_cpid and provider_id = (select id from public.founder_anchor_providers where name = 'ots-finney');
    select id into v_d from public.founder_anchor_jobs where cp_id = v_cpid and provider_id = (select id from public.founder_anchor_providers where name = 'digicert-tsa');
    perform public.founder_anchor_fail(v_a, 'calendar commitment is not 32 bytes', false);        -- died of the fixed cause
    perform public.founder_anchor_fail(v_b, 'calendar answered with a 500', false);                -- died of something else
    perform public.founder_anchor_fail(v_c, 'calendar commitment is not 32 bytes', false);        -- same cause, but its provider will be switched off
    if (select count(*) from public.founder_anchor_jobs where id in (v_a, v_b, v_c) and state = 'dead') <> 3 then raise exception 'setup: three jobs should be dead'; end if;
    -- refusals
    if not public._fs_fails(format($q$select public.founder_anchor_requeue(%L, 'ots-alice', 'not 32 bytes', 'short')$q$, v_uid)) then raise exception 'a short reason was accepted'; end if;
    if not public._fs_fails(format($q$select public.founder_anchor_requeue(%L, 'ots-alice', '', 'a proper reason here')$q$, v_uid)) then raise exception 'an empty cause was accepted (blanket requeue)'; end if;
    if not public._fs_fails(format($q$select public.founder_anchor_requeue(%L, 'ots-alice', 'abc', 'a proper reason here')$q$, v_uid)) then raise exception 'a 3-character cause was accepted'; end if;
    if not public._fs_fails($q$select public.founder_anchor_requeue(null, 'ots-alice', 'not 32 bytes', 'a proper reason here')$q$) then raise exception 'a null actor was accepted'; end if;
    if not public._fs_fails($q$select public.founder_anchor_requeue('00000000-0000-0000-0000-000000000001', 'ots-alice', 'not 32 bytes', 'a proper reason here')$q$) then raise exception 'a non-founder was accepted'; end if;
    if not public._fs_fails(format($q$select public.founder_anchor_requeue(%L, 'no-such-provider', 'not 32 bytes', 'a proper reason here')$q$, v_uid)) then raise exception 'an unknown provider was accepted'; end if;
    r := r || 'refusals OK; ';
    -- a provider that is switched off is left alone
    perform public.founder_anchor_provider_set(v_uid, 'ots-finney', false, 'selftest switches finney off');
    select count(*) into v_aud0 from public.founder_audit; select count(*) into v_ev0 from public.founder_anchor_events where event = 'requeued'; select count(*) into v_rq0 from public.founder_audit where action = 'anchor.requeue';
    -- on a LIVE ledger real dead jobs of the same cause may exist (the very ones this door is for): the selftest must not assume it is alone. It counts them first (inside the rolled-back transaction).
    select count(*) into v_pre from public.founder_anchor_jobs jj join public.founder_anchor_providers pp on pp.id = jj.provider_id
      where jj.state = 'dead' and pp.enabled and position('not 32 bytes' in lower(coalesce(jj.last_error, ''))) > 0;
    j := public.founder_anchor_requeue(v_uid, null, 'NOT 32 BYTES', 'requeue the jobs the 32-byte bug killed');       -- case-insensitive cause, all providers
    if (j ->> 'requeued')::int <> v_pre or v_pre < 1 then raise exception 'wrong number requeued (expected %): %', v_pre, j; end if;
    if not (j -> 'job_ids') @> to_jsonb(array[v_a]) or (j -> 'job_ids') @> to_jsonb(array[v_b]) or (j -> 'job_ids') @> to_jsonb(array[v_c]) then raise exception 'wrong set requeued: %', j; end if;
    if exists (select 1 from public.founder_anchor_jobs jj join public.founder_anchor_providers pp on pp.id = jj.provider_id
               where jj.state = 'dead' and pp.enabled and position('not 32 bytes' in lower(coalesce(jj.last_error, ''))) > 0) then raise exception 'a matching dead job was left behind'; end if;
    if (select state || '/' || attempts || '/' || next_try_ms from public.founder_anchor_jobs where id = v_a) <> 'queued/0/0' then raise exception 'job a was not reset'; end if;
    if (select last_error from public.founder_anchor_jobs where id = v_a) not like 'requeued: calendar commitment is not 32 bytes%' then raise exception 'the old error was lost'; end if;
    if (select state from public.founder_anchor_jobs where id = v_b) <> 'dead' then raise exception 'a job with another cause was touched'; end if;
    if (select state from public.founder_anchor_jobs where id = v_c) <> 'dead' then raise exception 'a job of a switched-off provider was touched'; end if;
    if (select state from public.founder_anchor_jobs where id = v_d) not in ('queued', 'pending') then raise exception 'an unrelated job changed state'; end if;
    if (select count(*) from public.founder_anchor_events where event = 'requeued') - v_ev0 <> v_pre or (select count(*) from public.founder_anchor_events where event = 'requeued' and cp_id = v_cpid) <> 1 then raise exception 'the requeued events are not one per job'; end if;
    if (select count(*) from public.founder_audit where action = 'anchor.requeue') - v_rq0 <> 1 or (select count(*) from public.founder_audit) <> v_aud0 + 1 then raise exception 'the requeue was not audited exactly once'; end if;
    r := r || 'exact set + event + one audit row; ';
    -- second call: nothing left, no audit noise
    j := public.founder_anchor_requeue(v_uid, null, 'not 32 bytes', 'requeue the jobs the 32-byte bug killed');
    if (j ->> 'requeued')::int <> 0 or (select count(*) from public.founder_audit) <> v_aud0 + 1 then raise exception 'a second run was not a no-op: %', j; end if;
    if (public.founder_anchor_verify(500) ->> 'ok')::boolean is not true then raise exception 'verify failed: %', public.founder_anchor_verify(500); end if;
    r := r || 'second run no-op, verify clean; ';
    raise exception 'ROLLBACK_SELFTEST';
  exception when others then
    if sqlerrm <> 'ROLLBACK_SELFTEST' then raise exception 'E134 selftest FAIL: %', sqlerrm; end if;
  end;
  if (select count(*) from public.founder_anchor_jobs) <> b_jobs or (select count(*) from public.founder_audit) <> b_aud or (select count(*) from public.founder_anchor_events) <> b_evt
     or (select count(*) from public.founder_anchor_evidence) <> b_evi then raise exception 'E134 selftest left rows behind'; end if;
  return 'E134 selftest OK — ' || r || 'rollback clean';
end $$;
revoke all on function public.founder_anchor_e134_selftest() from public, anon, authenticated;
grant execute on function public.founder_anchor_e134_selftest() to service_role;

do $$ begin raise notice '%', public.founder_anchor_e134_selftest(); end $$;

-- RUNBOOK: bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E134_anchor_requeue_door CHECK_E134   (needs E124 + E133). No Rust change.
-- Undo: drop function public.founder_anchor_requeue(uuid,text,text,text); public.founder_anchor_e134_selftest(); (the 'requeued' value may stay in the CHECK list).
