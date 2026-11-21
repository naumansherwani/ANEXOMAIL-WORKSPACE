#!/usr/bin/env bash
# ANEXOMAIL ADMIN DESK SQL AUTO (his 21 Nov 2026 10:34: "if a SQL was not run, run it automatically; if already run, say it is already run").
# For each admin-desk/sql/AD<n>.sql (by number) from origin/main: if its AD<n>-check.sql rows are ALL true -> prints "AD<n>: already run"; else runs the file (one transaction, idempotent), then the check. Uses DESK_DB_URL from /etc/anexomail-desk/db.env.
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"; ENVF=/etc/anexomail-desk/db.env
[ -r "$ENVF" ] || { echo "FAIL: $ENVF missing; run ad-db-env.sh first"; exit 2; }
. "$ENVF"; [ -n "${DESK_DB_URL:-}" ] || { echo "FAIL: DESK_DB_URL empty"; exit 2; }
git -C "$REPO" fetch -q origin main || { echo "FAIL: fetch"; exit 2; }
P(){ env -u PGHOST -u PGPORT -u PGUSER -u PGDATABASE -u PGSERVICE psql "$DESK_DB_URL" -X -q -P pager=off "$@"; }
S="$(mktemp)"; C="$(mktemp)"; trap 'rm -f "$S" "$C"' EXIT; RC=0; N=0
okcheck(){ OUT="$(P -f "$C" 2>&1)"; ! echo "$OUT" | grep -qE '\| f( |$)|ERROR' && echo "$OUT" | grep -q '| t'; }
for n in $(git -C "$REPO" ls-tree --name-only origin/main admin-desk/sql/ | sed -n 's#.*/AD\([0-9][0-9]*\)\.sql$#\1#p' | sort -n); do
  N=$((N+1)); git -C "$REPO" show "origin/main:admin-desk/sql/AD$n.sql" >"$S"
  if git -C "$REPO" show "origin/main:admin-desk/sql/checks/AD$n-check.sql" >"$C" 2>/dev/null; then
    if okcheck; then echo "AD$n: already run (check all true), nothing to do"; continue; fi
  fi
  echo "AD$n: not run yet, running now"
  P -v ON_ERROR_STOP=1 -f "$S" 2>&1 | grep -v NOTICE | tail -8 | sed 's/^/   /'
  if [ -s "$C" ]; then okcheck && echo "AD$n: run OK, check all true" || { echo "AD$n: FAIL after run:"; echo "$OUT" | sed 's/^/   /'; RC=1; }; fi
done
[ "$N" = 0 ] && { echo "FAIL: no AD sql in origin/main"; exit 2; }
exit $RC
