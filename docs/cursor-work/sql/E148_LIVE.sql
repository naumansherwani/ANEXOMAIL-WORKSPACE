
-- ==============================================================================================================================
-- E148_LIVE — founder WebTransport LIVE HEALTH (K6.4, founder lane). Sits under E148 (needs E111 + E148 first). ADVANCED, idempotent, read-only data.
-- WHY: K6 is GREEN only when signed frames really flow over WebTransport. This puts the proof into the database as ONE function the Rust service
--      (and later a Settings panel) can call, instead of a loose query:
--   1) founder_wt_live_report(hours)  one jsonb: verdict (proven | waiting | no_sessions | degraded), per transport counts / frames / p50 / p95,
--                                     reconnect flapping (window function lag), bad close reasons, orphans (open past lifetime), last sessions timeline.
--   2) founder_wt_live_selftest()     behaviour test on rows it creates itself, rolled back by a sentinel exception (nothing persists).
-- PRIVACY (Rule 69 / FC18): no uid, IP, token, user agent, body. Only transport kind, counts, times, reasons.
-- SECURITY: security definer, search_path pinned, statement_timeout pinned, hours clamped 1..720, execute only for service_role (RLS table untouched).
-- Same in the Supabase SQL editor (paste, Run) and through sql-run.sh (E148_LIVE then CHECK_E148_LIVE_FN).
-- ==============================================================================================================================
set lock_timeout = '5s';
set statement_timeout = '30s';

do $$ begin
  if to_regclass('public.founder_live_sessions') is null then raise exception 'E111 pehle chalao (founder_live_sessions nahi hai)' using errcode = '55000'; end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'founder_live_sessions' and column_name = 'transport') then
    raise exception 'E148 pehle chalao (transport column nahi hai)' using errcode = '55000';
  end if;
end $$;

create or replace function public.founder_wt_live_report(p_hours integer default 2) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '8s' as $$
declare
  v_h integer := least(greatest(coalesce(p_hours, 2), 1), 720);
  v_since timestamptz;
  v_wt jsonb; v_all jsonb; v_bad jsonb; v_orph integer; v_tl jsonb; v_verdict text;
  v_wt_n integer; v_wt_closed_frames integer; v_bad_n integer;
begin
  v_since := now() - make_interval(hours => v_h);

  with s as (
    select f.id, f.transport, f.opened_at, f.closed_at, f.close_reason, f.frames_sent, f.duration_ms,
           f.opened_at - lag(f.opened_at) over (partition by f.transport order by f.opened_at) as gap_prev
      from public.founder_live_sessions f where f.opened_at >= v_since
  ), agg as (
    select transport,
           count(*) as sessions,
           count(*) filter (where closed_at is null) as open_now,
           count(*) filter (where closed_at is not null) as closed,
           count(*) filter (where closed_at is not null and coalesce(frames_sent, 0) > 0) as closed_with_frames,
           coalesce(sum(frames_sent), 0)::bigint as frames,
           (percentile_cont(0.5)  within group (order by duration_ms) filter (where duration_ms is not null))::bigint as p50_ms,
           (percentile_cont(0.95) within group (order by duration_ms) filter (where duration_ms is not null))::bigint as p95_ms,
           count(*) filter (where gap_prev is not null and gap_prev < interval '15 seconds') as quick_reopens
      from s group by transport
  )
  select coalesce(jsonb_object_agg(transport, to_jsonb(agg) - 'transport'), '{}'::jsonb) into v_all from agg;

  v_wt := coalesce(v_all -> 'webtransport', '{}'::jsonb);
  v_wt_n := coalesce((v_wt ->> 'sessions')::int, 0);
  v_wt_closed_frames := coalesce((v_wt ->> 'closed_with_frames')::int, 0);

  select jsonb_build_object('count', count(*), 'reasons', coalesce(jsonb_agg(distinct close_reason), '[]'::jsonb)), count(*)
    into v_bad, v_bad_n
    from public.founder_live_sessions
   where opened_at >= v_since and transport = 'webtransport' and close_reason in ('slow_client', 'lagged', 'error', 'orphan');

  -- still "open" far beyond the 10 minute stream lifetime (+1 minute grace): a lost close or a crash
  select count(*) into v_orph from public.founder_live_sessions where opened_at >= v_since and closed_at is null and opened_at < now() - interval '11 minutes';

  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'age_s', extract(epoch from (now() - opened_at))::int, 'duration_ms', duration_ms,
                                               'frames', frames_sent, 'reason', close_reason) order by opened_at desc), '[]'::jsonb)
    into v_tl
    from (select * from public.founder_live_sessions where opened_at >= v_since and transport = 'webtransport' order by opened_at desc limit 8) t;

  v_verdict := case
    when v_wt_n = 0 then 'no_sessions'                              -- telemetry off, or the page never used WebTransport
    when v_bad_n > 0 or v_orph > 0 then 'degraded'                  -- sessions ended slow_client / lagged / error / orphan, or a close was lost
    when v_wt_closed_frames >= 1 then 'proven'                      -- a CLOSED WebTransport session delivered signed frames
    else 'waiting' end;                                             -- sessions exist but none closed yet (frames arrive when a session closes)

  return jsonb_build_object('hours', v_h, 'verdict', v_verdict, 'by_transport', v_all, 'bad_closes', v_bad, 'orphans', v_orph, 'last_webtransport', v_tl,
    'webtransport_share_pct', (select case when sum((value ->> 'sessions')::int) = 0 then null
                                           else round(100.0 * coalesce((v_all -> 'webtransport' ->> 'sessions')::int, 0) / sum((value ->> 'sessions')::int), 1) end
                                 from jsonb_each(v_all)));
