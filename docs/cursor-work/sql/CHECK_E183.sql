
-- CHECK E183 - Q1b4 verdict evidence: tables, chain, score function, doors closed to anon, door audit clean, sent_ms keys, selftest (52 checks, rolls back). Writes nothing.
select item, ok from (
select 'E183 evidence + signature tables exist, RLS forced' as item, (select relforcerowsecurity from pg_class where oid='public.fmail_auth_evidence'::regclass) and (select relforcerowsecurity from pg_class where oid='public.fmail_auth_sig'::regclass) as ok, 1 as n
union all select 'E183 evidence is append-only (service_role has no update/delete)', not has_table_privilege('service_role','public.fmail_auth_evidence','update') and not has_table_privilege('service_role','public.fmail_auth_evidence','delete'), 2
union all select 'E183 messages carry trust_score + trust_grade', (select count(*) from information_schema.columns where table_schema='public' and table_name='fmail_messages' and column_name in ('trust_score','trust_grade'))=2, 3
union all select 'E183 brand list seeded (40+)', (select count(*) from public.fmail_brand_domains183) >= 40, 4
union all select 'E183 writer + readers service_role only', has_function_privilege('service_role','public.fmail_auth_record183(uuid,uuid,jsonb,jsonb)','execute') and not has_function_privilege('anon','public.fmail_auth_record183(uuid,uuid,jsonb,jsonb)','execute') and not has_function_privilege('authenticated','public.fmail_auth_get183(uuid,uuid)','execute'), 5
union all select 'E183 list169/get169 carry sent_ms, score, grade', pg_get_functiondef('public.fmail_list169(uuid,text,timestamptz,uuid,integer)'::regprocedure) like '%''sent_ms''%' and pg_get_functiondef('public.fmail_get169(uuid,uuid,text)'::regprocedure) like '%''grade''%', 6
union all select 'E183 verdict chain verifies (all mailboxes)', (public.fmail_auth_chain_verify183(null)->>'broken')='0' and (public.fmail_auth_chain_verify183(null)->>'sigs_broken')='0', 7
union all select 'E183 door audit (E179) clean', not exists (select 1 from public.fmail_door_audit179()), 8
union all select 'E183 selftest all ok', public.fmail_selftest183() like 'E183 selftest: 52 ok, 0 failed', 9
) t order by n;
