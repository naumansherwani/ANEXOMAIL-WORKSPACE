-- ==============================================================================================================================
-- CHECK_E148_LIVE (K6.4, founder lane) — READ-ONLY proof report: does the founder page really get its live data over WebTransport?
-- Works the same in the Supabase SQL editor (paste and Run, ONE statement) and through sql-run.sh (two columns item | ok; ok=false => FAIL).
-- Edit the window in the first CTE (hours, 1..720). Reads only founder_live_sessions (E111 + E148). Privacy (E148): no uid, IP, token, user agent.
-- NOTE: a row is written when the session OPENS, frames_sent / close_reason arrive when it CLOSES (tab closed, 10 min lifetime, network gone).
--       So "frames delivered" is judged on CLOSED sessions; close the founder tab, wait a few seconds, run again.
-- ==============================================================================================================================
with p as (select 2::int as hours),                                                    -- <- the window, in hours
s as (                                                                                  -- sessions of the window, with the gap to the previous open of the SAME transport
  select f.id, f.transport, f.auth_kind, f.opened_at, f.closed_at, f.close_reason, f.frames_sent, f.duration_ms,
         f.opened_at - lag(f.opened_at) over (partition by f.transport order by f.opened_at) as gap_prev
    from public.founder_live_sessions f, p
   where f.opened_at >= now() - make_interval(hours => least(greatest(p.hours, 1), 720))
),
agg as (                                                                                -- one row per transport
  select transport,
         count(*)                                                              as sessions,
         count(*) filter (where closed_at is null)                             as open_now,
         count(*) filter (where closed_at is not null)                         as closed,
         count(*) filter (where closed_at is not null and coalesce(frames_sent, 0) > 0) as closed_with_frames,
         coalesce(sum(frames_sent), 0)                                         as frames,
         (percentile_cont(0.5)  within group (order by duration_ms) filter (where duration_ms is not null))::bigint as p50_ms,
         (percentile_cont(0.95) within group (order by duration_ms) filter (where duration_ms is not null))::bigint as p95_ms,
         count(*) filter (where gap_prev is not null and gap_prev < interval '15 seconds') as quick_reopens
    from s group by transport
),
wt as (select * from agg where transport = 'webtransport'),
sse as (select * from agg where transport = 'sse'),
bad as (                                                                                -- WebTransport sessions that ended for a bad reason
  select count(*) as n, coalesce(string_agg(distinct close_reason, ', '), '') as reasons
    from s where transport = 'webtransport' and close_reason in ('slow_client', 'lagged', 'error', 'orphan')
),
orphans as (                                                                            -- still "open" far beyond the 10 min stream lifetime (+1 min grace) = a crashed / lost close
  select count(*) as n from s where closed_at is null and opened_at < now() - interval '11 minutes'
),
timeline as (                                                                           -- last 8 WebTransport sessions, newest first: "+age s ago: lasted ms, frames, reason"
  select coalesce(string_agg(format('#%s %ss ago %s %s frames %s', id, extract(epoch from (now() - opened_at))::int,
                                    coalesce(duration_ms::text || ' ms', 'OPEN'), coalesce(frames_sent::text, '?'), coalesce(close_reason, '-')),
                             ' | ' order by opened_at desc), 'none') as line
    from (select * from s where transport = 'webtransport' order by opened_at desc limit 8) t
),
reasons as (
  select coalesce(string_agg(format('%s:%s=%s', transport, close_reason, n), ', ' order by transport, close_reason), 'none yet') as line
    from (select transport, close_reason, count(*) n from s where close_reason is not null group by 1, 2) r
)
select item, ok from (
  select 1 as ord,
         'WebTransport sessions in the window (ok = at least 1): ' || coalesce((select sessions::text from wt), '0') as item,
         coalesce((select sessions from wt), 0) >= 1 as ok
  union all select 2,
         'WebTransport sessions that CLOSED having delivered frames (ok = at least 1; this is the proof that signed frames really flowed): '
           || coalesce((select closed_with_frames::text || ' of ' || closed::text || ' closed, ' || frames::text || ' frames in total' from wt), 'none'),
         coalesce((select closed_with_frames from wt), 0) >= 1
  union all select 3,
         'WebTransport still open right now: ' || coalesce((select open_now::text from wt), '0') || ' (info: a healthy tab keeps one open; frames show when it closes)',
         true
  union all select 4,
         'No WebTransport session ended slow_client / lagged / error / orphan: ' || (select n::text from bad) || coalesce(' (' || nullif((select reasons from bad), '') || ')', ''),
         (select n from bad) = 0
  union all select 5,
         'Reconnect flapping: WebTransport sessions opened less than 15 s after the previous one: ' || coalesce((select quick_reopens::text from wt), '0')
           || ' (info; 1 or 2 right after a page load is normal, a steady number is a loop)',
         true
  union all select 6,
         'Duration of closed WebTransport sessions, p50 / p95 ms: ' || coalesce((select p50_ms::text || ' / ' || p95_ms::text from wt), 'n/a'),
         true
  union all select 7,
         'No session still "open" past the 10 min lifetime + 1 min (lost close / crash): ' || (select n::text from orphans),
         (select n from orphans) = 0
  union all select 8,
         'Share of WebTransport among all live sessions in the window, %: ' || coalesce(
             (select round(100.0 * coalesce((select sessions from wt), 0) / nullif((select sum(sessions) from agg), 0), 1)::text), 'n/a (no sessions: is FOUNDER_TELEMETRY=on?)'),
         true
  union all select 9,
         'SSE fallback for comparison (sessions / closed with frames / frames): ' || coalesce((select sessions::text || ' / ' || closed_with_frames::text || ' / ' || frames::text from sse), 'none'),
         true
  union all select 10, 'Close reasons (window): ' || (select line from reasons), true
  union all select 11, 'Last WebTransport sessions: ' || (select line from timeline), true
) t order by ord;
