#!/usr/bin/env bash
# ANEXOMAIL — Brain (anexomail-leo :3100) + chat (anexochat :3300) par IDENTITY VAULT (E66-E69) ka Bun hissa. Founder 22 Oct 2026.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/brain-identity-install.sh)
# Kya: naye lib files (identity-vault/mirror/guard) + live routes/auth.ts, routes/chat.ts, index.ts par chhote surgical tukde (anchor na mile => STOP, kuch nahi badla).
# PEPPER: DEVICE_VAULT_KEY /opt/anexomail/.env mein na ho to yahin ek random key banti hai (print NAHI hoti) — purani service-key-tail wali chaabi se bane device hash
#   dobara nahi milte (abhi koi user nahi, isliye theek). KEY_ROTATE nahi: ek baar set, phir kabhi na badlein.
# SQL (E66-E69) PEHLE chal chuki ho. Backup + bun build pre-flight + health + hostile-input + restore-on-fail. Rust, web, polar, Caddy ko haath nahi.
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"; SRC="${BRAIN_SRC:-/opt/anexomail/src}"; ENVF="${BRAIN_ENV:-/opt/anexomail/.env}"
BUN="$(command -v bun || echo /root/.bun/bin/bun)"; STAMP="$(date +%Y%m%d-%H%M%S)"; B="/root/anexomail-backups/brain-identity-$STAMP"
[ -d "$SRC/routes" ] && [ -f "$SRC/index.ts" ] && [ -f "$SRC/lib/supa.ts" ] || { echo "FAIL: Brain src nahi: $SRC"; exit 2; }
git -C "$REPO" fetch -q origin main 2>/dev/null
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT; mkdir -p "$T/repo/routes" "$T/repo/lib" "$T/out"
for f in routes/auth.ts routes/chat.ts index.ts lib/identity-vault.ts lib/identity-mirror.ts lib/identity-guard.ts; do
  git -C "$REPO" show "origin/main:server/$f" > "$T/repo/$f" 2>/dev/null; [ -s "$T/repo/$f" ] || { echo "FAIL: repo se server/$f nahi mila — git fetch hua?"; exit 2; }
done
git -C "$REPO" show origin/main:docs/cursor-work/server/brain_identity_patch.py > "$T/patch.py"; [ -s "$T/patch.py" ] || { echo "FAIL: brain_identity_patch.py nahi mila"; exit 2; }
ST="$(python3 -I "$T/patch.py" "$SRC" "$T/repo" "$T/out")"; RC=$?
[ "$RC" = 0 ] || { echo "$ST"; echo "(live file ke anchor alag hain — kuch nahi badla. Yeh output Claude ko bhejein.)"; exit 3; }
echo "status: $ST"
NEW_LIB=0; for f in identity-vault identity-mirror identity-guard; do cmp -s "$T/repo/lib/$f.ts" "$SRC/lib/$f.ts" 2>/dev/null || NEW_LIB=1; done
case "$ST" in *patched*) ;; *) [ "$NEW_LIB" = 0 ] && { echo "Pehle se lagi hai."; HAVEKEY=1; } ;; esac
# --- pre-flight build (copy par) ---
NM=""; d="$SRC"; for _ in 1 2 3; do [ -d "$d/node_modules" ] && { NM="$d/node_modules"; break; }; d="$(dirname "$d")"; done
[ -n "$NM" ] || { echo "FAIL: Brain ka node_modules nahi mila"; exit 2; }
mkdir -p "$T/pf/app/src"; (cd "$SRC" && tar cf - --exclude=node_modules .) | (cd "$T/pf/app/src" && tar xf -); ln -s "$NM" "$T/pf/app/node_modules"
for f in routes/auth.ts routes/chat.ts index.ts; do cp "$T/out/$f" "$T/pf/app/src/$f"; done
for f in identity-vault identity-mirror identity-guard; do cp "$T/repo/lib/$f.ts" "$T/pf/app/src/lib/$f.ts"; done
"$BUN" build "$T/pf/app/src/index.ts" --target=bun --outfile "$T/pf/out.js" >"$T/b.log" 2>&1 || { tail -20 "$T/b.log"; echo "!! nayi files ka build FAIL — kuch install nahi hua."; exit 1; }
"$BUN" build "$T/pf/app/src/routes/chat.ts" --target=bun --outfile "$T/pf/chat.js" >"$T/b2.log" 2>&1 || { tail -20 "$T/b2.log"; echo "!! chat.ts build FAIL — kuch install nahi hua."; exit 1; }
# --- pepper (print nahi hoti) ---
KEY_NOTE="DEVICE_VAULT_KEY pehle se set hai"
if ! grep -qE '^DEVICE_VAULT_KEY=.+' "$ENVF" 2>/dev/null; then
  [ -w "$ENVF" ] || [ ! -e "$ENVF" ] || { echo "FAIL: $ENVF likhne layak nahi"; exit 2; }
  mkdir -p "$B"; [ -e "$ENVF" ] && cp -p "$ENVF" "$B/env.bak"
  K="$(openssl rand -hex 32)"; umask 077; printf '\nDEVICE_VAULT_KEY=%s\n' "$K" >> "$ENVF"; unset K
  KEY_NOTE="DEVICE_VAULT_KEY NAYI bani aur $ENVF mein likhi (print nahi hui). Env backup: $B/env.bak"
