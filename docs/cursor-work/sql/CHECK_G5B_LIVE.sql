-- CHECK G5b LIVE — reads only. Run ~2 minutes after founder-install: the Rust sealer must have registered the audit-log key and signed every seal. 4 checks.
select item, ok from (
select 'G5b the audit-log public key is registered and active (Rust sealer ran with the key file)' as item, (select count(*) = 1 from public.founder_audit_log_keys where status = 'active') as ok, 1 as ord
union all select 'G5b every seal has a signed note (unsigned = 0), signing-lag level is ok',
       coalesce((public.founder_audit_signed_pulse() ->> 'unsigned')::int = 0 and public.founder_audit_signed_pulse() ->> 'level' = 'ok' and (public.founder_audit_signed_pulse() ->> 'signed')::int >= 1, false), 2
union all select 'G5b the stored notes re-check clean against the live ledger (root re-derived from the audit rows)',
       coalesce((public.founder_audit_signed_verify(5) ->> 'ok')::boolean and (public.founder_audit_signed_verify(5) ->> 'checked')::int >= 1, false), 3
union all select 'G5b the published verifier key (vkey) and the newest note exist, and the note starts with the key name as origin',
       coalesce(public.founder_audit_log_vkey() is not null and public.founder_audit_signed_cp_latest_note() like (select name || E'\n' || '%' from public.founder_audit_log_keys where status = 'active'), false), 4
) t order by ord;
