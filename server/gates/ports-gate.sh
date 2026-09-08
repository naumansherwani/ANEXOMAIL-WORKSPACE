#!/usr/bin/env bash
# ============================================================================
# SERVER PORT MAP — har deployed arm ka asli protocol/listener proof
# Caddy sirf HTTP(S) edge :80/:443 hai. SMTP, IMAP, TURN, QUIC aur DB ko
# Caddy se fake HTTP 200 banana protocol tor deta hai; unko listener/protocol
# handshake se verify kiya jata hai.
# ============================================================================
set -uo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

echo "=== SERVER PORT MAP ==="

echo "--- HTTP / HTTPS ---"
check_port "Caddy HTTP" 80
check_port "Caddy HTTPS TCP" 443
check_cmd "Caddy HTTP/3 UDP 443" bash -c "ss -lnu | grep -q ':443 '"
check_http "frontend SSR :3000" "http://127.0.0.1:3000/" 200
check_http "LEO API :3100" "http://127.0.0.1:3100/api/health" 200
check_http "Rust primary :3200" "http://127.0.0.1:3200/rpc/health" 200
check_http "chat fallback :3300" "http://127.0.0.1:3300/api/chat/health" 200
check_http "payments :3400" "http://127.0.0.1:3400/ready" 200
check_pm2 "n8n"
check_http "n8n :5678" "http://127.0.0.1:5678/healthz" 200

echo "--- UDP / mail protocols ---"
check_cmd "Rust WebTransport UDP 3443" bash -c "ss -lnu | grep -q ':3443 '"
check_port "coturn 3478" 3478
check_port "coturn TLS 5349" 5349
check_port "Postfix SMTP 25" 25
check_port "Postfix submission 587" 587
check_port "Postfix submissions 465" 465
check_port "Dovecot IMAPS 993" 993
check_cmd "Dovecot IMAP 143 listener" bash -c "ss -lnt | grep -Eq '(^|[[:space:]])(127\\.0\\.0\\.1|0\\.0\\.0\\.0|\\[::\\]):143[[:space:]]'"

echo "--- outbound database path ---"
check_cmd "database pooler 6543 reachable" bash -c ". /root/.anexomail.env 2>/dev/null || true; timeout 8 bash /opt/anexomail-web/sql/run.sh --query 'select 1' | tr -d '[:space:]' | grep -qx 1"

echo "--- SFU media + private observability ---"
check_cmd "SFU control tcp 3500" bash -c "ss -lnt | grep -q ':3500 '"
check_cmd "SFU media udp 3501" bash -c "ss -lnu | grep -q ':3501 '"
check_http "SFU control readiness" "http://127.0.0.1:3500/ready" 200
# jhoota listener kaafi nahi — asli do participants ke darmiyan packet forward hota hai
check_cmd "SFU asli packet forwarding" python3 /opt/anexomail-web/server/gates/sfu-packet-proof.py
check_body "SFU forwarded counter barha" "http://127.0.0.1:3500/metrics" 'anexomail_sfu_packets_forwarded'
check_http "Rust private readiness :3600" "http://127.0.0.1:3600/ready" 200
check_body "Rust private metrics :3600" "http://127.0.0.1:3600/metrics" 'anexomail_webtransport_live 1'

gate_result "SERVER PORT MAP"