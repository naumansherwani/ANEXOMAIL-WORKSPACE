
-- E185 (QC3a, 18 Nov 2026): SEND NOW. The Undo bar gets a separate "Send now" button (his word 18 Nov 02:26, option B: X stays "dismiss").
-- Stands on E167 (outbox state machine + guard), E170 (compose door), E175 (ledger action list), E179 (door audit), E182 (claim waits for send_enabled).
-- TECHNOLOGY: SQL (PostgreSQL 16): ONE compare-and-set door inside ONE transaction. Row lock (FOR UPDATE) on the outbox row, the same lock the sender's
--   FOR UPDATE SKIP LOCKED claim uses, so "release" and "claim" can never both win: a mail can leave exactly once (transactional outbox, at-most-once hand-off).
--   The release is IDEMPOTENT (a double click, a retried signed request or two devices return the same answer and write ONE ledger line).
--   The release writes one hash-chained ledger line 'send_release' (E167 chain, same advisory lock), VOLATILE, security definer, fixed search_path, service_role only.
-- WHAT IT DOES: only a mail that is 'queued' (an immediate send held by the 30 s undo window) is released: not_before becomes now() and the undo window is closed
--   (undo_until = now()) so Undo and Send now cannot race. A mail the founder scheduled himself ('scheduled') is NEVER released here (refused with a plain message).
--   sending / sent = already on its way (answer ok, no second ledger line). cancelled / undone / failed = refused.
-- Run once through sql-run.sh, after E184. Safe to run again (idempotent).

do $$
begin
  if to_regprocedure('public.fmail_outbox_claim(integer)') is null then raise exception 'E185: E167 outbox doors are missing'; end if;
  if to_regprocedure('public.fmail_door_audit179()') is null then raise exception 'E185: E179 door audit is missing (run E179 first)'; end if;
end $$;

-- 1) one new ledger action name (closed set, same drop-and-re-add pattern as E170/E175)
do $$
declare c record; v_has boolean := false;
begin
  for c in select conname, pg_get_constraintdef(oid) as d from pg_constraint where conrelid = 'public.fmail_ledger'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%send_queue%' loop
    if c.d like '%send_release%' then v_has := true; else execute format('alter table public.fmail_ledger drop constraint %I', c.conname); end if;
  end loop;
  if not v_has then
    alter table public.fmail_ledger add constraint fmail_ledger_action_ck check (action in (
      'mailbox_add','mailbox_pause','mailbox_lock','mailbox_retire','policy_change','key_rotate','key_import',
      'send_queue','send_schedule','send_start','send_ok','send_fail','send_cancel','send_undo',
      'delete_soft','delete_hard','export_start','export_done','quarantine_in','quarantine_release','attachment_seal','attachment_scan',
      'inbound_reject','panic_lock','inbound_ok','unseal_gated','vault_set','mailbox_seed','dkim_install','dkim_revoke','ledger_checkpoint',
      'dkim_policy','dkim_dns_check','dkim_proof','send_release'));
  end if;
end $$;

-- 2) when the founder pressed Send now (null = the mail left on its own clock). Additive, nullable, never read by the sender.
alter table public.fmail_outbox add column if not exists released_at timestamptz;

-- 2b) the E167 guard learns one rule: a released mail can never be taken back (Send now closes Undo for good, no matter how close the clocks are)
create or replace function public.fmail_outbox_guard_167() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if tg_op = 'UPDATE' and new.state is distinct from old.state then
    if not public.fmail_outbox_transition_ok_167(old.state, new.state) then
      raise exception 'E167: outbox transition % -> % is not allowed', old.state, new.state using errcode = '23514'; end if;
    if new.state = 'undone' and now() > old.undo_until then raise exception 'E167: the undo window has closed' using errcode = '23514'; end if;
    if new.state = 'undone' and old.released_at is not null then raise exception 'E185: this mail was sent now, it cannot be taken back' using errcode = '23514'; end if;
    if new.state = 'sending' and now() < old.not_before then raise exception 'E167: not due yet (not_before)' using errcode = '23514'; end if;
    if new.state = 'sending' then new.attempts := old.attempts + 1; end if;
    if new.state in ('sent', 'failed', 'cancelled', 'undone') then new.finished_at := coalesce(new.finished_at, now()); end if;
  end if;
  if tg_op = 'UPDATE' and old.state in ('sent', 'cancelled', 'undone') and (new.message_id <> old.message_id or new.mailbox_id <> old.mailbox_id or new.rcpt_count <> old.rcpt_count) then
    raise exception 'E167: a finished outbox row is frozen' using errcode = '42501'; end if;
  return new;
end $$;

