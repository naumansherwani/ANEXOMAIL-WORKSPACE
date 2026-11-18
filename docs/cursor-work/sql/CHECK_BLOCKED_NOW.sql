
-- CHECK BLOCKED NOW - reads only, prints facts (ok is always true; this is a look, not a test). Founder 18 Nov 06:02: dashboard says "6 requests blocked in the last 24 h".
-- Lists every 'blocked' event of the last 24 h (when, which session, the facts the gate wrote), then the count per session and the live DBSC mode facts.
select item, true as ok from (
select 1 as g, e.ts_ms as t, 'blocked ' || to_char(to_timestamp(e.ts_ms / 1000.0) at time zone 'Asia/Karachi', 'DD HH24:MI:SS') || ' sid=' || left(coalesce(e.sid, '-'), 8) || ' ' || left(e.facts::text, 160) as item
  from public.founder_dbsc_events e where e.kind = 'blocked' and e.ts_ms > (extract(epoch from now() - interval '24 hours') * 1000)::bigint
union all select 2, 0, 'per session ' || left(coalesce(e.sid, '-'), 8) || ' blocked=' || count(*) || ' first=' || to_char(to_timestamp(min(e.ts_ms) / 1000.0) at time zone 'Asia/Karachi', 'DD HH24:MI:SS') || ' last=' || to_char(to_timestamp(max(e.ts_ms) / 1000.0) at time zone 'Asia/Karachi', 'DD HH24:MI:SS')
  from public.founder_dbsc_events e where e.kind = 'blocked' and e.ts_ms > (extract(epoch from now() - interval '24 hours') * 1000)::bigint group by e.sid
union all select 3, 0, 'all kinds 24h ' || e.kind || '=' || count(*) from public.founder_dbsc_events e where e.ts_ms > (extract(epoch from now() - interval '24 hours') * 1000)::bigint group by e.kind
) a order by g, t;
