#!/usr/bin/env bash
# ============================================================================
# GATE 6 — ANEXOChat (feature-by-feature)
#   bash server/gates/chat-gate.sh
# Rust PRIMARY :3200 /rpc/* · Bun fallback :3300 /api/chat/* · DB truth
# ============================================================================
set -uo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

R=http://127.0.0.1:3200
B=http://127.0.0.1:3300

echo "=== GATE 6 · ANEXOChat ==="

check_pm2 anexochat
check_port "chat fallback" 3300
check_http "chat host live" "https://anexochat.anexomail.com/" 200
check_http "chat panel (app)" "https://anexomail.com/app/chat" 200

rpc() { # rpc <label> <proc>
  check_body "rpc $2" "$R/rpc/$2" '{' -X POST -H 'content-type: application/json' --data '{}'
}

echo "--- Rust arms (PRIMARY) ---"
for p in chat.conversations chat.messages chat.send chat.search.deep chat.device.seen \
         chat.continuity chat.draft.save chat.position.save \
         file.start file.status file.evidence \
         chat.receipts chat.timeline chat.health chat.provenance chat.collisions \
         chat.decisions chat.promise chat.work chat.safety chat.device.vault \
         chat.integrity chat.email.bridge chat.file.context chat.cost; do
  rpc "arm" "$p"
done

echo "--- Bun fallback (sirf fallback, primary nahi) ---"
check_http "fallback /api/chat/health" "$B/api/chat/health" 200
check_http "public fallback path"      "https://anexomail.com/api/chat/health" 200

echo "--- DB truth (feature tables) ---"
check_sql "chat_access() maujood"      "select count(*)>0 from pg_proc where proname='chat_access';" "t"
check_sql "chat_feature_ok() maujood"  "select count(*)>0 from pg_proc where proname='chat_feature_ok';" "t"
# asli schema ke naam (repo ki SQL se) — koi andaza nahi
for t in chat_conversations chat_messages chat_transfer_ledger file_evidence \
         chat_message_receipts chat_receipt_devices chat_receipt_certificates \
         chat_work_items chat_work_events chat_work_evidence \
         chat_message_provenance chat_message_important commitment_collisions \
         chat_decisions chat_decision_versions promise_recovery_log \
         safety_reports safety_reveal_log device_vault account_integrity_log \
         device_ban_appeals chat_drafts chat_positions; do
  check_sql "table $t" "select count(*)>0 from information_schema.tables where table_schema='public' and table_name='$t';" "t"
done
check_sql "RLS har chat table par ON" \
  "select count(*) from pg_tables t join pg_class c on c.relname=t.tablename where t.schemaname='public' and t.tablename like 'chat_%' and not c.relrowsecurity;" "0"
check_sql "provenance chain append-only" \
  "select count(*)>0 from pg_trigger where tgname like '%provenance%';" "t"

gate_result "ANEXOChat"
