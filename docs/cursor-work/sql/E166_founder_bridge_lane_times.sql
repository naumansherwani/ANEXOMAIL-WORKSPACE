
-- E166 - FOUNDER BRIDGE LANE TIMES (phase L-A LA-2 / LA-7): the REAL "when did something last happen" of every BridgeMap lane, read only.
-- ---------------------------------------------------------------------------------------------------------------------------------------
-- Why: the Bridge shows counts per lane (New leads, Polar events, New subscriptions / Mail waiting, Webhook errors, Rejected signatures). A tooltip that says
-- "last item 4 min ago" and the idle dimming of a quiet lane need a REAL timestamp per lane. Only the Polar events lane had one (E105 age_secs). This file
-- adds the other five, from the tables that already hold them. It CHANGES NOTHING in those tables (no index, trigger, grant, column): Polar engine / WAL NO-TOUCH (Rule B6a).
--
--   1) Helpers   founder_lane_col_ok166(table, column)   - does the column really exist (information_schema). A missing table or column = lane "not connected",
--                                                          never a made-up time and never a fake 0.
--                founder_lane_maxmin166(table, column, filter_sql_id) - fixed-shape aggregate through format(%I): no caller text ever reaches SQL
--                                                          (the filters are chosen from a closed list of numbers, not strings).
--   2) Main      founder_bridge_lane_times()   STABLE, security definer, search_path pinned, statement_timeout 5s, service_role only.
--                jsonb: { generated_at, lanes: { leads, polar_events, subscriptions, mail_waiting, webhook_errors, sig_rejects } }
--                each lane: { connected, count, last_at, age_secs, oldest_at?, oldest_age_secs? } (+ the honest window the count means)
--      PRIVACY: counts and timestamps only. No email, id, payload, header, customer (the selftest regex-checks the whole answer).
--   3) Selftest + posture  founder_bridge_lane_times_selftest166(), founder_lane_posture166()  and CHECK_E166.sql (reads only).
-- Run again any time: create or replace, writes nothing.

set lock_timeout = '10s';
set statement_timeout = '60s';
set search_path = pg_catalog, public, extensions;

-- 1a) does <table>.<column> exist in public? (closed identifiers only)
create or replace function public.founder_lane_col_ok166(p_table text, p_col text)
returns boolean language sql stable security definer set search_path = pg_catalog, public as $$
  select p_table ~ '^[a-z][a-z0-9_]{1,62}$' and p_col ~ '^[a-z][a-z0-9_]{1,62}$'
     and exists (select 1 from information_schema.columns c where c.table_schema = 'public' and c.table_name = p_table and c.column_name = p_col);
$$;
revoke all on function public.founder_lane_col_ok166(text, text) from public, anon, authenticated;
grant execute on function public.founder_lane_col_ok166(text, text) to service_role;

-- 1b) one aggregate per call. p_kind (closed list): 1 = count(*), 2 = max(col), 3 = min(col). p_where_id (closed list) picks a FIXED filter, never text:
--     0 none | 1 revenue_leads.stage='new' | 2 mail_outbox.state in (queued,failed) | 3 polar_webhook_inbox.process_error is not null
--     | 4 polar_webhook_inbox, last 24 h | 5 any table, created_at in the last 7 days
-- returns jsonb {ok:boolean, v: number|string|null}. ok=false = table/column missing or the filter does not apply there (the lane says "not connected").
create or replace function public.founder_lane_agg166(p_table text, p_col text, p_kind int, p_where_id int)
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '3s' as $$
declare v_filter text := ''; v_expr text; v_out text;
begin
  if p_kind not in (1, 2, 3) or p_where_id not between 0 and 5 then return jsonb_build_object('ok', false, 'v', null); end if;
  if to_regclass(format('public.%I', p_table)) is null then return jsonb_build_object('ok', false, 'v', null); end if;
  if p_kind in (2, 3) and not public.founder_lane_col_ok166(p_table, p_col) then return jsonb_build_object('ok', false, 'v', null); end if;
  v_filter := case p_where_id
    when 0 then ''
    when 1 then case when p_table = 'revenue_leads'       and public.founder_lane_col_ok166(p_table, 'stage')         then ' where stage = ''new''' else null end
    when 2 then case when p_table = 'mail_outbox'         and public.founder_lane_col_ok166(p_table, 'state')         then ' where state in (''queued'',''failed'')' else null end
    when 3 then case when p_table = 'polar_webhook_inbox' and public.founder_lane_col_ok166(p_table, 'process_error') then ' where process_error is not null' else null end
    when 4 then case when p_table = 'polar_webhook_inbox' and public.founder_lane_col_ok166(p_table, 'received_at')   then ' where received_at > now() - interval ''24 hours''' else null end
    when 5 then case when public.founder_lane_col_ok166(p_table, 'created_at') then ' where created_at > now() - interval ''7 days''' else null end
  end;
  if v_filter is null then return jsonb_build_object('ok', false, 'v', null); end if;
  v_expr := case p_kind when 1 then 'count(*)' when 2 then format('max(%I)', p_col) else format('min(%I)', p_col) end;
  execute format('select (%s)::text from public.%I%s', v_expr, p_table, v_filter) into v_out;
  return jsonb_build_object('ok', true, 'v', v_out);