end $$;

-- behaviour selftest: it creates its own rows and rolls EVERYTHING back (sentinel exception), so nothing persists and live data is never judged
create or replace function public.founder_wt_live_selftest() returns text
language plpgsql security definer set search_path = pg_catalog, public set statement_timeout = '15s' as $$
declare r jsonb; e text; v_before integer;
begin
  begin
    perform 1;
    -- window clamp + shape on whatever is there
    r := public.founder_wt_live_report(0);
    if (r ->> 'hours')::int <> 1 then raise exception 'SELFTEST hours not clamped to 1'; end if;
    r := public.founder_wt_live_report(100000);
    if (r ->> 'hours')::int <> 720 then raise exception 'SELFTEST hours not clamped to 720'; end if;
    if not (r ? 'verdict' and r ? 'by_transport' and r ? 'bad_closes' and r ? 'orphans' and r ? 'last_webtransport') then raise exception 'SELFTEST report shape'; end if;
    -- a proven session: opened, closed with frames
    insert into public.founder_live_sessions (auth_kind, transport, opened_at, closed_at, close_reason, frames_sent)
      values ('device', 'webtransport', now() - interval '5 seconds', now() - interval '1 second', 'client_gone', 7);
    r := public.founder_wt_live_report(1);
    if (r -> 'by_transport' -> 'webtransport' ->> 'closed_with_frames')::int < 1 then raise exception 'SELFTEST closed_with_frames not counted'; end if;
    if (r -> 'by_transport' -> 'webtransport' ->> 'frames')::int < 7 then raise exception 'SELFTEST frames not summed'; end if;
    if r ->> 'verdict' not in ('proven', 'degraded') then raise exception 'SELFTEST verdict % unexpected for a good closed session', r ->> 'verdict'; end if;
    -- a bad close must make the verdict degraded
    insert into public.founder_live_sessions (auth_kind, transport, opened_at, closed_at, close_reason, frames_sent)
      values ('device', 'webtransport', now() - interval '4 seconds', now() - interval '3 seconds', 'slow_client', 2);
    r := public.founder_wt_live_report(1);
    if r ->> 'verdict' <> 'degraded' then raise exception 'SELFTEST a slow_client close must be degraded, got %', r ->> 'verdict'; end if;
    if (r -> 'bad_closes' ->> 'count')::int < 1 then raise exception 'SELFTEST bad close not counted'; end if;
    -- two WebTransport opens 1 s apart count as a quick reopen
    if (r -> 'by_transport' -> 'webtransport' ->> 'quick_reopens')::int < 1 then raise exception 'SELFTEST quick reopen not detected'; end if;
    -- an open row older than lifetime + grace is an orphan
    insert into public.founder_live_sessions (auth_kind, transport, opened_at) values ('device', 'sse', now() - interval '30 minutes');
    r := public.founder_wt_live_report(1);
    if (r ->> 'orphans')::int < 1 then raise exception 'SELFTEST orphan not detected'; end if;
    raise exception 'E148_LIVE_ROLLBACK_OK';
  exception when others then
    get stacked diagnostics e = message_text;
    if e = 'E148_LIVE_ROLLBACK_OK' then return 'E148_LIVE selftest OK (clamps, shape, proven, degraded, quick reopen, orphan; rolled back)'; end if;
    return 'E148_LIVE selftest FAIL: ' || e;
  end;
end $$;

revoke all on function public.founder_wt_live_report(integer) from public, anon, authenticated;
revoke all on function public.founder_wt_live_selftest() from public, anon, authenticated;
grant execute on function public.founder_wt_live_report(integer) to service_role;
grant execute on function public.founder_wt_live_selftest() to service_role;

-- the answer, readable right in the SQL editor (one row)
select public.founder_wt_live_selftest() as selftest, public.founder_wt_live_report(2) as live_report;
