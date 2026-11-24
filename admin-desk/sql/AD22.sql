
-- TARGET-DB: AWAM DATABASE (schema cp). NOT the Desk database: scripts/cp-install.sh runs this file on the awam database; ad-auto.sh and ad-sql-run.sh skip every file with this line.
-- ANEXOMAIL CONTROL PLANE AD22 (phase 1m-4, card B9 Customers and Plans), 23 Nov 2026 PKT: the ONE read-only CENSUS door of the Control Plane on the awam database.
-- SCHEMA-FIRST: AD21 (cp.lookup, role cp_lookup, SECURITY DEFINER pattern), the live awam schema snapshot docs/cursor-work/live-snapshot/sql/schema-public.sql (orgs, workspace_subscriptions, org_members, billing_intents, admin_storage_snapshots), E34 (seats), AD04 (the Desk lookup contract), AD06 (package limits)
-- ADVANCE-RESEARCH: [1m] dimensions per package / state / interval / size band / 12-month growth / ended 30 days / renewals 7 days, six real needing-you-now signal families from the real tables, closed signal registry, set-based single pass for 10 million companies (docs/claude/admin-desk/D6-CARDS-LIST-23NOV.md U1..U12)
-- CHECK-FILE: docs/claude/admin-desk/sql/checks/AD22-check.sql
-- WHAT IT ADDS: cp.census(p_limits jsonb) returns jsonb, COUNTS ONLY. Role cp_lookup gets EXECUTE on that one function and nothing else (still no table right). It reads orgs(id, created_at), workspace_subscriptions(org_id, user_id, plan, state, seats, seats_used, interval, renews_at, updated_at),
--   org_members(org_id, user_id, status), billing_intents(user_id, paid_at, resolved_at: TIMESTAMPS ONLY), admin_storage_snapshots(user_id, mailbox, day, used_bytes, quota_bytes). It NEVER reads or returns an e-mail, a name, a company id, a money value.
--   Latest subscription per company = the newest updated_at (the same rule as cp.lookup). One set-based pass, no per-company loop, no per-company result.
--   Service state: active | trialing | grace_period (past_due) | not_active_yet (none or no subscription) | ended (cancelled). Package: basic | pro | business | business_pro | unknown. Size band by the larger of seats in use and active members: 1, 2-5, 6-20, 21-100, 101+.
--   The SIGNAL REGISTRY is a closed list inside the function (key, label, runbook, rule): a new signal is ONE row. Zero is shown as a real 0 (his FUTURE-PROOF LAW 23 Nov 06:42).
--   p_limits (optional) = the seat promise of each package as the Desk knows it, {"basic": 5, ...}; the answer counts, per named package, the companies whose seats in use are ABOVE that promise (counts only). Anything else in p_limits makes the function return null.
create schema if not exists cp;
do $$ begin if not exists (select 1 from pg_roles where rolname = 'cp_lookup') then create role cp_lookup nologin; end if; end $$;

