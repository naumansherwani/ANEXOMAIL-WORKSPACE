#!/usr/bin/env bash
# ANEXOMAIL — Brain: LOGIN-LOOP FIX (dashboard -> login -> loading). Founder 21 Oct 2026.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/brain-auth-harden-install.sh)
# Sabab: har request par Supabase auth.getUser(token) network call; temporary error/429 -> 401 -> app sign-out.
# Fix: lib/auth-harden.ts (20 s verify cache, in-flight share, sirf temporary error par retry, temp error = 503 not 401).
# Files: lib/auth-harden.ts (nayi), lib/supa.ts, routes/auth.ts. Har file: live == purani repo wali ho tabhi badalti; kuch aur ho to STOP.
# Backup + bun build pre-flight + health + restore-on-fail. Rust/web/polar/passkey ko haath nahi.
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"; SRC="${BRAIN_SRC:-/opt/anexomail/src}"
BUN="$(command -v bun || echo /root/.bun/bin/bun)"; STAMP="$(date +%Y%m%d-%H%M%S)"; B="/root/anexomail-backups/brain-auth-harden-$STAMP"
OLD_SUPA="d06939d511a79f2b"; OLD_AUTH="a3e81c97ad9d1ea8"
show() { git -C "$REPO" show "origin/main:$1" 2>/dev/null; }
sha() { sha256sum "$1" | cut -c1-16; }
[ -d "$SRC/routes" ] && [ -f "$SRC/index.ts" ] || { echo "FAIL: Brain src nahi: $SRC"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT; mkdir -p "$T/lib" "$T/routes"
for f in lib/auth-harden.ts lib/supa.ts routes/auth.ts; do show "server/$f" > "$T/$f"; [ -s "$T/$f" ] || { echo "FAIL: repo se server/$f nahi mila"; exit 2; }; done
ST=""
chk() { # file oldsha
  local live="$SRC/$1" ; local ns; ns="$(sha "$T/$1")"
  if [ ! -f "$live" ]; then [ "$1" = "lib/auth-harden.ts" ] && { ST="$ST $1:new"; return 0; }; echo "FAIL: live $1 nahi"; return 1; fi
  local ls; ls="$(sha "$live")"
  if [ "$ls" = "$ns" ]; then ST="$ST $1:same"; return 0; fi
  if [ "$ls" = "$2" ]; then ST="$ST $1:update"; return 0; fi
  echo "STOP: live $1 na purani repo wali ($ls) na nayi ($ns) — kisi ne server par badla. Kuch nahi badla."; diff "$live" "$T/$1" | head -20; return 1
}
chk lib/auth-harden.ts x || exit 3
chk lib/supa.ts "$OLD_SUPA" || exit 3
chk routes/auth.ts "$OLD_AUTH" || exit 3
echo "status:$ST"
case "$ST" in *update*|*:new*) ;; *) echo "Sab pehle se lagi hain."; exit 0;; esac
# pre-flight: poori Brain copy par nayi files lagao aur build karo (live ko haath lagane se pehle)
# node_modules Brain src ke upar (ya andar) hota hai — upar chadh kar dhoondo, pre-flight copy ke saath lagao.
NM=""; d="$SRC"; for _ in 1 2 3; do [ -d "$d/node_modules" ] && { NM="$d/node_modules"; break; }; d="$(dirname "$d")"; done
[ -n "$NM" ] || { echo "FAIL: Brain ka node_modules nahi mila (SRC=$SRC)"; exit 2; }
mkdir -p "$T/pf/app/src"; (cd "$SRC" && tar cf - --exclude=node_modules .) | (cd "$T/pf/app/src" && tar xf -); ln -s "$NM" "$T/pf/app/node_modules"; PF="$T/pf/app/src"
cp "$T/lib/auth-harden.ts" "$PF/lib/"; cp "$T/lib/supa.ts" "$PF/lib/"; cp "$T/routes/auth.ts" "$PF/routes/"
"$BUN" build "$PF/index.ts" --target=bun --outfile "$T/pf/out.js" >"$T/b.log" 2>&1 || { tail -20 "$T/b.log"; echo "!! nayi files ka build FAIL — kuch install nahi hua."; exit 1; }
mkdir -p "$B/lib" "$B/routes"
for f in lib/supa.ts routes/auth.ts lib/auth-harden.ts; do [ -f "$SRC/$f" ] && cp -p "$SRC/$f" "$B/$f"; done
cp "$T/lib/auth-harden.ts" "$SRC/lib/auth-harden.ts"; cp "$T/lib/supa.ts" "$SRC/lib/supa.ts"; cp "$T/routes/auth.ts" "$SRC/routes/auth.ts"
echo "lagaya. backup: $B"
restore() { for f in lib/supa.ts routes/auth.ts; do cp -p "$B/$f" "$SRC/$f"; done; [ -f "$B/lib/auth-harden.ts" ] && cp -p "$B/lib/auth-harden.ts" "$SRC/lib/auth-harden.ts" || rm -f "$SRC/lib/auth-harden.ts"; pm2 restart anexomail-leo --update-env >/dev/null 2>&1; }
pm2 restart anexomail-leo --update-env >/dev/null 2>&1 && pm2 save >/dev/null 2>&1; sleep 6
H="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/health)"
C="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/api/auth/session)"
C2="$(curl -s -o /dev/null -w '%{http_code}' -H 'authorization: Bearer not-a-real-token' http://127.0.0.1:3100/api/auth/session)"
echo "Brain health $H · /api/auth/session bina token $C (401) · ghalat token $C2 (401, 503 nahi)"
if [ "$H" != "200" ] || [ "$C" != "401" ] || [ "$C2" != "401" ]; then restore; echo "!! check FAIL — purani files wapas, health $(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/health)"; exit 1; fi
pm2 status anexomail-leo | head -6
echo "DONE: login-loop fix (Brain)."
