#!/usr/bin/env bash
# ANEXOMAIL — Business Pro test accounts: login theek karo + naya account banao (19 Oct 2026, founder ka hukm).
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/bizpro-login-fix.sh)
#
# Kya karti hai (Rule 15 / Rule 17: browser ke baghair, seedha server se):
#   1. Password SIRF silent prompt se leti hai (screen par nahi dikhta, dobara confirm). Kahin store nahi hota: na file, na history, na repo,
#      na chat. SQL ko plain password nahi jata — usse pehle crypt() hash banta hai; psql ko password stdin se milta hai (ps mein nahi).
#   2. Pehle DEKHTI hai (read-only): account hai? confirm? ban? delete? password? identity? plan? organisation? Kharabi saaf likhti hai.
#   3. docs/cursor-work/sql/E36_ensure_test_account.sql chalati hai (idempotent: account nahi to banata hai, kharab hai to theek karta hai).
#        - business_pro.test@anexomail.com   (aapka purana account — login theek hoga)
#        - bpro.test@anexomail.com           (naya Business Pro test account)
#   4. Asli saboot: (a) GoTrue password-grant, (b) website jis raaste se login karti hai wohi /api/auth/login (Brain), (c) Rust /rpc par plan.
#      Aakhir mein har account ke liye "LOGIN OK" ya "LOGIN FAIL — wajah".
# Sirf DEKHNA ho (kuch na badle):  DRY=1 bash <(...)      Sirf ek account:  ONLY=bpro.test bash <(...)
# Password kabhi chat mein bhejne ki zaroorat nahi — script khud poochti hai.
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"
SYNC_ENV="${SYNC_ENV:-/etc/anexomail/sync.env}"
APP_ENV="${APP_ENV:-/opt/anexomail/.env}"
BRAIN="${BRAIN:-http://127.0.0.1:3100}"
RUST="${RUST:-http://127.0.0.1:3200}"
DRY="${DRY:-0}"; ONLY="${ONLY:-}"
# handle | naam | organisation | test domain
ACCOUNTS=(
  "business_pro.test|Business Pro Test|Business Pro Test|bizprotest.axonetis.com"
  "bpro.test|Business Pro Test Two|Business Pro Test Two|bprotest.axonetis.com"
)
PLAN="${PLAN:-business_pro}"          # Business ka test account: PLAN=business ACCT="business.test|Business Test|Business Test|biztest.axonetis.com"
[ -n "${ACCT:-}" ] && ACCOUNTS=("$ACCT")
PW=""; PW2=""
trap 'unset PW PW2 pw_esc 2>/dev/null' EXIT
hr() { printf '\n== %s ==\n' "$1"; }

[ -r "$SYNC_ENV" ] || { echo "FAIL: $SYNC_ENV nahi mili"; exit 2; }
# shellcheck disable=SC1090
. "$SYNC_ENV"
[ -n "${WORKING_URL:-}" ] || { echo "FAIL: WORKING_URL khali ($SYNC_ENV)"; exit 2; }
for b in psql curl python3; do command -v "$b" >/dev/null 2>&1 || { echo "FAIL: $b nahi mila"; exit 2; }; done
envval() { grep -m1 "^$1=" "$APP_ENV" 2>/dev/null | cut -d= -f2- | tr -d "\"' "; }
U="$(envval SUPABASE4_URL)"; K="$(envval SUPABASE4_ANON_KEY)"
[ -n "$U" ] && [ -n "$K" ] || { echo "FAIL: $APP_ENV mein SUPABASE4_URL / SUPABASE4_ANON_KEY nahi mili"; exit 2; }
Q() { psql "$WORKING_URL" -X -At -F ' | ' -c "$1" 2>&1 | head -"${2:-12}"; }

T="$(mktemp -d)"; trap 'rm -rf "$T"; unset PW PW2 pw_esc 2>/dev/null' EXIT
git -C "$REPO" fetch -q origin main 2>/dev/null
SQLFILE="${E36_FILE:-}"
if [ -z "$SQLFILE" ]; then
  git -C "$REPO" show origin/main:docs/cursor-work/sql/E36_ensure_test_account.sql >"$T/E36.sql" 2>/dev/null
  SQLFILE="$T/E36.sql"
fi
[ -s "$SQLFILE" ] || { echo "FAIL: E36_ensure_test_account.sql repo (origin/main) mein nahi mili — git fetch hua?"; exit 2; }

hr "0. login service zinda hai?"
echo "   GoTrue health: $(curl -s -m 8 -o /dev/null -w '%{http_code}' "$U/auth/v1/health" -H "apikey: $K" 2>/dev/null)   Brain /health: $(curl -s -m 8 -o /dev/null -w '%{http_code}' "$BRAIN/health" 2>/dev/null)   Rust /rpc/health: $(curl -s -m 8 -o /dev/null -w '%{http_code}' "$RUST/rpc/health" 2>/dev/null)"

