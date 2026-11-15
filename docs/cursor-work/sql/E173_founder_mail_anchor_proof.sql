
-- E173 (QUI-H4, 15 Nov 2026): MAIL LEDGER CHECKPOINTS inside the founder audit Merkle tree + the per-message anchor proof door for the browser kernel.
-- Finding that shaped this file: inbound mail rows ('inbound_ok', E169) are written WITHOUT a founder_audit anchor (p_anchor = false, one audit row per mail would
-- flood the audit tree), so a per-message "audit row" never existed. Design (Certificate-Transparency style): a CHECKPOINT row ('ledger_checkpoint') is appended to the
-- mail ledger with p_anchor = true, so founder_audit gets ONE row binding the ledger head (fmail_seq, fmail_hash) and that audit row sits in the E107 Merkle tree.
-- Proof for one mail = the ledger rows from the mail's row up to the first checkpoint (browser kernel re-hashes the slice) + that checkpoint's audit row + its RFC 6962
-- inclusion path (kernel re-hashes the audit row with the E102 formula and verifies the path). Read door is read-only; the writer is idempotent (no new row while
-- the head is already a checkpoint).
-- TECHNOLOGY: SQL (PostgreSQL 16, RLS forced on fmail_ledger and founder_audit, security-definer doors with a fixed search_path, service_role only, closed action list,
-- append-only hash chain, advisory-lock single writer through fmail_ledger_append, reuses E102 + E107).
-- Needs: E102 (founder_audit), E107 (founder_audit_merkle_proof), E167/E169/E170 (fmail_ledger + its action list).
do $$ begin
  if to_regprocedure('public.founder_audit_merkle_proof(bigint,bigint)') is null then raise exception 'E173: founder_audit_merkle_proof missing (run E107 first)'; end if;
  if to_regclass('public.fmail_ledger') is null then raise exception 'E173: fmail_ledger missing (run E167 first)'; end if;
end $$;

-- 1) the closed action list grows by one name (same pattern as E169 / E170)
do $$
declare c record; v_has boolean := false;
begin
  for c in select conname, pg_get_constraintdef(oid) as d from pg_constraint where conrelid = 'public.fmail_ledger'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%send_queue%' loop
    if c.d like '%ledger_checkpoint%' then v_has := true; else execute format('alter table public.fmail_ledger drop constraint %I', c.conname); end if;
  end loop;
  if not v_has then
    alter table public.fmail_ledger add constraint fmail_ledger_action_ck check (action in (
      'mailbox_add','mailbox_pause','mailbox_lock','mailbox_retire','policy_change','key_rotate','key_import',
      'send_queue','send_schedule','send_start','send_ok','send_fail','send_cancel','send_undo',
      'delete_soft','delete_hard','export_start','export_done','quarantine_in','quarantine_release','attachment_seal','attachment_scan',
      'inbound_reject','panic_lock','inbound_ok','unseal_gated','vault_set','mailbox_seed','dkim_install','dkim_revoke','ledger_checkpoint'));
  end if;
end $$;

-- 2) THE WRITER: one anchored checkpoint row for the current ledger head. Idempotent. p_mailbox = any mailbox of the founder (the ledger row needs one).
create or replace function public.fmail_ledger_checkpoint173(p_mailbox uuid)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_owner uuid; v_head public.fmail_ledger%rowtype; v_led jsonb;
begin
  select owner into v_owner from public.fmail_mailboxes where id = p_mailbox;
  if v_owner is null then raise exception 'E173: unknown mailbox' using errcode = '22023'; end if;
  select * into v_head from public.fmail_ledger order by seq desc limit 1;
  if not found then return jsonb_build_object('ok', true, 'empty', true); end if;
  if v_head.action = 'ledger_checkpoint' and v_head.audit_seq is not null then return jsonb_build_object('ok', true, 'already', true, 'seq', v_head.seq); end if;
  v_led := public.fmail_ledger_append(v_owner, p_mailbox, 'ledger_checkpoint', '', 'checkpoint of the mail ledger head, anchored in the audit Merkle tree', jsonb_build_object('head_seq', v_head.seq), true);
  return jsonb_build_object('ok', true, 'seq', (v_led ->> 'seq')::bigint);
end $$;
revoke all on function public.fmail_ledger_checkpoint173(uuid) from public, anon, authenticated;
grant execute on function public.fmail_ledger_checkpoint173(uuid) to service_role;

-- 3) THE DOOR: everything the kernel needs to prove ONE mail is inside the audit tree.
create or replace function public.fmail_anchor_proof173(p_mailbox uuid, p_message uuid)
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public, extensions as $$
declare r public.fmail_ledger%rowtype; c public.fmail_ledger%rowtype; a public.founder_audit%rowtype; v_p jsonb; v_rows jsonb;
begin
  if p_mailbox is null or p_message is null then raise exception 'E173: mailbox and message are required' using errcode = '22023'; end if;
  if not exists (select 1 from public.fmail_messages where id = p_message and mailbox_id = p_mailbox) then return jsonb_build_object('v', 'fmail-anchor-v1', 'found', false); end if;
  select * into r from public.fmail_ledger where action = 'inbound_ok' and target = p_message::text order by seq limit 1;
  if not found then return jsonb_build_object('v', 'fmail-anchor-v1', 'found', true, 'anchored', false, 'reason', 'this mail has no ledger row yet'); end if;
  select * into c from public.fmail_ledger where action = 'ledger_checkpoint' and audit_seq is not null and seq > r.seq order by seq limit 1;
  if not found then return jsonb_build_object('v', 'fmail-anchor-v1', 'found', true, 'anchored', false, 'reason', 'no checkpoint covers this mail yet'); end if;
  if c.seq - r.seq + 1 > 1000 then return jsonb_build_object('v', 'fmail-anchor-v1', 'found', true, 'anchored', false, 'reason', 'the checkpoint is more than 1000 ledger rows away'); end if;
  select * into a from public.founder_audit where seq = c.audit_seq;
  if not found then return jsonb_build_object('v', 'fmail-anchor-v1', 'found', true, 'anchored', false, 'reason', 'audit row missing'); end if;
  select jsonb_agg(jsonb_build_object('seq', t.seq::text, 'ts', t.ts_ms::text, 'actor', t.actor::text, 'action', t.action, 'target', t.target, 'reason', t.reason,
                                      'meta', t.meta::text, 'prev', t.prev_hash, 'hash', t.row_hash) order by t.seq) into v_rows
    from public.fmail_ledger t where t.seq between r.seq and c.seq;
  v_p := public.founder_audit_merkle_proof(a.seq, null);
  return jsonb_build_object(
    'v', 'fmail-anchor-v1', 'found', true, 'anchored', true, 'message', p_message::text,
    'chain', jsonb_build_object('v', 'fmail-ledger-v1', 'zero', repeat('0', 64), 'rows', v_rows, 'more', false),
    'audit', jsonb_build_object('seq', a.seq::text, 'ts', a.ts_ms::text, 'actor', a.actor::text, 'action', a.action, 'target', a.target, 'reason', a.reason, 'meta', a.meta::text,
                                'prev', a.prev_hash, 'hash', a.hash),
    'merkle', jsonb_build_object('upto', v_p -> 'upto', 'leaf', v_p ->> 'leaf', 'path', v_p -> 'path', 'root', v_p ->> 'root'));
end $$;
revoke all on function public.fmail_anchor_proof173(uuid, uuid) from public, anon, authenticated;
grant execute on function public.fmail_anchor_proof173(uuid, uuid) to service_role;
