-- ANEXOMAIL CONTROL PLANE CP3 (phase 1m-5, card B6 Deliverability), 23 Nov 2026 PKT: the ONE read-only DELIVERABILITY door of the Control Plane on the awam database.
-- SCHEMA-FIRST: CP1 (cp.lookup, role cp_lookup, SECURITY DEFINER pattern), CP2 (cp.census, signal registry pattern), E15 public.org_domains (status pending/verified/removed, txt_ok, mx_ok, spf_ok, dkim_ok, dmarc_ok, last_checked_at, verified_at, created_at) read from the live snapshot docs/cursor-work/live-snapshot/sql/schema-public.sql.
-- ADVANCE-RESEARCH: [1m] authentication posture of every company domain (SPF, DKIM, DMARC, MX), freshness of the checks, domains stuck in verification, a closed signal registry with the runbook that fixes each; research list D6-CARDS-LIST-23NOV.md section B6 (Google Postmaster dashboards, Gmail/Yahoo bulk-sender rules, RFC 8460), set-based single pass, counts only.
-- CHECK-FILE: control-plane/sql/checks/CP3-check.sql
-- WHAT IT ADDS: cp.deliverability() returns jsonb, COUNTS ONLY. Role cp_lookup gets EXECUTE on that one function and nothing else (still no table right). It reads ONLY public.org_domains(org_id, status, spf_ok, dkim_ok, dmarc_ok, mx_ok, last_checked_at, created_at).
--   It NEVER returns a domain name, a company id, a token, a DKIM key or an e-mail. Removed domains are not counted. Posture is counted over VERIFIED domains. A verified domain is "fully authenticated" when SPF, DKIM, DMARC and MX are all true.
--   The SIGNAL REGISTRY is a closed list inside the function (key, label, runbook, source): a new signal is ONE row. Zero is shown as a real 0 (his FUTURE-PROOF LAW 23 Nov 06:42).
create schema if not exists cp;
do $$ begin if not exists (select 1 from pg_roles where rolname = 'cp_lookup') then create role cp_lookup nologin; end if; end $$;

create or replace function cp.deliverability() returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, pg_temp as $f$
declare r jsonb;
begin
  with
  d as (select x.org_id, x.status, x.spf_ok, x.dkim_ok, x.dmarc_ok, x.mx_ok, x.last_checked_at, x.created_at
          from public.org_domains x where x.status in ('pending', 'verified')),
  v as (select * from d where status = 'verified'),
  cnt as (
    select
      (select count(*) from d)::int as domains,
      (select count(distinct org_id) from d)::int as companies,
      (select count(*) from d where status = 'pending')::int as s_pending,
      (select count(*) from v)::int as s_verified,
      (select count(*) from v where spf_ok)::int as p_spf,
      (select count(*) from v where dkim_ok)::int as p_dkim,
      (select count(*) from v where dmarc_ok)::int as p_dmarc,
      (select count(*) from v where mx_ok)::int as p_mx,
      (select count(*) from v where spf_ok and dkim_ok and dmarc_ok and mx_ok)::int as p_all,
      (select count(*) from d where last_checked_at is null)::int as never_checked,
      (select count(*) from v where last_checked_at is null or last_checked_at < now() - interval '24 hours')::int as stale_24h,
      (select count(*) from d where status = 'pending' and created_at < now() - interval '7 days')::int as pending_7d,
      (select count(distinct org_id) from v where not (spf_ok and dkim_ok and dmarc_ok and mx_ok))::int as companies_failing,
      (select count(*) from v where not spf_ok)::int as sig_spf,
      (select count(*) from v where not dkim_ok)::int as sig_dkim,
      (select count(*) from v where not dmarc_ok)::int as sig_dmarc,
      (select count(*) from v where not mx_ok)::int as sig_mx)
  select jsonb_build_object(
    'generated_at', to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'domains', cnt.domains, 'companies', cnt.companies,
    'status', jsonb_build_object('pending', cnt.s_pending, 'verified', cnt.s_verified),
    'posture', jsonb_build_object('spf', cnt.p_spf, 'dkim', cnt.p_dkim, 'dmarc', cnt.p_dmarc, 'mx', cnt.p_mx, 'all_ok', cnt.p_all),
    'never_checked', cnt.never_checked, 'stale_24h', cnt.stale_24h, 'pending_7d', cnt.pending_7d, 'companies_failing', cnt.companies_failing,
    'signals', (select jsonb_agg(jsonb_build_object('key', g.key, 'label', g.label, 'runbook', g.runbook, 'count', (to_jsonb(cnt) ->> g.src)::int) order by g.ord)
                from (values
                  (1, 'spf_missing',   'Verified domains without SPF',                    'Email not delivered', 'sig_spf'),
                  (2, 'dkim_missing',  'Verified domains without DKIM',                   'Email not delivered', 'sig_dkim'),
                  (3, 'dmarc_missing', 'Verified domains without DMARC',                  'Email not delivered', 'sig_dmarc'),
                  (4, 'mx_missing',    'Verified domains without MX pointing to us',      'Email not delivered', 'sig_mx'),
                  (5, 'stale_check',   'Verified domains not checked in the last 24 hours', null,               'stale_24h'),
                  (6, 'pending_7d',    'Domains waiting for verification over 7 days',    null,                  'pending_7d')) as g(ord, key, label, runbook, src)))
  into r from cnt;
  return r;
