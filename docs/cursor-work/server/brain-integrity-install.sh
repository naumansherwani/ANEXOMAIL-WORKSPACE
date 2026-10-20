#!/usr/bin/env bash
# ANEXOMAIL — Brain (anexomail-leo) SAFE install: blocked-account guard G37 (restore-on-fail).
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/brain-integrity-install.sh)
#
# Kya hota hai: blocked/purged account ki har /api call 403 `account_blocked` (siwaye login/logout, apna delete, public, health).
# Naya file lib/integrity-gate.ts + live index.ts mein 3 line (import + 2 mount). Baqi index.ts ko haath nahi lagata
# (founder ke server-side badlav bachte hain). Anchor na mile (founderGate nahi) => STOP, kuch nahi badla.
# SQL phase24a (account_integrity table) pehle chal chuka ho — na ho to guard khula rehta hai (fail-open), kuch nahi tootta.
# polar-rust-payment, Rust, web ko haath nahi lagata. Dobara chalana safe.
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="/root/anexomail-backups/brain-integrity-$STAMP"
BUN="$(command -v bun || echo /root/.bun/bin/bun)"
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
[ -x "$BUN" ] || { echo "FAIL: bun nahi mila"; exit 2; }
[ -f "$SRC/lib/supa.ts" ] || { echo "STOP: $SRC/lib/supa.ts nahi — kuch nahi badla."; exit 3; }
echo "Brain src: $SRC   bun: $($BUN --version)"

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
show "server/lib/integrity-gate.ts" >"$T/gate.ts"; [ -s "$T/gate.ts" ] || { echo "FAIL: repo (origin/main) se server/lib/integrity-gate.ts nahi mila — git fetch hua?"; exit 2; }
cp "$SRC/index.ts" "$T/index.ts.try"

python3 -I - "$T/index.ts.try" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read(); ch=[]
if 'integrityGate' in s and 'lib/integrity-gate' in s:
    print("index.ts: guard pehle se juda hai"); sys.exit(0)
if 'integrityGate' in s:
    print("STOP: index.ts mein integrityGate naam pehle se kisi aur cheez ka hai"); sys.exit(4)
imp='import { founderGate } from "./lib/founder-gate";\n'
mount='app.use("/api/founder", founderGate);\n'
if imp not in s or s.count(mount)!=1:
    print("STOP: live index.ts mein founderGate import/mount anchor nahi mila (ya do baar hai) — kuch nahi badla."); sys.exit(4)
s=s.replace(imp, imp+'import { integrityGate } from "./lib/integrity-gate";\n',1)
s=s.replace(mount, mount+'\n// Blocked/purged account (G37): sirf auth / apna delete / public / health. Founder gate ke BAAD, baqi routers se PEHLE.\napp.use("/api", integrityGate);\n',1)
leo='app.use("/api/leo", async (req, res) => {'
if s.count(leo)==1:
    s=s.replace(leo,'// Blocked account guard (G37) — Leo bridge ke liye bhi.\napp.use("/api/leo", integrityGate);\n\n'+leo,1)
else:
    print("note: Leo bridge anchor nahi mila — /api/leo ke liye alag guard nahi laga (baqi /api laga hai)")
open(p,'w').write(s); print("index.ts: guard joda")
PY
prc=$?
[ $prc -eq 0 ] || exit 3

NEWSHA="$(sha256sum "$T/index.ts.try" | cut -c1-16)"; OLDSHA="$(sha256sum "$SRC/index.ts" | cut -c1-16)"
GATE_SAME=0; [ -f "$SRC/lib/integrity-gate.ts" ] && cmp -s "$T/gate.ts" "$SRC/lib/integrity-gate.ts" && GATE_SAME=1
if [ "$NEWSHA" = "$OLDSHA" ] && [ "$GATE_SAME" = 1 ]; then echo "Pehle se lagi hui hai — sirf restart check."; SKIP=1; else SKIP=0; fi

if [ "$SKIP" = 0 ]; then
  # pre-flight: live lib ke saath bun build
  mkdir -p "$T/pf/lib"; cp -r "$SRC/lib/." "$T/pf/lib/"; cp "$T/gate.ts" "$T/pf/lib/integrity-gate.ts"
  "$BUN" build "$T/pf/lib/integrity-gate.ts" --target=bun --external '*' --outfile "$T/pf/out.js" >"$T/build.log" 2>&1 || { cat "$T/build.log"; echo "!! guard file ka syntax FAIL — kuch install nahi hua."; exit 1; }
  mkdir -p "$BACKUP"; cp -p "$SRC/index.ts" "$BACKUP/index.ts"; [ -f "$SRC/lib/integrity-gate.ts" ] && cp -p "$SRC/lib/integrity-gate.ts" "$BACKUP/integrity-gate.ts.prev"
  cp "$T/gate.ts" "$SRC/lib/integrity-gate.ts"; cp "$T/index.ts.try" "$SRC/index.ts"
  echo "lagaya. backup: $BACKUP"
fi

if command -v pm2 >/dev/null 2>&1 && [ -z "${NO_PM2:-}" ]; then
  pm2 restart anexomail-leo --update-env >/dev/null 2>&1 && pm2 save >/dev/null 2>&1
  sleep 5
  H="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/health)"
  A="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/api/auth/passkey/status)"
  echo "Brain health $H · bina login /api/auth/passkey/status $A (401 = routes zinda, guard ne seedhe nahi roka)"
  if [ "$H" != "200" ] || { [ "$A" != "401" ] && [ "$A" != "200" ]; }; then
    if [ "$SKIP" = 0 ]; then
      cp -p "$BACKUP/index.ts" "$SRC/index.ts"
      if [ -f "$BACKUP/integrity-gate.ts.prev" ]; then cp -p "$BACKUP/integrity-gate.ts.prev" "$SRC/lib/integrity-gate.ts"; else rm -f "$SRC/lib/integrity-gate.ts"; fi
      pm2 restart anexomail-leo --update-env >/dev/null 2>&1; sleep 4
      echo "!! check FAIL — purani files wapas, Brain dobara chala: health $(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/health)"
    fi
    exit 1
  fi
  pm2 status anexomail-leo | head -8
else
  echo "(pm2 nahi mila / NO_PM2 — restart nahi kiya)"
fi
echo "DONE: Brain par G37 blocked-account guard."
