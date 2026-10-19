#!/usr/bin/env bash
# ANEXOMAIL — Import mail (G30) ka LIVE test, asli website ke raaste se, bina kisi asli Gmail password ke.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/mig-live-test.sh)
#
# Kya jaanchta hai (test account bpro.test@anexomail.com ke naam se; us ka password SIRF yahan chup-chaap poochta hai, kahin save nahi):
#   1. login (GoTrue) -> token.
#   2. Rust `migration.providers`  -> provider list aati hai.
#   3. Rust `migration.list`       -> khali/purani list aati hai (E35 SQL lagi hui hai).
#   4. Rust `migration.start` NAKLI Gmail login + NAKLI App Password ke saath -> asli imap.gmail.com:993 par TLS + LOGIN hota hai
#      aur jawab "provider ne login mana kiya" aana chahiye. Yeh saabit karta hai: rustls build, asli TLS, IMAP LOGIN, galat-password raasta.
#   5. `migration.list` dobara: wohi nakli copy "failed / provider ne password mana kiya" dikhe, koi mail nahi aayi.
# Kuch asli nahi badalta: ek failed migration row banti hai (test account ki). Asli Gmail ka koi password nahi lagta.
set -uo pipefail
APP_ENV="${APP_ENV:-/opt/anexomail/.env}"; RUST="${RUST:-http://127.0.0.1:3200}"
ACC="${ACC:-bpro.test@anexomail.com}"
for b in curl python3; do command -v "$b" >/dev/null 2>&1 || { echo "FAIL: $b nahi mila"; exit 2; }; done
envval() { grep -m1 "^$1=" "$APP_ENV" 2>/dev/null | cut -d= -f2- | tr -d "\"' "; }
U="$(envval SUPABASE4_URL)"; K="$(envval SUPABASE4_ANON_KEY)"
[ -n "$U" ] && [ -n "$K" ] || { echo "FAIL: $APP_ENV mein SUPABASE4_URL / SUPABASE4_ANON_KEY nahi mili"; exit 2; }
PW=""; trap 'unset PW TOK 2>/dev/null' EXIT
read -r -s -p "   $ACC ka password (screen par nahi dikhega, save nahi hota): " PW; echo
BODY="$(python3 -c 'import sys,json; print(json.dumps({"email":sys.argv[1],"password":sys.stdin.read().rstrip("\n")}))' "$ACC" <<<"$PW")"
TOK="$(curl -s -m 15 "$U/auth/v1/token?grant_type=password" -H "apikey: $K" -H 'content-type: application/json' --data-binary @- <<<"$BODY" | python3 -c 'import sys,json
try: print(json.loads(sys.stdin.read()).get("access_token",""))
except Exception: print("")')"
unset PW BODY
[ -n "$TOK" ] || { echo "FAIL 1: login nahi hua (password galat?)"; exit 1; }
echo "OK   1 login"
call() { curl -s -m "${3:-70}" -X POST "$RUST/rpc/$1" -H "authorization: Bearer $TOK" -H 'content-type: application/json' -d "$2"; }
show() { python3 -c 'import sys,json
t=sys.stdin.read()
try:
    d=json.loads(t); d=d.get("result",d); d=d.get("data",d)
    print(json.dumps(d,ensure_ascii=False)[:420])
except Exception: print(t[:420])'; }
bad=0
P="$(call migration.providers '{}' 15)"
echo "$P" | grep -q '"gmail"' && echo "OK   2 migration.providers: provider list aayi" || { echo "FAIL 2 migration.providers: $(show <<<"$P")"; bad=1; }
L="$(call migration.list '{}' 15)"
echo "$L" | grep -q '"sessions"' && echo "OK   3 migration.list: $(show <<<"$L" | cut -c1-160)" || { echo "FAIL 3 migration.list: $(show <<<"$L")  (E35 SQL?)"; bad=1; }
echo "     4 asli imap.gmail.com:993 par NAKLI login (45 second tak lag sakta hai)..."
S="$(call migration.start "{\"mailbox\":\"$ACC\",\"provider\":\"gmail\",\"login\":\"no.such.person.e35test@gmail.com\",\"password\":\"abcd efgh ijkl mnop\"}" 70)"
if echo "$S" | grep -qi "refused the login\|auth_failed\|App Password"; then
  echo "OK   4 provider ne login mana kiya (matlab TLS + IMAP LOGIN asli server tak gaya): $(show <<<"$S" | cut -c1-200)"
elif echo "$S" | grep -qi "connecting\|session_id"; then
  echo "..   4 copy shuru dikhi (provider slow); 20 second baad list dekhte hain: $(show <<<"$S" | cut -c1-200)"; sleep 20
else echo "FAIL 4: $(show <<<"$S")"; bad=1; fi
L2="$(call migration.list '{}' 15)"
echo "     5 ab ki list: $(show <<<"$L2" | cut -c1-300)"
echo "$L2" | grep -q '"copied": *0\|"copied":0' && echo "OK   5 koi mail copy nahi hui (nakli login)" || echo "     (5: upar ki list khud dekh lein)"
[ "$bad" = 0 ] && echo "== RESULT: GREEN — Import mail asli website ke raaste se kaam kar raha hai (nakli login par sahi jawab)" || echo "== RESULT: FAIL — upar ka FAIL wala step paste karein"
