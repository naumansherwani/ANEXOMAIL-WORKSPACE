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

step "0/8 DATABASE HEAL + FINAL MAIL CONTRACT + MAILBOX LIST (idempotent)"
# Yeh files jitni dafa chalao, wahi nateeja. Mail row/table delete nahi hoti.
#   phase57 -> purani mail tables mein missing canonical columns add karti hai
#   phase58 -> live ingest function + legacy cc_addrs compatibility + schema reload
#   phase56 -> final address list (9 mailbox/sendonly + 3 forward) set karti hai
for migration in \
  sql/phase57_mail_schema_heal.sql \
  sql/phase58_mail_contract_final.sql \
  sql/phase59_account_lifecycle.sql \
  sql/phase56_mailbox_final.sql; do
  [ -f "$migration" ] || { echo "RED missing migration: $migration"; exit 10; }
  bash sql/run.sh "$migration" || { echo "RED migration failed: $migration"; exit 10; }
  echo "APPLIED $migration"
done

[ -f anexochat/sql/phase31b_family_chat_workspace.sql ] || {
  echo "RED missing migration: anexochat/sql/phase31b_family_chat_workspace.sql"
  exit 10
}
bash sql/run.sh anexochat/sql/phase31b_family_chat_workspace.sql || {
  echo "RED migration failed: anexochat/sql/phase31b_family_chat_workspace.sql"
  exit 10
}
echo "APPLIED anexochat/sql/phase31b_family_chat_workspace.sql"

MAIL_CONTRACT="$(bash sql/run.sh --query "select concat_ws('|', (exists(select 1 from information_schema.columns where table_schema='public' and table_name='mailboxes' and column_name='org_id'))::int, (exists(select 1 from information_schema.columns where table_schema='public' and table_name='mail_messages' and column_name='cc_addrs'))::int, coalesce(obj_description('public.mail_ingest(jsonb)'::regprocedure),'missing'))" | tr -d '[:space:]')"
[ "$MAIL_CONTRACT" = "1|1|anexomail-mail-contract-v59" ] || {
  echo "RED live mail contract mismatch: $MAIL_CONTRACT"
  exit 11
}
echo "GREEN live mail contract v59"

step "1/8 FRONTEND (anexomail-web :3000)"
bun install
bun run build:bun
pm2 restart anexomail-web --update-env || pm2 start ecosystem.config.cjs

step "2/8 BRAIN API (:3100)"
bash server/deploy-brain.sh

step "3/8 RUST PRIMARY ENGINE (:3200 + UDP :3443)"
bash server/rust/deploy.sh

step "4/8 POLAR PAYMENT ENGINE (:3400)"
bash server/rust/polar-payment/deploy.sh

step "5/8 CADDY (:80/:443 TCP + :443 UDP HTTP/3)"
bash server/caddy/deploy-sites.sh

step "6/8 SERVICES (:3300 fallback + n8n :5678)"
pm2 restart anexochat --update-env
pm2 restart n8n --update-env
pm2 save

step "7/8 MAIL + TURN"
bash server/mail/deploy-mail.sh
bash server/rust/turn-env-sync.sh

step "8/8 COMPLETE PROTOCOL AUDIT"
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
