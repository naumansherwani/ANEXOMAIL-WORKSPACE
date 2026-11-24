-- ANEXOMAIL CONTROL PLANE CP4 (phase 1m-8, card B9b Customers: six packages, No plan yet, plan detail), 23 Nov 2026 PKT. FIX of BL-21: replaces the ONE read-only CENSUS door.
-- SCHEMA-FIRST: CP2 (cp.census, role cp_lookup, SECURITY DEFINER, counts only), CP1 (cp.lookup), the live awam schema snapshot docs/cursor-work/live-snapshot/sql/schema-public.sql (orgs, workspace_subscriptions, org_members, billing_intents, admin_storage_snapshots), AD06 (package limits).
-- ADVANCE-RESEARCH: [1m] 1m-8 Zendesk plan view (plan, seats bought vs used, allowances), Salesforce account view: SIX packages (basic, pro, business, business_pro, business_premium, business_max) + a real 'none' bucket (no subscription yet) beside 'unknown' (a plan name nobody knows), and a per-package breakdown (states, intervals, size bands, seats in use, storage at 90 percent) in the SAME single set-based pass, so a plan detail page needs no new door.
-- CHECK-FILE: docs/claude/admin-desk/sql/checks/CP4-check.sql
-- WHAT IT CHANGES (nothing else): cp.census gets 'business_premium', 'business_max', 'none' in packages (sum still = companies), and 'by_package' (8 keys, each counts only). A company with NO subscription is 'none' (was wrongly 'unknown' = "Plan not recognised"). p_limits may now name the six packages. Still counts only: no company id, e-mail, name, or a money value.
create schema if not exists cp;
do $$ begin if not exists (select 1 from pg_roles where rolname = 'cp_lookup') then create role cp_lookup nologin; end if; end $$;

