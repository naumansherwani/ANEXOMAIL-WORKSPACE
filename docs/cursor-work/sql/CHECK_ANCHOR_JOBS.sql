
-- CHECK_ANCHOR_JOBS — reads only. Lists every anchoring job that is NOT done (provider, seal, state, attempts, stored error) plus the last 12 requeue events, so a FAIL in CHECK_E135 can be read, not guessed.
select item, ok from (
  select 1 as ord, j.cp_id as a, j.id as b,
         'job ' || j.id || ' seal ' || j.cp_id || ' ' || p.name || (case when p.enabled then '' else ' (OFF)' end) || ' ' || j.state || ' attempts=' || j.attempts || ' | ' || left(coalesce(j.last_error, '-'), 150) as item,
         true as ok
  from public.founder_anchor_jobs j join public.founder_anchor_providers p on p.id = j.provider_id where j.state <> 'done'
  union all
  select 2, e.cp_id, e.id, 'event ' || e.id || ' ' || e.event || ' seal ' || coalesce(e.cp_id::text, '-') || ' | ' || left(e.detail, 120), true
  from (select * from public.founder_anchor_events where event in ('requeued', 'dead') order by id desc limit 12) e
) t order by ord, a, b;
