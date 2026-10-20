#!/usr/bin/env bash
# ANEXOMAIL — LOGIN-LOOP PROBE (server par, founder ek baar chalata hai; password sirf silent prompt, kahin save/print nahi).
#   bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/login-probe.sh)
# Kya karta hai: asli /api/auth/login -> token -> dashboard jaisi 24 parallel calls (session, trial/state, passkey/status ...)
# 3 baar; har status ka hisaab chhapta hai. Koi 401/5xx mila => login loop ki asli wajah yehi hai. Sab 200 => server theek, masla browser side.
# Sirf padhne wali calls; kuch badalta nahi; token/password kabhi screen par nahi aata.
set -uo pipefail
BASE="${BASE:-http://127.0.0.1:3100}"
read -r -p "Email (sirf Enter dabayein = basic.test@anexomail.com): " EM
EM="${EM:-basic.test@anexomail.com}"
PW=""
while [ -z "$PW" ]; do
  read -r -s -p "Password likhein (nazar nahi aayega, phir Enter): " PW; echo
  [ -z "$PW" ] && echo "   (khaali tha — dobara likhein)"
done
J="$(python3 -c 'import json,sys;print(json.dumps({"email":sys.argv[1],"password":sys.argv[2]}))' "$EM" "$PW")"; unset PW
T0=$(date +%s.%N)
R="$(curl -s -m 20 -w '\n%{http_code}' -H 'content-type: application/json' -H 'user-agent: Mozilla/5.0 (Windows NT 10.0) Chrome/130 Safari/537.36' -d "$J" "$BASE/api/auth/login")"; unset J
CODE="${R##*$'\n'}"; BODY="${R%$'\n'*}"
echo "login -> HTTP $CODE ($(python3 -c "import time;print(round(time.time()-$T0,2))")s)"
TOK="$(printf '%s' "$BODY" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("token",""))
except Exception: print("")')"
[ -n "$TOK" ] || { echo "token nahi mila (password ghalat / mfa_required?). Body ki pehli 120 chars: $(printf '%s' "$BODY" | head -c 120)"; exit 1; }
PATHS=(/api/auth/session /api/trial/state /api/auth/passkey/status /api/mail/handoff /api/auth/session /api/trial/state)
for round in 1 2 3; do
  OUT="$(mktemp)"
  for i in 1 2 3 4; do for p in "${PATHS[@]}"; do
    ( curl -s -o /dev/null -m 20 -w "%{http_code} $p\n" -H "authorization: Bearer $TOK" "$BASE$p" >>"$OUT" ) &
  done; done; wait
  echo "--- round $round (24 parallel):"; sort "$OUT" | uniq -c | sort -rn; rm -f "$OUT"
  sleep 1
done
curl -s -o /dev/null -m 20 -w "logout -> HTTP %{http_code}\n" -X POST -H "authorization: Bearer $TOK" "$BASE/api/auth/logout"; unset TOK
echo "DONE. Sab 200 hon to server/token theek; koi 401/503 ho to us line ki wajah dhoondni hai (Claude ko output bhejein)."
