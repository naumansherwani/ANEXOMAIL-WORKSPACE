
-- CHECK E137 — reads only. 3 checks + live numbers (the retry itself needs a minute or two: look again, or at CHECK_ANCHOR_JOBS, if freetsa is still queued).
select item, ok from (
select 'E137 no ENABLED provider has a job that is still dead of the unsupported ECDSA pair' as item,
       not exists (select 1 from public.founder_anchor_jobs j join public.founder_anchor_providers p on p.id = j.provider_id
                   where j.state = 'dead' and p.enabled and position('unsupported ecdsa curve/hash pair' in lower(coalesce(j.last_error, ''))) > 0) as ok, 1 as ord
union all select 'E137 the anchor evidence + event chains still verify', coalesce((public.founder_anchor_verify(500) ->> 'ok')::boolean, false), 2
union all select 'E137 live: freetsa jobs ' || coalesce((select string_agg(j.state || '=' || n, ' ' order by j.state) from (select j2.state, count(*) n from public.founder_anchor_jobs j2 join public.founder_anchor_providers p2 on p2.id = j2.provider_id where p2.name = 'freetsa' group by j2.state) j), 'none'), true, 3
union all select 'E137 live: all jobs by state ' || coalesce((select string_agg(state || '=' || n, ' ' order by state) from (select state, count(*) n from public.founder_anchor_jobs group by state) s), 'none'), true, 4
) t order by ord;
