
-- E179 - FIX (found on his real server 16 Nov 05:50 by fmail-gate-probe.sh): the first real send failed with "the DKIM gate did not answer".
-- Cause: fmail_dkim_send_gate175 was declared STABLE, and PostgREST runs a STABLE function in a READ ONLY transaction; the health report it calls may write
-- (e.g. the per-mailbox default policy row), so the call died with 25006 "cannot execute INSERT in a read-only transaction". psql (read-write) never showed it.
-- Fix: the gate is VOLATILE (same body, same answer, same grants). Re-run safe. Needs E175.
create or replace function public.fmail_dkim_send_gate175(p_mailbox uuid) returns jsonb
language sql volatile security definer set search_path = pg_catalog, public as $$
  select jsonb_build_object('ok', (h ->> 'send_ready')::boolean, 'reasons', h -> 'blockers') from (select public.fmail_dkim_health175(p_mailbox) as h) x
$$;
revoke all on function public.fmail_dkim_send_gate175(uuid) from public, anon, authenticated;
grant execute on function public.fmail_dkim_send_gate175(uuid) to service_role;
