#!/usr/bin/env bash
# ANEXOMAIL — Brain (anexomail-leo) SAFE install: founder gate + organisation authorisation (restore-on-fail).
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/brain-org-install.sh)
#
# Kya theek hota hai:
#   1. /api/founder/* par EK founder-gate (index.ts mein sab routers se pehle). Pehle har founder router sirf "koi logged-in hai?" poochta tha,
#      yaani koi bhi customer token se movein (mailbox/DNS/rollback/invoice), release lock/run, revenue, storage, org kill-switch chal sakte thay.
#   2. routes/org.ts: member revoke / policy toggle / session kill / break-glass / mailbox create par ROLE check + sirf apni organisation;
#      audit read/verify sirf apni chain; "pehli organisation utha lo" fallback sirf founder ke liye; revoked member ki org nahi.
# Sirf anexomail-leo (Brain). Rust, web, polar-rust-payment :3400 ko haath nahi lagata. SQL phase64 PEHLE chala lein.
# Pehle server par wahi tests chalte hain jo repo mein pass hain (live index.ts par patch laga kar); fail ho to kuch install nahi hota.
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="/root/anexomail-backups/brain-org-$STAMP"
BUN="$(command -v bun || echo /root/.bun/bin/bun)"
show() { git -C "$REPO" show "origin/main:$1" 2>/dev/null; }

BR="$(find "${BRAIN:-/opt/anexomail}" -type d -name routes -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | head -1)"
[ -n "$BR" ] && [ -f "$BR/org.ts" ] || { echo "FAIL: live Brain routes/org.ts nahi mili (BRAIN=${BRAIN:-/opt/anexomail}?)"; exit 2; }
SRC="$(dirname "$BR")"; LIB="$SRC/lib"; IDX="$SRC/index.ts"
[ -d "$LIB" ] && [ -f "$IDX" ] || { echo "FAIL: $LIB ya $IDX nahi mili"; exit 2; }
[ -x "$BUN" ] || { echo "FAIL: bun nahi mila"; exit 2; }
echo "Brain src: $SRC   bun: $($BUN --version)"

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
for f in server/routes/org.ts server/lib/org-authz.ts server/lib/founder-gate-core.ts server/lib/founder-gate.ts; do
  show "$f" >"$T/$(basename "$f")"; [ -s "$T/$(basename "$f")" ] || { echo "FAIL: repo (origin/main) se $f nahi mili — git fetch hua?"; exit 2; }
done

# live index.ts par patch (idempotent) — ek hi function, pre-flight aur asli install dono mein
patch_index() { python3 - "$1" <<'PY'
import sys,re
p=sys.argv[1]; s=open(p).read()
if "founderGate" in s:
    print("index.ts: founderGate pehle se hai"); sys.exit(0)
imp='import { founderGate } from "./lib/founder-gate";\n'
m=list(re.finditer(r'^import .*;\s*$', s, re.M))
if not m: print("PATCH FAIL: index.ts mein koi import line nahi mili"); sys.exit(4)
s=s[:m[-1].end()]+"\n"+imp.rstrip("\n")+s[m[-1].end():]
mount='// Founder gate — EVERY /api/founder/* call needs a founder identity (mounted before all routers).\napp.use("/api/founder", founderGate);\n\n'
a=re.search(r'^app\.use\("/api/auth"', s, re.M)
if not a: print('PATCH FAIL: app.use("/api/auth" anchor index.ts mein nahi mila'); sys.exit(4)
s=s[:a.start()]+mount+s[a.start():]
open(p,"w").write(s); print("index.ts: founderGate lag gaya")
PY
}

echo "== 1) pre-flight: wahi tests server par, LIVE index.ts ki copy par (kuch install nahi hua abhi)"
mkdir -p "$T/pf/server/routes" "$T/pf/server/lib"
cp "$T/org.ts" "$T/pf/server/routes/org.ts"
for f in org-authz founder-gate-core founder-gate; do cp "$T/$f.ts" "$T/pf/server/lib/$f.ts"; done
echo 'export const admin: any = null;' >"$T/pf/server/lib/supa.ts"
cp "$IDX" "$T/pf/server/index.ts"; patch_index "$T/pf/server/index.ts" || { echo "!! live index.ts par patch nahi lag sakta — kuch install nahi hua."; exit 4; }
for f in lib/org-authz.test.ts lib/founder-gate.test.ts routes/org.guard.test.ts index.order.test.ts; do show "server/$f" >"$T/pf/server/$f"; done
( cd "$T/pf" && "$BUN" test server >"$T/test.log" 2>&1 ); trc=$?
tail -6 "$T/test.log"
[ "$trc" -eq 0 ] || { echo "!! pre-flight tests FAIL — kuch install nahi hua. Upar ka output Claude ko paste karein."; exit 1; }

