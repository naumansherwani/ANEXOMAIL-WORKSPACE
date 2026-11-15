
-- CHECK E173 - mail ledger checkpoints in the audit Merkle tree + the per-message anchor proof door (QUI-H4). READ-ONLY, writes nothing. 6 checks.
with cp as (select l.seq, l.row_hash, l.audit_seq, a.meta as ameta, a.action as aaction, a.hash as ahash,
                   public._fa_hash(a.prev_hash, a.seq, a.actor, a.action, a.target, a.reason, a.ts_ms, a.meta) as again
            from public.fmail_ledger l left join public.founder_audit a on a.seq = l.audit_seq where l.action = 'ledger_checkpoint')
select item, ok from (
select 'E173 the closed ledger action list contains ledger_checkpoint' as item,
       exists (select 1 from pg_constraint where conrelid = 'public.fmail_ledger'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%ledger_checkpoint%') as ok, 1 as ord
union all select 'E173 every checkpoint row has an audit anchor (' || (select count(*) from cp) || ' checkpoints, ' || (select count(*) filter (where audit_seq is null or ahash is null) from cp) || ' without)',
       (select count(*) filter (where audit_seq is null or ahash is null) from cp) = 0, 2
union all select 'E173 every anchor row re-hashes with the E102 formula (' || (select count(*) filter (where again <> ahash) from cp) || ' bad)',
       (select count(*) filter (where again <> ahash) from cp) = 0, 3
union all select 'E173 every anchor row names exactly its checkpoint row (fmail_seq + fmail_hash, ' || (select count(*) filter (where (ameta ->> 'fmail_seq')::bigint is distinct from seq or ameta ->> 'fmail_hash' is distinct from row_hash) from cp) || ' wrong)',
       (select count(*) filter (where (ameta ->> 'fmail_seq')::bigint is distinct from seq or ameta ->> 'fmail_hash' is distinct from row_hash) from cp) = 0, 4
union all select 'E173 the door and the writer are service_role only; the door is read-only (stable); both are security definer with a fixed search_path',
       not has_function_privilege('anon', 'public.fmail_anchor_proof173(uuid,uuid)', 'execute') and not has_function_privilege('authenticated', 'public.fmail_anchor_proof173(uuid,uuid)', 'execute')
       and not has_function_privilege('anon', 'public.fmail_ledger_checkpoint173(uuid)', 'execute') and not has_function_privilege('authenticated', 'public.fmail_ledger_checkpoint173(uuid)', 'execute')
       and (select provolatile = 's' and prosecdef and proconfig is not null from pg_proc where oid = 'public.fmail_anchor_proof173(uuid,uuid)'::regprocedure)
       and (select prosecdef and proconfig is not null from pg_proc where oid = 'public.fmail_ledger_checkpoint173(uuid)'::regprocedure), 5
union all select 'E173 the mail ledger chain still verifies end to end', public.fmail_ledger_verify(1) >= 0, 6
) t order by ord;
