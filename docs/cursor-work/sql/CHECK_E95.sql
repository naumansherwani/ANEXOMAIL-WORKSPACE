
-- CHECK E95 — sirf padhta hai. Har row ok = true.
select item, ok from (
select 'E95 rebuild function maujood' as item, to_regprocedure('public.anexo_rebuild_contacts(uuid)') is not null as ok, 1 as n
union all select 'E95 rebuild ab to_addrs padhta hai',
       pg_get_functiondef('public.anexo_rebuild_contacts(uuid)'::regprocedure) like '%to_addrs%', 2
union all select 'E95 rebuild ab cc_addrs padhta hai',
       pg_get_functiondef('public.anexo_rebuild_contacts(uuid)'::regprocedure) like '%cc_addrs%', 3
union all select 'E95 anon/authenticated chala nahi sakte',
       not has_function_privilege('anon', 'public.anexo_rebuild_contacts(uuid)', 'execute')
       and not has_function_privilege('authenticated', 'public.anexo_rebuild_contacts(uuid)', 'execute'), 4
) t order by n;
