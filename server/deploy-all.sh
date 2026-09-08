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
#   6. Mail stack + TURN secret sync
#   7. Aakhir mein saare protocol gates (claim nahi, reading)
# ============================================================================
set -euo pipefail

ROOT="/opt/anexomail-web"
cd "$ROOT"

step() { echo; echo "=============== $* ==============="; }

step "0/7 DATABASE HEAL + FINAL MAILBOX LIST (idempotent)"
# Yeh do file jitni dafa chalao, wahi nateeja. Koi table drop nahi, koi row delete nahi.
#   phase57 -> purani mail_messages mein missing column (spf_result …) add karti hai
#   phase56 -> final address list (9 mailbox + 3 forward) set karti hai
bash sql/run.sh sql/phase57_mail_schema_heal.sql
bash sql/run.sh sql/phase56_mailbox_final.sql

step "1/7 FRONTEND (anexomail-web :3000)"
bun install
bun run build:bun
pm2 restart anexomail-web --update-env || pm2 start ecosystem.config.cjs

step "2/7 RUST PRIMARY ENGINE (:3200 + UDP :3443)"
bash server/rust/deploy.sh

step "3/7 POLAR PAYMENT ENGINE (:3400)"
bash server/rust/polar-payment/deploy.sh

step "4/7 CADDY (:80/:443 TCP + :443 UDP HTTP/3)"
bash server/caddy/deploy-sites.sh

step "5/7 SERVICES (:3100 + :3300 fallback + n8n :5678)"
pm2 restart anexochat --update-env
pm2 restart anexomail-leo --update-env
pm2 restart n8n --update-env
pm2 save

step "6/7 MAIL + TURN"
bash server/mail/deploy-mail.sh
bash server/rust/turn-env-sync.sh

step "7/7 COMPLETE PROTOCOL AUDIT"
bash server/gates/all-gates.sh

step "LIVE READINGS (asli codes)"
for u in \
  http://127.0.0.1:3000/ \
  http://127.0.0.1:3100/api/health \
  http://127.0.0.1:3200/rpc/health \
  http://127.0.0.1:3300/api/chat/health \
  http://127.0.0.1:3400/ready \
  http://127.0.0.1:3500/ready \
  http://127.0.0.1:3600/ready \
  http://127.0.0.1:5678/healthz; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$u" || echo 000)
  printf '%-55s -> %s\n' "$u" "$code"
done
for u in \
  https://anexomail.com/ \
  https://anexomail.com/file/ping \
  https://founderworkspace.anexomail.com/file/ping \
  https://ai.anexomail.com/file/ping \
  https://polarpayments.anexomail.com/ \
  https://polarpayments.anexomail.com/health \
  https://anexovideocall.anexomail.com/ready ; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$u" || echo 000)
  printf '%-55s -> %s\n' "$u" "$code"
done

echo
pm2 list --no-color
