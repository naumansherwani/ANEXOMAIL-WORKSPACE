
-- E177 - NORMAL SEND (his word 16 Nov 2026 04:55): "send par itna fingerprint aur codes ki strictness kaam kero, normal routine wala system, hold 30 seconds theek hai".
-- The per-send passkey touch is switched OFF through the ledgered policy door (fmail_policy_set, old and new value anchored). The 30 second undo hold stays (undo_seconds = 30).
-- Key creation and policy ratchets (DKIM) keep their touch; hard delete and export keep theirs. The E167 selftest tests the touch rule, so it is patched to switch the rule ON inside its own rolled-back subtransaction first.
-- Needs E167, E170. Re-run safe.

do $p$
declare d text;
begin
  select pg_get_functiondef('public.fmail_selftest167()'::regprocedure) into d;
  if d not like '%selftest: the touch rule is tested as ON%' then
    d := replace(d, 'begin perform public.fmail_outbox_enqueue(v_actor, v_box, v_msg_out, array[b32], null, null);',
      'perform public.fmail_policy_set(v_actor, ''require_touch_send'', ''true'', ''selftest: the touch rule is tested as ON''); begin perform public.fmail_outbox_enqueue(v_actor, v_box, v_msg_out, array[b32], null, null);');
    if d not like '%selftest: the touch rule is tested as ON%' then raise exception 'E177: the E167 selftest text was not found, nothing changed'; end if;
    execute d;
  end if;
end $p$;

do $s$
declare v_actor uuid;
begin
  if (select require_touch_send from public.fmail_policy where id = 1) then
    select user_id into v_actor from public.founder_accounts limit 1;
    if v_actor is null then raise exception 'E177: no founder account'; end if;
    perform public.fmail_policy_set(v_actor, 'require_touch_send', 'false', 'founder 16 Nov 2026 04:55: normal send, the 30 second undo hold stays; key creation and policy ratchets keep their touch');
  end if;
end $s$;

-- Exact-time wake for the sender (his word 16 Nov 04:57: advance technology, advance code): seconds until the earliest queued or scheduled mail is due, null when nothing waits.
-- The Rust worker sleeps exactly that long (and wakes at once when a mail is queued), so a mail leaves the moment its 30 s hold ends instead of on a polling tick.
create or replace function public.fmail_outbox_next_due177() returns double precision language sql stable security definer set search_path = pg_catalog, public as $f$
  select extract(epoch from (min(not_before) - now()))::double precision from public.fmail_outbox where state in ('queued', 'scheduled')
$f$;
revoke all on function public.fmail_outbox_next_due177() from public, anon, authenticated;
grant execute on function public.fmail_outbox_next_due177() to service_role;

create or replace function public.fmail_selftest177() returns text language plpgsql security definer set search_path = pg_catalog, public as $$
declare ok int := 0; bad int := 0; r jsonb;
begin
  if (select require_touch_send from public.fmail_policy where id = 1) = false then ok := ok + 1; else bad := bad + 1; end if;
  if (select undo_seconds from public.fmail_policy where id = 1) = 30 then ok := ok + 1; else bad := bad + 1; end if;
  if exists (select 1 from public.fmail_ledger where action = 'policy_change' and target = 'require_touch_send') then ok := ok + 1; else bad := bad + 1; end if;
  r := public.fmail_selftest167();
  if coalesce((r ->> 'ok')::boolean, false) then ok := ok + 1; else bad := bad + 1; end if;
  if has_function_privilege('service_role', 'public.fmail_outbox_next_due177()', 'execute') and not has_function_privilege('anon', 'public.fmail_outbox_next_due177()', 'execute') then ok := ok + 1; else bad := bad + 1; end if;
  return 'E177 selftest: ' || ok || ' ok, ' || bad || ' failed';
end $$;
revoke all on function public.fmail_selftest177() from public, anon, authenticated;
grant execute on function public.fmail_selftest177() to service_role;

select public.fmail_selftest177() as e177_selftest;
