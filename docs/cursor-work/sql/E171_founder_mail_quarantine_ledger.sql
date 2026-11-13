

-- E171 (Q1b-3 T4, 13 Nov 2026): the QUARANTINE LEDGER + the scan state 'opaque'.
-- Found by the live look at the real T3 self-test mails: Quarantine held 2 mails but the Bridge lane "Quarantined" said 0, because the lane counts ledger rows
-- 'quarantine_in' and the intake never wrote one (fmail_scan_set169 only wrote a mislabelled 'inbound_ok' row for infected mail, nothing for error / skipped).
-- TECHNOLOGY: SQL (PostgreSQL 16, RLS forced, service_role only, security-definer door with a fixed search_path, append-only SHA-256 hash-chained ledger, one-time
-- idempotent backfill, self-rolling-back selftest). Stands on E167 (ledger, folders), E169 (scan door), E170. Run once through sql-run.sh. Safe to run again.
--   1) scan_state accepts 'opaque' = a clean verdict that cannot be trusted because an attachment hides its content (encrypted ZIP / PDF / Office, Rust guard in fmail_in.rs)
--   2) fmail_scan_set171: pending -> clean | infected | error | skipped | opaque, once. Anything but 'clean' puts the message in the quarantine folder and writes ONE ledger row 'quarantine_in'
--   3) backfill: every inbound message already sitting in Quarantine without such a row gets one (the 2 T3 mails), so the lane tells the truth
-- The Rust engine calls fmail_scan_set171 from this version on (fmail_in.rs).

do $$
begin
  if to_regprocedure('public.fmail_scan_set169(uuid,uuid,text)') is null then raise exception 'E171: E169 is missing (run E169 first)'; end if;
  if to_regprocedure('public.fmail_selftest170()') is null then raise exception 'E171: E170 is missing (run E170 first)'; end if;
end $$;

-- 1) the scan state list grows by 'opaque'
do $$
declare c record; v_has boolean := false;
begin
  for c in select conname, pg_get_constraintdef(oid) as d from pg_constraint where conrelid = 'public.fmail_messages'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%scan_state%' loop
    if c.d like '%opaque%' then v_has := true; else execute format('alter table public.fmail_messages drop constraint %I', c.conname); end if;
  end loop;
  if not v_has then
    alter table public.fmail_messages add constraint fmail_messages_scan_state_ck check (scan_state in ('pending', 'clean', 'infected', 'error', 'skipped', 'opaque'));
  end if;
end $$;

