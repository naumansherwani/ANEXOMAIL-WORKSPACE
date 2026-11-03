
-- CHECK G5D LIVE — reads only. Proves the Rust observer is really ticking on THIS server (run it a few minutes after founder-install). 5 checks.
select item, ok from (
select 'G5D live: the Rust tick has written to the tick log (a holder named founder-<pid>-<boot>)' as item,
       exists (select 1 from public.founder_portable_tick_log where holder ~ '^founder-[0-9]+-[0-9]+$') as ok, 1 as ord
union all select 'G5D live: the newest tick is less than 5 minutes old (heartbeat or change)',
       coalesce((select (extract(epoch from clock_timestamp()) * 1000)::bigint - max(ts_ms) < 300000 from public.founder_portable_tick_log), false), 2
union all select 'G5D live: the observer pulse is ok and no failed tick is counted',
       coalesce((public.founder_portable_tick_pulse() ->> 'level') = 'ok' and (public.founder_portable_tick_pulse() ->> 'consec_fail')::int = 0, false), 3
union all select 'G5D live: an outside-time horizon exists, it was observed, and the lease epoch is >= 1',
       coalesce((select outcome in ('observed', 'throttled') from public.founder_portable_tick_log where outcome <> 'lease_denied' order by id desc limit 1), false)
       and (select epoch >= 1 from public.founder_portable_lease where id), 4
union all select 'G5D live: both E138 chains re-check clean and the overall status answers (' || coalesce(public.founder_portable_status() ->> 'level', '?') || ')',
       coalesce((public.founder_portable_tick_verify(500) ->> 'ok')::boolean, false) and (public.founder_portable_status() ? 'level'), 5
) t order by ord;
