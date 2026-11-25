#!/usr/bin/env bash
# Runs sql/legacy-rename.sql on the Desk database BEFORE ad-auto (so AD01's fadm_* table law passes). Read-only when nothing needs renaming. Called only by desk-sql-install.sh.
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"; ENVF=/etc/anexomail-desk/db.env
[ -r "$ENVF" ] || { echo "FAIL: $ENVF missing, run ad-db-env.sh first"; exit 2; }
. "$ENVF"; [ -n "${DESK_DB_URL:-}" ] || { echo "FAIL: DESK_DB_URL empty"; exit 2; }
F="$(mktemp)"; trap 'rm -f "$F"' EXIT
git -C "$REPO" show origin/main:admin-desk/sql/legacy-rename.sql >"$F" || { echo "FAIL: legacy-rename.sql not on origin/main"; exit 2; }
O="$(env -u PGHOST -u PGPORT -u PGUSER -u PGDATABASE -u PGSERVICE psql "$DESK_DB_URL" -X -q -v ON_ERROR_STOP=1 -P pager=off -f "$F" 2>&1)"; RC=$?
echo "$O" | grep -E 'LEGACY RENAME|ERROR' | sed 's/^psql:[^ ]* //'
[ "$RC" = 0 ] || { echo "FAIL: legacy rename"; exit 1; }
