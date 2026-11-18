
-- CHECK BLOCKED TIMELINE - reads only, prints facts (ok is always true). Founder 18 Nov 06:1x: the 6 blocked events are all sid LbDzb2Iz, no_cookie, in pairs 2 s apart (03:56, 04:53, 05:22),
-- and reject_replay is 12 in the same 24 h. This shows every event of that session within 3 minutes of a blocked event, in time order, so the cause is read, not guessed.
select item, true as ok from (
select e.ts_ms as t, e.kind || ' ' || to_char(to_timestamp(e.ts_ms / 1000.0) at time zone 'Asia/Karachi', 'DD HH24:MI:SS') || ' sid=' || left(coalesce(e.sid, '-'), 8) || ' ' || left(e.facts::text, 120) as item
  from public.founder_dbsc_events e
 where e.ts_ms > (extract(epoch from now() - interval '24 hours') * 1000)::bigint
   and exists (select 1 from public.founder_dbsc_events b where b.kind = 'blocked' and b.sid is not distinct from e.sid and abs(b.ts_ms - e.ts_ms) <= 180000)
) a order by t limit 80;
