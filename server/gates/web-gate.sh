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

PUBLIC_ROUTES="/ /plans /security /ownership /move-in /anexochat /auth /status /docs /privacy /partners /enterprise /migration /about /pages"
APP_ROUTES="/app /app/mail /app/chat /app/work /app/people /app/calendar /app/crm /app/org /app/ai /app/analytics /app/admin /app/security /app/security/vault /app/settings /app/settings/appearance /app/billing /app/storage /app/devices /app/safety /app/perf"
FOUNDER_ROUTES="/app/founder /app/founder/crm /app/founder/billing /app/founder/security /app/founder/launch /app/founder/revenue"
AI_ROUTES="/ /ai /ai/studio /ai/automation /ai/knowledge /ai/credits /plans"
CRM_ROUTES="/ /app/crm /app/crm/leads /app/crm/pipeline /app/crm/activity"

echo "--- awam host: anexomail.com ---"
for r in $PUBLIC_ROUTES $APP_ROUTES; do
  check_http "anexomail.com$r" "https://anexomail.com$r" 200
done

echo "--- founder host: founderworkspace.anexomail.com ---"
for r in $PUBLIC_ROUTES $APP_ROUTES $FOUNDER_ROUTES; do
  check_http "founderworkspace$r" "https://founderworkspace.anexomail.com$r" 200
done

echo "--- AI host: ai.anexomail.com ---"
for r in $AI_ROUTES; do
  check_http "ai.anexomail.com$r" "https://ai.anexomail.com$r" 200
done

echo "--- CRM do host: aicrm (AI ON) + crm (AI-free) ---"
for h in aicrm.anexomail.com crm.anexomail.com; do
  for r in $CRM_ROUTES; do
    check_http "$h$r" "https://$h$r" 200
  done
done

echo "--- founder surface awam ke har host par band hona chahiye ---"
for h in anexomail.com www.anexomail.com ai.anexomail.com aicrm.anexomail.com crm.anexomail.com anexochat.anexomail.com; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "https://$h/app/founder" || echo 000)
  case "$code" in
    404 | 403 | 302) ok "$h par /app/founder band ($code)" ;;
    *) bad "$h par /app/founder band" "got $code — founder surface leak" ;;
  esac
done

echo "--- HTTPS + HTTP/3 (h3) har host par ---"
for h in anexomail.com founderworkspace.anexomail.com ai.anexomail.com aicrm.anexomail.com crm.anexomail.com anexochat.anexomail.com; do
  if curl -sSI --max-time 15 "https://$h/" | grep -qi '^alt-svc:.*h3'; then
    ok "$h HTTP/3 advertise"
  else
    bad "$h HTTP/3" "Alt-Svc h3 header nahi mila"
  fi
done

echo "--- brain API zinda ---"
check_http "127.0.0.1:3100 /api/health" "http://127.0.0.1:3100/api/health" 200
check_http "public /api/health" "https://anexomail.com/api/health" 200

gate_result "CADDY + FRONTEND"