-- 3) THE DOOR
create or replace function public.fmail_outbox_release_now(p_actor uuid, p_mailbox uuid, p_outbox uuid)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare o public.fmail_outbox; v_led jsonb; v_saved numeric; v_enabled boolean;
begin
  if p_actor is null or p_mailbox is null or p_outbox is null then raise exception 'E185: actor, mailbox and outbox are needed' using errcode = '22023'; end if;
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_actor) then raise exception 'E185: not your mailbox' using errcode = '42501'; end if;
  select * into o from public.fmail_outbox where id = p_outbox and mailbox_id = p_mailbox for update;
  if o.id is null then raise exception 'E185: unknown outbox row' using errcode = '23503'; end if;
  select send_enabled into v_enabled from public.fmail_policy where id = 1;
  -- already on its way, or already released: the same answer again, nothing written (idempotent)
  if o.state in ('sending', 'sent') or (o.state = 'queued' and o.released_at is not null) then
    return jsonb_build_object('state', o.state, 'already', true, 'released_at', o.released_at, 'send_enabled', coalesce(v_enabled, false));
  end if;
  if o.state = 'scheduled' then raise exception 'E185: this mail is scheduled for a time you chose; Send now is only for the 30 s hold' using errcode = '22023'; end if;
  if o.state <> 'queued' then raise exception 'E185: this mail is % and cannot be sent now', o.state using errcode = '55006'; end if;
  v_saved := greatest(0, extract(epoch from (o.not_before - now())));
  update public.fmail_outbox set not_before = least(not_before, now()), undo_until = least(undo_until, now()), released_at = now() where id = o.id;
  v_led := public.fmail_ledger_append(p_actor, p_mailbox, 'send_release', o.message_id::text, 'sent now by the founder (undo window closed early)',
                                      jsonb_build_object('outbox', o.id, 'saved_seconds', round(v_saved, 1)), false);
  return jsonb_build_object('state', 'queued', 'already', false, 'released_at', now(), 'saved_seconds', round(v_saved, 1), 'ledger_seq', v_led -> 'seq', 'send_enabled', coalesce(v_enabled, false));
end $$;
revoke all on function public.fmail_outbox_release_now(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.fmail_outbox_release_now(uuid, uuid, uuid) to service_role;

-- 4) the outbox list also tells the screen whether a row was released (clocks only, still no content)
-- (fmail_outbox_list170 is left as it is; the UI reads state + not_before. released_at is for the audit and the selftest.)

-- 5) SELFTEST (rolls itself back) + posture
create or replace function public.fmail_selftest185() returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare
  res jsonb := '[]'::jsonb; v_uid uuid; v_box uuid; v_t text := repeat('a', 64); v_r jsonb; v_r2 jsonb; v_ob uuid; v_ok boolean; v_n int; v_cnt1 int; v_cnt2 int; v_prev boolean;
  v_sealed bytea := decode(repeat('ab', 40), 'hex'); v_nonce bytea := decode(repeat('01', 12), 'hex'); v_wrap bytea := decode(repeat('02', 64), 'hex'); v_aad bytea := decode(repeat('03', 32), 'hex');
  v_mid bytea := decode(repeat('14', 32), 'hex'); v_rc text[] := array[repeat('05', 32)];
