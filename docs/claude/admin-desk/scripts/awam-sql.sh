#!/usr/bin/env bash
# AWAM-DATABASE SQL for the Control Plane (his 25 Nov 2026 03:50 order: the WEB install carries NO SQL, like founder-install.sh; SQL runs only through SQL commands).
# Called by desk-sql-install.sh. Runs AD21..AD26 + AD31 (+ CHECKs) on the awam database, sets the cp_lookup password and stores the read-only URL root-only in /etc/anexomail-controlplane/db.url for cp-install.sh.
set -u
REPO="${REPO:-/opt/anexomail-web}"; ETC=/etc/anexomail-controlplane
for t in psql openssl python3; do command -v $t >/dev/null 2>&1 || { echo "FAIL: $t not found"; exit 2; }; done
git -C "$REPO" fetch -q origin main || { echo "FAIL: fetch"; exit 2; }
show() { git -C "$REPO" show "origin/main:$1"; }
ADMIN="$( . /etc/anexomail/sync.env 2>/dev/null; printf %s "${WORKING_URL:-}" )"; [ -n "$ADMIN" ] || { echo "FAIL: no WORKING_URL in sync.env"; exit 2; }
psqla() { env -u PGHOST -u PGPORT -u PGUSER -u PGDATABASE -u PGSERVICE psql "$ADMIN" -X -q -At -v ON_ERROR_STOP=1 "$@"; }
echo "== CP 3/7 database: AD21.sql + CHECK + read-only login cp_lookup"
S="$(mktemp)"; show admin-desk/sql/AD21.sql >"$S"; psqla -f "$S" 2>&1 | tail -3; [ "${PIPESTATUS[0]}" = 0 ] || { echo "FAIL: AD21.sql (a table it reads is missing?)"; rm -f "$S"; exit 4; }
show admin-desk/sql/checks/AD21-check.sql >"$S"; CH="$(psqla -f "$S" 2>&1)"; rm -f "$S"; echo "$CH" | sed 's/^/   /'
echo "$CH" | grep -q '|f$' && { echo "FAIL: AD21 CHECK has a false row"; exit 4; }; echo "$CH" | grep -qi error && { echo "FAIL: AD21 CHECK error"; exit 4; }
echo "== CP 3b/7 database: AD22.sql (census for Customers and Plans) + selftest + CHECK"
S="$(mktemp)"; show admin-desk/sql/AD22.sql >"$S"; C2="$(psqla -f "$S" 2>&1 | tail -4)"; C2R=$?; rm -f "$S"; echo "$C2" | sed 's/^/   /'
S="$(mktemp)"; show admin-desk/sql/checks/AD22-check.sql >"$S"; CH2="$(psqla -f "$S" 2>&1)"; rm -f "$S"; echo "$CH2" | sed 's/^/   /'
if echo "$CH2" | grep -q '|f$' || echo "$CH2" | grep -qi error || echo "$C2" | grep -qi "error"; then echo "WARN: AD22 did not install cleanly: the Customers and Plans card will say Data unavailable (fail-closed) until it is fixed; the rest of the install continues"; else echo "OK: AD22 census installed and CHECKed"; fi
echo "== CP 3c/7 database: AD23.sql (deliverability for the Deliverability card) + selftest + CHECK"
S="$(mktemp)"; show admin-desk/sql/AD23.sql >"$S"; C3="$(psqla -f "$S" 2>&1 | tail -4)"; rm -f "$S"; echo "$C3" | sed 's/^/   /'
S="$(mktemp)"; show admin-desk/sql/checks/AD23-check.sql >"$S"; CH3="$(psqla -f "$S" 2>&1)"; rm -f "$S"; echo "$CH3" | sed 's/^/   /'
if echo "$CH3" | grep -q '|f$' || echo "$CH3" | grep -qi error || echo "$C3" | grep -qi "error"; then echo "WARN: AD23 did not install cleanly: the Deliverability card will say Data unavailable (fail-closed) until it is fixed; the rest of the install continues"; else echo "OK: AD23 deliverability installed and CHECKed"; fi
echo "== CP 3d/7 database: AD24.sql (six packages, No plan yet, plan detail for the Customers card) + selftest + CHECK"
S="$(mktemp)"; show admin-desk/sql/AD24.sql >"$S"; C4="$(psqla -f "$S" 2>&1 | tail -4)"; rm -f "$S"; echo "$C4" | sed 's/^/   /'
S="$(mktemp)"; show admin-desk/sql/checks/AD24-check.sql >"$S"; CH4="$(psqla -f "$S" 2>&1)"; rm -f "$S"; echo "$CH4" | sed 's/^/   /'
if echo "$CH4" | grep -q '|f$' || echo "$CH4" | grep -qi error || echo "$C4" | grep -qi "error"; then echo "WARN: AD24 did not install cleanly: the Customers card will say Data unavailable (fail-closed) until it is fixed; the rest of the install continues"; else echo "OK: AD24 customers census installed and CHECKed"; fi
echo "== CP 3e/7 database: AD25.sql (B13 Z4a: customer consent inbox + hash-chained ledger, the Control Plane can push/cancel/poll but never decide) + selftest + CHECK"
S="$(mktemp)"; show admin-desk/sql/AD25.sql >"$S"; C5="$(psqla -f "$S" 2>&1 | tail -4)"; rm -f "$S"; echo "$C5" | sed 's/^/   /'
S="$(mktemp)"; show admin-desk/sql/checks/AD25-check.sql >"$S"; CH5="$(psqla -f "$S" 2>&1)"; rm -f "$S"; echo "$CH5" | sed 's/^/   /'
if echo "$CH5" | grep -q '|f$' || echo "$CH5" | grep -qi error || echo "$C5" | grep -qi "error"; then echo "WARN: AD25 did not install cleanly: customer consent stays closed (requests cannot be approved) until it is fixed; the rest of the install continues"; else echo "OK: AD25 consent inbox installed and CHECKed"; fi
echo "== CP 3f/7 database: AD26.sql (B13 T1: tenant registry check + versioned domain ownership + first history fill) + selftest + CHECK"
S="$(mktemp)"; show admin-desk/sql/AD26.sql >"$S"; C6="$(psqla -f "$S" 2>&1 | tail -4)"; rm -f "$S"; echo "$C6" | sed 's/^/   /'
S="$(mktemp)"; show admin-desk/sql/checks/AD26-check.sql >"$S"; CH6="$(psqla -f "$S" 2>&1)"; rm -f "$S"; echo "$CH6" | sed 's/^/   /'
if echo "$CH6" | grep -q '|f$' || echo "$CH6" | grep -qi error || echo "$C6" | grep -qi "error"; then echo "WARN: AD26 did not install cleanly: tenant binding stays closed (no consent request can be bound to a tenant) until it is fixed; the rest of the install continues"; else echo "OK: AD26 tenant registry + domain ownership installed and CHECKed"; fi
PW="$(openssl rand -hex 24)"
URL="$(ADMIN_URL="$ADMIN" CPW="$PW" python3 - <<'P'
import os,urllib.parse as u
a=u.urlsplit(os.environ["ADMIN_URL"]); user=u.unquote(a.username or "postgres")
nu="cp_lookup"+("."+user.split(".",1)[1] if "." in user else "")
host=a.hostname+(":"+str(a.port) if a.port else ""); q=dict(u.parse_qsl(a.query)); q.setdefault("sslmode","require")
print(u.urlunsplit((a.scheme,nu+":"+os.environ["CPW"]+"@"+host,a.path,u.urlencode(q),"")))
P
)" || { echo "FAIL: cp_lookup url"; exit 4; }
printf "alter role cp_lookup login password :'pw';\n" | psqla -v pw="$PW" 2>&1 | tail -2; [ "${PIPESTATUS[1]}" = 0 ] || { echo "FAIL: ALTER ROLE cp_lookup"; exit 4; }; unset PW
echo "== CP 3g/7 database: AD31.sql (B13 T3a: cp.resolve_sender, sender to tenant verdict) + selftest + CHECK"
S="$(mktemp)"; show admin-desk/sql/AD31.sql >"$S"; C7="$(psqla -f "$S" 2>&1 | tail -4)"; rm -f "$S"; echo "$C7" | sed 's/^/   /'
S="$(mktemp)"; show admin-desk/sql/checks/AD31-check.sql >"$S"; CH7="$(psqla -f "$S" 2>&1)"; rm -f "$S"; echo "$CH7" | sed 's/^/   /'
if echo "$CH7" | grep -q '|f$' || echo "$CH7" | grep -qi error || echo "$C7" | grep -qi "error"; then echo "WARN: AD31 did not install cleanly: the sender verdict stays closed (every sender is unknown) until it is fixed; the rest of the install continues"; else echo "OK: AD31 sender-to-tenant verdict installed and CHECKed"; fi
mkdir -p -m 700 "$ETC"; ( umask 077; printf %s "$URL" >"$ETC/db.url" ); unset URL; chmod 600 "$ETC/db.url"; echo "   read-only login URL stored root-only (never printed)"
echo "== AWAM SQL PROOFS"
show(){ git -C "$REPO" show "origin/main:$1"; }
# 9b (his 23 Nov 2026 07:12: a step that is installed must be PROVEN in the last lines, never hidden above them): the census function of the Control Plane (AD22, Customers and Plans) is checked LAST, read-only.
ADMINU="$( . /etc/anexomail/sync.env 2>/dev/null; printf %s "${WORKING_URL:-}" )"
AD22="$(show admin-desk/sql/checks/AD22-check.sql | env -u PGHOST -u PGPORT -u PGUSER -u PGDATABASE -u PGSERVICE psql "${ADMINU:-postgres://none}" -X -q -At -f - 2>&1)"
CPT="$(printf '%s\n' "$AD22" | grep -c '|t$')"; CPF="$(printf '%s\n' "$AD22" | grep -c '|f$')"
if [ -n "$ADMINU" ] && [ "$CPT" -ge 8 ] && [ "$CPF" = 0 ]; then echo "   PROOF census (AD22): cp.census is in the awam database, CHECK $CPT of $CPT true"; else echo "   PROOF census (AD22): NOT PROVEN (true $CPT, false $CPF): the Customers and Plans card will say Data unavailable until this is fixed"; fi
AD24="$(show admin-desk/sql/checks/AD24-check.sql | env -u PGHOST -u PGPORT -u PGUSER -u PGDATABASE -u PGSERVICE psql "${ADMINU:-postgres://none}" -X -q -At -f - 2>&1)"
AD24T="$(printf '%s\n' "$AD24" | grep -c '|t$')"; AD24F="$(printf '%s\n' "$AD24" | grep -c '|f$')"
if [ -n "$ADMINU" ] && [ "$AD24T" -ge 6 ] && [ "$AD24F" = 0 ]; then echo "   PROOF customers plans (AD24): six packages + No plan yet + per-plan detail are in the awam database, CHECK $AD24T of $AD24T true"; else echo "   PROOF customers plans (AD24): NOT PROVEN (true $AD24T, false $AD24F): the Customers card will say Data unavailable until this is fixed"; fi
AD31="$(show admin-desk/sql/checks/AD31-check.sql | env -u PGHOST -u PGPORT -u PGUSER -u PGDATABASE -u PGSERVICE psql "${ADMINU:-postgres://none}" -X -q -At -f - 2>&1)"
AD31T="$(printf '%s\n' "$AD31" | grep -c '|t$')"; AD31F="$(printf '%s\n' "$AD31" | grep -c '|f$')"
if [ -n "$ADMINU" ] && [ "$AD31T" -ge 8 ] && [ "$AD31F" = 0 ]; then echo "   PROOF sender verdict (AD31): cp.resolve_sender is in the awam database, CHECK $AD31T of $AD31T true"; else echo "   PROOF sender verdict (AD31): NOT PROVEN (true $AD31T, false $AD31F): every sender stays unknown until this is fixed"; fi
AD23="$(show admin-desk/sql/checks/AD23-check.sql | env -u PGHOST -u PGPORT -u PGUSER -u PGDATABASE -u PGSERVICE psql "${ADMINU:-postgres://none}" -X -q -At -f - 2>&1)"
AD23T="$(printf '%s\n' "$AD23" | grep -c '|t$')"; AD23F="$(printf '%s\n' "$AD23" | grep -c '|f$')"
if [ -n "$ADMINU" ] && [ "$AD23T" -ge 9 ] && [ "$AD23F" = 0 ]; then echo "   PROOF deliverability (AD23): cp.deliverability is in the awam database, CHECK $AD23T of $AD23T true"; else echo "   PROOF deliverability (AD23): NOT PROVEN (true $AD23T, false $AD23F): the Deliverability card will say Data unavailable until this is fixed"; fi
