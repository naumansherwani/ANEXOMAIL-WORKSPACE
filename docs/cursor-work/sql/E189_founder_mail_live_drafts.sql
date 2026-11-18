
-- E189 - LIVE DRAFTS (QLIVE-c, 18 Nov 2026 07:0x PKT, his order: "draft ka asal edit doosre device par announce nahi hota, fix kero").
-- The honest gap in E187: a draft is not a message row. It lives in fmail_drafts + fmail_draft_versions (E167/E170, append-only versions), so saving a new
-- version of a draft on one device wrote NO line to the change log and another open device never heard about it. This file closes it.
-- WHAT IT DOES (all through the E187 internal door, so the sequence stays gapless and the hash chain stays valid):
--   * AFTER INSERT on fmail_draft_versions  -> one 'draft' line (a new version was saved; the draft id rides in the message_id slot: ids only, never text)
--   * AFTER UPDATE OF discarded_at on fmail_drafts -> one 'draft' line (a draft was discarded or restored on another device)
--   Nothing else changes: no new table, no new kind (the E187 closed list already has 'draft'), no new Rust or browser code (the browser already refreshes on every kind).
-- PRIVACY: ids and the kind only. The sealed draft text never leaves its row; the other device fetches it through the sealed draft doors.
-- Search / research (18 Nov 2026): JMAP (RFC 8620) treats drafts as ordinary Emails that carry a $draft keyword, so every draft edit is a state change; IMAP NOTIFY (RFC 5465)
--   reports MessageNew / FlagChange for the Drafts mailbox too. Same rule here: a draft edit is a change, announced as a prompt, the content is fetched by the cursor.
-- Run once through sql-run.sh, after E187 (E188 is kept for QC1c). Safe to run again (idempotent).

do $$
begin
  if to_regprocedure('public.fmail_change_' || 'note187(uuid,text,uuid,uuid,uuid)') is null then raise exception 'E189: E187 is missing (run E187 first)'; end if;
  if to_regclass('public.fmail_drafts') is null or to_regclass('public.fmail_draft_versions') is null then raise exception 'E189: E167 draft tables are missing'; end if;
end $$;

create or replace function public.fmail_change_draftv189() returns trigger language plpgsql set search_path = pg_catalog, public as $$
declare m uuid;
begin
  select mailbox_id into m from public.fmail_drafts where id = new.draft_id;
  if m is not null then perform public.fmail_change_note187(m, 'draft', null, new.draft_id, null); end if;
  return null;
end $$;
drop trigger if exists fmail_change_draftv on public.fmail_draft_versions;
create trigger fmail_change_draftv after insert on public.fmail_draft_versions for each row execute function public.fmail_change_draftv189();

create or replace function public.fmail_change_draftd189() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if new.discarded_at is distinct from old.discarded_at then perform public.fmail_change_note187(new.mailbox_id, 'draft', null, new.id, null); end if;
  return null;
end $$;
drop trigger if exists fmail_change_draftd on public.fmail_drafts;
create trigger fmail_change_draftd after update of discarded_at on public.fmail_drafts for each row execute function public.fmail_change_draftd189();

revoke all on function public.fmail_change_draftv189(), public.fmail_change_draftd189() from public, anon, authenticated;

-- selftest: rolls itself back ---------------------------------------------------------------------------------------------------------------------------
create or replace function public.fmail_selftest189() returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare
  res jsonb := '[]'::jsonb; v_uid uuid; v_box uuid; v_d uuid; v_r jsonb; v_h bigint;
  v_seal bytea := decode(repeat('ab', 40), 'hex'); v_nonce bytea := decode(repeat('01', 12), 'hex'); v_wrap bytea := decode(repeat('02', 64), 'hex');
