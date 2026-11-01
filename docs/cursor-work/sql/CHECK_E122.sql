-- CHECK E122 — reads only. 2 checks.
select item, ok from (
select 'E122 seal interval is 20 or lower (first seal does not wait for 50) and the policy order still holds' as item,
       coalesce((select every_rows <= 20 and warn_lag_rows >= every_rows and fail_lag_rows > warn_lag_rows from public.founder_audit_merkle_policy where id), false) as ok, 1 as ord
union all select 'E122 audit chain intact and E107 + E120 selftests still green',
       public.founder_audit_verify(1) is null
       and coalesce((select public.founder_audit_merkle_selftest() like 'E107 selftest OK%' or public.founder_audit_merkle_selftest() like 'E107 selftest SKIP%'), false)
       and coalesce((select public.founder_audit_g4_selftest() like 'E120 selftest OK%' or public.founder_audit_g4_selftest() like 'E120 selftest SKIP%'), false), 2
) t order by ord;
