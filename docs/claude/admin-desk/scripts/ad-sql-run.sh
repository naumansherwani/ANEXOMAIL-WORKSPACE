#!/usr/bin/env bash
# ANEXOMAIL ADMIN DESK SQL RUNNER (21 Nov 2026): runs admin-desk/sql/AD<n>.sql from origin/main strictly by number, then its checks/AD<n>-check.sql. DESK ISOLATION: its OWN ledger
# (/var/lib/anexomail-desk/sql-applied.tsv), it never reads /etc/anexomail/sync.env (founder/awam) and never runs an E-series file.
# DESK ISOLATION: the Desk gets its OWN database `anexo_desk` (his server has anexo_copy, anexo_founder, postgres, template0/1 as of his 21 Nov 10:04 paste); it is created here if missing. No other name is ever created.
# Usage: ad-sql-run.sh [database]   (default anexo_desk)   (the database name comes from his read-only paste: runuser -u postgres -- psql -h /var/run/postgresql -lqt | cut -d\| -f1)
# Connects through the local unix socket as the postgres OS user (PostgreSQL has no TCP port on his server). A file whose sha256 is already in the ledger is NOT run again (FORCE=1 overrides).
set -uo pipefail
# HIS SERVER FACT (21 Nov 2026 10:01 paste): a bare `psql` there fails with 'could not translate host name "/var/run/postgresql"' (PGHOST is set WITH quotes in his shell). So every call clears the PG* variables and names the unix socket directory itself.
PSQL() { runuser -u postgres -- env -u PGHOST -u PGPORT -u PGUSER -u PGDATABASE -u PGSERVICE psql -h /var/run/postgresql "$@"; }
REPO="${REPO:-/opt/anexomail-web}"; DB="${1:-${DESK_DB:-anexo_desk}}"; LEDGER=/var/lib/anexomail-desk/sql-applied.tsv
[ "$DB" = anexo_desk ] || echo "   note: using database $DB (not the default anexo_desk)"
[ -n "$DB" ] || { echo "FAIL: give the database name: ad-sql-run.sh <database> (read-only list: runuser -u postgres -- psql -h /var/run/postgresql -lqt | cut -d\| -f1)"; exit 2; }
command -v psql >/dev/null || { echo "FAIL: psql not found"; exit 2; }
if [ "$DB" = anexo_desk ] && [ "$(PSQL -d postgres -Atqc "select count(*) from pg_database where datname='anexo_desk'" 2>/dev/null)" = 0 ]; then echo "== creating the Desk's own database anexo_desk"; PSQL -d postgres -qc "CREATE DATABASE anexo_desk" || { echo "FAIL: CREATE DATABASE"; exit 2; }; fi
PSQL -d "$DB" -Atqc "select 1" >/dev/null 2>&1 || { echo "FAIL: cannot open database $DB as postgres over the unix socket"; exit 2; }
mkdir -p "$(dirname "$LEDGER")"; touch "$LEDGER"; chmod 600 "$LEDGER"
git -C "$REPO" fetch -q origin main || { echo "FAIL: fetch"; exit 2; }
T="$(mktemp)"; chmod 644 "$T"; trap 'rm -f "$T"' EXIT; RAN=""
for f in $(git -C "$REPO" ls-tree --name-only origin/main admin-desk/sql/ | sed -n 's#.*/\(AD\([0-9][0-9]*\)\)\.sql$#\2 \1#p' | sort -n | awk '{print $2}'); do
  git -C "$REPO" show "origin/main:admin-desk/sql/$f.sql" >"$T"; h="$(sha256sum "$T" | cut -c1-16)"
  if [ "${FORCE:-0}" != 1 ] && grep -q "^$f	$h	" "$LEDGER"; then echo "   $f: already applied (same sha256), skipped"; continue; fi
  echo "== running $f ($h)"; PSQL -d "$DB" -v ON_ERROR_STOP=1 -X -q -f "$T" 2>&1 | grep -v NOTICE | tail -8
  [ "${PIPESTATUS[0]}" = 0 ] || { echo "FAIL: $f stopped, nothing after it ran"; exit 3; }
  printf '%s\t%s\t%s\n' "$f" "$h" "$(date -u +%FT%TZ)" >>"$LEDGER"; RAN="$RAN $f"
done
for f in $(git -C "$REPO" ls-tree --name-only origin/main admin-desk/sql/checks/ | sed -n 's#.*/\(AD[0-9][0-9]*\)-check\.sql$#\1#p' | sort -V); do
  git -C "$REPO" show "origin/main:admin-desk/sql/checks/$f-check.sql" >"$T"
  echo "== check $f"; OUT="$(PSQL -d "$DB" -X -q -P pager=off -f "$T" 2>&1)"; echo "$OUT" | sed 's/^/   /'
  echo "$OUT" | grep -qE '\| f( |$)' && { echo "FAIL: a check row is false"; exit 4; }
done
echo "OK: Desk SQL applied:${RAN:- none new} and every check row is true"