create or replace function cp.census(p_limits jsonb default '{}'::jsonb) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, pg_temp as $f$
declare r jsonb; lim jsonb := coalesce(p_limits, '{}'::jsonb); k text; v text;
begin
  if jsonb_typeof(lim) <> 'object' then return null; end if;
  for k, v in select * from jsonb_each_text(lim) loop
    if k not in ('basic','pro','business','business_pro') or v !~ '^[0-9]{1,6}$' then return null; end if;
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
           case when su.plan in ('basic','pro','business','business_pro') then su.plan else 'unknown' end as pkg,
           case when su.state is null or su.state = 'none' then 'not_active_yet' when su.state = 'active' then 'active' when su.state = 'trialing' then 'trialing'
                when su.state = 'past_due' then 'grace_period' when su.state = 'cancelled' then 'ended' else 'not_active_yet' end as svc,
           greatest(coalesce(su.seats_used, 0), coalesce(me.n, 0)) as size,
           (pd.user_id is not null) as paid_open, st.used, st.quota
         from public.orgs o left join sub su on su.org_id = o.id left join mem me on me.org_id = o.id left join paid pd on pd.user_id = su.user_id left join stor st on st.org_id = o.id),
  cnt as (select
      count(*) as companies,
      coalesce(sum(size), 0) as seats_in_use,
      count(*) filter (where pkg = 'basic') as p_basic, count(*) filter (where pkg = 'pro') as p_pro, count(*) filter (where pkg = 'business') as p_business,
      count(*) filter (where pkg = 'business_pro') as p_business_pro, count(*) filter (where pkg = 'unknown') as p_unknown,
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
  gr as (select jsonb_agg(x.n order by x.m) as a from (select g.m, (select count(*) from public.orgs o where o.created_at >= g.m and o.created_at < g.m + interval '1 month')::int as n
         from generate_series(date_trunc('month', now()) - interval '11 months', date_trunc('month', now()), interval '1 month') as g(m)) x),
  ol as (select coalesce(jsonb_object_agg(l.key, (select count(*) from co c where c.pkg = l.key and c.size > l.value::int)), '{}'::jsonb) as o from jsonb_each_text(lim) l)
  select jsonb_build_object(
    'generated_at', to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'companies', cnt.companies, 'seats_in_use', cnt.seats_in_use,
    'packages', jsonb_build_object('basic', cnt.p_basic, 'pro', cnt.p_pro, 'business', cnt.p_business, 'business_pro', cnt.p_business_pro, 'unknown', cnt.p_unknown),
    'states', jsonb_build_object('active', cnt.s_active, 'trialing', cnt.s_trialing, 'grace_period', cnt.s_grace, 'not_active_yet', cnt.s_not_active, 'ended', cnt.s_ended),
    'intervals', jsonb_build_object('month', cnt.i_month, 'year', cnt.i_year, 'none', cnt.i_none),
    'size_bands', jsonb_build_object('1', cnt.b_1, '2-5', cnt.b_2_5, '6-20', cnt.b_6_20, '21-100', cnt.b_21_100, '101+', cnt.b_101),
    'growth_12m', gr.a, 'ended_30d', cnt.ended_30d, 'renewals_7d', cnt.renewals_7d, 'over_limit', ol.o,
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
  into r from cnt, gr, ol;
  return r;
end $f$;
revoke all on function cp.census(jsonb) from public;
revoke all on schema cp from public; grant usage on schema cp to cp_lookup; grant execute on function cp.census(jsonb) to cp_lookup;

-- SELFTEST (rolls back; success is the exception P0CP2). It needs the right to switch off the foreign keys for its synthetic rows (a superuser installer has it); without that right it says so and the CHECK file still runs.
-- It runs on the LIVE database too, so every count is a DELTA of what the test adds, never an exact total.
create function pg_temp.cp2_ok(c boolean, msg text) returns void language plpgsql as $f$ begin if c is not true then raise exception 'AD22 selftest: %', msg using errcode = 'P0CP1'; end if; end $f$;
do $$
declare c0 jsonb; c1 jsonb; o record; u uuid;
begin
  begin set local session_replication_role = replica; exception when insufficient_privilege then raise notice 'AD22 selftest: skipped (needs a superuser installer to switch off foreign keys for synthetic rows); the CHECK file still proves the privileges'; return; end;
  c0 := cp.census('{}'::jsonb);
  perform pg_temp.cp2_ok(c0 is not null and jsonb_array_length(c0->'signals') = 8 and jsonb_array_length(c0->'growth_12m') = 12, 'the census has 8 registered signals and a 12-month growth line');
  perform pg_temp.cp2_ok(cp.census('[]'::jsonb) is null AND cp.census('{"evil": 1}'::jsonb) is null AND cp.census('{"basic": "x; drop"}'::jsonb) is null, 'bad limits make the function return null');
  -- synthetic companies, one per case
  for o in select * from (values
     ('ok-active',   'pro',          'active',    10,  3, 'month', 1),
     ('grace',       'basic',        'past_due',  5,   2, 'year',  1),
     ('none',        null,           'none',      1,   1, null,    1),
     ('ended-recent','business',     'cancelled', 8,   8, 'month', 1),
     ('seats-89',    'business_pro', 'active',    100, 89, 'month', 1),
     ('seats-90',    'business_pro', 'active',    100, 90, 'month', 1),
     ('seats-94',    'business_pro', 'active',    100, 94, 'month', 1),
     ('seats-95',    'business_pro', 'active',    100, 95, 'month', 1)) as t(nm, plan, st, seats, used, iv, one) loop
    u := gen_random_uuid();
    insert into public.orgs (id) values (u);
    insert into public.workspace_subscriptions (user_id, org_id, plan, state, seats, seats_used, "interval", renews_at, updated_at)
      values (u, u, o.plan, o.st, o.seats, o.used, coalesce(o.iv, 'month'), case when o.nm = 'ok-active' then now() + interval '3 days' else null end, now());
  end loop;
  c1 := cp.census('{}'::jsonb);
  perform pg_temp.cp2_ok((c1->>'companies')::int - (c0->>'companies')::int = 8, 'eight synthetic companies counted');
  perform pg_temp.cp2_ok((c1->'states'->>'grace_period')::int - (c0->'states'->>'grace_period')::int = 1 and (c1->'states'->>'not_active_yet')::int - (c0->'states'->>'not_active_yet')::int = 1 and (c1->'states'->>'ended')::int - (c0->'states'->>'ended')::int = 1 and (c1->'states'->>'active')::int - (c0->'states'->>'active')::int = 5, 'service states: grace 1, not active yet 1, ended 1, active 5');
  perform pg_temp.cp2_ok((c1->'packages'->>'business_pro')::int - (c0->'packages'->>'business_pro')::int = 4 and (c1->'packages'->>'unknown')::int - (c0->'packages'->>'unknown')::int = 1, 'packages: 4 business_pro and one unknown (no plan)');
  perform pg_temp.cp2_ok((c1->>'ended_30d')::int - (c0->>'ended_30d')::int = 1 and (c1->>'renewals_7d')::int - (c0->>'renewals_7d')::int = 1, 'ended in 30 days 1, renewals due in 7 days 1');
  perform pg_temp.cp2_ok((c1->'size_bands'->>'101+')::int = (c0->'size_bands'->>'101+')::int and (c1->'size_bands'->>'21-100')::int - (c0->'size_bands'->>'21-100')::int = 4, 'size bands: four companies of 89 to 95 seats are in 21-100');
  perform pg_temp.cp2_ok((c1->'growth_12m'->>11)::int - (c0->'growth_12m'->>11)::int = 8, 'all eight new companies are in this month of the growth line');
  -- boundaries 89 / 90 / 94 / 95 percent: seats_90 counts 90 and 94, seats_95 counts 95; 89 counts in neither
  perform pg_temp.cp2_ok(((c1->'signals'->4->>'count')::int - (c0->'signals'->4->>'count')::int) = 2 and ((c1->'signals'->5->>'count')::int - (c0->'signals'->5->>'count')::int) = 1, 'seats boundaries: 89 in neither, 90 and 94 in the 90 band, 95 in the 95 band');
  perform pg_temp.cp2_ok(c1->'signals'->0->>'key' = 'grace_period' and (c1->'signals'->0->>'count')::int - (c0->'signals'->0->>'count')::int = 1 and c1->'signals'->3->>'runbook' = 'Payment received, service not active', 'signal order and runbook names are the registered ones');
  -- payment received but service not active: a paid, unresolved intent on the grace company
  insert into public.billing_intents (user_id, paid_at, resolved_at) select s.user_id, now(), null from public.workspace_subscriptions s where s.state = 'past_due' and s.plan = 'basic' order by s.updated_at desc limit 1;
  c1 := cp.census('{}'::jsonb);
  perform pg_temp.cp2_ok((c1->'signals'->3->>'count')::int - (c0->'signals'->3->>'count')::int = 1, 'a paid but unresolved intent on a not-active company is counted once');
  -- storage: 90 / 94 / 95 percent of quota on active companies (one member each)
  insert into public.org_members (org_id, user_id, status) select s.org_id, s.user_id, 'active' from public.workspace_subscriptions s where s.state = 'active' and s.plan = 'business_pro' and s.seats_used in (89, 90, 94, 95) and s.updated_at >= now() - interval '1 minute';
  insert into public.admin_storage_snapshots (user_id, mailbox, day, used_bytes, quota_bytes)
    select s.user_id, 'm', current_date, (case s.seats_used when 89 then 89 when 90 then 90 when 94 then 94 else 95 end)::bigint * 1000, 100000 from public.workspace_subscriptions s where s.state = 'active' and s.plan = 'business_pro' and s.seats_used in (89, 90, 94, 95) and s.updated_at >= now() - interval '1 minute';
  c1 := cp.census('{}'::jsonb);
  perform pg_temp.cp2_ok((c1->'signals'->6->>'count')::int - (c0->'signals'->6->>'count')::int = 2 and (c1->'signals'->7->>'count')::int - (c0->'signals'->7->>'count')::int = 1, 'storage boundaries: 89 in neither, 90 and 94 in the 90 band, 95 in the 95 band');
  -- over the package promise: business_pro promises 94 seats; 95 is over
  perform pg_temp.cp2_ok((cp.census('{"business_pro": 94}'::jsonb)->'over_limit'->>'business_pro')::int - (select count(*) from public.workspace_subscriptions s where s.plan = 'business_pro' and s.updated_at < now() - interval '1 minute' and s.seats_used > 94)::int >= 1, 'a company above its package seat promise is counted');
  -- aggregate only: no uuid, e-mail or money word anywhere in the answer
  perform pg_temp.cp2_ok(c1::text !~* '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|@|amoun[t]|pric[e]|currenc[y]|invoic[e])', 'counts only: no company id, e-mail or money word in the answer');
  perform pg_temp.cp2_ok(has_function_privilege('cp_lookup', 'cp.census(jsonb)', 'EXECUTE') and not has_function_privilege('public', 'cp.census(jsonb)', 'EXECUTE') and not has_table_privilege('cp_lookup', 'public.billing_intents', 'SELECT') and not has_table_privilege('cp_lookup', 'public.admin_storage_snapshots', 'SELECT'), 'cp_lookup may run the census and read no table');
  raise exception 'AD22 selftest passed, rolling back' using errcode = 'P0CP2';
exception when sqlstate 'P0CP2' then raise notice 'AD22 selftest: ALL RULES PASSED (rows rolled back)';
end $$;
