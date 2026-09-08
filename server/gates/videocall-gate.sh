#!/usr/bin/env bash
# ============================================================================
# GATE 7 — ANEXOVideoCall (signaling · ICE · relay · recording)
#   bash server/gates/videocall-gate.sh
# ============================================================================
set -uo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

R=http://127.0.0.1:3200
TURNHOST=anexovideocall.anexomail.com

echo "=== GATE 7 · ANEXOVideoCall ==="

echo "--- signaling (Rust primary) ---"
for p in call.start call.join call.signal call.ice call.leave call.quality \
         call.consent call.record.start call.record.stop call.record.export \
         call.cost call.outcome; do
  check_body "rpc $p" "$R/rpc/$p" '{' -X POST -H 'content-type: application/json' --data '{}'
done
check_http "public signaling ingress" "https://anexochat.anexomail.com/rpc/health" 200

echo "--- relay (apna coturn, koi external API nahi) ---"
check_cmd "coturn active" systemctl is-active --quiet coturn
check_port "turn 3478 (tcp/udp)" 3478
check_port "turns 5349" 5349
check_http "turn host https" "https://$TURNHOST" 200
check_cmd "turn cert copy maujood" test -f /etc/anexochat/turn/fullchain.pem
check_body "ICE creds server-side HMAC" "$R/rpc/call.ice" 'credential' \
  -X POST -H 'content-type: application/json' --data '{}'

echo "--- DB truth ---"
for t in call_sessions call_participants call_events call_quality_samples \
         call_consent call_recordings call_cost; do
  check_sql "table $t" "select count(*)>0 from information_schema.tables where table_schema='public' and table_name='$t';" "t"
done
check_sql "recording sirf consent ke saath" \
  "select count(*)>0 from pg_proc where proname like '%call_record%';" "t"

echo "--- UI ---"
check_http "call panel" "https://anexomail.com/app/chat" 200
check_http "founder call view" "https://founderworkspace.anexomail.com/app/founder" 200

gate_result "ANEXOVideoCall"