exception when others then
  return jsonb_build_object('ok', false, 'v', null);   -- an odd column type or a timeout never becomes a fake answer
end $$;
revoke all on function public.founder_lane_agg166(text, text, int, int) from public, anon, authenticated;
grant execute on function public.founder_lane_agg166(text, text, int, int) to service_role;

-- small shaping helper: build one lane object from count + last + oldest. NULL last = no timestamp known (the UI then shows the count only).
create or replace function public.founder_lane_obj166(p_connected boolean, p_count bigint, p_last timestamptz, p_oldest timestamptz, p_window text)
returns jsonb language sql stable set search_path = pg_catalog, public as $$
  select case when not p_connected then jsonb_build_object('connected', false)
    else jsonb_build_object('connected', true, 'count', p_count, 'window', p_window,
      'last_at', p_last,
      'age_secs', case when p_last is null then null else greatest(0, extract(epoch from (now() - p_last))::bigint) end,
      'oldest_at', p_oldest,
      'oldest_age_secs', case when p_oldest is null then null else greatest(0, extract(epoch from (now() - p_oldest))::bigint) end) end;
$$;
revoke all on function public.founder_lane_obj166(boolean, bigint, timestamptz, timestamptz, text) from public, anon, authenticated;
grant execute on function public.founder_lane_obj166(boolean, bigint, timestamptz, timestamptz, text) to service_role;

-- 2) the answer
create or replace function public.founder_bridge_lane_times()
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
declare
  a jsonb; b jsonb; c jsonb;
  v_leads jsonb; v_polar jsonb; v_subs jsonb; v_mail jsonb; v_err jsonb; v_rej jsonb;
begin
  -- New leads (stage = new): count, newest, oldest waiting
  a := public.founder_lane_agg166('revenue_leads', 'created_at', 1, 1); b := public.founder_lane_agg166('revenue_leads', 'created_at', 2, 1); c := public.founder_lane_agg166('revenue_leads', 'created_at', 3, 1);
  v_leads := public.founder_lane_obj166((a->>'ok')::boolean and (b->>'ok')::boolean, (a->>'v')::bigint, (b->>'v')::timestamptz, (c->>'v')::timestamptz, 'waiting now (stage new)');

  -- Polar events (24 h): count in 24 h and newest event ever
  a := public.founder_lane_agg166('polar_webhook_inbox', 'received_at', 1, 4); b := public.founder_lane_agg166('polar_webhook_inbox', 'received_at', 2, 0);
  v_polar := public.founder_lane_obj166((a->>'ok')::boolean and (b->>'ok')::boolean, (a->>'v')::bigint, (b->>'v')::timestamptz, null, 'last 24 h');

  -- Subscriptions: new in 30 d (E105 counts it) + newest created and newest change
  if to_regclass('public.polar_subscriptions') is null or not public.founder_lane_col_ok166('polar_subscriptions', 'created_at') then
    v_subs := public.founder_lane_obj166(false, null, null, null, '');
  else
    v_subs := public.founder_lane_obj166(true, (select count(*) from public.polar_subscriptions where created_at > now() - interval '30 days'),
                                         (select max(created_at) from public.polar_subscriptions), null, 'created in the last 30 days');
  end if;

  -- Mail waiting or failed: count, oldest still waiting, newest
  a := public.founder_lane_agg166('mail_outbox', 'created_at', 1, 2); b := public.founder_lane_agg166('mail_outbox', 'created_at', 2, 2); c := public.founder_lane_agg166('mail_outbox', 'created_at', 3, 2);
  v_mail := public.founder_lane_obj166((a->>'ok')::boolean and (b->>'ok')::boolean, (a->>'v')::bigint, (b->>'v')::timestamptz, (c->>'v')::timestamptz, 'waiting now (queued or failed)');

  -- Webhook errors (24 h): count in 24 h (E105 rule: process_error not null) and the newest error ever
  if to_regclass('public.polar_webhook_inbox') is null or not public.founder_lane_col_ok166('polar_webhook_inbox', 'process_error') or not public.founder_lane_col_ok166('polar_webhook_inbox', 'received_at') then
    v_err := public.founder_lane_obj166(false, null, null, null, '');
  else
    v_err := public.founder_lane_obj166(true,
      (select count(*) from public.polar_webhook_inbox where process_error is not null and received_at > now() - interval '24 hours'),
      (select max(received_at) from public.polar_webhook_inbox where process_error is not null), null, 'last 24 h');
  end if;

  -- Rejected signatures (7 d): count in 7 d and the newest reject ever
  a := public.founder_lane_agg166('polar_signature_rejects', 'created_at', 1, 5); b := public.founder_lane_agg166('polar_signature_rejects', 'created_at', 2, 0);
  v_rej := public.founder_lane_obj166((a->>'ok')::boolean and (b->>'ok')::boolean, (a->>'v')::bigint, (b->>'v')::timestamptz, null, 'last 7 days');

  return jsonb_build_object('generated_at', now(), 'lanes', jsonb_build_object(
    'leads', v_leads, 'polar_events', v_polar, 'subscriptions', v_subs, 'mail_waiting', v_mail, 'webhook_errors', v_err, 'sig_rejects', v_rej),
    'source', 'E166 read-only timestamps from the live tables');
