
-- CHECK E96 — sirf padhta hai. Har row ok = true.
select item, ok from (
select 'E96 rebuild function maujood' as item, to_regprocedure('public.anexo_rebuild_contacts(uuid)') is not null as ok, 1 as n
union all select 'E96 rebuild ab contact_stats ke live column likhta hai (first_contact_at, computed_at)',
       pg_get_functiondef('public.anexo_rebuild_contacts(uuid)'::regprocedure) like '%first_contact_at%'
       and pg_get_functiondef('public.anexo_rebuild_contacts(uuid)'::regprocedure) like '%computed_at%', 2
union all select 'E96 rebuild contacts.last_contact_at / stats.org_id nahi likhta',
       pg_get_functiondef('public.anexo_rebuild_contacts(uuid)'::regprocedure) not like '%public.contacts (org_id, display_name, primary_address, addresses, company_domain, last_contact_at)%'
       and pg_get_functiondef('public.anexo_rebuild_contacts(uuid)'::regprocedure) not like '%contact_stats (contact_id, org_id%', 3
union all select 'E96 live table mein jo column function likhta hai wo maujood hain',
       (select count(*) from information_schema.columns where table_schema='public' and table_name='contact_stats'
          and column_name in ('contact_id','messages_in','messages_out','open_threads','first_contact_at','last_contact_at','relationship','computed_at')) = 8
       and (select count(*) from information_schema.columns where table_schema='public' and table_name='contacts'
          and column_name in ('org_id','display_name','primary_address','addresses','company_domain','updated_at')) = 6, 4
union all select 'E96 anon/authenticated chala nahi sakte',
       not has_function_privilege('anon', 'public.anexo_rebuild_contacts(uuid)', 'execute')
       and not has_function_privilege('authenticated', 'public.anexo_rebuild_contacts(uuid)', 'execute'), 5
) t order by n;
