#!/usr/bin/env bash
# ============================================================================
# ANEXOMAIL — Storage Box ko storage_volumes mein register (Supabase = truth)
#   bash server/storage/register-box.sh u123456
# Founder token /etc/anexomail/founder.jwt se, warna FOUNDER_JWT env se.
# ============================================================================
set -uo pipefail
BOX="${1:-${BOX:-box}}"
MNT=/mnt/anexomail-box
API=http://127.0.0.1:3100

mountpoint -q "$MNT" || { echo "FAIL: $MNT mounted nahi — pehle mount-box.sh chalao"; exit 2; }

TOKEN="${FOUNDER_JWT:-}"
[ -z "$TOKEN" ] && [ -f /etc/anexomail/founder.jwt ] && TOKEN="$(tr -d '[:space:]' < /etc/anexomail/founder.jwt)"
[ -n "$TOKEN" ] || { echo "FAIL: founder token nahi mila (FOUNDER_JWT ya /etc/anexomail/founder.jwt)"; exit 2; }

CAP="$(df -B1 --output=size "$MNT" | tail -1 | tr -d ' ')"
echo "==> capacity bytes: $CAP"

RES="$(curl -s -X POST "$API/api/founder/storage/volume" \
  -H "authorization: Bearer $TOKEN" -H 'content-type: application/json' \
  -d "{\"name\":\"hetzner-box-$BOX\",\"kind\":\"storage_box\",\"capacity_bytes\":$CAP,\"endpoint\":\"$MNT/attachments\",\"drain_others\":true}")"
echo "$RES"

case "$RES" in
  *'"ok":true'*|*hetzner-box*) echo "GREEN  volume registered"; ;;
  *) echo "FAIL   register nahi hua — pm2 logs anexomail-leo dekho"; exit 1;;
esac

echo "==> capacity sweep cron (har ghante, 85% par auto-drain)"
if [ -n "${CRON_SECRET:-}" ]; then
  ( crontab -l 2>/dev/null | grep -v 'storage/sweep'; \
    echo "7 * * * * curl -s -X POST $API/api/internal/storage/sweep -H 'x-cron-secret: $CRON_SECRET' >/dev/null" ) | crontab -
  echo "  cron lagaya"
else
  echo "  skip: CRON_SECRET set nahi (server .env se export kar ke dobara chala sakte ho)"
fi
