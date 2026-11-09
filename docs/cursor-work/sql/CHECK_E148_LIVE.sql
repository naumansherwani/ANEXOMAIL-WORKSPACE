-- CHECK_E148_LIVE (K6.4, founder lane, READ-ONLY): did the real page open WebTransport live sessions, and how did they end? Safe to repeat. No uid / IP / token (E148 privacy).
select t.item, t.ok from (
  select 'E148 LIVE real WebTransport sessions in the last 2 h (ok = at least 1): ' || coalesce((public.founder_wt_report(2) -> 'by_transport' -> 'webtransport')::text, 'none') as item,
         coalesce((public.founder_wt_report(2) -> 'by_transport' -> 'webtransport' ->> 'sessions')::int, 0) >= 1 as ok, 1 as ord
  union all select 'E148 LIVE close reasons (last 2 h): ' || coalesce((public.founder_wt_report(2) -> 'close_reasons')::text, '{}'), true, 2
  union all select 'E148 LIVE share of WebTransport among all live sessions (last 2 h, %): ' || coalesce((public.founder_wt_report(2) ->> 'webtransport_share_pct'), 'n/a'), true, 3
) t order by t.ord;
