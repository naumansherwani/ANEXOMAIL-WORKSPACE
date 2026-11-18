
-- E190 (QC1cF3-5 / F3-6, 18 Nov 2026 08:4x PKT, his order "E190 commit send kero"): THE CHIP UPDATES BY ITSELF.
-- The lock on a recipient chip (E189 facts) must change when a probe finishes or a retry is scheduled, without a refresh. The live channel for that already exists:
-- the E187 change log + the signed QLIVE tick. This file teaches that log ONE new closed kind, 'tls', and writes one line whenever a TLS fact row of E189 is created or its verdict changes.
-- WHAT IT DOES: (1) widens the E187 kind list with 'tls' (the closed list stays closed; every other kind is unchanged). (2) AFTER INSERT / AFTER UPDATE OF verdict, next_try_at on fmail_domain_tls189 -> one 'tls' line
--   through the E187 internal door (gapless sequence, hash chain unchanged). The browser refreshes its chips on any kind (E188 rule), then asks the E189 read door for the 50 domains it shows.
-- PRIVACY: kind only. The line carries NO domain, NO blind index, NO verdict: folder, message and thread stay empty. Which domain changed is learned only through the sealed read door.
-- Run through sql-run.sh, after E189. Safe to run again (idempotent). Awam is not touched. Re-run after the 18 Nov 10:2x loophole fix: trigger is SECURITY DEFINER and never undoes the fact; the nonsense-kind check is a real attempt.

do $$
begin
  if to_regprocedure('public.fmail_change_' || 'note187(uuid,text,uuid,uuid,uuid)') is null then raise exception 'E190: E187 is missing (run E187 first)'; end if;
  if to_regclass('public.fmail_domain_tls189') is null then raise exception 'E190: E189 is missing (run E189 first)'; end if;
end $$;

do $$
declare c record;
begin
  for c in select conname from pg_constraint where conrelid = 'public.fmail_change_log187'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%expunge%' and pg_get_constraintdef(oid) like '%kind%' loop
    execute format('alter table public.fmail_change_log187 drop constraint %I', c.conname);
  end loop;
  alter table public.fmail_change_log187 add constraint fmail_change_kind_ck190 check (kind in ('arrive', 'sent', 'draft', 'expunge', 'read', 'unread', 'star', 'unstar', 'move', 'label', 'unlabel', 'outbox', 'scan', 'verdict', 'tls'));
exception when duplicate_object then null;
end $$;

-- LOOPHOLE FIX (18 Nov 10:2x PKT): (a) SECURITY DEFINER, so the line is written whoever touched the row (a caller without the note187 grant no longer makes the fact write fail);
-- (b) a failure of the live-tick line must NEVER undo the TLS fact itself: it is caught, reported as a WARNING, and the browser's 15 s re-read still finds the fact.
create or replace function public.fmail_change_tls190() returns trigger language plpgsql security definer set search_path = pg_catalog, public as $$
begin
  if tg_op = 'INSERT' or new.verdict is distinct from old.verdict or new.next_try_at is distinct from old.next_try_at then
    begin
      perform public.fmail_change_note187(new.mailbox_id, 'tls', null, null, null);
    exception when others then
      raise warning 'E190: tls change line not written (%): the fact itself is kept', sqlerrm;
    end;
  end if;
  return null;
end $$;
drop trigger if exists fmail_change_tls on public.fmail_domain_tls189;
create trigger fmail_change_tls after insert or update of verdict, next_try_at on public.fmail_domain_tls189 for each row execute function public.fmail_change_tls190();
revoke all on function public.fmail_change_tls190() from public, anon, authenticated;

