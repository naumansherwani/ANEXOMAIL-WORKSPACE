

-- E137 — G5c REPAIR R2 (data step): re-queue the freetsa jobs that died of "unsupported ECDSA curve/hash pair" (freetsa signs with P-384 + SHA-512; ring could not verify it).
-- The R2 binary (RustCrypto p384 verify, kernel 0.10.0) is on the server since his founder-install (3 Nov ~06:55), so a retry now meets a verifier. Same door as E134/E136, cause named, enabled providers only,
-- one event per job + one audit row; idempotent (nothing matching = nothing written). The retry hits the REAL freetsa service: success = the R2 proof, failure text is stored as plain text, never swallowed.
-- Actor: the founder with the newest audited action, else the only founder (the E136 rule).
do $$ declare v_uid uuid; v_n integer; j jsonb;
begin
  if to_regprocedure('public.founder_anchor_requeue(uuid,text,text,text)') is null then raise exception 'E137: run E134 first'; end if;
  select a.actor into v_uid from public.founder_audit a join public.founder_accounts f on f.user_id = a.actor order by a.seq desc limit 1;
  if v_uid is null then
    select count(*) into v_n from public.founder_accounts;
    if v_n = 1 then select user_id into v_uid from public.founder_accounts; end if;
  end if;
  if v_uid is null then raise notice 'E137 SKIP: no founder account has an audit entry and there is not exactly one founder account - nothing requeued'; return; end if;
  j := public.founder_anchor_requeue(v_uid, null, 'unsupported ECDSA curve/hash pair', 'R2 repair: re-queue the freetsa jobs that died before P-384/SHA-512 could be verified');
  raise notice 'E137 requeued: %', j;
end $$;

-- RUNBOOK: bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh)   (bare = AUTO runs E137, then CHECK_E137). Needs E134 + the R2 founder-install. No Rust change.