create or replace function cp.census(p_limits jsonb default '{}'::jsonb) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, pg_temp as $f$
declare r jsonb; lim jsonb := coalesce(p_limits, '{}'::jsonb); k text; v text;
begin
  if jsonb_typeof(lim) <> 'object' then return null; end if;
  for k, v in select * from jsonb_each_text(lim) loop
    if k not in ('basic','pro','business','business_pro','business_premium','business_max') or v !~ '^[0-9]{1,6}$' then return null; end if;
  end loop;
  with
  sub as (select distinct on (s.org_id) s.org_id, s.user_id, s.plan, s.state, s.seats, s.seats_used, s."interval" as iv, s.renews_at, s.updated_at
            from public.workspace_subscriptions s where s.org_id is not null order by s.org_id, s.updated_at desc nulls last),
  mem as (select m.org_id, count(*)::int as n from public.org_members m where coalesce(m.status, 'active') = 'active' group by m.org_id),
  paid as (select distinct bi.user_id from public.billing_intents bi where bi.paid_at is not null and bi.resolved_at is null and bi.user_id is not null),
  snap as (select distinct on (a.user_id, a.mailbox) a.user_id, a.used_bytes, a.quota_bytes from public.admin_storage_snapshots a order by a.user_id, a.mailbox, a.day desc),
  stor as (select m.org_id, sum(sn.used_bytes)::numeric as used, sum(sn.quota_bytes)::numeric as quota
             from public.org_members m join snap sn on sn.user_id = m.user_id where coalesce(m.status, 'active') = 'active' group by m.org_id),
  co as (select o.id, o.created_at, su.state as raw_state, su.seats, su.seats_used, su.iv, su.renews_at, su.updated_at,
           case when su.plan in ('basic','pro','business','business_pro','business_premium','business_max') then su.plan when su.plan is null then 'none' else 'unknown' end as pkg,
           case when su.state is null or su.state = 'none' then 'not_active_yet' when su.state = 'active' then 'active' when su.state = 'trialing' then 'trialing'
                when su.state = 'past_due' then 'grace_period' when su.state = 'cancelled' then 'ended' else 'not_active_yet' end as svc,
           greatest(coalesce(su.seats_used, 0), coalesce(me.n, 0)) as size,
           (pd.user_id is not null) as paid_open, st.used, st.quota
         from public.orgs o left join sub su on su.org_id = o.id left join mem me on me.org_id = o.id left join paid pd on pd.user_id = su.user_id left join stor st on st.org_id = o.id),
  cnt as (select
      count(*) as companies,
      coalesce(sum(size), 0) as seats_in_use,
      count(*) filter (where pkg = 'basic') as p_basic, count(*) filter (where pkg = 'pro') as p_pro, count(*) filter (where pkg = 'business') as p_business,
      count(*) filter (where pkg = 'business_pro') as p_business_pro, count(*) filter (where pkg = 'business_premium') as p_business_premium, count(*) filter (where pkg = 'business_max') as p_business_max, count(*) filter (where pkg = 'none') as p_none, count(*) filter (where pkg = 'unknown') as p_unknown,
      count(*) filter (where svc = 'active') as s_active, count(*) filter (where svc = 'trialing') as s_trialing, count(*) filter (where svc = 'grace_period') as s_grace,
      count(*) filter (where svc = 'not_active_yet') as s_not_active, count(*) filter (where svc = 'ended') as s_ended,
      count(*) filter (where iv = 'month') as i_month, count(*) filter (where iv = 'year') as i_year, count(*) filter (where iv is null) as i_none,
      count(*) filter (where size <= 1) as b_1, count(*) filter (where size between 2 and 5) as b_2_5, count(*) filter (where size between 6 and 20) as b_6_20,
      count(*) filter (where size between 21 and 100) as b_21_100, count(*) filter (where size >= 101) as b_101,
      count(*) filter (where svc = 'ended' and updated_at > now() - interval '30 days') as ended_30d,
      count(*) filter (where svc in ('active','trialing') and renews_at >= now() and renews_at < now() + interval '7 days') as renewals_7d,
      count(*) filter (where svc = 'grace_period') as sig_grace,
      count(*) filter (where svc = 'not_active_yet') as sig_not_active,
      count(*) filter (where svc = 'ended') as sig_ended,
      count(*) filter (where paid_open and svc not in ('active','trialing')) as sig_paid_not_active,
      count(*) filter (where svc in ('active','trialing','grace_period') and seats > 0 and seats_used * 100 >= seats * 90 and seats_used * 100 < seats * 95) as sig_seats_90,
      count(*) filter (where svc in ('active','trialing','grace_period') and seats > 0 and seats_used * 100 >= seats * 95) as sig_seats_95,
      count(*) filter (where svc in ('active','trialing','grace_period') and quota > 0 and used * 100 >= quota * 90 and used * 100 < quota * 95) as sig_storage_90,
      count(*) filter (where svc in ('active','trialing','grace_period') and quota > 0 and used * 100 >= quota * 95) as sig_storage_95
    from co),
  bp as (select coalesce(jsonb_object_agg(p.k, jsonb_build_object(
            'companies', x.companies, 'seats_in_use', x.seats,
            'states', jsonb_build_object('active', x.s_active, 'trialing', x.s_trialing, 'grace_period', x.s_grace, 'not_active_yet', x.s_not_active, 'ended', x.s_ended),
            'intervals', jsonb_build_object('month', x.i_month, 'year', x.i_year, 'none', x.i_none),
            'size_bands', jsonb_build_object('1', x.b_1, '2-5', x.b_2_5, '6-20', x.b_6_20, '21-100', x.b_21_100, '101+', x.b_101),
            'storage_90', x.stor90)), '{}'::jsonb) as a
         from (values ('basic'),('pro'),('business'),('business_pro'),('business_premium'),('business_max'),('none'),('unknown')) p(k)
         cross join lateral (select count(*) as companies, coalesce(sum(c.size), 0) as seats,
            count(*) filter (where c.svc = 'active') as s_active, count(*) filter (where c.svc = 'trialing') as s_trialing, count(*) filter (where c.svc = 'grace_period') as s_grace,
            count(*) filter (where c.svc = 'not_active_yet') as s_not_active, count(*) filter (where c.svc = 'ended') as s_ended,
            count(*) filter (where c.iv = 'month') as i_month, count(*) filter (where c.iv = 'year') as i_year, count(*) filter (where c.iv is null) as i_none,
            count(*) filter (where c.size <= 1) as b_1, count(*) filter (where c.size between 2 and 5) as b_2_5, count(*) filter (where c.size between 6 and 20) as b_6_20,
            count(*) filter (where c.size between 21 and 100) as b_21_100, count(*) filter (where c.size >= 101) as b_101,
            count(*) filter (where c.svc in ('active','trialing','grace_period') and c.quota > 0 and c.used * 100 >= c.quota * 90) as stor90
            from co c where c.pkg = p.k) x),
  gr as (select jsonb_agg(x.n order by x.m) as a from (select g.m, (select count(*) from public.orgs o where o.created_at >= g.m and o.created_at < g.m + interval '1 month')::int as n
         from generate_series(date_trunc('month', now()) - interval '11 months', date_trunc('month', now()), interval '1 month') as g(m)) x),
  ol as (select coalesce(jsonb_object_agg(l.key, (select count(*) from co c where c.pkg = l.key and c.size > l.value::int)), '{}'::jsonb) as o from jsonb_each_text(lim) l)
  select jsonb_build_object(
    'generated_at', to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'companies', cnt.companies, 'seats_in_use', cnt.seats_in_use,
    'packages', jsonb_build_object('basic', cnt.p_basic, 'pro', cnt.p_pro, 'business', cnt.p_business, 'business_pro', cnt.p_business_pro, 'business_premium', cnt.p_business_premium, 'business_max', cnt.p_business_max, 'none', cnt.p_none, 'unknown', cnt.p_unknown),
    'states', jsonb_build_object('active', cnt.s_active, 'trialing', cnt.s_trialing, 'grace_period', cnt.s_grace, 'not_active_yet', cnt.s_not_active, 'ended', cnt.s_ended),
    'intervals', jsonb_build_object('month', cnt.i_month, 'year', cnt.i_year, 'none', cnt.i_none),
    'size_bands', jsonb_build_object('1', cnt.b_1, '2-5', cnt.b_2_5, '6-20', cnt.b_6_20, '21-100', cnt.b_21_100, '101+', cnt.b_101),
    'growth_12m', gr.a, 'ended_30d', cnt.ended_30d, 'renewals_7d', cnt.renewals_7d, 'over_limit', ol.o, 'by_package', bp.a,
    'signals', (select jsonb_agg(jsonb_build_object('key', d.key, 'label', d.label, 'runbook', d.runbook, 'count', (to_jsonb(cnt) ->> d.src)::int) order by d.ord)
                from (values
                  (1, 'grace_period',               'In grace period',                                  'Grace period',                         'sig_grace'),
                  (2, 'not_active_yet',             'Not active yet',                                   null,                                   'sig_not_active'),
                  (3, 'ended',                      'Ended (cancelled)',                                'Account suspended',                    'sig_ended'),
                  (4, 'payment_received_not_active','Payment received, service not active',            'Payment received, service not active', 'sig_paid_not_active'),
                  (5, 'seats_90',                   'Seats at 90 percent or more',                      'Storage or seats limit reached',       'sig_seats_90'),
                  (6, 'seats_95',                   'Seats at 95 percent or more',                      'Storage or seats limit reached',       'sig_seats_95'),
                  (7, 'storage_90',                 'Storage at 90 percent or more',                    'Storage or seats limit reached',       'sig_storage_90'),
                  (8, 'storage_95',                 'Storage at 95 percent or more',                    'Storage or seats limit reached',       'sig_storage_95')) as d(ord, key, label, runbook, src)))
  into r from cnt, gr, ol, bp;
  return r;
