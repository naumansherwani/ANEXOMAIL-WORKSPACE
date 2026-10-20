#!/usr/bin/env bash
# ANEXOMAIL — blocked account purge (G36): har ghante `account_integrity_purge_due()` chalata hai.
# Sirf woh accounts jo 'blocked' hain AUR 72 ghante ki export window guzar chuki. Secret print nahi hota.
set -uo pipefail
ENV_FILE="${ENV_FILE:-/opt/anexomail-web/.env}"
set -a; [ -f "$ENV_FILE" ] && . "$ENV_FILE"; set +a
URL="${SUPABASE4_URL:-${SUPABASE_URL:-}}"
SRK="${SUPABASE4_SERVICE_ROLE_KEY:-${SUPABASE_SERVICE_ROLE_KEY:-}}"
[ -n "$URL" ] && [ -n "$SRK" ] || { echo "integrity-purge: Supabase env nahi mila ($ENV_FILE)"; exit 2; }
KEY="${DEVICE_VAULT_KEY:-}"; [ -n "$KEY" ] || KEY="anexomail-vault:${SRK: -32}"   # server/routes/auth.ts vaultKey() jaisa (device-hash-migrate.sh bhi yahi)
BODY="$(python3 -c 'import json,sys; print(json.dumps({"_key": sys.argv[1]}))' "$KEY")"
OUT="$(curl -sS --max-time 120 -X POST "$URL/rest/v1/rpc/account_integrity_purge_due" \
  -H "apikey: $SRK" -H "Authorization: Bearer $SRK" -H "Content-Type: application/json" -d "$BODY" 2>&1)"
echo "integrity-purge $(date -u +%FT%TZ) $OUT" | cut -c1-400
case "$OUT" in *'"ok"'*true*) exit 0 ;; *) exit 1 ;; esac
