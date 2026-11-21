#!/usr/bin/env bash
# ANEXOMAIL ADMIN DESK AUTO SQL (his 21 Nov 2026 10:35: "auto wala kero, agar koi sql run nahi hui auto run hogi, jo run ho chuki woh bolay: already run").
# For every admin-desk/sql/AD<n>.sql on origin/main, in number order: run its CHECK first; all rows true = "AD<n> already run (already in the database)", skip.
# Otherwise run AD<n>.sql (one transaction, idempotent, no superuser) and then its CHECK. Uses DESK_DB_URL from /etc/anexomail-desk/db.env (made by ad-db-env.sh). Touches only schema desk.
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"; ENVF=/etc/anexomail-desk/db.env
[ -r "$ENVF" ] || { echo "FAIL: $ENVF missing, run ad-db-env.sh first"; exit 2; }
. "$ENVF"; [ -n "${DESK_DB_URL:-}" ] || { echo "FAIL: DESK_DB_URL empty"; exit 2; }
git -C "$REPO" fetch -q origin main || { echo "FAIL: fetch"; exit 2; }
P(){ env -u PGHOST -u PGPORT -u PGUSER -u PGDATABASE -u PGSERVICE psql "$DESK_DB_URL" -X -q -P pager=off "$@"; }
S="$(mktemp)"; C="$(mktemp)"; trap 'rm -f "$S" "$C"' EXIT; N=0; BAD=0
ok(){ ! echo "$1" | grep -qE '\| f( |$)|ERROR' && echo "$1" | grep -qE '\| t( |$)'; }
for n in $(git -C "$REPO" ls-tree --name-only origin/main admin-desk/sql/ | sed -n 's#.*/\(AD[0-9][0-9]*\)\.sql$#\1#p' | sort -V); do
  N=$((N+1)); git -C "$REPO" show "origin/main:admin-desk/sql/$n.sql" >"$S"
  HAS=0; git -C "$REPO" cat-file -e "origin/main:admin-desk/sql/checks/$n-check.sql" 2>/dev/null && { HAS=1; git -C "$REPO" show "origin/main:admin-desk/sql/checks/$n-check.sql" >"$C"; }
  if [ $HAS = 1 ]; then R="$(P -f "$C" 2>&1)"; if ok "$R"; then echo "$n: already run (yeh already is database mein implement hai), skipped"; continue; fi; fi
  echo "$n: not in the database yet, running it now"
  O="$(P -v ON_ERROR_STOP=1 -f "$S" 2>&1 | grep -v '^NOTICE')"; RC=${PIPESTATUS[0]}
  echo "$O" | tail -5 | sed 's/^/   /'
  echo "$O" | grep -q 'ERROR' && { echo "$n: FAILED, nothing was created (one transaction)"; BAD=1; break; }
  if [ $HAS = 1 ]; then R="$(P -f "$C" 2>&1)"; echo "$R" | sed 's/^/   /'; ok "$R" && echo "$n: run and CHECK OK" || { echo "$n: CHECK FALSE"; BAD=1; break; }; fi
done
[ "$N" = 0 ] && { echo "FAIL: no AD sql on origin/main"; exit 2; }
[ "$BAD" = 0 ] && echo "DONE: every Desk SQL is in the database" || exit 1
