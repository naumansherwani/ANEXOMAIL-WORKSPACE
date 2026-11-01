-- E122 — G5a live proof: seal every 20 new entries instead of 50 (founder 2 Nov 04:36: "G5a bhi fix kero").
-- Why: the ledger has ~28 entries and the first seal waited for 50, so the browser had nothing to pin and the
-- RFC 9162 consistency check (G5a) could never run live. A seal is only a checkpoint (append-only, no data change).
-- Safe: uses the existing audited door founder_audit_merkle_policy_set (E107) which also writes an audit row. Idempotent.
-- warn/fail lag stay 200/2000 (unchanged). Min allowed by the table is 5.
do $$
declare v_actor uuid; v_pol public.founder_audit_merkle_policy%rowtype;
begin
  select * into v_pol from public.founder_audit_merkle_policy where id;
  if not found then raise notice 'E122 SKIP: no merkle policy row (E107 not applied)'; return; end if;
  if v_pol.every_rows <= 20 then raise notice 'E122: already %, nothing to do', v_pol.every_rows; return; end if;
  select user_id into v_actor from public.founder_accounts order by 1 limit 1;
  if v_actor is null then raise notice 'E122 SKIP: no founder account yet'; return; end if;
  perform public.founder_audit_merkle_policy_set(v_actor, 20, v_pol.warn_lag_rows, v_pol.fail_lag_rows,
          'E122: seal every 20 entries so the browser consistency proof (G5a) can run live');
  raise notice 'E122: seal interval % -> 20', v_pol.every_rows;
end $$;
-- RUNBOOK: bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E122_founder_seal_interval CHECK_E122  (after fetch)
-- Undo: select public.founder_audit_merkle_policy_set(<founder uuid>, 50, 200, 2000, 'undo E122');
