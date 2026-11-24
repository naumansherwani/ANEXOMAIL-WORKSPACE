#!/usr/bin/env bash
# ANEXOMAIL ADMIN DESK: READ-ONLY look at the device-bound-session refusals (found by the Ledger card 24 Nov 2026 08:51: 42,563 'dbsc.refused' lines in 24 hours).
# Changes NOTHING (every statement runs with default_transaction_read_only=on), prints no secret and no session id. Question: WHICH refusal repeats, at what rate, from which step, and how many different sessions?
set +e
ENVF="${ENVF:-/etc/anexomail-desk/db.env}"
[ -r "$ENVF" ] || { echo "FAIL: $ENVF missing"; exit 2; }
. "$ENVF"; [ -n "${DESK_DB_URL:-}" ] || { echo "FAIL: DESK_DB_URL empty"; exit 2; }
export PGOPTIONS="-c default_transaction_read_only=on"
Q(){ env -u PGHOST -u PGPORT -u PGUSER -u PGDATABASE -u PGSERVICE psql "$DESK_DB_URL" -X -At -F ' | ' -c "$1" 2>&1 | head -${2:-30}; }
echo "== 1. last 24 hours: why | step | lines | different sessions | first | last"
Q "select detail->>'why', detail->>'step', count(*), count(distinct detail->>'session'), min(ts)::timestamp(0), max(ts)::timestamp(0) from desk.fadm_ledger where kind='dbsc.refused' and ts > now()-interval '24 hours' group by 1,2 order by 3 desc" 14
echo "== 2. rate per hour of dbsc.refused (hour | lines)"
Q "select date_trunc('hour', ts)::timestamp(0), count(*) from desk.fadm_ledger where kind='dbsc.refused' and ts > now()-interval '24 hours' group by 1 order by 1 desc" 26
echo "== 3. which accounts (role only): role | lines"
Q "select coalesce((select role from desk.fadm_owner o where o.id=l.actor),'system/unknown'), count(*) from desk.fadm_ledger l where kind='dbsc.refused' and ts > now()-interval '24 hours' group by 1" 6
echo "== 4. DBSC mode of the running Desk (observe / enforce / off)"
systemctl show anexomail-desk -p Environment 2>/dev/null | tr ' ' '\n' | grep -i "DESK_DBSC" | head -2
echo "DONE: read only, nothing was changed"
