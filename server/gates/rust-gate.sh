#!/usr/bin/env bash
# ============================================================================
# GATE 2 — RUST PRIMARY ENGINE (:3200 + QUIC/WebTransport 3443)
#   bash server/gates/rust-gate.sh
# Sirf padhta hai. Deploy ke baad chalao.
# ============================================================================
set -uo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

echo "=== GATE 2 · RUST ENGINE ==="

check_pm2 anexomail-rust
check_port "rust engine" 3200

# local truth
check_http "local /rpc/health"        "http://127.0.0.1:3200/rpc/health" 200
check_body "health JSON asli"         "http://127.0.0.1:3200/rpc/health" '"status":"up"'
check_http "local /file/ping"         "http://127.0.0.1:3200/file/ping" 200

# asli RPC dispatch: unknown proc par bhi engine JSON deti hai (routing zinda)
check_body "rpc dispatch zinda" "http://127.0.0.1:3200/rpc/chat.ping" '{' \
  -X POST -H 'content-type: application/json' --data '{}'

# public ingress (Caddy -> 3200)
for h in anexomail.com founderworkspace.anexomail.com ai.anexomail.com anexochat.anexomail.com; do
  check_http "public https://$h/rpc/health" "https://$h/rpc/health" 200
  check_http "public https://$h/file/ping"  "https://$h/file/ping"  200
done

# HTTP/3 advertisement (QUIC edge zinda)
if curl -sSI --max-time 15 https://anexomail.com/rpc/health | grep -qi '^alt-svc:.*h3'; then
  ok "HTTP/3 (h3) advertise ho raha hai"
else
  bad "HTTP/3 advertise" "Alt-Svc h3 header nahi mila"
fi

# WebTransport UDP 3443 — engine sach bolta hai, jhoot nahi
if ss -lnu 2>/dev/null | grep -q ':3443 '; then
  ok "WebTransport UDP 3443 listening"
else
  bad "WebTransport UDP 3443" "cert na hone par engine WT OFF rakhti hai (sach) — /rpc/* fallback zinda"
fi

gate_result "RUST ENGINE :3200"
