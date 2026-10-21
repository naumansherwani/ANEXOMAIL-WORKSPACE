#!/usr/bin/env bash
# ANEXOMAIL — Brain: B6 (G16) Manage-billing fallback + billing mount-order fix. 21 Oct 2026.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/brain-portal-install.sh)
# Kya: (1) routes/billing-sync.ts mein POST /api/billing/portal (Rust billing.portal PRIMARY; yeh sirf fallback)
#      (2) index.ts mein billing-sync router polar.ts router se PEHLE (purana /subscription shadow band)
# Surgical + idempotent (brain_portal_patch.py). Anchor na mile to STOP. Backup + bun build pre-flight + health + restore-on-fail.
# Polar engine / Rust / Web / Caddy ko haath nahi.
set -uo pipefail
SRC="${BRAIN_SRC:-/opt/anexomail/src}"; BUN="$(command -v bun || echo /root/.bun/bin/bun)"; REPO="${REPO:-/opt/anexomail-web}"
B="/root/anexomail-backups/brain-portal-$(date +%Y%m%d-%H%M%S)"
[ -d "$SRC/routes" ] && [ -f "$SRC/index.ts" ] && [ -f "$SRC/routes/billing-sync.ts" ] || { echo "FAIL: Brain src nahi: $SRC (BRAIN_SRC=... de)"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
git -C "$REPO" show origin/main:docs/cursor-work/server/brain_portal_patch.py >"$T/patch.py" 2>/dev/null && [ -s "$T/patch.py" ] || { echo "FAIL: repo se patch script nahi mili (git fetch?)"; exit 2; }
git -C "$REPO" show origin/main:server/routes/billing-sync.ts >"$T/repo-bs.ts" 2>/dev/null && [ -s "$T/repo-bs.ts" ] || { echo "FAIL: repo billing-sync.ts nahi"; exit 2; }
python3 -I "$T/patch.py" "$SRC" "$T/repo-bs.ts" "$T/new"; RC=$?
[ "$RC" = 4 ] && { echo "Sab pehle se lagi hain."; exit 0; }
[ "$RC" = 0 ] || { echo "(kuch nahi badla — upar ka STOP Claude ko paste karein)"; exit 3; }
NM=""; d="$SRC"; for _ in 1 2 3; do [ -d "$d/node_modules" ] && { NM="$d/node_modules"; break; }; d="$(dirname "$d")"; done
[ -n "$NM" ] || { echo "FAIL: Brain ka node_modules nahi mila"; exit 2; }
mkdir -p "$T/pf/app/src"; (cd "$SRC" && tar cf - --exclude=node_modules .) | (cd "$T/pf/app/src" && tar xf -); ln -s "$NM" "$T/pf/app/node_modules"
cp "$T/new/routes/billing-sync.ts" "$T/pf/app/src/routes/billing-sync.ts"; cp "$T/new/index.ts" "$T/pf/app/src/index.ts"
"$BUN" build "$T/pf/app/src/index.ts" --target=bun --outfile "$T/pf/out.js" >"$T/b.log" 2>&1 || { tail -20 "$T/b.log"; echo "!! build FAIL — kuch install nahi hua."; exit 1; }
mkdir -p "$B/routes"; cp -p "$SRC/routes/billing-sync.ts" "$B/routes/"; cp -p "$SRC/index.ts" "$B/"
cp "$T/new/routes/billing-sync.ts" "$SRC/routes/billing-sync.ts"; cp "$T/new/index.ts" "$SRC/index.ts"; echo "lagaya. backup: $B"
restore(){ cp -p "$B/routes/billing-sync.ts" "$SRC/routes/"; cp -p "$B/index.ts" "$SRC/"; pm2 restart anexomail-leo --update-env >/dev/null 2>&1; }
pm2 restart anexomail-leo --update-env >/dev/null 2>&1 && pm2 save >/dev/null 2>&1; sleep 6
H="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/health)"
P="$(curl -s -o /dev/null -w '%{http_code}' -X POST http://127.0.0.1:3100/api/billing/portal)"
S="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/api/billing/subscription)"
echo "Brain health $H (200) · portal bina token $P (401) · subscription bina token $S (401)"
if [ "$H" != "200" ] || [ "$P" != "401" ] || [ "$S" != "401" ]; then restore; echo "!! check FAIL — purani files wapas, health $(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/health)"; exit 1; fi
pm2 status anexomail-leo | head -6
echo "DONE: Brain portal fallback + billing mount order."
