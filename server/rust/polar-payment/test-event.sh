#!/usr/bin/env bash
# ============================================================================
# ANEXOMAIL — POLAR WEBHOOK SELF-TEST (Nauman ke liye: sirf ek command)
#
#   cd /opt/anexomail-web && bash server/rust/polar-payment/test-event.sh
#
# Yeh script:
#   1. /opt/polar-rust-payment/.env se legacy/fallback secret parhti hai
#   2. Standard + legacy dono valid signatures ek header mein banati hai
#   3. Dono endpoints par bhejti hai; engine Polar API se har endpoint ka apna
#      secret bhi auto-load karti hai
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

# Standard Webhooks: key = base64-decode(secret ka whsec_ ke baad wala hissa).
# Purane Polar HMAC secrets: key = poora whsec_... text. Engine dono accept karti
# hai, is liye self-test bhi dono v1 signatures bhejti hai. Pehli script ki ghalti
# yahi thi ke woh sirf Standard key bhej rahi thi.
RAW_KEY="${SECRET#whsec_}"
KEY_HEX="$(printf '%s' "$RAW_KEY" | base64 -d 2>/dev/null | xxd -p -c 256 | tr -d '\n' || true)"
LEGACY_KEY_HEX="$(printf '%s' "$SECRET" | xxd -p -c 256 | tr -d '\n')"

SIGNATURES=""
if [ -n "$KEY_HEX" ]; then
  STANDARD_SIG="$(printf '%s' "$SIGNED" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:$KEY_HEX" -binary | base64 | tr -d '\n')"
  SIGNATURES="v1,$STANDARD_SIG"
fi
LEGACY_SIG="$(printf '%s' "$SIGNED" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:$LEGACY_KEY_HEX" -binary | base64 | tr -d '\n')"
SIGNATURES="${SIGNATURES:+$SIGNATURES }v1,$LEGACY_SIG"

send() {
  local label="$1" url="$2"
  local code
  code="$(curl -s -o /tmp/polar-test-out.txt -w '%{http_code}' -X POST "$url" \
    -H 'content-type: application/json' \
    -H "webhook-id: $EVENT_ID" \
    -H "webhook-timestamp: $TS" \
    -H "webhook-signature: $SIGNATURES" \
    --data-binary "$BODY" || echo 000)"
  echo "  $label -> HTTP $code   $(head -c 120 /tmp/polar-test-out.txt)"
}

echo "==> test event id: $EVENT_ID"
send "PRIMARY (polarpayments)" "$PRIMARY"
send "BACKUP  (anexomail.com)" "$BACKUP"
echo
echo "200 = kaamyab. Ab Supabase #4 SQL Editor mein:"
echo "  select event_id, event_type, processed, process_error, received_at"
echo "  from public.polar_webhook_inbox where event_id = '$EVENT_ID';"
echo
echo "Dead-letter count DB column nahi; server metric mein dekhein:"
echo "  curl -s http://127.0.0.1:3400/metrics"
