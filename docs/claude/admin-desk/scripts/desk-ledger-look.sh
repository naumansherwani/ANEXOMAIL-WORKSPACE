#!/usr/bin/env bash
# ANEXOMAIL ADMIN DESK: READ-ONLY look at the ledger probe (his 24 Nov 2026 05:52 "DO": the Systems page showed Audit trail as slow or partly down).
# Changes NOTHING (every statement runs with default_transaction_read_only=on), prints no secret. Question: is the ledger CHAIN broken, or is the ledger check only slow?
set +e
ENVF="${ENVF:-/etc/anexomail-desk/db.env}"
[ -r "$ENVF" ] || { echo "FAIL: $ENVF missing"; exit 2; }
. "$ENVF"; [ -n "${DESK_DB_URL:-}" ] || { echo "FAIL: DESK_DB_URL empty"; exit 2; }
export PGOPTIONS="-c default_transaction_read_only=on"
Q(){ env -u PGHOST -u PGPORT -u PGUSER -u PGDATABASE -u PGSERVICE psql "$DESK_DB_URL" -X -At -F ' | ' -c "$1" 2>&1 | head -${2:-30}; }
echo "== 1. ledger size and newest line"
Q "select count(*)||' lines, newest '||coalesce(max(ts)::text,'none') from desk.fadm_ledger"
echo "== 2. the ledger service row: how often it is probed, the slow limit (ms), the state RIGHT NOW"
Q "select 'probe every '||probe_every_s||' s, slow limit '||degraded_ms||' ms, state now = '||desk.fadm_service_state(service) from desk.fadm_service where service='ledger'"
echo "== 3. last 12 probes of the ledger (time | ok | ms | note)"
Q "select at::timestamp(0), ok, latency_ms, left(detail->>'note',60) from desk.fadm_probe where service='ledger' order by at desc, id desc limit 12" 14
echo "== 4. last 24 hours: probes | failed | slower than the limit | slowest ms"
Q "select count(*), count(*) filter (where not ok), count(*) filter (where latency_ms > (select degraded_ms from desk.fadm_service where service='ledger')), max(latency_ms) from desk.fadm_probe where service='ledger' and at > now() - interval '1 day'"
echo "== 5. the chain check run NOW by this script (true = every line chains to the one before; ms = how long it took)"
Q "do \$\$ declare t0 timestamptz := clock_timestamp(); v boolean; begin v := desk.fadm_ledger_verify(); raise notice 'chain verifies = %, took % ms', v, round(extract(epoch from clock_timestamp()-t0)*1000); end \$\$" 5
echo "DONE: read only, nothing was changed"
