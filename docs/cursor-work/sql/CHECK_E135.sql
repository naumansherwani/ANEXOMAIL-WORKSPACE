
-- CHECK E135 — reads only. 2 checks + the live numbers.
select item, ok from (
select 'E135 no ENABLED provider has a job that is still dead of the 32-byte bug (they were re-queued; the audit row anchor.requeue exists if any were)' as item,
       not exists (select 1 from public.founder_anchor_jobs j join public.founder_anchor_providers p on p.id = j.provider_id
                   where j.state = 'dead' and p.enabled and position('is not 32 bytes' in lower(coalesce(j.last_error, ''))) > 0) as ok, 1 as ord
union all select 'E135 the anchor evidence + event chains still verify',
       coalesce((public.founder_anchor_verify(500) ->> 'ok')::boolean, false), 2
union all select 'E135 live: jobs by state ' || coalesce((select string_agg(state || '=' || n, ' ' order by state) from (select state, count(*) n from public.founder_anchor_jobs group by state) s), 'none'), true, 3
) t order by ord;
