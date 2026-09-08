#!/usr/bin/env bash
# ============================================================================
# ANEXOMAIL — Storage Box ko storage_volumes mein register (Supabase = truth)
#   bash server/storage/register-box.sh u659696
# Protected SUPABASE4_* server env se direct service RPC; founder JWT ki zarurat nahi.
# ============================================================================
set -uo pipefail
BOX="${1:-${BOX:-u659696}}"
[ "$BOX" = "u659696" ] || { echo "FAIL: issued Storage Box username sirf u659696 hai"; exit 2; }
MNT=/mnt/anexomail-box

mountpoint -q "$MNT" || { echo "FAIL: $MNT mounted nahi — pehle mount-box.sh chalao"; exit 2; }

read_protected_value() {
  local primary="$1" fallback="$2" source key value
  for key in "$primary" "$fallback"; do
    value="${!key:-}"
    if [ -n "$value" ]; then printf '%s' "$value"; return 0; fi
    for source in /root/.anexomail.env /opt/anexomail/.env /opt/anexomail-web/.env /etc/anexomail/mail.env; do
      [ -r "$source" ] || continue
      value="$(grep -am1 -E "^[[:space:]]*(export[[:space:]]+)?${key}=" "$source" | cut -d= -f2- || true)"
      value="${value#\"}"; value="${value%\"}"; value="${value#\'}"; value="${value%\'}"
      if [ -n "$value" ]; then printf '%s' "$value"; return 0; fi
    done
  done
  return 1
}

DB_URL="$(read_protected_value SUPABASE4_URL SUPABASE_URL)" || {
  echo "FAIL: SUPABASE4_URL / SUPABASE_URL protected server env mein nahi mila"
  exit 2
}
SERVICE_KEY="$(read_protected_value SUPABASE4_SERVICE_ROLE_KEY SUPABASE_SERVICE_ROLE_KEY)" || {
  echo "FAIL: SUPABASE4_SERVICE_ROLE_KEY / SUPABASE_SERVICE_ROLE_KEY protected server env mein nahi mila"
  exit 2
}

CAP="$(df -B1 --output=size "$MNT" | tail -1 | tr -d ' ')"
echo "==> capacity bytes: $CAP"

echo "==> storage volume register (protected service RPC)"
RPC_RESULT="$(curl -sS -w $'\n%{http_code}' -X POST \
  "${DB_URL%/}/rest/v1/rpc/storage_volume_register" \
  -H "apikey: $SERVICE_KEY" \
  -H "authorization: Bearer $SERVICE_KEY" \
  -H 'content-type: application/json' \
  -d "{\"_name\":\"hetzner-box-$BOX\",\"_kind\":\"storage_box\",\"_capacity_bytes\":$CAP,\"_endpoint\":\"$MNT/attachments\",\"_drain_others\":true}")" || {
  echo "FAIL: database RPC tak network request nahi pohanchi"
  exit 1
}
HTTP_CODE="${RPC_RESULT##*$'\n'}"
RES="${RPC_RESULT%$'\n'*}"

if [ "$HTTP_CODE" = "200" ] && printf '%s' "$RES" | grep -Eq '^"[0-9a-fA-F-]{36}"$'; then
  echo "GREEN  hetzner-box-$BOX registered; doosre volumes drain mode mein"
else
  echo "FAIL: storage register RPC HTTP $HTTP_CODE"
  printf '%s\n' "$RES"
  exit 1
fi

echo "==> capacity sweep cron (har ghante, 85% par auto-drain)"
CRON_SECRET="${CRON_SECRET:-$(read_protected_value CRON_SECRET CRON_SECRET || true)}"
API=http://127.0.0.1:3100
if [ -n "$CRON_SECRET" ]; then
  ( crontab -l 2>/dev/null | grep -v 'storage/sweep'; \
    echo "7 * * * * curl -s -X POST $API/api/internal/storage/sweep -H 'x-cron-secret: $CRON_SECRET' >/dev/null" ) | crontab -
  echo "  cron lagaya"
else
  echo "  skip: CRON_SECRET set nahi (server .env se export kar ke dobara chala sakte ho)"
fi
