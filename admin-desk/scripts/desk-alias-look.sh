#!/usr/bin/env bash
# ANEXOMAIL ADMIN DESK: READ-ONLY look (his 21 Nov 2026 10:52: "meri company ke aliases ban rahay hain"). Changes NOTHING, prints no secret.
# Question: how and where do his company's own addresses (admindesk, hello, moveyourbusiness, resolved, billing, noreply, leo, postmaster, abuse, dmarc, naumansherwani.founder) exist as aliases/mailboxes today?
set +e
. /etc/anexomail/sync.env 2>/dev/null || { echo "FAIL: /etc/anexomail/sync.env"; exit 2; }
Q(){ env -u PGHOST -u PGPORT -u PGUSER -u PGDATABASE -u PGSERVICE psql "$WORKING_URL" -X -At -F ' | ' -c "$1" 2>&1 | head -${2:-40}; }
echo "== 1. tables with an address / alias / local_part column (schema.table.column)"
Q "select table_schema||'.'||table_name||'.'||column_name from information_schema.columns where table_schema in ('public','desk') and (column_name in ('address','alias','local_part','email_address','handle') or table_name ilike '%alias%') order by 1" 60
echo "== 2. his company names in those tables (table | rows matching)"
for t in $(Q "select distinct table_schema||'.'||table_name from information_schema.columns where table_schema='public' and column_name in ('address','alias','email_address')" 30); do
  for c in address alias email_address; do
    n=$(Q "select count(*) from $t where $c::text ~* '^(admindesk|hello|moveyourbusiness|resolved|billing|noreply|leo|postmaster|abuse|dmarc|naumansherwani\.founder)@'" 1 2>/dev/null); case "$n" in ''|*[!0-9]*) ;; *) echo "$t.$c: $n";; esac
  done
done
echo "== 3. the matching rows themselves (first 25 addresses only)"
for t in $(Q "select distinct table_schema||'.'||table_name from information_schema.columns where table_schema='public' and column_name='address'" 20); do echo "-- $t"; Q "select address from $t where address ~* '^(admindesk|hello|moveyourbusiness|resolved|billing|noreply|leo|postmaster|abuse|dmarc|naumansherwani\.founder)@' order by 1" 25; done
echo "== done (read-only)"
