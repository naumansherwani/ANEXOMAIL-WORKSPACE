#!/usr/bin/env bash
# ============================================================================
# pcp-call.sh — Polar engine ke MUHAR-WALE raaste ko server se bulane ka aasaan tareeqa.
#   bash pcp-call.sh POST /api/v1/portal '{"user_id":"<uuid>"}'
#   bash pcp-call.sh GET  /api/v1/billing/<uuid>
# Key: /etc/anexomail/pcp.key (root). Sirf 127.0.0.1:3400 par jaata hai.
# ============================================================================
set -euo pipefail
METHOD="${1:?METHOD}"; PATH_="${2:?PATH}"; BODY="${3:-}"
KEYFILE="${PCP_KEY_FILE:-/etc/anexomail/pcp.key}"
BASE="${PCP_BASE:-http://127.0.0.1:3400}"
KEY="$(tr -d '[:space:]' < "$KEYFILE")"
TS="$(date +%s)"
NONCE="$(openssl rand -hex 16)"
BH="$(printf '%s' "$BODY" | sha256sum | cut -d' ' -f1)"
CANON="$(printf 'v1\n%s\n%s\n%s\n%s\n%s' "${METHOD^^}" "$PATH_" "$TS" "$NONCE" "$BH")"
SIG="$(printf '%s' "$CANON" | openssl dgst -sha256 -hmac "$KEY" -r | cut -d' ' -f1)"
ARGS=(-sS -m 25 -o - -w '\n%{http_code}\n' -X "${METHOD^^}" -H "x-pcp-ts: $TS" -H "x-pcp-nonce: $NONCE" -H "x-pcp-sig: $SIG")
if [ -n "$BODY" ]; then ARGS+=(-H 'content-type: application/json' --data-binary "$BODY"); fi
curl "${ARGS[@]}" "$BASE$PATH_"
