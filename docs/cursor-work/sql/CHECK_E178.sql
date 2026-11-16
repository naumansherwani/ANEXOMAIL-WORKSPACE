
-- CHECK E178 - the E167 selftest passes on a database that already holds real queued mail; the E177 selftest is 5 of 5. Writes nothing.
select item, ok from (
select 'E178 E167 selftest ok (scoped claim check)' as item, (public.fmail_selftest167() ->> 'ok')::boolean as ok, 1 as n
union all select 'E178 E177 selftest 5 ok', public.fmail_selftest177() like 'E177 selftest: 5 ok, 0 failed', 2
union all select 'E178 selftest text is scoped to its own row', pg_get_functiondef('public.fmail_selftest167()'::regprocedure) like '%from public.fmail_outbox_claim(10) cl where cl = v_o%', 3
) t order by n;