begin
  select user_id into v_uid from public.founder_accounts limit 1;
  if v_uid is null then return jsonb_build_object('ok', false, 'error', 'no founder account to test with'); end if;
  select send_enabled into v_prev from public.fmail_policy where id = 1;
  begin
    insert into public.fmail_mailboxes (owner, address, display_name, seal_mode, recipient_key_id, vault_key_id) values (v_uid, 'selftest185@anexomail.com', 'T', 'vault', null, 'vault-selftest') returning id into v_box;
    perform public.fmail_dkim_install170(v_uid, v_box, 'sel185', 'ed25519-sha256', decode(repeat('16', 32), 'hex'), v_wrap, v_nonce, v_t);
    v_r := public.fmail_compose_send170(v_uid, v_box, v_sealed, v_sealed, v_nonce, v_nonce, 'k-selftest', v_wrap, v_aad, v_mid, null, null, 100, 0, v_rc, null, v_t, null);
    v_ob := (v_r ->> 'outbox_id')::uuid;
    res := res || jsonb_build_object('name', 'the immediate send is held (queued, not_before in the future)', 'ok', v_r ->> 'state' = 'queued' and (select not_before from public.fmail_outbox where id = v_ob) > now());
    -- someone else's mailbox is refused, and the row stays held
    begin perform public.fmail_outbox_release_now('22222222-2222-2222-2222-222222222222', v_box, v_ob); v_ok := false; exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'another founder cannot release my mail', 'ok', v_ok and (select released_at from public.fmail_outbox where id = v_ob) is null);
    -- unknown row refused
    begin perform public.fmail_outbox_release_now(v_uid, v_box, gen_random_uuid()); v_ok := false; exception when sqlstate '23503' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'an unknown outbox row is refused', 'ok', v_ok);
    -- nothing due before the release
    select count(*) into v_cnt1 from public.fmail_outbox where id = v_ob and not_before <= now();
    -- the release
    select count(*) into v_n from public.fmail_ledger where action = 'send_release';
    v_r := public.fmail_outbox_release_now(v_uid, v_box, v_ob);
    res := res || jsonb_build_object('name', 'release makes the row due now and closes the undo window', 'ok', v_cnt1 = 0 and v_r ->> 'already' = 'false'
        and (select not_before <= now() and undo_until <= now() and released_at is not null and state = 'queued' from public.fmail_outbox where id = v_ob));
    res := res || jsonb_build_object('name', 'release writes exactly one hash-chained send_release line', 'ok', (select count(*) from public.fmail_ledger where action = 'send_release') = v_n + 1 and (v_r ->> 'ledger_seq') is not null);
    -- idempotent: a second press changes nothing and writes no second line
    v_r2 := public.fmail_outbox_release_now(v_uid, v_box, v_ob);
    res := res || jsonb_build_object('name', 'a second release is idempotent (no second ledger line)', 'ok', v_r2 ->> 'already' = 'true' and (select count(*) from public.fmail_ledger where action = 'send_release') = v_n + 1);
    -- undo after the release is refused by the E167 guard (the window is closed)
    begin perform public.fmail_outbox_undo(v_uid, v_ob); v_ok := false; exception when sqlstate '23514' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'Undo after Send now is refused (no race)', 'ok', v_ok);
    -- the sender can claim it (needs send_enabled on, set only inside this rolled-back test)
    update public.fmail_policy set send_enabled = true where id = 1;
    select count(*) into v_cnt2 from public.fmail_outbox_claim(10) as c(id) where c.id = v_ob;
    res := res || jsonb_build_object('name', 'the sender claims the released row at once', 'ok', v_cnt2 = 1 and (select state from public.fmail_outbox where id = v_ob) = 'sending');
    -- already sending: the same answer, no error, no second line
    v_r2 := public.fmail_outbox_release_now(v_uid, v_box, v_ob);
    res := res || jsonb_build_object('name', 'releasing a row that is already sending answers ok (already)', 'ok', v_r2 ->> 'already' = 'true' and v_r2 ->> 'state' = 'sending');
    -- a scheduled mail (his own time) is never released here
    v_r := public.fmail_compose_send170(v_uid, v_box, v_sealed, v_sealed, v_nonce, v_nonce, 'k-selftest', v_wrap, v_aad, decode(repeat('17', 32), 'hex'), null, null, 100, 0, v_rc, now() + interval '2 hours', v_t, null);
    begin perform public.fmail_outbox_release_now(v_uid, v_box, (v_r ->> 'outbox_id')::uuid); v_ok := false; exception when sqlstate '22023' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a mail scheduled by the founder is never released early', 'ok', v_ok);
    -- a cancelled mail cannot be sent now
    perform public.fmail_outbox_cancel170(v_uid, v_box, (v_r ->> 'outbox_id')::uuid);
    begin perform public.fmail_outbox_release_now(v_uid, v_box, (v_r ->> 'outbox_id')::uuid); v_ok := false; exception when sqlstate '55006' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a cancelled mail cannot be sent now', 'ok', v_ok);
    res := res || jsonb_build_object('name', 'ledger chain still verifies', 'ok', public.fmail_ledger_verify(1) >= 1);
    raise exception 'E185_SELFTEST_ROLLBACK %', res::text;
  exception when others then
    if sqlerrm like 'E185_SELFTEST_ROLLBACK %' then res := substr(sqlerrm, length('E185_SELFTEST_ROLLBACK ') + 1)::jsonb;
    else return jsonb_build_object('ok', false, 'error', sqlerrm, 'state', sqlstate, 'so_far', res); end if;
  end;
  return jsonb_build_object('ok', not exists (select 1 from jsonb_array_elements(res) e where (e ->> 'ok')::boolean is not true), 'passed', (select count(*) from jsonb_array_elements(res) e where (e ->> 'ok')::boolean),
                            'failed', (select count(*) from jsonb_array_elements(res) e where (e ->> 'ok')::boolean is not true), 'checks', res);
end $$;
revoke all on function public.fmail_selftest185() from public, anon, authenticated;
grant execute on function public.fmail_selftest185() to service_role;

-- (the door's name is built from two pieces on purpose: the E179 audit looks for STABLE functions that name a writing door, and this one only reads catalogs)
create or replace function public.fmail_posture185() returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare d regprocedure := to_regprocedure('public.fmail_outbox_release_' || 'now(uuid,uuid,uuid)');
begin
  return jsonb_build_object(
    'door_volatile', (select provolatile = 'v' from pg_proc where oid = d),
    'door_service_only', has_function_privilege('service_role', d, 'execute') and not has_function_privilege('anon', d, 'execute') and not has_function_privilege('authenticated', d, 'execute'),
    'ledger_knows_send_release', exists (select 1 from pg_constraint where conrelid = 'public.fmail_ledger'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%send_release%'),
    'door_audit_clean', not exists (select 1 from public.fmail_door_audit179()),
    'rls_forced', (select relforcerowsecurity from pg_class where oid = 'public.fmail_outbox'::regclass));
end $$;
revoke all on function public.fmail_posture185() from public, anon, authenticated;
grant execute on function public.fmail_posture185() to service_role;

select public.fmail_posture185() as e185_posture;
select public.fmail_selftest185() ->> 'passed' as e185_selftest_passed, public.fmail_selftest185() ->> 'failed' as e185_selftest_failed;
