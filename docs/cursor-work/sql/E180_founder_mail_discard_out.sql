
-- E180 - DELETE for outgoing mail (his 16 Nov 05:55 order: "outbox msg delete kyon nahi hote, fix kero").
-- CAUSE: the Delete button called fmail_move, which by design (E167) moves only direction='in' mail that is not a draft, so for an Outbox or Sent mail it matched 0 rows,
--   returned ok and did nothing (no error, no change).
-- FIX: fmail_discard180(actor, mailbox, message) = the one ledgered door for deleting OUTGOING mail:
--   * a mail still waiting or failed in the Outbox (queued, scheduled, failed): its outbox row is cancelled FIRST (so the sender can never retry it), then it goes to Trash;
--   * a mail already sent (Sent folder): it goes to Trash (soft delete, nothing is sent again);
--   * a mail being sent right now (sending) is refused with a plain message; hard delete stays behind the passkey touch (fmail_delete_hard, unchanged).
-- Every discard writes one hash-chained ledger line (send_cancel / delete_soft). Re-run safe. Needs E167, E170.
create or replace function public.fmail_discard180(p_actor uuid, p_mailbox uuid, p_message uuid)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare m public.fmail_messages; o public.fmail_outbox; v_trash uuid; v_led jsonb; v_kind text; v_how text;
begin
  select * into m from public.fmail_messages where id = p_message and mailbox_id = p_mailbox for update;
  if m.id is null then raise exception 'E180: unknown message' using errcode = '23503'; end if;
  if m.direction <> 'out' then raise exception 'E180: this door is for outgoing mail; incoming mail moves with Delete as before' using errcode = '22023'; end if;
  select kind into v_kind from public.fmail_folders where id = m.folder_id;
  select id into v_trash from public.fmail_folders where mailbox_id = p_mailbox and kind = 'trash';
  if v_kind = 'trash' then return jsonb_build_object('state', 'already_in_trash'); end if;
  select * into o from public.fmail_outbox where message_id = p_message and mailbox_id = p_mailbox order by created_at desc limit 1 for update;
  if o.id is not null and o.state = 'sending' then raise exception 'E180: this mail is being sent right now; wait a moment and try again' using errcode = '55006'; end if;
  if o.id is not null and o.state in ('queued', 'scheduled', 'failed') then
    update public.fmail_outbox set state = 'cancelled' where id = o.id;
    v_how := 'cancelled';
    v_led := public.fmail_ledger_append(p_actor, p_mailbox, 'send_cancel', p_message::text, 'outgoing mail discarded by the founder (' || o.state || ' -> cancelled, then Trash)', '{}'::jsonb, false);
  else
    v_how := 'trashed';
    v_led := public.fmail_ledger_append(p_actor, p_mailbox, 'delete_soft', p_message::text, 'outgoing mail moved to Trash by the founder', '{}'::jsonb, false);
  end if;
  update public.fmail_messages set folder_id = v_trash, is_draft = false where id = p_message;
  return jsonb_build_object('state', v_how, 'folder', 'trash', 'ledger_seq', v_led -> 'seq');
end $$;
revoke all on function public.fmail_discard180(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.fmail_discard180(uuid, uuid, uuid) to service_role;

-- the E179 door audit must still be clean after adding a writing door (this one is VOLATILE, as every door that writes must be)
create or replace function public.fmail_selftest180() returns text language plpgsql security definer set search_path = pg_catalog, public as $$
declare ok int := 0; bad int := 0;
begin
  if (select provolatile from pg_proc where oid = 'public.fmail_discard180(uuid,uuid,uuid)'::regprocedure) = 'v' then ok := ok + 1; else bad := bad + 1; end if;
  if not exists (select 1 from public.fmail_door_audit179()) then ok := ok + 1; else bad := bad + 1; end if;
  if has_function_privilege('service_role', 'public.fmail_discard180(uuid,uuid,uuid)', 'execute') and not has_function_privilege('anon', 'public.fmail_discard180(uuid,uuid,uuid)', 'execute') and not has_function_privilege('authenticated', 'public.fmail_discard180(uuid,uuid,uuid)', 'execute') then ok := ok + 1; else bad := bad + 1; end if;
  if public.fmail_outbox_transition_ok_167('failed', 'cancelled') and public.fmail_outbox_transition_ok_167('queued', 'cancelled') and not public.fmail_outbox_transition_ok_167('sent', 'cancelled') and not public.fmail_outbox_transition_ok_167('sending', 'cancelled') then ok := ok + 1; else bad := bad + 1; end if;
  return 'E180 selftest: ' || ok || ' ok, ' || bad || ' failed';
end $$;
revoke all on function public.fmail_selftest180() from public, anon, authenticated;
grant execute on function public.fmail_selftest180() to service_role;

select public.fmail_selftest180() as e180_selftest;