fi
echo "$KEY_NOTE"
# --- install ---
mkdir -p "$B/routes" "$B/lib"; for f in routes/auth.ts routes/chat.ts index.ts; do cp -p "$SRC/$f" "$B/$f"; done
for f in identity-vault identity-mirror identity-guard; do [ -f "$SRC/lib/$f.ts" ] && cp -p "$SRC/lib/$f.ts" "$B/lib/$f.ts"; done
for f in routes/auth.ts routes/chat.ts index.ts; do cp "$T/out/$f" "$SRC/$f"; done
for f in identity-vault identity-mirror identity-guard; do cp "$T/repo/lib/$f.ts" "$SRC/lib/$f.ts"; done
echo "lagaya. backup: $B"
restore() {
  for f in routes/auth.ts routes/chat.ts index.ts; do cp -p "$B/$f" "$SRC/$f"; done
  for f in identity-vault identity-mirror identity-guard; do [ -f "$B/lib/$f.ts" ] && cp -p "$B/lib/$f.ts" "$SRC/lib/$f.ts" || rm -f "$SRC/lib/$f.ts"; done
  pm2 restart anexomail-leo --update-env >/dev/null 2>&1; pm2 restart anexochat --update-env >/dev/null 2>&1
}
pm2 restart anexomail-leo --update-env >/dev/null 2>&1; pm2 restart anexochat --update-env >/dev/null 2>&1; pm2 save >/dev/null 2>&1; sleep 7
H="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/health)"
# nakli/ghalat input: signup-appeal bina bayan => saaf 400 (500 nahi); chat identity bina token => 401
A="$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'content-type: application/json' -d '{"email":"x","statement":"short"}' http://127.0.0.1:3100/api/auth/signup-appeal)"
C="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3300/api/chat/integrity/identity)"
S="$(pm2 jlist 2>/dev/null | python3 -c 'import json,sys
try:
    for p in json.load(sys.stdin):
        if p.get("name") in ("anexomail-leo","anexochat"): print(p["name"]+"="+p["pm2_env"].get("status","?")+" restarts="+str(p["pm2_env"].get("restart_time")),end="  ")
except Exception: print("pm2?")')"
echo "health :3100 = $H   signup-appeal(ghalat) = $A (400 chahiye)   chat identity(bina token) = $C (401 chahiye)"
echo "pm2: $S"
if [ "$H" != 200 ] || [ "$A" != 400 ]; then echo "!! health/hostile-input FAIL — purani files wapas"; restore; sleep 5; echo "health ab: $(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/health)"; exit 1; fi
[ "$C" = 401 ] || echo "(dhyan: chat :3300 ne $C diya — anexochat alag jagah se chalti ho to wahan routes/chat.ts ki copy chahiye; Claude ko batayein. Bun fallback ke bina bhi Rust/baqi theek.)"
sleep 20; pm2 logs anexomail-leo --lines 40 --nostream 2>/dev/null | grep -i "identity" | tail -5
echo "OK — identity vault (Bun) lag gayi. Mirror 30 sec mein bharti hai; founder panel mein 'Identity vault' hissa."
