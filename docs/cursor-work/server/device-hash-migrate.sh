#!/usr/bin/env bash
# G34 — purane (v1) device hash ko HMAC-SHA256 (v2) mein badalna. Pehle E42_device_hash_hmac.sql Supabase mein chalao.
# Key server ke env mein hai (DEVICE_VAULT_KEY); kahin print/store nahi hoti. Dobara chalana safe.
# Chalao:  cd /opt/anexomail-web && bash docs/cursor-work/server/device-hash-migrate.sh
set -euo pipefail
cd /opt/anexomail-web
set -a; [ -f .env ] && . ./.env; set +a
URL="${SUPABASE4_URL:-${SUPABASE_URL:-}}"
SRK="${SUPABASE4_SERVICE_ROLE_KEY:-${SUPABASE_SERVICE_ROLE_KEY:-}}"
[ -n "$URL" ] && [ -n "$SRK" ] || { echo "STOP: Supabase env nahi mila"; exit 2; }
KEY="${DEVICE_VAULT_KEY:-}"
if [ -z "$KEY" ]; then KEY="anexomail-vault:${SRK: -32}"; fi   # server/routes/auth.ts vaultKey() jaisa
BODY=$(python3 -c 'import json,sys; print(json.dumps({"_key": sys.argv[1]}))' "$KEY")
curl -sS -X POST "$URL/rest/v1/rpc/device_hash_migrate_v2" \
  -H "apikey: $SRK" -H "Authorization: Bearer $SRK" -H "Content-Type: application/json" -d "$BODY"
echo
