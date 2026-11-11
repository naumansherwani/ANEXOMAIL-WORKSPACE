
-- CHECK DRIFT NOW (v2) - reads only, prints facts (ok is always true; this is a look, not a test). Founder 11 Nov 18:15: ring Alert after K8d.
select item, true as ok from (
select 1 as g, s.created_at as t, 'binding ' || s.source || ' pub=' || left(s.pub, 10) || ' fp=' || left(encode(sha256(convert_to(s.pub, 'UTF8')), 'hex'), 8) || ' created=' || to_char(s.created_at at time zone 'Asia/Karachi', 'DD HH24:MI:SS') || ' refreshes=' || s.refresh_count || ' revoked=' || coalesce(s.revoke_reason, 'ACTIVE') as item
  from public.founder_dbsc_sessions s order by s.created_at desc limit 8
) a
union all select 'session ' || left(r.sid_hash, 6) || ' key=' || r.key_source || ':' || left(coalesce(r.key_fp, '-'), 8) || ' created=' || to_char(r.created_at at time zone 'Asia/Karachi', 'DD HH24:MI:SS') || ' revoked=' || coalesce(to_char(r.revoked_at at time zone 'Asia/Karachi', 'HH24:MI:SS'), 'LIVE'), true from (select * from public.founder_session_registry order by created_at desc limit 4) r
union all select 'event ' || e.kind || ' ' || to_char(to_timestamp(e.ts_ms / 1000.0) at time zone 'Asia/Karachi', 'DD HH24:MI:SS') || ' ' || left(e.facts::text, 110), true from (select * from public.founder_dbsc_events order by id desc limit 14) e
union all select 'ledger ' || l.kind || ' ' || to_char(to_timestamp(l.ts_ms / 1000.0) at time zone 'Asia/Karachi', 'DD HH24:MI:SS') || ' proto=' || coalesce(l.protocol, '-') || ' ' || left(l.facts::text, 90), true from (select * from public.founder_session_ledger where kind in ('identity_drift', 'protocol_changed') order by id desc limit 10) l
union all select 'net ' || l.kind || ' ' || to_char(to_timestamp(l.ts_ms / 1000.0) at time zone 'Asia/Karachi', 'HH24:MI:SS') || ' net=' || left(l.net_hash, 6) || ' proto=' || coalesce(l.protocol, '-') || ' sid=' || left(l.sid_hash, 6), true from (select * from public.founder_session_ledger where kind in ('net_changed', 'net_flapping', 'seen', 'registered') order by id desc limit 14) l;
