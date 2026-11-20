#!/usr/bin/env bash
# qconnect-measure.sh (21 Nov 2026 01:15 PKT, QCONNECT step 9). READ ONLY. Local socket latency vs the managed REST latency, plus what the founder service itself says (engine line, SLOW lines). Prints no key.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/qconnect-measure.sh) 2>&1 | tail -30
unset PGHOST PGPORT PGSERVICE PGDATABASE PGUSER
S=/var/run/postgresql; SU=anexomail-founder
echo "== 1/3 what the running service says"
journalctl -u $SU -n 400 --no-pager 2>/dev/null | grep -o 'database engine = [A-Za-z ()0-9,;=.+-]*' | tail -1 | sed 's/^/   /'
echo "   SLOW lines in the last 10 min: $(journalctl -u $SU --since '10 min ago' --no-pager 2>/dev/null | grep -c SLOW)"; journalctl -u $SU --since '10 min ago' --no-pager 2>/dev/null | grep SLOW | tail -4 | cut -c1-160 | sed 's/^/   /'
echo "== 2/3 local socket, AS the service user, 30 round trips of a real door (localid_verify)"
T0=$(date +%s%N); for I in $(seq 1 30); do echo "select public.localid_verify();"; done | runuser -u $SU -- psql -X -q -At -h $S -d anexo_copy -c "set role service_role" -f - >/dev/null 2>&1; T1=$(date +%s%N)
echo "   30 calls in $(( (T1-T0)/1000000 )) ms in total (one process start included), about $(( (T1-T0)/30000000 )) ms each at worst"
echo "== 3/3 managed REST distance (read only, db-latency-check.sh)"
bash /opt/anexomail-web/docs/cursor-work/server/db-latency-check.sh 2>&1 | tail -8 | sed 's/^/   /'
echo "DONE (read only)."
