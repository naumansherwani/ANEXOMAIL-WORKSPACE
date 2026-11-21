#!/usr/bin/env bash
# ANEXOMAIL ADMIN DESK: create the Desk's OWN env file /etc/anexomail-desk/db.env (root-only, 0600) holding DESK_DB_URL, ONCE, by HIS explicit run.
# Why: the Desk SQL check must reach the same database his SQL editor ran AD1 in. The URL is the one his existing SQL runner already uses (the same database); it is copied ONE time and only its HOST is printed, never the secret.
# DESK ISOLATION NOTE: this URL is an ADMIN URL, used ONLY by ad-check.sh. When AD1b gives desk_app its own login, the running Desk binary gets a desk_app URL in this same file instead (never the admin URL).
set -uo pipefail
SRC=/etc/anexomail/sync.env; DST=/etc/anexomail-desk/db.env
[ -r "$SRC" ] || { echo "FAIL: $SRC not readable"; exit 2; }
[ -f "$DST" ] && grep -q '^DESK_DB_URL=' "$DST" && { echo "already there: $DST (host: $(. "$DST"; echo "$DESK_DB_URL" | sed -e 's#^[a-z]*://[^@]*@##' -e 's#[:/?].*##'))"; exit 0; }
( . "$SRC" 2>/dev/null; [ -n "${WORKING_URL:-}" ] || { echo "FAIL: no database URL in $SRC"; exit 2; }
  umask 077; mkdir -p /etc/anexomail-desk; printf 'DESK_DB_URL=%q\n' "$WORKING_URL" >"$DST"; chmod 600 "$DST"
  echo "written: $DST (root-only). database host: $(echo "$WORKING_URL" | sed -e 's#^[a-z]*://[^@]*@##' -e 's#[:/?].*##')" ) || exit $?
echo "next: run the Desk SQL check line"