end $f$;
revoke all on function cp.census(jsonb) from public;
revoke all on schema cp from public; grant usage on schema cp to cp_lookup; grant execute on function cp.census(jsonb) to cp_lookup;
comment on function cp.census(jsonb) is 'CP4: the Control Plane census, counts only, six packages + none + unknown, per-package breakdown, one set-based pass.';

-- SELFTEST (rolls back; success is the exception P0CP4). Needs a superuser installer for synthetic rows. Runs on the LIVE database too: DELTAS only.
create function pg_temp.cp4_ok(c boolean, msg text) returns void language plpgsql as $f$ begin if c is not true then raise exception 'CP4 selftest: %', msg using errcode = 'P0CP3'; end if; end $f$;
do $$
declare c0 jsonb; c1 jsonb; o record; u uuid; k text;
begin
  begin set local session_replication_role = replica; exception when insufficient_privilege then raise notice 'CP4 selftest: skipped (needs a superuser installer)'; return; end;
  c0 := cp.census('{}'::jsonb);
  perform pg_temp.cp4_ok(jsonb_typeof(c0->'by_package') = 'object' and (select count(*) from jsonb_object_keys(c0->'by_package')) = 8, 'by_package has the eight keys');
  perform pg_temp.cp4_ok(cp.census('{"business_premium": 7000, "business_max": 100000}'::jsonb) is not null and cp.census('{"evil": 1}'::jsonb) is null, 'the six packages are valid limit keys, anything else is null');
  for o in select * from (values
     ('p1','business_premium','active',7000,10,'month'),('p2','business_premium','trialing',7000,2,'year'),
     ('m1','business_max','active',100000,200,'month'),
     ('none1',null,'none',1,1,null),('none2',null,null,1,1,null),
     ('weird','mystery_plan','active',3,3,'month'),('b1','basic','active',5,1,'month')) as t(nm, plan, st, seats, used, iv) loop
    u := gen_random_uuid(); insert into public.orgs (id) values (u);
    if o.nm <> 'none2' then insert into public.workspace_subscriptions (user_id, org_id, plan, state, seats, seats_used, "interval", updated_at) values (u, u, o.plan, o.st, o.seats, o.used, coalesce(o.iv, 'month'), now()); end if;
  end loop;
  c1 := cp.census('{}'::jsonb);
  perform pg_temp.cp4_ok((c1->>'companies')::int - (c0->>'companies')::int = 7, 'seven synthetic companies counted');
  perform pg_temp.cp4_ok((c1->'packages'->>'business_premium')::int - (c0->'packages'->>'business_premium')::int = 2 and (c1->'packages'->>'business_max')::int - (c0->'packages'->>'business_max')::int = 1
    and (c1->'packages'->>'none')::int - (c0->'packages'->>'none')::int = 2 and (c1->'packages'->>'unknown')::int - (c0->'packages'->>'unknown')::int = 1 and (c1->'packages'->>'basic')::int - (c0->'packages'->>'basic')::int = 1, 'packages: premium 2, max 1, none 2 (no plan yet), unknown 1 (a plan name nobody knows), basic 1');
  perform pg_temp.cp4_ok((select sum(v::int) from jsonb_each_text(c1->'packages') e(k, v)) = (c1->>'companies')::int, 'the package counts add up to the companies');
  perform pg_temp.cp4_ok((c1->'by_package'->'business_premium'->>'companies')::int - (c0->'by_package'->'business_premium'->>'companies')::int = 2
    and (c1->'by_package'->'business_premium'->'states'->>'trialing')::int - (c0->'by_package'->'business_premium'->'states'->>'trialing')::int = 1
    and (c1->'by_package'->'business_premium'->'intervals'->>'year')::int - (c0->'by_package'->'business_premium'->'intervals'->>'year')::int = 1
    and (c1->'by_package'->'business_max'->>'seats_in_use')::int - (c0->'by_package'->'business_max'->>'seats_in_use')::int = 200, 'by_package: premium companies 2 (one trial, one yearly), max seats in use 200');
  perform pg_temp.cp4_ok((select sum((v->>'companies')::int) from jsonb_each(c1->'by_package') e(k, v)) = (c1->>'companies')::int and (select sum((v->>'seats_in_use')::int) from jsonb_each(c1->'by_package') e(k, v)) = (c1->>'seats_in_use')::int, 'the per-package parts add up to the whole (companies and seats)');
  perform pg_temp.cp4_ok(c1::text !~* '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|@|amoun[t]|pric[e]|currenc[y]|invoic[e])', 'counts only: no company id, e-mail or money word');
  perform pg_temp.cp4_ok(has_function_privilege('cp_lookup', 'cp.census(jsonb)', 'EXECUTE') and not has_function_privilege('public', 'cp.census(jsonb)', 'EXECUTE'), 'cp_lookup may run the census, PUBLIC may not');
  raise exception 'CP4 selftest passed, rolling back' using errcode = 'P0CP4';
exception when sqlstate 'P0CP4' then raise notice 'CP4 selftest: ALL RULES PASSED (rows rolled back)';
end $$;
