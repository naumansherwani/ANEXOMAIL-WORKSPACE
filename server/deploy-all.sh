#!/usr/bin/env bash
# ============================================================================
# ANEXOMAIL — ONE COMMAND FULL AUTO-SYNC (Server 2)
#
#   cd /opt/anexomail-web && git pull && bash server/deploy-all.sh
#
# Yeh script sab kuch khud sync karti hai — Nauman koi file nano/overwrite
# nahi karta. Secrets (.env) KABHI touch nahi hoti.
#   1. frontend build + pm2 restart (anexomail-web)
#   2. Rust PRIMARY engine  (server/rust/deploy.sh)          :3200
#   3. Polar payment engine (server/rust/polar-payment/...)  :3400
#   4. Caddy site blocks + main Caddyfile auto-patch         (443 / h3)
#   5. Bun fallback restart (anexochat, anexomail-leo)
#   6. Aakhir mein asli HTTP readings (claim nahi, reading)
# ============================================================================
set -uo pipefail

ROOT="/opt/anexomail-web"
cd "$ROOT"

step() { echo; echo "=============== $* ==============="; }

step "1/5 FRONTEND (anexomail-web :3000)"
bun install || true
bun run build:node || echo "!!! frontend build fail — purana build zinda hai"
pm2 restart anexomail-web --update-env || pm2 start ecosystem.config.cjs || true

step "2/5 RUST PRIMARY ENGINE (:3200)"
bash server/rust/deploy.sh || echo "!!! rust deploy fail"

step "3/5 POLAR PAYMENT ENGINE (:3400)"
bash server/rust/polar-payment/deploy.sh || echo "!!! polar deploy fail"

step "4/5 CADDY (sites + main Caddyfile auto-patch)"
bash server/caddy/deploy-sites.sh || echo "!!! caddy deploy fail"

step "5/5 BUN FALLBACKS"
pm2 restart anexochat --update-env || true
pm2 restart anexomail-leo --update-env || true
pm2 save || true

step "LIVE READINGS (asli codes)"
for u in \
  https://anexomail.com/ \
  https://anexomail.com/file/ping \
  https://founderworkspace.anexomail.com/file/ping \
  https://ai.anexomail.com/file/ping \
  https://polarpayments.anexomail.com/ \
  https://polarpayments.anexomail.com/health \
  https://anexovideocall.anexomail.com/ ; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$u" || echo 000)
  printf '%-55s -> %s\n' "$u" "$code"
done

echo
pm2 list --no-color || true
