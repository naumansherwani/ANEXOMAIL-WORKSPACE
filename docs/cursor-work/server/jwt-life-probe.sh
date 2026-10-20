#!/usr/bin/env bash
# JWT kitni der chalta hai (sirf number chhapta hai, token nahi). Session logout ki wajah dhoondne ke liye.
#!/usr/bin/env bash
# ANEXOMAIL — LOGIN-LOOP PROBE v2: KOI TYPING NAHI (email/password kuch nahi poochta).
#   bash <(git -C /opt/anexomail-web fetch -q origin main; git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/login-probe.sh)
# Kaise: server ki apni service key (sirf server ke andar) se test account ka session token banata hai (Supabase admin magic-link,
# email nahi bhejta, password nahi chahiye), phir dashboard jaisi 24 parallel calls x 3 rounds — Brain :3100 AUR Rust :3200 dono par.
# Output: har status ki ginti. Sab 200/401(sirf Rust rpc ke liye nakli entitlement) => theek; koi 5xx/anokha 401 => wahi loop ki wajah.
# Sirf padhne wali calls (GET). Token/key kabhi screen par nahi aata. Email badalna ho: EMAIL=pro.buyer@anexomail.com bash <(...)
set -uo pipefail
EMAIL="${EMAIL:-basic.test@anexomail.com}"
envv(){ for f in /opt/anexomail/.env /etc/anexomail/sync.env; do [ -r "$f" ] && grep -m1 -E "^$1=" "$f" | cut -d= -f2- | sed -e "s/^[\"']//" -e "s/[\"']$//"; done | head -1; }
URL="${SUPABASE4_URL:-$(envv SUPABASE4_URL)}"; [ -n "$URL" ] || URL="$(envv SUPABASE_URL)"
KEY="$(envv SUPABASE4_SERVICE_ROLE_KEY)"; [ -n "$KEY" ] || KEY="$(envv SUPABASE_SERVICE_ROLE_KEY)"
[ -n "$URL" ] && [ -n "$KEY" ] || { echo "FAIL: /opt/anexomail/.env mein SUPABASE4_URL / SERVICE_ROLE_KEY nahi mili"; exit 2; }
URL="${URL%/}"
LINK="$(curl -s -m 20 -H "apikey: $KEY" -H "authorization: Bearer $KEY" -H 'content-type: application/json' -d "{\"type\":\"magiclink\",\"email\":\"$EMAIL\"}" "$URL/auth/v1/admin/generate_link")"
HASH="$(printf '%s' "$LINK" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("hashed_token",""))
except Exception: print("")')"
[ -n "$HASH" ] || { echo "FAIL: $EMAIL ka login-token nahi bana (account hai? email sahi?). Jawab ki shuruaat: $(printf '%s' "$LINK" | head -c 120)"; exit 1; }
SESS="$(curl -s -m 20 -H "apikey: $KEY" -H 'content-type: application/json' -d "{\"type\":\"magiclink\",\"token_hash\":\"$HASH\"}" "$URL/auth/v1/verify")"
EXPIN="$(printf '%s' "$SESS" | python3 -c 'import json,sys
try:
 d=json.load(sys.stdin);print(d.get("expires_in"),"refresh_token" in d and bool(d.get("refresh_token")))
except Exception: print("?")')"
TOK="$(printf '%s' "$SESS" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("access_token",""))
except Exception: print("")')"; unset LINK HASH KEY SUPABASE4_SERVICE_ROLE_KEY SUPABASE_SERVICE_ROLE_KEY
[ -n "$TOK" ] || { echo "FAIL: session token nahi mila"; exit 1; }
python3 - "$TOK" <<'P'
import sys,base64,json
t=sys.argv[1].split('.')[1];t+='='*(-len(t)%4)
d=json.loads(base64.urlsafe_b64decode(t));print("JWT lifetime (sec):",d["exp"]-d["iat"],"=",round((d["exp"]-d["iat"])/3600,2),"ghante")
P
echo "Supabase expires_in / refresh_token mila: $EXPIN"
unset TOK SESS
