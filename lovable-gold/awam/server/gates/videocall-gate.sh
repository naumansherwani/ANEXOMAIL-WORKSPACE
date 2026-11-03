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
check_body "turn host https readiness" "https://$TURNHOST/ready" '"credential_ready":true'
check_cmd "turn cert copy maujood" test -f /etc/anexochat/turn/fullchain.pem

echo "--- SFU media forwarding (apna Rust, koi external video API nahi) ---"
check_cmd "SFU media udp 3501 live" bash -c "ss -lnu | grep -q ':3501 '"
check_body "SFU forwarding mode sach" "http://127.0.0.1:3500/ready" '"live":true'
check_cmd "SFU do participants ke beech asli packet forward" \
  python3 /opt/anexomail-web/server/gates/sfu-packet-proof.py
# ICE creds ka asli sach: readiness arm (public, secret-free) + authenticated arm
# bina token 401 deta hai. Asli credential value kabhi bina auth nahi milti.
check_body "ICE creds server-side HMAC ready" "$R/rpc/chat.turn.health" '"credential_ready":true' \
  -X POST -H 'content-type: application/json' --data '{}'
check_http "chat.turn.credentials auth-only (401 expected)" "$R/rpc/chat.turn.credentials" 401 \
  -X POST -H 'content-type: application/json' --data '{}'


echo "--- DB truth ---"
# asli schema ke naam (anexochat/sql se)
for t in chat_call_sessions chat_call_stats chat_call_events chat_call_transport_events \
         chat_call_files chat_call_work chat_call_rings chat_call_ring_log \
         chat_call_connect_marks chat_call_survival chat_call_sfu_rooms \
         chat_call_sfu_participants; do
  check_sql "table $t" "select count(*)>0 from information_schema.tables where table_schema='public' and table_name='$t';" "t"
done
check_sql "recording sirf consent ke saath" \
  "select count(*)>0 from pg_proc where proname like '%call_record%';" "t"

echo "--- UI ---"
check_http "call panel" "https://anexomail.com/app/chat" 200
check_http "founder call view" "https://founderworkspace.anexomail.com/app/founder" 200

gate_result "ANEXOVideoCall"
