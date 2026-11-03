
-- E135 — G5c REPAIR R1 (part 3, the data step): re-queue the OpenTimestamps jobs that died of "calendar commitment is not 32 bytes" (founder 3 Nov 06:41 "R1 green kero ... ek bhi nahi bachay").
-- Needs E134 (the audited door) and the R1 fix already installed (E133 + anchors.rs: founder-install ran 3 Nov ~06:04). Idempotent: when nothing matches, it does nothing and writes no audit row.
-- Only the cause the founder's probe PROVED (all three calendars hand out a 44-byte pending commitment) is matched; nothing else is touched. The freetsa jobs ("unsupported ECDSA curve/hash pair") are NOT re-queued here:
-- they need the R2 binary first (a later file, after his founder-install). Honest effect: the stamps are requested NOW for the old seals' digests - an OpenTimestamps / TSA proof says "this digest existed by then",
-- so a late request still proves a real (later) upper bound; it never claims an earlier time than the service saw.
do $$ declare v_uid uuid; v_n integer; j jsonb;
begin
  if to_regprocedure('public.founder_anchor_requeue(uuid,text,text,text)') is null then raise exception 'E135: run E134 first'; end if;
  select count(*) into v_n from public.founder_accounts;
  if v_n <> 1 then raise notice 'E135 SKIP: needs exactly one founder account (found %), so the audit row has an unambiguous actor', v_n; return; end if;
  select user_id into v_uid from public.founder_accounts;
  j := public.founder_anchor_requeue(v_uid, null, 'is not 32 bytes', 'R1 repair: re-queue the OpenTimestamps jobs the 32-byte bug killed (E133)');
  raise notice 'E135 requeued: %', j;
end $$;

-- RUNBOOK: bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E135_requeue_ots_dead_by_32byte_bug CHECK_E135   (after E134). No Rust change.