end $f$;
revoke all on function cp.deliverability() from public;
grant usage on schema cp to cp_lookup;
grant execute on function cp.deliverability() to cp_lookup;

-- SELFTEST (rolls back; success is the exception P0CP3). Needs a superuser installer to switch off foreign keys for its synthetic rows. Every count is a DELTA of what the test adds (it also runs on the LIVE database).
create function pg_temp.cp3_ok(c boolean, msg text) returns void language plpgsql as $f$ begin if c is not true then raise exception 'CP3 selftest: %', msg using errcode = 'P0CP1'; end if; end $f$;
do $$
declare c0 jsonb; c1 jsonb; a uuid := gen_random_uuid(); b uuid := gen_random_uuid(); n int := 0; dn text;
begin
  begin set local session_replication_role = replica; exception when insufficient_privilege then raise notice 'CP3 selftest: skipped (needs a superuser installer)'; return; end;
  c0 := cp.deliverability();
  perform pg_temp.cp3_ok(c0 is not null and jsonb_array_length(c0->'signals') = 6, 'six registered signals');
  -- company a: one fully good verified domain, one verified without DKIM (checked 2 days ago), one pending for 8 days; company b: one verified, never checked, nothing ok; one removed (not counted)
  insert into public.org_domains (org_id, domain, status, spf_ok, dkim_ok, dmarc_ok, mx_ok, txt_ok, last_checked_at, created_at) values
    (a, 'cp3-good-' || replace(a::text, '-', '') || '.example', 'verified', true, true, true, true, true, now(), now()),
    (a, 'cp3-nodkim-' || replace(a::text, '-', '') || '.example', 'verified', true, false, true, true, true, now() - interval '2 days', now()),
    (a, 'cp3-pending-' || replace(a::text, '-', '') || '.example', 'pending', false, false, false, false, false, now(), now() - interval '8 days'),
    (b, 'cp3-bad-' || replace(b::text, '-', '') || '.example', 'verified', false, false, false, false, false, null, now()),
    (b, 'cp3-removed-' || replace(b::text, '-', '') || '.example', 'removed', true, true, true, true, true, now(), now());
  c1 := cp.deliverability();
  perform pg_temp.cp3_ok((c1->>'domains')::int - (c0->>'domains')::int = 4 and (c1->>'companies')::int - (c0->>'companies')::int = 2, 'four live domains in two companies; the removed one is not counted');
  perform pg_temp.cp3_ok((c1->'status'->>'verified')::int - (c0->'status'->>'verified')::int = 3 and (c1->'status'->>'pending')::int - (c0->'status'->>'pending')::int = 1, 'three verified, one pending');
  perform pg_temp.cp3_ok((c1->'posture'->>'all_ok')::int - (c0->'posture'->>'all_ok')::int = 1 and (c1->'posture'->>'dkim')::int - (c0->'posture'->>'dkim')::int = 1 and (c1->'posture'->>'spf')::int - (c0->'posture'->>'spf')::int = 2, 'posture over verified: one fully authenticated, one DKIM, two SPF');
  perform pg_temp.cp3_ok((c1->>'never_checked')::int - (c0->>'never_checked')::int = 1 and (c1->>'stale_24h')::int - (c0->>'stale_24h')::int = 2 and (c1->>'pending_7d')::int - (c0->>'pending_7d')::int = 1, 'never checked 1, stale 2 (2 days old and never checked), pending over 7 days 1');
  perform pg_temp.cp3_ok((c1->>'companies_failing')::int - (c0->>'companies_failing')::int = 2, 'both companies have a verified domain that fails a check');
  perform pg_temp.cp3_ok((c1->'signals'->1->>'count')::int - (c0->'signals'->1->>'count')::int = 2 and c1->'signals'->0->>'key' = 'spf_missing' and c1->'signals'->0->>'runbook' = 'Email not delivered' and c1->'signals'->4->'runbook' = 'null'::jsonb, 'signal order, counts and runbook names');
  perform pg_temp.cp3_ok(c1::text !~* '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|@|cp3-|\.example|token|selector)', 'counts only: no domain, company id, token or e-mail in the answer');
  perform pg_temp.cp3_ok(has_function_privilege('cp_lookup', 'cp.deliverability()', 'EXECUTE') and not has_function_privilege('public', 'cp.deliverability()', 'EXECUTE') and not has_table_privilege('cp_lookup', 'public.org_domains', 'SELECT'), 'cp_lookup may run it, PUBLIC may not, and cp_lookup has no table right');
  raise exception 'CP3 selftest passed, rolling back' using errcode = 'P0CP3';
exception when sqlstate 'P0CP3' then raise notice 'CP3 selftest: ALL RULES PASSED (rows rolled back)';
end $$;
