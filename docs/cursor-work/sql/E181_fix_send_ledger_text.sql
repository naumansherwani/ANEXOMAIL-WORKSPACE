
-- E181 - AUDIT FIX (his 16 Nov 06:21 order: audit the 30 s hold / send code, auto fix what is wrong).
-- FINDING: fmail_outbox_enqueue always wrote the ledger line "send queued by the founder (passkey touched)", even when the normal-send policy (E177) means NO touch happened.
--   The ledger is evidence, so it must never claim a touch that did not happen.
-- FIX: the text now says "(passkey touched)" only when a touch hash came with the send, else "(normal send, no touch needed by policy)". The 30 s undo hold, limits and state machine are untouched.
-- Audited and found correct: undo window = now + policy undo_seconds (30), a scheduled time must be after it, the claim takes only rows with not_before <= now(), the state trigger refuses
-- undo after undo_until and every illegal move, the exact-time sender (E177) sleeps until the next due row. Re-run safe. Needs E167, E177.
do $p$
declare d text;
begin
  select pg_get_functiondef('public.fmail_outbox_enqueue(uuid,uuid,uuid,bytea[],timestamptz,text)'::regprocedure) into d;
  if d not like '%normal send, no touch needed by policy%' then
    d := replace(d, '''send queued by the founder (passkey touched)''', 'case when p_touch_hash is null then ''send queued by the founder (normal send, no touch needed by policy)'' else ''send queued by the founder (passkey touched)'' end');
    if d not like '%normal send, no touch needed by policy%' then raise exception 'E181: the enqueue text was not found, nothing changed'; end if;
    execute d;
  end if;
end $p$;

create or replace function public.fmail_selftest181() returns text language plpgsql security definer set search_path = pg_catalog, public as $$
declare ok int := 0; bad int := 0; d text;
begin
  select pg_get_functiondef('public.fmail_outbox_enqueue(uuid,uuid,uuid,bytea[],timestamptz,text)'::regprocedure) into d;
  if d like '%normal send, no touch needed by policy%' and d like '%passkey touched%' then ok := ok + 1; else bad := bad + 1; end if;
  if (select undo_seconds from public.fmail_policy where id = 1) = 30 then ok := ok + 1; else bad := bad + 1; end if;
  if d like '%v_nb := v_undo%' and d like '%a scheduled time must be after the undo window%' then ok := ok + 1; else bad := bad + 1; end if;
  if not exists (select 1 from public.fmail_door_audit179()) then ok := ok + 1; else bad := bad + 1; end if;
  return 'E181 selftest: ' || ok || ' ok, ' || bad || ' failed';
end $$;
revoke all on function public.fmail_selftest181() from public, anon, authenticated;
grant execute on function public.fmail_selftest181() to service_role;
select public.fmail_selftest181() as e181_selftest;