create or replace function public.fmail_posture190() returns jsonb language sql stable security definer set search_path = pg_catalog, public as $$
  select jsonb_build_object(
    'tls_trigger', (select count(*) from pg_trigger where tgrelid = 'public.fmail_domain_tls189'::regclass and tgname = 'fmail_change_tls' and not tgisinternal),
    'kind_tls_allowed', exists (select 1 from pg_constraint where conrelid = 'public.fmail_change_log187'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%''tls''%'),
    'trigger_fn_closed', not has_function_privilege('anon', 'public.fmail_change_tls190()', 'execute') and not has_function_privilege('authenticated', 'public.fmail_change_tls190()', 'execute'),
    'door_audit_clean', not exists (select 1 from public.fmail_door_audit179()));
$$;
revoke all on function public.fmail_posture190() from public, anon, authenticated;
grant execute on function public.fmail_posture190() to service_role;

-- selftest: rolls itself back ---------------------------------------------------------------------------------------------------------------------------
create or replace function public.fmail_selftest190() returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare
  res jsonb := '[]'::jsonb; v_uid uuid; v_box uuid; v_r jsonb;
  b1 bytea := sha256(convert_to('selftest190-one', 'UTF8'));
  v_seal bytea := decode(repeat('ab', 40), 'hex'); v_nonce bytea := decode(repeat('01', 12), 'hex'); v_wrap bytea := decode(repeat('02', 64), 'hex'); v_aad bytea := decode(repeat('03', 32), 'hex');
begin
  select user_id into v_uid from public.founder_accounts limit 1;
  if v_uid is null then return jsonb_build_object('ok', false, 'error', 'no founder account to test with'); end if;
  begin
    insert into public.fmail_mailboxes (owner, address, display_name, seal_mode, recipient_key_id, vault_key_id) values (v_uid, 'selftest190@anexomail.com', 'T', 'vault', null, 'vault-selftest') returning id into v_box;
    v_r := public.fmail_dtls_claim189(v_uid, v_box, b1, v_seal, v_nonce, 'k', v_wrap, v_aad);
    v_r := public.fmail_change_since187(v_uid, v_box, 0, 50);
    res := res || jsonb_build_object('name', 'a new domain row writes one tls line, number 1', 'ok', (v_r ->> 'head') = '1' and v_r #>> '{changes,0,kind}' = 'tls');
    res := res || jsonb_build_object('name', 'the tls line carries no folder, message or thread (no domain, no verdict leaks)', 'ok', v_r #>> '{changes,0,folder}' is null and v_r #>> '{changes,0,message}' is null and v_r #>> '{changes,0,thread}' is null);
    v_r := public.fmail_dtls_claim189(v_uid, v_box, b1, v_seal, v_nonce, 'k', v_wrap, v_aad);
    res := res || jsonb_build_object('name', 'a busy claim (nothing changed) writes no line', 'ok', (public.fmail_change_since187(v_uid, v_box, 0, 50) ->> 'head') = '1');
    v_r := public.fmail_dtls_finish189(v_uid, v_box, b1, 'pq', 'X25519MLKEM768', 'TLSv1.3', 'TLS_AES_256_GCM_SHA384', true, v_seal, v_nonce);
    v_r := public.fmail_change_since187(v_uid, v_box, 1, 50);
    res := res || jsonb_build_object('name', 'finishing the probe writes the next tls line, number 2', 'ok', (v_r ->> 'head') = '2' and v_r #>> '{changes,0,kind}' = 'tls' and (v_r #>> '{changes,0,seq}') = '2');
    res := res || jsonb_build_object('name', 'the E187 chain still verifies with the new kind', 'ok', coalesce((public.fmail_change_verify187(v_box) ->> 'ok')::boolean, false));
    -- a REAL attempt through the E187 door (not a text look): a kind outside the closed list must be refused, by the door or by the table
    begin
      perform public.fmail_change_note187(v_box, 'nonsense', null, null, null);
      res := res || jsonb_build_object('name', 'a kind outside the closed list is still refused', 'ok', false);
    exception when check_violation or raise_exception or invalid_parameter_value then
      res := res || jsonb_build_object('name', 'a kind outside the closed list is still refused', 'ok', true);
    end;
    raise exception 'E190_ROLLBACK';
  exception when others then
    if sqlerrm <> 'E190_ROLLBACK' then return jsonb_build_object('ok', false, 'error', sqlerrm, 'passed', 0, 'checks', res); end if;
  end;
  return jsonb_build_object('ok', not exists (select 1 from jsonb_array_elements(res) e where (e ->> 'ok') is distinct from 'true'), 'passed', (select count(*) from jsonb_array_elements(res) e where (e ->> 'ok') = 'true'), 'total', jsonb_array_length(res), 'checks', res);
end $$;
revoke all on function public.fmail_selftest190() from public, anon, authenticated;
grant execute on function public.fmail_selftest190() to service_role;
