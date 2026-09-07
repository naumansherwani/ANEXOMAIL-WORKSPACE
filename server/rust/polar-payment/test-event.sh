#!/usr/bin/env bash
# ============================================================================
# ANEXOMAIL — POLAR WEBHOOK SELF-TEST (Nauman ke liye: sirf ek command)
#
#   cd /opt/anexomail-web && bash server/rust/polar-payment/test-event.sh
#
# Yeh script:
#   1. /opt/polar-rust-payment/.env se POLAR_WEBHOOK_SECRET parhti hai
#   2. Standard-Webhooks tareeqe se ek asli signed test event banati hai
#   3. Dono endpoints par bhejti hai (primary + backup)
#   4. HTTP code print karti hai — 200 = kaamyab
#
# Koi paisa, koi asli subscription nahi banti — yeh sirf ek fake test event hai
# jisay engine inbox mein daalti hai (type: test.ping).
# ============================================================================
set -euo pipefail

ENGINE_DIR="${ENGINE_DIR:-/opt/polar-rust-payment}"
PRIMARY="${PRIMARY:-https://polarpayments.anexomail.com/api/v1/polar-webhook}"
BACKUP="${BACKUP:-https://anexomail.com/api/v1/polar-webhook}"

SECRET="$(grep -E '^POLAR_WEBHOOK_SECRET=' "$ENGINE_DIR/.env" | head -1 | cut -d= -f2- | tr -d '"'"'"'[:space:]')"
if [ -z "$SECRET" ]; then
  echo "!!! $ENGINE_DIR/.env mein POLAR_WEBHOOK_SECRET nahi mila."
  exit 1
fi

EVENT_ID="test_$(date +%s)_$RANDOM"
TS="$(date +%s)"
BODY="{\"id\":\"$EVENT_ID\",\"type\":\"test.ping\",\"data\":{\"note\":\"anexomail self test\"}}"
SIGNED="$EVENT_ID.$TS.$BODY"

# Standard Webhooks: key = base64-decode(secret ka whsec_ ke baad wala hissa)
RAW_KEY="${SECRET#whsec_}"
KEY_HEX="$(printf '%s' "$RAW_KEY" | base64 -d 2>/dev/null | xxd -p -c 256 | tr -d '\n' || true)"
if [ -z "$KEY_HEX" ]; then
  KEY_HEX="$(printf '%s' "$SECRET" | xxd -p -c 256 | tr -d '\n')"
fi
SIG="$(printf '%s' "$SIGNED" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:$KEY_HEX" -binary | base64)"

send() {
  local label="$1" url="$2"
  local code
  code="$(curl -s -o /tmp/polar-test-out.txt -w '%{http_code}' -X POST "$url" \
    -H 'content-type: application/json' \
    -H "webhook-id: $EVENT_ID" \
    -H "webhook-timestamp: $TS" \
    -H "webhook-signature: v1,$SIG" \
    --data-binary "$BODY" || echo 000)"
  echo "  $label -> HTTP $code   $(head -c 120 /tmp/polar-test-out.txt)"
}

echo "==> test event id: $EVENT_ID"
send "PRIMARY (polarpayments)" "$PRIMARY"
send "BACKUP  (anexomail.com)" "$BACKUP"
echo
echo "200 = kaamyab. Ab Supabase #4 SQL Editor mein:"
echo "  select event_id, type, processed, process_error, received_at"
echo "  from public.polar_webhook_inbox where event_id = '$EVENT_ID';"