echo "== 2) live org.ts / index.ts kis version ke hain?"
LIVE="$(sha256sum "$BR/org.ts" | cut -c1-16)"
OLD="$(git -C "$REPO" show "${OLD_REF:-464baae}:server/routes/org.ts" 2>/dev/null | sha256sum | cut -c1-16)"
NEWS="$(sha256sum "$T/org.ts" | cut -c1-16)"
echo "   org.ts  live=$LIVE  repo-purani=$OLD  repo-nayi=$NEWS"
if [ "$LIVE" = "$NEWS" ] && grep -q founderGate "$IDX" && cmp -s "$T/founder-gate.ts" "$LIB/founder-gate.ts" 2>/dev/null; then echo "   pehle se install hai — kuch nahi karna."; exit 0; fi
if [ "$LIVE" != "$OLD" ] && [ "$LIVE" != "$NEWS" ] && [ "${FORCE:-}" != "1" ]; then
  echo "!! live org.ts repo ki purani version se bhi alag hai (live par kisi ne alag badla hai). Overwrite se pehle farq dekhein:"
  diff <(git -C "$REPO" show "${OLD_REF:-464baae}:server/routes/org.ts" 2>/dev/null) "$BR/org.ts" | head -40 | cut -c1-160   # < repo ki purani, > live par jo alag hai
  echo "   Agar overwrite theek hai to:  FORCE=1 bash <(git -C $REPO show origin/main:docs/cursor-work/server/brain-org-install.sh)"
  exit 3
fi

echo "== 3) backup + install"
mkdir -p "$BACKUP"; cp -p "$BR/org.ts" "$BACKUP/org.ts"; cp -p "$IDX" "$BACKUP/index.ts"
for f in org-authz founder-gate-core founder-gate; do [ -f "$LIB/$f.ts" ] && cp -p "$LIB/$f.ts" "$BACKUP/$f.ts"; done
restore() {
  cp -p "$BACKUP/org.ts" "$BR/org.ts"; cp -p "$BACKUP/index.ts" "$IDX"
  for f in org-authz founder-gate-core founder-gate; do [ -f "$BACKUP/$f.ts" ] && cp -p "$BACKUP/$f.ts" "$LIB/$f.ts" || rm -f "$LIB/$f.ts"; done
  pm2 restart anexomail-leo --update-env >/dev/null 2>&1; pm2 save >/dev/null 2>&1
}
for f in org-authz founder-gate-core founder-gate; do cp "$T/$f.ts" "$LIB/$f.ts"; done
cp "$T/org.ts" "$BR/org.ts"
patch_index "$IDX" || { echo "!! index.ts patch fail — purani files wapas"; restore; exit 4; }
"$BUN" build "$IDX" --target bun --outfile /tmp/.brain-build-check.js >/tmp/.brain-build.log 2>&1 || { echo "!! bun build FAIL (import/syntax) — purani files wapas:"; head -20 /tmp/.brain-build.log | cut -c1-180; restore; exit 1; }
rm -f /tmp/.brain-build-check.js

echo "== 4) pm2 restart anexomail-leo + health"
pm2 restart anexomail-leo --update-env >/dev/null 2>&1; pm2 save >/dev/null 2>&1; sleep 4
code="$(curl -s -m 8 -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/health 2>/dev/null)"
if [ "$code" != "200" ]; then echo "!! health=$code — PURANI files wapas laga raha hoon"; restore; sleep 4; echo "   ab health: $(curl -s -m 8 -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/health)"; exit 1; fi

echo "== 5) live check (bina login: sab 401; naye gate se customer-token par 403 aata hai — asli test: basic.test se login karke /api/founder/org/list = 403)"
for p in /api/founder/org/list /api/founder/movein/cockpit /api/founder/release/overview /api/org/audit; do printf '   %-34s %s\n' "$p" "$(curl -s -m 8 -o /dev/null -w '%{http_code}' http://127.0.0.1:3100$p)"; done
echo "OK — Brain par founder-gate + org authorisation live. Backup: $BACKUP"
echo "   wapas lene ke liye: cp $BACKUP/org.ts $BR/org.ts && cp $BACKUP/index.ts $IDX && pm2 restart anexomail-leo --update-env"
