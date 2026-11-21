#!/usr/bin/env bash
# ANEXOMAIL ADMIN DESK SQL CHECK, READ-ONLY (his 21 Nov 2026 10:28: "AD1 goes to the SQL editor, the CHECK runs on the server"). Runs every admin-desk/sql/checks/AD<n>-check.sql from origin/main against the database in
# /etc/anexomail-desk/db.env (DESK_DB_URL, root-only, the Desk's OWN env file). It changes NOTHING (SELECTs only). Any row with ok = f makes it exit 1.
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"; ENVF=/etc/anexomail-desk/db.env
[ -r "$ENVF" ] || { echo "FAIL: $ENVF is missing. Create it ONCE with this line, then run the check again:"; echo "git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:admin-desk/scripts/ad-db-env.sh) 2>&1 | tail -6"; exit 2; }
. "$ENVF"; [ -n "${DESK_DB_URL:-}" ] || { echo "FAIL: DESK_DB_URL is empty in $ENVF"; exit 2; }
command -v psql >/dev/null || { echo "FAIL: psql not found"; exit 2; }
git -C "$REPO" fetch -q origin main || { echo "FAIL: fetch"; exit 2; }
T="$(mktemp)"; trap 'rm -f "$T"' EXIT; BAD=0; N=0
for f in $(git -C "$REPO" ls-tree --name-only origin/main admin-desk/sql/checks/ | sed -n 's#.*/\(AD[0-9][0-9]*[a-z]*\)-check\.sql$#\1#p' | sort -V); do
  git -C "$REPO" show "origin/main:admin-desk/sql/checks/$f-check.sql" >"$T"; N=$((N+1))
  echo "== check $f"; OUT="$(env -u PGHOST -u PGPORT -u PGUSER -u PGDATABASE -u PGSERVICE psql "$DESK_DB_URL" -X -q -P pager=off -f "$T" 2>&1)"; echo "$OUT" | sed 's/^/   /'
  echo "$OUT" | grep -qE '\| f( |$)|ERROR' && BAD=1
done
[ "$N" = 0 ] && { echo "FAIL: no check file found in origin/main"; exit 2; }
[ "$BAD" = 0 ] && echo "OK: every Desk SQL check row is true" || { echo "FAIL: a check row is false or errored"; exit 1; }
