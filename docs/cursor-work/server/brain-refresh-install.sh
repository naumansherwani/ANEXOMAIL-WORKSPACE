#!/usr/bin/env bash
# ANEXOMAIL — Brain: SESSION REFRESH (token 1 ghante mein khatam hota tha, app refresh nahi karti thi => har ghante sign-out). Founder 21 Oct 2026.
#   bash <(git -C /opt/anexomail-web fetch -q origin main; git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/brain-refresh-install.sh)
# Kya: login/passkey/callback ab refresh_token + expires_at bhi dete hain; naya POST /api/auth/refresh (Supabase refreshSession, rotation);
#   client (Web pull) access token khatam hone se pehle chupke se naya leta hai. Session id wahi rehti hai => logout / device-revoke asli.
# Files: routes/auth.ts (live == purani repo wali ho tabhi badalti, warna STOP) + routes/auth-passkey.ts (live repo se ALAG hai: sirf 3 chhoti jagah surgical).
# Backup + bun build pre-flight + health + nakli-token 401 + restore-on-fail. Rust/web/polar ko haath nahi.
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"; SRC="${BRAIN_SRC:-/opt/anexomail/src}"
BUN="$(command -v bun || echo /root/.bun/bin/bun)"; STAMP="$(date +%Y%m%d-%H%M%S)"; B="/root/anexomail-backups/brain-refresh-$STAMP"
OLD_AUTH="768d265adecb8f19"
show() { git -C "$REPO" show "origin/main:$1" 2>/dev/null; }
sha() { sha256sum "$1" | cut -c1-16; }
[ -d "$SRC/routes" ] && [ -f "$SRC/index.ts" ] || { echo "FAIL: Brain src nahi: $SRC"; exit 2; }
git -C "$REPO" fetch -q origin main 2>/dev/null
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT; mkdir -p "$T/routes"
show server/routes/auth.ts > "$T/routes/auth.ts"; [ -s "$T/routes/auth.ts" ] || { echo "FAIL: repo se auth.ts nahi mila"; exit 2; }
grep -q '"/refresh"' "$T/routes/auth.ts" || { echo "FAIL: repo auth.ts mein /refresh nahi — git fetch hua?"; exit 2; }
LA="$(sha "$SRC/routes/auth.ts")"; NA="$(sha "$T/routes/auth.ts")"
if [ "$LA" = "$NA" ]; then AUTH_ST=same; elif [ "$LA" = "$OLD_AUTH" ]; then AUTH_ST=update
else echo "STOP: live routes/auth.ts na purani repo wali ($LA) na nayi ($NA) — kisi ne server par badla. Kuch nahi badla."; diff "$SRC/routes/auth.ts" "$T/routes/auth.ts" | head -20; exit 3; fi
PK="$SRC/routes/auth-passkey.ts"; [ -f "$PK" ] || { echo "FAIL: live auth-passkey.ts nahi"; exit 2; }
python3 - "$PK" "$T/auth-passkey.ts" <<'PY'
import sys
src,out=sys.argv[1:3]
s=open(src).read()
rt='{ refresh_token: verified.session.refresh_token, expires_at: verified.session.expires_at }'
old='return sessionResult(verified.user, verified.session.access_token, req);'
new='return sessionResult(verified.user, verified.session.access_token, req, '+rt+');'
t='sessionResult: (user: any, accessToken?: string, req?: any) => Promise<unknown>;'
tn='sessionResult: (user: any, accessToken?: string, req?: any, rt?: { refresh_token?: string | null; expires_at?: number | null }) => Promise<unknown>;'
if 'refresh_token: verified.session.refresh_token' in s and tn in s:
    open(out,'w').write(s); print('same'); sys.exit(0)
if s.count(old)!=2 or s.count(t)!=1:
    print('STOP: auth-passkey.ts ke markers nahi mile (%d,%d)'%(s.count(old),s.count(t))); sys.exit(3)
