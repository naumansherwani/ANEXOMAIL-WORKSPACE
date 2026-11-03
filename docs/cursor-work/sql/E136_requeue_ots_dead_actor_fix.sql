
-- E136 — G5c REPAIR R1 (part 4): E135 skipped itself on his server. Evidence (3 Nov 06:57, my Chrome look): the audit ledger is still at entry 39 after E135 ran, and CHECK_E135 still found dead jobs of the 32-byte bug,
-- so E135 re-queued nothing: it insisted on EXACTLY ONE founder account ("an unambiguous actor") and the server has more than one. A skip is safe but it is not a repair.
-- Rule here: the actor of the audit row is the founder who performed the most recent audited action (the one who is operating the system now); if none of them is a founder account, the only founder account;
-- otherwise it still skips, loudly. Same door, same cause string, same guards as E135 (E134 does the work). Idempotent: nothing matching = nothing written. E135 is not edited (a later file replaces the step).
do $$ declare v_uid uuid; v_n integer; j jsonb;
begin
  if to_regprocedure('public.founder_anchor_requeue(uuid,text,text,text)') is null then raise exception 'E136: run E134 first'; end if;
  select a.actor into v_uid from public.founder_audit a join public.founder_accounts f on f.user_id = a.actor order by a.seq desc limit 1;
  if v_uid is null then
    select count(*) into v_n from public.founder_accounts;
    if v_n = 1 then select user_id into v_uid from public.founder_accounts; end if;
  end if;
  if v_uid is null then raise notice 'E136 SKIP: no founder account has an audit entry and there is not exactly one founder account - nothing requeued'; return; end if;
  j := public.founder_anchor_requeue(v_uid, null, 'is not 32 bytes', 'R1 repair: re-queue the OpenTimestamps jobs the 32-byte bug killed (E133)');
  raise notice 'E136 requeued: %', j;
end $$;

-- RUNBOOK: bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh)   (bare = AUTO runs E136, then CHECK_E136). No Rust change.
