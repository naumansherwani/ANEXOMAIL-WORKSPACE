#!/usr/bin/env bash
# ============================================================================
# GATE 3 — CADDY + FRONTEND (awam host + founder host)
#   bash server/gates/web-gate.sh
# Har asli route ka HTTP code padhta hai. Koi cheez badalta nahi.
# ============================================================================
set -uo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

echo "=== GATE 3 · CADDY + FRONTEND ==="

check_cmd "caddy config valid" caddy validate --config /etc/caddy/Caddyfile
check_cmd "caddy service active" systemctl is-active --quiet caddy
check_pm2 anexomail-web
check_pm2 anexomail-leo
check_port "frontend SSR" 3000
check_port "brain api" 3100

PUBLIC_ROUTES="/ /plans /security /ownership /move-in /anexochat /auth /status /docs /pages"
APP_ROUTES="/app /app/mail /app/chat /app/work /app/people /app/calendar /app/crm /app/org /app/ai /app/analytics /app/admin /app/security /app/security/vault /app/settings /app/settings/appearance /app/billing"
FOUNDER_ROUTES="/app/founder /app/founder/crm /app/founder/billing /app/founder/security"

echo "--- awam host: anexomail.com ---"
for r in $PUBLIC_ROUTES $APP_ROUTES; do
  check_http "anexomail.com$r" "https://anexomail.com$r" 200
done

echo "--- founder host: founderworkspace.anexomail.com ---"
for r in $PUBLIC_ROUTES $APP_ROUTES $FOUNDER_ROUTES; do
  check_http "founderworkspace$r" "https://founderworkspace.anexomail.com$r" 200
done

echo "--- AI host: ai.anexomail.com ---"
check_http "ai.anexomail.com/" "https://ai.anexomail.com/" 200

echo "--- founder surface public host par band hona chahiye ---"
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 https://anexomail.com/app/founder || echo 000)
if [ "$code" = "404" ] || [ "$code" = "403" ] || [ "$code" = "302" ]; then
  ok "public host par /app/founder band ($code)"
else
  bad "public host par /app/founder band" "got $code — founder surface leak"
fi

echo "--- brain API zinda ---"
check_http "127.0.0.1:3100 /api/health" "http://127.0.0.1:3100/api/health" 200
check_http "public /api/health" "https://anexomail.com/api/health" 200

gate_result "CADDY + FRONTEND"