look() {   # read-only: ek account ki poori haalat (hash/password kabhi print nahi)
  local em="$1"
  [ "$(Q "select count(*) from auth.users where lower(btrim(email))='$em';" 1)" = "0" ] && { echo "   (is naam ka login account hai hi nahi — step 3 mein banega)"; return; }
  echo "   -- login (auth.users): confirmed | banned_until | deleted_at | password hai? | aud | role | identities | NULL token columns"
  Q "select (u.email_confirmed_at is not null), coalesce(u.banned_until::text,'-'), coalesce(u.deleted_at::text,'-'), (u.encrypted_password is not null and u.encrypted_password<>''), coalesce(u.aud,'NULL'), coalesce(u.role,'NULL'), (select count(*) from auth.identities i where i.user_id=u.id), (u.confirmation_token is null or u.recovery_token is null or u.email_change_token_new is null or u.email_change is null) from auth.users u where lower(btrim(u.email))='$em';" 3
  echo "   -- trial_accounts: status | plan | address"
  Q "select t.status, coalesce(t.plan,'-'), coalesce(t.anexomail_address,'-') from public.trial_accounts t join auth.users u on u.id=t.user_id where lower(btrim(u.email))='$em';" 3
  echo "   -- entitlement_state plan | active_until   /   workspace_subscriptions plan | state"
  Q "select e.plan||' | '||coalesce(e.active_until::date::text,'-') from public.entitlement_state e join auth.users u on u.id=e.user_id where lower(btrim(u.email))='$em';" 2
  Q "select s.plan||' | '||coalesce(s.state,'-') from public.workspace_subscriptions s join auth.users u on u.id=s.user_id where lower(btrim(u.email))='$em';" 2
  echo "   -- organisation: slug | role | status"
  Q "select o.slug, m.role::text, coalesce(m.status::text,'-') from public.org_members m join public.organisations o on o.id=m.org_id join auth.users u on u.id=m.user_id where lower(btrim(u.email))='$em';" 3
}

hr "1. abhi ki haalat (read-only) — milte-julte login naam bhi, taake spelling ka farq pakda jaye"
Q "select email from auth.users where email ilike '%business%pro%' or email ilike 'bpro%' or email ilike '%biz%pro%' order by created_at;" 12 | sed 's/^/   milta hua: /'
for row in "${ACCOUNTS[@]}"; do
  IFS='|' read -r H NM ORG DOM <<<"$row"
  [ -n "$ONLY" ] && [ "$ONLY" != "$H" ] && continue
  echo "== $H@anexomail.com"; look "$H@anexomail.com"
done

if [ "$DRY" = "1" ]; then echo; echo "DRY=1 — kuch nahi badla. Theek karne ke liye DRY=1 hata kar dobara chalayen."; exit 0; fi

hr "2. password (screen par nahi dikhega; kahin save nahi hota)"
[ -r /dev/tty ] || { echo "FAIL: terminal nahi — yeh script password poochti hai, ise terminal se chalayen"; exit 2; }
read -rs -p "   Business Pro test accounts ka password (6 se zyada akshar): " PW </dev/tty; echo
read -rs -p "   Dobara wohi password: " PW2 </dev/tty; echo
[ -n "$PW" ] && [ "$PW" = "$PW2" ] || { echo "FAIL: password khali ya dono baar alag — kuch nahi badla"; exit 2; }
[ "${#PW}" -ge 6 ] || { echo "FAIL: password 6 se chhota hai — kuch nahi badla"; exit 2; }
unset PW2
pw_esc="${PW//\\/\\\\}"; pw_esc="${pw_esc//\'/\'\'}"     # psql \set ke liye escape (stdin se jata hai, ps mein nahi dikhta)

hr "3. theek karna / banana (E36 — dobara chalane par bhi safe)"
declare -A RESULT
for row in "${ACCOUNTS[@]}"; do
  IFS='|' read -r H NM ORG DOM <<<"$row"
  [ -n "$ONLY" ] && [ "$ONLY" != "$H" ] && continue
  echo "== $H@anexomail.com"
  # E76 (Rule 49): test account PEHLE registry mein (asli-signup deewar usay rok na de); E76 chali na ho to chup-chaap skip
  psql "$WORKING_URL" -X -qAt -c "select public.register_test_account('${H}@anexomail.com','bizpro-login-fix')" >/dev/null 2>&1 || true
  OUT="$( { printf '%s\n' "\\set pw '${pw_esc}'"; cat "$SQLFILE"; } | psql "$WORKING_URL" -X -q -P pager=off -v ON_ERROR_STOP=1 \
        -v handle="$H" -v nm="$NM" -v org="$ORG" -v domain="$DOM" -v plan="$PLAN" -f - 2>&1 )"
  rc=$?
  # password kisi error text mein na aaye: agar aa jaye to mita do
  OUT="${OUT//"$PW"/<password>}"
  echo "$OUT" | grep -v '^$' | grep -v -E '^(SET|BEGIN|COMMIT|CREATE FUNCTION)$' | cut -c1-230 | sed 's/^/   /'
  [ "$rc" -eq 0 ] || echo "   !! E36 $H par fail (rc=$rc) — upar ka error Claude ko paste karein"
