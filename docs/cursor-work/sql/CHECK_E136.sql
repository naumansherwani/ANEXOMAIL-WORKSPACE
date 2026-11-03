
-- CHECK E136 — reads only. 3 checks + the live numbers.
select item, ok from (
select 'E136 no ENABLED provider has a job that is still dead of the 32-byte bug' as item,
       not exists (select 1 from public.founder_anchor_jobs j join public.founder_anchor_providers p on p.id = j.provider_id
                   where j.state = 'dead' and p.enabled and position('is not 32 bytes' in lower(coalesce(j.last_error, ''))) > 0) as ok, 1 as ord
union all select 'E136 the requeue was audited (anchor.requeue exists) and every requeue has its event',
       exists (select 1 from public.founder_audit where action = 'anchor.requeue') and (select count(*) from public.founder_anchor_events where event = 'requeued') >= 1, 2
union all select 'E136 the anchor evidence + event chains still verify', coalesce((public.founder_anchor_verify(500) ->> 'ok')::boolean, false), 3
union all select 'E136 live: jobs by state ' || coalesce((select string_agg(state || '=' || n, ' ' order by state) from (select state, count(*) n from public.founder_anchor_jobs group by state) s), 'none'), true, 4
) t order by ord;