-- 2) the scan door: quarantine + ledger in ONE transaction
create or replace function public.fmail_scan_set171(p_mailbox uuid, p_message uuid, p_state text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare m public.fmail_messages%rowtype; v_q uuid; v_owner uuid; v_led jsonb; v_why text;
begin
  if p_state not in ('clean', 'infected', 'error', 'skipped', 'opaque') then raise exception 'E171: bad scan state' using errcode = '22023'; end if;
  select * into m from public.fmail_messages where id = p_message and mailbox_id = p_mailbox for update;
  if not found then raise exception 'E171: unknown message' using errcode = '42704'; end if;
  if m.scan_state <> 'pending' then raise exception 'E171: the scan result of this message is already recorded' using errcode = '23514'; end if;
  update public.fmail_messages set scan_state = p_state where id = p_message;
  if p_state <> 'clean' then
    select id into v_q from public.fmail_folders where mailbox_id = p_mailbox and kind = 'quarantine';
    if v_q is null then raise exception 'E171: the mailbox has no quarantine folder' using errcode = '55000'; end if;
    update public.fmail_messages set folder_id = v_q where id = p_message;
    v_why := case p_state when 'infected' then 'virus found' when 'opaque' then 'an attachment hides its content (encrypted): a clean verdict is not trusted'
                          when 'skipped' then 'not scanned: nothing reaches the inbox unscanned' else 'the scanner could not give a verdict: fail closed' end;
    select owner into v_owner from public.fmail_mailboxes where id = p_mailbox;
    if not exists (select 1 from public.fmail_ledger where action = 'quarantine_in' and target = p_message::text) then
      v_led := public.fmail_ledger_append(v_owner, p_mailbox, 'quarantine_in', p_message::text, v_why, jsonb_build_object('scan', p_state), false);
    end if;
  end if;
  return jsonb_build_object('ok', true, 'scan', p_state, 'quarantined', p_state <> 'clean', 'ledger_seq', (v_led ->> 'seq')::bigint);
end $$;
revoke all on function public.fmail_scan_set171(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.fmail_scan_set171(uuid, uuid, text) to service_role;

-- 3) backfill: quarantined inbound mail without its ledger row (idempotent: a second run finds nothing)
create or replace function public.fmail_quarantine_backfill171() returns int language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare r record; v_owner uuid; v_n int := 0;
begin
  for r in select m.id, m.mailbox_id, m.scan_state from public.fmail_messages m join public.fmail_folders f on f.id = m.folder_id
            where m.direction = 'in' and f.kind = 'quarantine'
              and not exists (select 1 from public.fmail_ledger l where l.action = 'quarantine_in' and l.target = m.id::text) loop
    select owner into v_owner from public.fmail_mailboxes where id = r.mailbox_id;
    perform public.fmail_ledger_append(v_owner, r.mailbox_id, 'quarantine_in', r.id::text, 'backfill (E171): the intake did not ledger this quarantined mail', jsonb_build_object('scan', r.scan_state, 'backfill', true), false);
    v_n := v_n + 1;
  end loop;
  return v_n;
end $$;
revoke all on function public.fmail_quarantine_backfill171() from public, anon, authenticated;
grant execute on function public.fmail_quarantine_backfill171() to service_role;
select public.fmail_quarantine_backfill171();

create or replace function public.fmail_posture171() returns jsonb language sql security definer set search_path = pg_catalog, public as $$
  select jsonb_build_object(
    'opaque_allowed', (select bool_or(pg_get_constraintdef(oid) like '%opaque%') from pg_constraint where conrelid = 'public.fmail_messages'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%scan_state%'),
    'quarantined_without_ledger', (select count(*) from public.fmail_messages m join public.fmail_folders f on f.id = m.folder_id
                                    where m.direction = 'in' and f.kind = 'quarantine' and not exists (select 1 from public.fmail_ledger l where l.action = 'quarantine_in' and l.target = m.id::text)))
$$;
revoke all on function public.fmail_posture171() from public, anon, authenticated;
grant execute on function public.fmail_posture171() to service_role;

create or replace function public.fmail_selftest171() returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare
  res jsonb := '[]'::jsonb; v_uid uuid; v_box uuid; v_r jsonb; v_a uuid; v_b uuid; v_c uuid; v_ok boolean; v_n0 bigint; v_n1 bigint; v_f text;
  v_s bytea := decode(repeat('ab', 40), 'hex'); v_nc bytea := decode(repeat('01', 12), 'hex'); v_w bytea := decode(repeat('02', 64), 'hex'); v_aad bytea := decode(repeat('03', 32), 'hex');
begin
  select user_id into v_uid from public.founder_accounts limit 1;
  if v_uid is null then return jsonb_build_object('ok', false, 'error', 'no founder account to test with'); end if;
  begin
    insert into public.fmail_mailboxes (owner, address, display_name, seal_mode, recipient_key_id, vault_key_id) values (v_uid, 'selftest171@anexomail.com', 'T', 'vault', null, 'vault-selftest') returning id into v_box;
    select (l ->> 'count')::bigint into v_n0 from jsonb_array_elements(public.fmail_bridge_feed(24) -> 'lanes') l where l ->> 'lane' = 'mail-quarantine';
    v_r := public.fmail_deliver_inbound(v_box, 'inbox', 'vault', v_s, v_s, v_nc, v_nc, 'k-selftest', v_w, v_aad, decode(repeat('11', 32), 'hex'), null, null, null, 'x.test', 100, 'none', 'none', 'none', 'none', false, null, null); v_a := (v_r ->> 'message_id')::uuid;
    v_r := public.fmail_deliver_inbound(v_box, 'inbox', 'vault', v_s, v_s, v_nc, v_nc, 'k-selftest', v_w, v_aad, decode(repeat('12', 32), 'hex'), null, null, null, 'x.test', 100, 'none', 'none', 'none', 'none', false, null, null); v_b := (v_r ->> 'message_id')::uuid;
    v_r := public.fmail_deliver_inbound(v_box, 'inbox', 'vault', v_s, v_s, v_nc, v_nc, 'k-selftest', v_w, v_aad, decode(repeat('13', 32), 'hex'), null, null, null, 'x.test', 100, 'none', 'none', 'none', 'none', false, null, null); v_c := (v_r ->> 'message_id')::uuid;
    -- 1 an unknown state is refused
    begin perform public.fmail_scan_set171(v_box, v_a, 'maybe'); v_ok := false; exception when sqlstate '22023' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'an unknown scan state is refused', 'ok', v_ok);
    -- 2 clean stays in the inbox and writes no quarantine row
    v_r := public.fmail_scan_set171(v_box, v_a, 'clean');
    res := res || jsonb_build_object('name', 'clean stays in the inbox, no quarantine ledger row', 'ok', (v_r ->> 'quarantined')::boolean is false
      and (select f.kind from public.fmail_messages m join public.fmail_folders f on f.id = m.folder_id where m.id = v_a) = 'inbox'
      and not exists (select 1 from public.fmail_ledger where action = 'quarantine_in' and target = v_a::text));
    -- 3 opaque: moved to quarantine + ONE ledger row
    v_r := public.fmail_scan_set171(v_box, v_b, 'opaque');
    res := res || jsonb_build_object('name', 'opaque goes to quarantine and is ledgered once', 'ok', (v_r ->> 'quarantined')::boolean and (v_r ->> 'ledger_seq') is not null
      and (select f.kind from public.fmail_messages m join public.fmail_folders f on f.id = m.folder_id where m.id = v_b) = 'quarantine'
      and (select scan_state from public.fmail_messages where id = v_b) = 'opaque'
      and (select count(*) from public.fmail_ledger where action = 'quarantine_in' and target = v_b::text) = 1);
    -- 4 the verdict can only be set once
    begin perform public.fmail_scan_set171(v_box, v_b, 'clean'); v_ok := false; exception when sqlstate '23514' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a recorded verdict cannot be changed (opaque -> clean refused)', 'ok', v_ok);
    -- 5 infected / error / skipped all quarantine
    v_r := public.fmail_scan_set171(v_box, v_c, 'skipped');
    res := res || jsonb_build_object('name', 'not scanned (skipped) is quarantined, never inboxed', 'ok', (v_r ->> 'quarantined')::boolean and (select f.kind from public.fmail_messages m join public.fmail_folders f on f.id = m.folder_id where m.id = v_c) = 'quarantine');
    -- 6 the Bridge lane tells the truth: +2 (opaque + skipped)
    select (l ->> 'count')::bigint into v_n1 from jsonb_array_elements(public.fmail_bridge_feed(24) -> 'lanes') l where l ->> 'lane' = 'mail-quarantine';
    res := res || jsonb_build_object('name', 'the Bridge Quarantined lane counted both', 'ok', v_n1 = v_n0 + 2);
    -- 7 backfill: a quarantined mail without a ledger row (made by hand) is found once, then never again
    v_r := public.fmail_deliver_inbound(v_box, 'quarantine', 'vault', v_s, v_s, v_nc, v_nc, 'k-selftest', v_w, v_aad, decode(repeat('14', 32), 'hex'), null, null, null, 'x.test', 100, 'none', 'none', 'none', 'none', false, null, null);
    res := res || jsonb_build_object('name', 'backfill finds the unledgered quarantined mail', 'ok', public.fmail_quarantine_backfill171() >= 1);
    res := res || jsonb_build_object('name', 'backfill is idempotent (second run finds nothing)', 'ok', public.fmail_quarantine_backfill171() = 0 and (public.fmail_posture171() ->> 'quarantined_without_ledger')::int = 0);
    res := res || jsonb_build_object('name', 'ledger chain still verifies', 'ok', public.fmail_ledger_verify(1) >= 1);
    raise exception 'E171_SELFTEST_ROLLBACK %', res::text;
  exception when others then
    if sqlerrm like 'E171_SELFTEST_ROLLBACK %' then res := substr(sqlerrm, length('E171_SELFTEST_ROLLBACK ') + 1)::jsonb;
    else return jsonb_build_object('ok', false, 'error', sqlerrm, 'state', sqlstate, 'so_far', res); end if;
  end;
  return jsonb_build_object('ok', not exists (select 1 from jsonb_array_elements(res) e where (e ->> 'ok')::boolean is not true), 'passed', (select count(*) from jsonb_array_elements(res) e where (e ->> 'ok')::boolean is true),
                            'failed', (select count(*) from jsonb_array_elements(res) e where (e ->> 'ok')::boolean is not true), 'checks', res);
end $$;
revoke all on function public.fmail_selftest171() from public, anon, authenticated;
grant execute on function public.fmail_selftest171() to service_role;