open(out,'w').write(s.replace(old,new).replace(t,tn)); print('update')
PY
PKRC=$?; [ "$PKRC" = 0 ] || { echo "(auth-passkey.ts surgical patch nahi ban saka — kuch nahi badla)"; exit 3; }
PK_ST="$(python3 -c "print('same' if open('$T/auth-passkey.ts').read()==open('$PK').read() else 'update')")"
echo "status: auth.ts=$AUTH_ST passkey=$PK_ST"
[ "$AUTH_ST" = same ] && [ "$PK_ST" = same ] && { echo "Sab pehle se lagi hain."; exit 0; }
NM=""; d="$SRC"; for _ in 1 2 3; do [ -d "$d/node_modules" ] && { NM="$d/node_modules"; break; }; d="$(dirname "$d")"; done
[ -n "$NM" ] || { echo "FAIL: Brain ka node_modules nahi mila"; exit 2; }
mkdir -p "$T/pf/app/src"; (cd "$SRC" && tar cf - --exclude=node_modules .) | (cd "$T/pf/app/src" && tar xf -); ln -s "$NM" "$T/pf/app/node_modules"; PF="$T/pf/app/src"
cp "$T/routes/auth.ts" "$PF/routes/auth.ts"; cp "$T/auth-passkey.ts" "$PF/routes/auth-passkey.ts"
"$BUN" build "$PF/index.ts" --target=bun --outfile "$T/pf/out.js" >"$T/b.log" 2>&1 || { tail -20 "$T/b.log"; echo "!! nayi files ka build FAIL — kuch install nahi hua."; exit 1; }
mkdir -p "$B/routes"; cp -p "$SRC/routes/auth.ts" "$B/routes/auth.ts"; cp -p "$PK" "$B/routes/auth-passkey.ts"
cp "$T/routes/auth.ts" "$SRC/routes/auth.ts"; cp "$T/auth-passkey.ts" "$PK"
echo "lagaya. backup: $B"
restore() { cp -p "$B/routes/auth.ts" "$SRC/routes/auth.ts"; cp -p "$B/routes/auth-passkey.ts" "$PK"; pm2 restart anexomail-leo --update-env >/dev/null 2>&1; }
pm2 restart anexomail-leo --update-env >/dev/null 2>&1 && pm2 save >/dev/null 2>&1; sleep 6
H="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/health)"
C="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/api/auth/session)"
R0="$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'content-type: application/json' -d '{}' http://127.0.0.1:3100/api/auth/refresh)"
R1="$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'content-type: application/json' -d '{"refresh_token":"not-a-real-token"}' http://127.0.0.1:3100/api/auth/refresh)"
echo "Brain health $H · session bina token $C (401) · refresh khali $R0 (400) · refresh nakli $R1 (401)"
if [ "$H" != "200" ] || [ "$C" != "401" ] || [ "$R0" != "400" ] || [ "$R1" != "401" ]; then restore; echo "!! check FAIL — purani files wapas, health $(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/health)"; exit 1; fi
# ASLI SABOOT: test account ke asli refresh_token se naya token (secret screen par nahi)
envv(){ for f in /opt/anexomail/.env /etc/anexomail/sync.env; do [ -r "$f" ] && grep -m1 -E "^$1=" "$f" | cut -d= -f2- | sed -e "s/^[\"']//" -e "s/[\"']$//"; done | head -1; }
SBU="$(envv SUPABASE4_URL)"; SBK="$(envv SUPABASE4_SERVICE_ROLE_KEY)"; SBU="${SBU%/}"
if [ -n "$SBU" ] && [ -n "$SBK" ]; then
  EMAIL="${EMAIL:-basic.test@anexomail.com}"
  LINK="$(curl -s -m 20 -H "apikey: $SBK" -H "authorization: Bearer $SBK" -H 'content-type: application/json' -d "{\"type\":\"magiclink\",\"email\":\"$EMAIL\"}" "$SBU/auth/v1/admin/generate_link")"
  HASH="$(printf '%s' "$LINK" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("hashed_token",""))
except Exception: print("")')"
  SESS="$(curl -s -m 20 -H "apikey: $SBK" -H 'content-type: application/json' -d "{\"type\":\"magiclink\",\"token_hash\":\"$HASH\"}" "$SBU/auth/v1/verify")"
  RT="$(printf '%s' "$SESS" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("refresh_token",""))
except Exception: print("")')"; unset SESS LINK HASH SBK
  if [ -n "$RT" ]; then
    OUT="$(curl -s -m 20 -X POST -H 'content-type: application/json' -d "{\"refresh_token\":\"$RT\"}" http://127.0.0.1:3100/api/auth/refresh)"
    echo "asli refresh -> $(printf '%s' "$OUT" | python3 -c 'import json,sys
try:
  d=json.load(sys.stdin); print("OK naya token mila, naya refresh_token:", bool(d.get("refresh_token")), "expires_at:", d.get("expires_at"))
except Exception: print("FAIL jawab:", sys.stdin.read()[:80])')"
  else echo "(test refresh_token nahi bana — asli saboot chhoda)"; fi
  unset RT
fi
pm2 status anexomail-leo | head -6
echo "DONE: session refresh (Brain). Ab Web pull."