begin
  select user_id into v_uid from public.founder_accounts limit 1;
  if v_uid is null then return jsonb_build_object('ok', false, 'error', 'no founder account to test with'); end if;
  begin
    insert into public.fmail_mailboxes (owner, address, display_name, seal_mode, recipient_key_id, vault_key_id) values (v_uid, 'selftest189@anexomail.com', 'T', 'vault', null, 'vault-selftest') returning id into v_box;
    insert into public.fmail_drafts (mailbox_id) values (v_box) returning id into v_d;
    v_r := public.fmail_change_since187(v_uid, v_box, 0, 50);
    res := res || jsonb_build_object('name', 'creating the (empty) draft row alone writes nothing', 'ok', (v_r ->> 'head') = '0');
    insert into public.fmail_draft_versions (draft_id, version, sealed, nonce, key_id, key_wrap) values (v_d, 1, v_seal, v_nonce, 'k-selftest', v_wrap);
    v_r := public.fmail_change_since187(v_uid, v_box, 0, 50);
    res := res || jsonb_build_object('name', 'saving version 1 writes ONE draft line carrying the draft id (no folder, no thread)',
        'ok', (v_r ->> 'head') = '1' and v_r #>> '{changes,0,kind}' = 'draft' and v_r #>> '{changes,0,message}' = v_d::text and v_r #>> '{changes,0,folder}' is null);
    insert into public.fmail_draft_versions (draft_id, version, sealed, nonce, key_id, key_wrap) values (v_d, 2, v_seal, v_nonce, 'k-selftest', v_wrap);
    v_r := public.fmail_change_since187(v_uid, v_box, 1, 50);
    res := res || jsonb_build_object('name', 'an edit (version 2) writes the next draft line, number 2', 'ok', (v_r ->> 'head') = '2' and v_r #>> '{changes,0,kind}' = 'draft' and (v_r #>> '{changes,0,seq}') = '2');
    update public.fmail_drafts set discarded_at = now() where id = v_d;
    res := res || jsonb_build_object('name', 'discarding the draft writes a draft line', 'ok', (public.fmail_change_since187(v_uid, v_box, 2, 50) ->> 'head') = '3');
    update public.fmail_drafts set updated_at = now() where id = v_d;
    res := res || jsonb_build_object('name', 'touching other draft columns writes nothing', 'ok', (public.fmail_change_since187(v_uid, v_box, 2, 50) ->> 'head') = '3');
    res := res || jsonb_build_object('name', 'the hash chain still verifies after draft lines', 'ok', (public.fmail_change_verify187(v_box) ->> 'ok')::boolean);
    res := res || jsonb_build_object('name', 'the log still holds no text beyond the kind (no draft text can leak)',
        'ok', (select array_agg(attname::text order by attname) from pg_attribute where attrelid = 'public.fmail_change_log187'::regclass and attnum > 0 and not attisdropped and atttypid = 'text'::regtype) = array['kind']);
    raise exception 'E189_SELFTEST_ROLLBACK %', res::text;
  exception when others then
    if sqlerrm like 'E189_SELFTEST_ROLLBACK %' then res := substr(sqlerrm, length('E189_SELFTEST_ROLLBACK ') + 1)::jsonb;
    else return jsonb_build_object('ok', false, 'error', sqlerrm, 'state', sqlstate, 'so_far', res); end if;
  end;
  return jsonb_build_object('ok', not exists (select 1 from jsonb_array_elements(res) e where (e ->> 'ok')::boolean is not true), 'passed', (select count(*) from jsonb_array_elements(res) e where (e ->> 'ok')::boolean is true),
                            'failed', (select count(*) from jsonb_array_elements(res) e where (e ->> 'ok')::boolean is not true), 'checks', res);
end $$;
revoke all on function public.fmail_selftest189() from public, anon, authenticated;
grant execute on function public.fmail_selftest189() to service_role;

create or replace function public.fmail_posture189() returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public as $$
begin
  return jsonb_build_object(
    'draft_triggers', (select count(*) from pg_trigger where not tgisinternal and tgname in ('fmail_change_draftv', 'fmail_change_draftd')),
    'trigger_fns_closed', not exists (select 1 from pg_proc where proname in ('fmail_change_draftv189', 'fmail_change_draftd189') and (has_function_privilege('anon', oid, 'execute') or has_function_privilege('authenticated', oid, 'execute'))),
    'door_audit_clean', not exists (select 1 from public.fmail_door_audit179()));
end $$;
revoke all on function public.fmail_posture189() from public, anon, authenticated;
grant execute on function public.fmail_posture189() to service_role;
