#!/usr/bin/env bash
# db-latency-check.sh (18 Nov 2026): READ-ONLY. Measures the network distance from this server to the founder database (Supabase REST), so the speed work is
# based on a measured fact, not a guess. Writes nothing, changes nothing, prints NO key and NO full URL (the project name is masked).
set -u
ENVF=/etc/anexomail/founder.env
[ -r "$ENVF" ] || { echo "no $ENVF"; exit 1; }
set -a; . "$ENVF"; set +a
URL="${SUPABASE4_URL:-}"; KEY="${SUPABASE4_SERVICE_ROLE_KEY:-}"
[ -n "$URL" ] && [ -n "$KEY" ] || { echo "database url or key missing in env"; exit 1; }
HOST=$(echo "$URL" | sed -E 's#https?://##; s#/.*##')
echo "== database host (masked): $(echo "$HOST" | sed -E 's/^[a-z0-9]+\./X./')"
echo "== server IP of database: $(getent hosts "$HOST" | awk '{print $1}' | head -1)"
IP=$(getent hosts "$HOST" | awk '{print $1}' | head -1)
echo "== ping (ICMP may be blocked, then it prints nothing):"
ping -c 4 -W 2 "$IP" 2>/dev/null | tail -2 | cut -c1-120
T="$URL/rest/v1/founder_accounts?select=user_id&limit=1"   # ONE tiny row: the root path returns the whole 1 MB OpenAPI schema, which is NOT a fair probe
echo "== 6 tiny REST calls, seconds (dns tcp tls first-byte total, a NEW connection each time, so tcp+tls show the handshake cost):"
for i in 1 2 3 4 5 6; do
  curl -s -o /dev/null -H "apikey: $KEY" -H "authorization: Bearer $KEY" -w "dns %{time_namelookup} tcp %{time_connect} tls %{time_appconnect} first %{time_starttransfer} total %{time_total}\n" "$T"
done
echo "== 6 tiny calls on ONE reused connection (what the Rust server really pays per call; the first line includes the handshake):"
curl -s -o /dev/null -H "apikey: $KEY" -H "authorization: Bearer $KEY" -w "%{time_total}\n" "$T" -o /dev/null "$T" -o /dev/null "$T" -o /dev/null "$T" -o /dev/null "$T" -o /dev/null "$T"
echo "== server location (public IP lookup is not used; only the system timezone):"; timedatectl 2>/dev/null | grep "Time zone"
echo "DONE: read-only, nothing changed."