end $$;
revoke all on function public.founder_bridge_lane_times() from public, anon, authenticated;
grant execute on function public.founder_bridge_lane_times() to service_role;
comment on function public.founder_bridge_lane_times() is 'E166: real last-event / oldest-waiting time per Bridge lane. Read only, no PII, writes nothing, touches no table definition.';

-- 3) posture: every function is read-only (STABLE), search_path pinned, no anon/authenticated execute
create or replace function public.founder_lane_posture166() returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare r jsonb := '{}'::jsonb; f text;
begin
  foreach f in array array['founder_lane_col_ok166(text,text)', 'founder_lane_agg166(text,text,integer,integer)', 'founder_lane_obj166(boolean,bigint,timestamp with time zone,timestamp with time zone,text)', 'founder_bridge_lane_times()'] loop
    r := r || jsonb_build_object(f || ' stable', (select p.provolatile = 's' from pg_proc p where p.oid = ('public.' || f)::regprocedure));
    r := r || jsonb_build_object(f || ' no anon/auth', not (has_function_privilege('anon', 'public.' || f, 'execute') or has_function_privilege('authenticated', 'public.' || f, 'execute')));
    r := r || jsonb_build_object(f || ' service_role', has_function_privilege('service_role', 'public.' || f, 'execute'));
  end loop;
  r := r || jsonb_build_object('search_path pinned (main)', coalesce((select 'search_path=pg_catalog, public' = any(p.proconfig) from pg_proc p where p.oid = 'public.founder_bridge_lane_times()'::regprocedure), false));
  return r;
end $$;
revoke all on function public.founder_lane_posture166() from public, anon, authenticated;
grant execute on function public.founder_lane_posture166() to service_role;

create or replace function public.founder_bridge_lane_times_selftest166() returns text language plpgsql security definer set search_path = pg_catalog, public as $$
declare j jsonb; txt text; k text; lane jsonb; n int := 0; agg jsonb;
begin
  j := public.founder_bridge_lane_times();
  if not (j ? 'generated_at' and j ? 'lanes') then raise exception 'E166 shape wrong: %', j; end if;
  foreach k in array array['leads', 'polar_events', 'subscriptions', 'mail_waiting', 'webhook_errors', 'sig_rejects'] loop
    lane := j #> array['lanes', k];
    if lane is null or not (lane ? 'connected') then raise exception 'E166 lane % missing', k; end if;
    if (lane->>'connected')::boolean then
      n := n + 1;
      if (lane->>'count')::bigint < 0 then raise exception 'E166 lane % negative count', k; end if;
      if lane->>'age_secs' is not null and (lane->>'age_secs')::bigint < 0 then raise exception 'E166 lane % negative age', k; end if;
      if lane->>'last_at' is not null and (lane->>'last_at')::timestamptz > now() + interval '1 minute' then raise exception 'E166 lane % last_at in the future', k; end if;
    end if;
  end loop;
  txt := j::text;
  if txt ~* '[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}' then raise exception 'E166 answer contains an email-like text: PII leak'; end if;
  if txt ~* '"(payload|raw_body|headers|email|polar_customer_id|user_id|customer)"' then raise exception 'E166 answer contains a forbidden key'; end if;
  -- the closed lists: a hostile identifier or filter id is refused, never executed
  agg := public.founder_lane_agg166('revenue_leads; drop table x', 'created_at', 1, 0);
  if (agg->>'ok')::boolean then raise exception 'E166 hostile table name was accepted'; end if;
  agg := public.founder_lane_agg166('revenue_leads', 'created_at', 9, 0);
  if (agg->>'ok')::boolean then raise exception 'E166 unknown aggregate kind was accepted'; end if;
  agg := public.founder_lane_agg166('revenue_leads', 'created_at', 1, 99);
  if (agg->>'ok')::boolean then raise exception 'E166 unknown filter id was accepted'; end if;
  agg := public.founder_lane_agg166('mail_outbox', 'created_at', 1, 1);       -- a filter that belongs to another table must not apply
  if (agg->>'ok')::boolean then raise exception 'E166 a leads filter was applied to mail_outbox'; end if;
  if exists (select 1 from jsonb_each_text(public.founder_lane_posture166()) where value <> 'true') then raise exception 'E166 posture: %', public.founder_lane_posture166(); end if;
  return 'E166 selftest PASS - shape, six lanes, no PII, closed identifier and filter lists, read-only, grants; connected lanes=' || n;
end $$;
revoke all on function public.founder_bridge_lane_times_selftest166() from public, anon, authenticated;
grant execute on function public.founder_bridge_lane_times_selftest166() to service_role;

do $$ begin raise notice '%', public.founder_bridge_lane_times_selftest166(); end $$;
