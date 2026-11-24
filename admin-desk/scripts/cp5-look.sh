#!/usr/bin/env bash
# ANEXOMAIL CP5 LOOK (B13 Z4a, 24 Nov 2026): READ-ONLY. Shows (1) the CP5 CHECK rows, (2) the real fact: which company-id family has owners/admins, so Z4c knows where the approver lives, (3) the CP5 ledger and inbox now. Changes nothing.
set -u
ADMIN="$( . /etc/anexomail/sync.env 2>/dev/null; printf %s "${WORKING_URL:-}" )"; [ -n "$ADMIN" ] || { echo "FAIL: no WORKING_URL in sync.env"; exit 2; }
REPO="${REPO:-/opt/anexomail-web}"; git -C "$REPO" fetch -q origin main || { echo "FAIL: fetch"; exit 2; }
q() { env -u PGHOST -u PGPORT -u PGUSER -u PGDATABASE -u PGSERVICE psql "$ADMIN" -X -q -At -F' | ' -v ON_ERROR_STOP=1 "$@" 2>&1; }
echo "== 0. which database am I on (read-only select)"
q -c "select current_database(), current_user, inet_server_port(), to_regclass('cp.consent_inbox') is not null as inbox_here, to_regprocedure('cp.consent_minutes(text)') is not null as fn_here, (select count(*) from pg_namespace where nspname='cp') as cp_schema" | sed 's/^/   /'
echo "== 1. CP5 CHECK (every row must end true)"
S="$(mktemp)"; git -C "$REPO" show origin/main:control-plane/sql/checks/CP5-check.sql >"$S"; q -f "$S" | sed 's/^/   /'; rm -f "$S"
echo "== 2. the company families (counts only; -1 = table does not exist)"
q -c "select 'public.orgs (the Desk company id)', count(*) from public.orgs union all select 'public.organisations (org_members points here)', case when to_regclass('public.organisations') is null then -1 else (select count(*) from public.organisations) end union all select 'org_members rows, active owner or admin', count(*) from public.org_members where role in ('owner','admin') and coalesce(status,'active')='active' union all select 'orgs whose id is ALSO in organisations', case when to_regclass('public.organisations') is null then -1 else (select count(*) from public.orgs o join public.organisations x on x.id=o.id) end union all select 'orgs with an active owner/admin in org_members', count(*) from public.orgs o where exists (select 1 from public.org_members m where m.org_id=o.id and m.role in ('owner','admin') and coalesce(m.status,'active')='active') union all select 'account_organisations', case when to_regclass('public.account_organisations') is null then -1 else (select count(*) from public.account_organisations) end union all select 'orgs whose id is in account_organisations', case when to_regclass('public.account_organisations') is null then -1 else (select count(*) from public.orgs o join public.account_organisations a on a.id=o.id) end" | sed 's/^/   /'
echo "== 3. the CP5 ledger and inbox right now"
q -c "select 'ledger lines', count(*) from cp.consent_ledger union all select 'inbox rows', count(*) from cp.consent_inbox union all select 'chain verifies (1 = yes)', case when cp.consent_ledger_verify() then 1 else 0 end" | sed 's/^/   /'
echo "DONE: read only, nothing was changed"
