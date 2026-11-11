-- CHECK DRIFT NOW - reads only, prints facts (ok is always true; this is a look, not a test). Founder 11 Nov 18:15: ring turned Alert after K8d.
select item, true as ok from (
select 'live session: ua=' || r.ua_family || ' hint=' || r.hint_family || ' proto=' || r.protocol || ' key_source=' || r.key_source || ' key=' || left(coalesce(r.key_fp, 'none'), 8) as item, 1 as ord from public.founder_session_registry r where r.revoked_at is null order by r.created_at desc limit 3
) a
union all select 'ledger ' || l.kind || ' proto=' || coalesce(l.protocol, '-') || ' facts=' || left(l.facts::text, 160), true from (select * from public.founder_session_ledger where kind in ('identity_drift', 'protocol_changed', 'network_flip', 'seen') order by id desc limit 8) l;
