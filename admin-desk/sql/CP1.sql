-- SCHEMA-FIRST: read before writing: sql/phase21_billing_platform.sql (workspace_subscriptions: org_id, plan, state), sql/phase60_org_identity_repair.sql (org_members: org_id, status), the awam public.orgs table (id only).
-- ADVANCE-RESEARCH: [D5a-3b] a Desk-side lookup must be ONE closed, read-only SECURITY DEFINER door with a fixed search_path, no table right for its role, and answers that say null when the database does not hold a fact (Zendesk / Salesforce account views read through a narrow API, never the tables).
-- CHECK-FILE: docs/claude/admin-desk/sql/checks/CP1-check.sql
-- ANEXOMAIL CONTROL PLANE CP1 (22 Nov 2026, D5a-3b): the ONE read-only door the Control Plane responder uses on the awam database.
-- Role cp_lookup has EXECUTE on cp.lookup(text) and NOTHING else: no table right, no other schema. The function reads only orgs.id,
-- workspace_subscriptions(org_id, plan, state) and org_members(org_id, status). It never reads an email, a name or any money column.
-- Honest: a value the database does not hold is JSON null, never a guess. Unknown company = null result (the responder answers refused).
create schema if not exists cp;
do $$ begin if not exists (select 1 from pg_roles where rolname = 'cp_lookup') then create role cp_lookup nologin; end if; end $$;
create or replace function cp.lookup(p_company text) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, pg_temp as $f$
declare v_org uuid; v_plan text; v_state text; v_seats int; v_pkg text; v_svc text;
begin
  if p_company is null or p_company !~ '^[0-9a-fA-F-]{36}$' then return null; end if;
  select o.id into v_org from public.orgs o where o.id = p_company::uuid;
  if v_org is null then return null; end if;
  select s.plan::text, s.state::text into v_plan, v_state
    from public.workspace_subscriptions s where s.org_id = v_org order by s.updated_at desc nulls last limit 1;
  select count(*)::int into v_seats from public.org_members m where m.org_id = v_org and coalesce(m.status::text, 'active') = 'active';
  v_pkg := case when v_plan in ('basic','pro','business','business_pro') then v_plan else null end;
  v_svc := case when v_state is null then 'not_active_yet'
                when v_state in ('active','trialing') then 'active'
                when v_state = 'past_due' then 'grace_period'
                else null end;
  return jsonb_build_object('package_id', v_pkg, 'service_state', v_svc, 'usage_seats', v_seats,
    'data_freshness', to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'));
end $f$;
revoke all on schema cp from public; revoke all on function cp.lookup(text) from public;
grant usage on schema cp to cp_lookup; grant execute on function cp.lookup(text) to cp_lookup;

-- selftest (added 24 Nov 2026 for the SQL world-class law): nothing is kept, it raises a custom SQLSTATE and catches it
do $st$ begin
  begin
    if cp.lookup(null) is not null or cp.lookup('not-a-uuid') is not null or cp.lookup('00000000-0000-0000-0000-000000000000') is not null then raise exception 'CP1 selftest: garbage or unknown company must give null'; end if;
    if has_function_privilege('public', 'cp.lookup(text)', 'execute') or not has_function_privilege('cp_lookup', 'cp.lookup(text)', 'execute') then raise exception 'CP1 selftest: execute rights are wrong'; end if;
    raise exception 'CP1 selftest done' using errcode = 'AC001';
  exception when sqlstate 'AC001' then null;
  end;
  raise notice 'CP1 selftest: ALL RULES PASSED (nothing kept)';
end $st$;
