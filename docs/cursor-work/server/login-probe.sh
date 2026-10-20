#!/usr/bin/env bash
# ANEXOMAIL — LOGIN-LOOP PROBE v2: KOI TYPING NAHI (email/password kuch nahi poochta).
#   bash <(git -C /opt/anexomail-web fetch -q origin main; git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/login-probe.sh)
# Kaise: server ki apni service key (sirf server ke andar) se test account ka session token banata hai (Supabase admin magic-link,
# email nahi bhejta, password nahi chahiye), phir dashboard jaisi 24 parallel calls x 3 rounds — Brain :3100 AUR Rust :3200 dono par.
# Output: har status ki ginti. Sab 200/401(sirf Rust rpc ke liye nakli entitlement) => theek; koi 5xx/anokha 401 => wahi loop ki wajah.
# Sirf padhne wali calls (GET). Token/key kabhi screen par nahi aata. Email badalna ho: EMAIL=pro.buyer@anexomail.com bash <(...)
set -uo pipefail
EMAIL="${EMAIL:-basic.test@anexomail.com}"
for f in /opt/anexomail/.env /etc/anexomail/sync.env; do [ -r "$f" ] && { set -a; . "$f"; set +a; }; done
URL="${SUPABASE4_URL:-${SUPABASE_URL:-}}"; KEY="${SUPABASE4_SERVICE_ROLE_KEY:-${SUPABASE_SERVICE_ROLE_KEY:-}}"
[ -n "$URL" ] && [ -n "$KEY" ] || { echo "FAIL: /opt/anexomail/.env mein SUPABASE4_URL / SERVICE_ROLE_KEY nahi mili"; exit 2; }
URL="${URL%/}"
LINK="$(curl -s -m 20 -H "apikey: $KEY" -H "authorization: Bearer $KEY" -H 'content-type: application/json' -d "{\"type\":\"magiclink\",\"email\":\"$EMAIL\"}" "$URL/auth/v1/admin/generate_link")"
HASH="$(printf '%s' "$LINK" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("hashed_token",""))
except Exception: print("")')"
[ -n "$HASH" ] || { echo "FAIL: $EMAIL ka login-token nahi bana (account hai? email sahi?). Jawab ki shuruaat: $(printf '%s' "$LINK" | head -c 120)"; exit 1; }
SESS="$(curl -s -m 20 -H "apikey: $KEY" -H 'content-type: application/json' -d "{\"type\":\"magiclink\",\"token_hash\":\"$HASH\"}" "$URL/auth/v1/verify")"
TOK="$(printf '%s' "$SESS" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("access_token",""))
except Exception: print("")')"; unset SESS LINK HASH KEY SUPABASE4_SERVICE_ROLE_KEY SUPABASE_SERVICE_ROLE_KEY
[ -n "$TOK" ] || { echo "FAIL: session token nahi mila"; exit 1; }
echo "token bana ($EMAIL) — ab 24 parallel calls x 3 rounds"
BRAIN="${BRAIN:-http://127.0.0.1:3100}"; RUST="${RUST:-http://127.0.0.1:3200}"
B_PATHS=(/api/auth/session /api/trial/state /api/auth/passkey/status /api/mail/handoff /api/auth/session /api/trial/state)
for round in 1 2 3; do
  OUT="$(mktemp)"
  for i in 1 2 3 4; do
    for p in "${B_PATHS[@]}"; do ( curl -s -o /dev/null -m 20 -w "BRAIN %{http_code} $p\n" -H "authorization: Bearer $TOK" "$BRAIN$p" >>"$OUT" ) & done
    ( curl -s -o /dev/null -m 20 -w "RUST  %{http_code} /rpc/mail.inbox\n" -X POST -H "authorization: Bearer $TOK" -H 'content-type: application/json' -d '{"input":{}}' "$RUST/rpc/mail.inbox" >>"$OUT" ) &
  done; wait
  echo "--- round $round:"; sort "$OUT" | uniq -c | sort -rn; rm -f "$OUT"; sleep 1
done
unset TOK
echo "DONE. Brain ki sab /api/auth/* calls 200 hon aur RUST mein 401 na ho => login loop ka server-side raasta band. Output Claude ko bhejein."
