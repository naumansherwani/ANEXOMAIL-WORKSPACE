
-- E179 - FIX + GUARD (found on his real server 16 Nov 05:50 by fmail-gate-probe.sh): the first real send failed with "the DKIM gate did not answer".
-- CAUSE: fmail_dkim_send_gate175 was declared STABLE. PostgREST runs a STABLE or IMMUTABLE function inside a READ ONLY transaction, and the health report it calls
--   may write (the per-mailbox default policy row), so the call died with 25006 "cannot execute INSERT in a read-only transaction". psql is read-write and never showed it.
-- 1) FIX: the gate is VOLATILE (same body, same answer, same grants).
-- 2) GUARD against the whole class of bug: fmail_door_audit179() lists every service_role door (fmail_* / dkim) that is declared STABLE or IMMUTABLE but writes,
--    either in its own body or by calling another door that writes (one level deep). It must return zero rows; CHECK_E179 and the selftest fail loudly if it does not.
-- 3) fmail_selftest179(): 5 checks, writes nothing. Re-run safe. Needs E175.
create or replace function public.fmail_dkim_send_gate175(p_mailbox uuid) returns jsonb
language sql volatile security definer set search_path = pg_catalog, public as $$
  select jsonb_build_object('ok', (h ->> 'send_ready')::boolean, 'reasons', h -> 'blockers') from (select public.fmail_dkim_health175(p_mailbox) as h) x
$$;
revoke all on function public.fmail_dkim_send_gate175(uuid) from public, anon, authenticated;
grant execute on function public.fmail_dkim_send_gate175(uuid) to service_role;

create or replace function public.fmail_door_audit179()
returns table (door text, volatility text, why text)
language sql stable security definer set search_path = pg_catalog, public as $$
  with d as (
    select p.oid, p.proname, p.provolatile as v, p.prosrc,
           (p.prosrc ~* '(^|[^a-z_])(insert[[:space:]]+into|update[[:space:]]+(only[[:space:]]+)?(public\.)?[a-z_]+[[:space:]]+set|delete[[:space:]]+from|truncate)([^a-z_]|$)'
            or p.prosrc ~* 'fmail_ledger_append') as writes
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace and p.prokind = 'f' and p.prolang in (select oid from pg_language where lanname in ('sql', 'plpgsql'))
       and (p.proname like 'fmail\_%' or p.proname like '%dkim%') and p.proname <> 'fmail_door_audit179'   -- the audit's own text names the write words
       and has_function_privilege('service_role', p.oid, 'execute'))
  select d.oid::regprocedure::text, case d.v when 's' then 'stable' else 'immutable' end,
         case when d.writes then 'writes in its own body' else 'calls ' || (select string_agg(w.proname, ', ' order by w.proname) from d w where w.writes and w.oid <> d.oid and d.prosrc ~ ('(^|[^a-z_0-9])' || w.proname || '[[:space:]]*\(')) end
    from d
   where d.v in ('s', 'i')
     and (d.writes or exists (select 1 from d w where w.writes and w.oid <> d.oid and d.prosrc ~ ('(^|[^a-z_0-9])' || w.proname || '[[:space:]]*\(')))
$$;
revoke all on function public.fmail_door_audit179() from public, anon, authenticated;
grant execute on function public.fmail_door_audit179() to service_role;

create or replace function public.fmail_selftest179() returns text language plpgsql security definer set search_path = pg_catalog, public as $$
declare ok int := 0; bad int := 0;
begin
  if (select provolatile from pg_proc where oid = 'public.fmail_dkim_send_gate175(uuid)'::regprocedure) = 'v' then ok := ok + 1; else bad := bad + 1; end if;
  if has_function_privilege('service_role', 'public.fmail_dkim_send_gate175(uuid)', 'execute') and not has_function_privilege('anon', 'public.fmail_dkim_send_gate175(uuid)', 'execute') then ok := ok + 1; else bad := bad + 1; end if;
  if not exists (select 1 from public.fmail_door_audit179()) then ok := ok + 1; else bad := bad + 1; end if;
  if coalesce((select bool_and((public.fmail_dkim_send_gate175(id) ->> 'ok') is not null) from public.fmail_mailboxes), true) then ok := ok + 1; else bad := bad + 1; end if;
  if has_function_privilege('service_role', 'public.fmail_door_audit179()', 'execute') and not has_function_privilege('anon', 'public.fmail_door_audit179()', 'execute') then ok := ok + 1; else bad := bad + 1; end if;
  return 'E179 selftest: ' || ok || ' ok, ' || bad || ' failed';
end $$;
revoke all on function public.fmail_selftest179() from public, anon, authenticated;
grant execute on function public.fmail_selftest179() to service_role;

select public.fmail_selftest179() as e179_selftest;
