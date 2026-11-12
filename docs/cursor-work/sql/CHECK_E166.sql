
-- CHECK E166 - reads only. 3 checks.
select item, ok from (
select 'E166 posture: every function STABLE, search_path pinned, service_role only, no anon/authenticated' as item, (select bool_and(value::boolean) from jsonb_each_text(public.founder_lane_posture166())) as ok, 1 as ord
union all select 'E166 selftest: ' || public.founder_bridge_lane_times_selftest166(), public.founder_bridge_lane_times_selftest166() ~ '^E166 selftest PASS', 2
union all select 'E166 answer has the six lanes: ' || (select string_agg(k, ',' order by k) from jsonb_object_keys(public.founder_bridge_lane_times() -> 'lanes') k), (select count(*) from jsonb_object_keys(public.founder_bridge_lane_times() -> 'lanes')) = 6, 3
) t order by ord;