done

hr "4. asli saboot (login ka wohi raasta jo website use karti hai)"
J() { python3 -c 'import sys,json
em=sys.argv[1]; pw=sys.stdin.read().rstrip("\n")
print(json.dumps({"email":em,"password":pw}))' "$1" <<<"$PW"; }
for row in "${ACCOUNTS[@]}"; do
  IFS='|' read -r H NM ORG DOM <<<"$row"
  [ -n "$ONLY" ] && [ "$ONLY" != "$H" ] && continue
  EM="$H@anexomail.com"; echo "== $EM"
  BODY="$(J "$EM")"
  # (a) GoTrue seedha
  G="$(curl -s -m 15 -w '\n%{http_code}' "$U/auth/v1/token?grant_type=password" -H "apikey: $K" -H 'content-type: application/json' --data-binary @- <<<"$BODY" 2>/dev/null)"
  GCODE="${G##*$'\n'}"; GJSON="${G%$'\n'*}"
  TOK="$(python3 -c 'import sys,json
try: print(json.loads(sys.stdin.read()).get("access_token",""))
except Exception: print("")' <<<"$GJSON")"
  if [ -n "$TOK" ]; then echo "   (a) GoTrue password-grant : OK (HTTP $GCODE)"
  else echo "   (a) GoTrue password-grant : FAIL (HTTP $GCODE) — $(python3 -c 'import sys,json
try:
    d=json.loads(sys.stdin.read()); print((d.get("error_description") or d.get("msg") or d.get("message") or d.get("error") or "")[:160])
except Exception: print("jawab samajh nahi aya")' <<<"$GJSON")"; fi
  # (b) website ka asli login raasta
  L="$(curl -s -m 15 -w '\n%{http_code}' -X POST "$BRAIN/api/auth/login" -H 'content-type: application/json' --data-binary @- <<<"$BODY" 2>/dev/null)"
  LCODE="${L##*$'\n'}"; LJSON="${L%$'\n'*}"
  LSUM="$(python3 -c 'import sys,json
def find(o,keys,out):
    if isinstance(o,dict):
        for k,v in o.items():
            if k in keys and isinstance(v,(str,int,bool)): out.append("%s=%s"%(k,v))
            find(v,keys,out)
    elif isinstance(o,list):
        for v in o: find(v,keys,out)
try:
    d=json.loads(sys.stdin.read())
    if d.get("error"): print("error: "+str(d["error"])[:140])
    else:
        out=[]; find(d,{"plan","billed","featurePlan","kind","workspaceKind","onboarded","mfa_required"},out)
        print(("token hai; " if d.get("token") else "token NAHI; ")+", ".join(dict.fromkeys(out))[:200])
except Exception: print("jawab samajh nahi aya")' <<<"$LJSON")"
  if [ "$LCODE" = "200" ]; then echo "   (b) website /api/auth/login: OK (HTTP $LCODE) — $LSUM"
  else echo "   (b) website /api/auth/login: FAIL (HTTP $LCODE) — $LSUM"; fi
  # (c) Rust par plan
  RP=""
  if [ -n "$TOK" ]; then
    RP="$(curl -s -m 12 -X POST "$RUST/rpc/dashboard.summary" -H "authorization: Bearer $TOK" -H 'content-type: application/json' -d '{}' 2>/dev/null | python3 -c 'import sys,json
try:
    d=json.loads(sys.stdin.read()); d=d.get("result",{}).get("data",d)
    print("plan=%s domain=%s/%s"%(d.get("plan"),d.get("domain"),d.get("domain_status")))
except Exception: print("")')"
    echo "   (c) Rust dashboard.summary: ${RP:-jawab nahi mila}"
  fi
  if [ -n "$TOK" ] && [ "$LCODE" = "200" ] && [[ "$RP" == plan=$PLAN* ]]; then RESULT[$H]="LOGIN OK — $EM (plan $PLAN)"
  elif [ -n "$TOK" ] && [ "$LCODE" = "200" ]; then RESULT[$H]="LOGIN OK par plan alag dikha ($RP) — Claude ko paste karein"
  elif [ -z "$TOK" ]; then RESULT[$H]="LOGIN FAIL — $EM : GoTrue ne password nahi mana (upar (a) ki wajah dekhein)"
  else RESULT[$H]="LOGIN FAIL — $EM : GoTrue theek par website ka login (Brain) fail (upar (b) dekhein)"; fi
done

hr "5. natija"
for row in "${ACCOUNTS[@]}"; do
  IFS='|' read -r H NM ORG DOM <<<"$row"
  [ -n "$ONLY" ] && [ "$ONLY" != "$H" ] && continue
  echo "   ${RESULT[$H]:-$H : (nahi chala)}"
done
echo "   Login page par sirf naam (business_pro.test / bpro.test) likhna bhi chalega — website khud @anexomail.com laga deti hai."
echo "   Password kahin save nahi hua. (Test account hai: asli paise/Polar ki jagah entitlement row — E28 jaisa.)"
