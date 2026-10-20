#!/usr/bin/env bash
# ANEXOMAIL — Brain (anexomail-leo) SAFE install: passkey routes G35 (restore-on-fail). Sirf routes/auth-passkey.ts.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/brain-passkey-install.sh)
#
# Kya hota hai: passkey status / recovery codes / backup passkey (QR + excludeCredentials). SQL E43 PEHLE chala lein
# (na chala ho to bhi kuch nahi tootta: status route "unknown" deta hai aur app gate nahi lagata).
# TECH-MAP Rule 25 ka apwad: WebAuthn verify abhi Bun mein hai (G42 = Rust port); naya kaam yahin tak, baqi Rust mein.
# Pehle live file ki sha dekhta hai: sirf "purani repo wali" ya "nayi" ho to lagata hai; kuch aur ho to STOP (founder ka koi aur badlav na mitay).
# polar-rust-payment, Rust, web ko haath nahi lagata.
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="/root/anexomail-backups/brain-passkey-$STAMP"
BUN="$(command -v bun || echo /root/.bun/bin/bun)"
F="routes/auth-passkey.ts"
OLD_OK="${OLD_OK:-6613e76750a3fe9f}"      # repo ka pichla version (commit 60bbe0f)
show() { git -C "$REPO" show "origin/main:$1" 2>/dev/null; }

find_brain_src() {
  local c cands=() base="${BRAIN:-/opt/anexomail}"
  [ -n "${BRAIN_SRC:-}" ] && cands+=("$BRAIN_SRC")
  cands+=("$base/src" "$base/server" "$base")
  while IFS= read -r c; do [ -n "$c" ] && cands+=("$c"); done < <(pm2 jlist 2>/dev/null | python3 -c 'import json,sys,os
try:
    for p in json.load(sys.stdin):
        if p.get("name")=="anexomail-leo":
            e=p["pm2_env"]; x=e.get("pm_exec_path") or ""; w=e.get("pm_cwd") or ""
            for d in (os.path.dirname(x), w, w+"/src", w+"/server"): print(d)
except Exception: pass' 2>/dev/null)
  for c in "${cands[@]}"; do
    case "$c" in *backup*|*/node_modules/*|*/.git/*|*/dist|*/dist/*|*/build|*/build/*) continue ;; esac
    if [ -d "$c/routes" ] && [ -f "$c/index.ts" ]; then echo "$c"; return 0; fi
  done
  return 1
}

SRC="$(find_brain_src)" || { echo "FAIL: live Brain (routes/ + index.ts) nahi mili. 'pm2 describe anexomail-leo | grep -E \"exec cwd|script path\"' ka output Claude ko bhejein."; exit 2; }
LIVE="$SRC/$F"
[ -f "$LIVE" ] || { echo "FAIL: $LIVE nahi mila"; exit 2; }
[ -x "$BUN" ] || { echo "FAIL: bun nahi mila"; exit 2; }
echo "Brain src: $SRC   bun: $($BUN --version)"

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
show "server/$F" >"$T/new.ts"; [ -s "$T/new.ts" ] || { echo "FAIL: repo (origin/main) se server/$F nahi mila — git fetch hua?"; exit 2; }
NEW_SHA="$(sha256sum "$T/new.ts" | cut -c1-16)"; LIVE_SHA="$(sha256sum "$LIVE" | cut -c1-16)"
echo "live sha $LIVE_SHA · repo sha $NEW_SHA"
if [ "$LIVE_SHA" = "$NEW_SHA" ]; then echo "Pehle se nayi version lagi hai — sirf restart check."; SKIP=1; else SKIP=0; fi
if [ "$SKIP" = 0 ] && [ "$LIVE_SHA" != "$OLD_OK" ]; then
  echo "STOP: live $F na purani repo wali hai na nayi (kisi ne server par badla). Kuch nahi badla."
  echo "Diff (live vs repo) ka aakhri hissa Claude ko bhejein:"; diff <(cat "$LIVE") "$T/new.ts" | head -40; exit 3
fi
# lib/webauthn live mein hona lazmi (import)
[ -f "$SRC/lib/webauthn.ts" ] || { echo "STOP: $SRC/lib/webauthn.ts nahi — passkey base hi nahi, kuch nahi badla."; exit 3; }

if [ "$SKIP" = 0 ]; then
  # syntax pre-flight (live lib ke saath): nayi file ko temp mein bana kar bun build
  mkdir -p "$T/pf/routes" "$T/pf/lib"; cp "$T/new.ts" "$T/pf/routes/auth-passkey.ts"; cp -r "$SRC/lib/." "$T/pf/lib/"
  "$BUN" build "$T/pf/routes/auth-passkey.ts" --target=bun --external '*' --outfile "$T/pf/out.js" >"$T/build.log" 2>&1 || { cat "$T/build.log"; echo "!! nayi file ka syntax/import FAIL — kuch install nahi hua."; exit 1; }
  mkdir -p "$BACKUP"; cp -p "$LIVE" "$BACKUP/auth-passkey.ts"
  cp "$T/new.ts" "$LIVE"; echo "lagaya. backup: $BACKUP/auth-passkey.ts"
fi

if command -v pm2 >/dev/null 2>&1 && [ -z "${NO_PM2:-}" ]; then
  pm2 restart anexomail-leo --update-env >/dev/null 2>&1 && pm2 save >/dev/null 2>&1
  sleep 5
  H="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/health)"
  S="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/api/auth/passkey/status)"
  echo "Brain health $H · /api/auth/passkey/status (bina login) $S (401 = route zinda)"
  if [ "$H" != "200" ] || [ "$S" != "401" ]; then
    if [ "$SKIP" = 0 ]; then
      cp -p "$BACKUP/auth-passkey.ts" "$LIVE"; pm2 restart anexomail-leo --update-env >/dev/null 2>&1; sleep 4
      echo "!! check FAIL — purani file wapas, Brain dobara chala: health $(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/health)"
    fi
    exit 1
  fi
  pm2 status anexomail-leo | head -8
else
  echo "(pm2 nahi mila / NO_PM2 — restart nahi kiya)"
fi
echo "DONE: Brain par G35 passkey routes."
