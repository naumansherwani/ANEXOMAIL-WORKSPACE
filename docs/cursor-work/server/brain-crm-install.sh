#!/usr/bin/env bash
# ANEXOMAIL — Brain (anexomail-leo) SAFE install: CRM tenant-isolation fix (17 Oct) — live par abhi PURANA routes/crm.ts hai.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/brain-crm-install.sh)
# Kyun: A1 audit (21 Oct) ne dikhaya — live crm.ts mein org filter nahi (shared items / mentions / approvals / audit / activities
# bina workspace filter ke) => ek workspace doosre ka CRM data dekh sakta tha. Repo wali file sab rows ko caller ke org par pin karti hai.
# Sirf routes/crm.ts. Rust / web / polar ko haath nahi. Backup + bun build pre-flight + health probe, fail par purani file wapas.
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"
STAMP="$(date +%Y%m%d-%H%M%S)"; BACKUP="/root/anexomail-backups/brain-crm-$STAMP"
BUN="$(command -v bun || echo /root/.bun/bin/bun)"; F="routes/crm.ts"; MARK="Tenant isolation (17 Oct 2026"
show() { git -C "$REPO" show "origin/main:$1" 2>/dev/null; }
SRC="${BRAIN_SRC:-/opt/anexomail/src}"
[ -d "$SRC/routes" ] && [ -f "$SRC/index.ts" ] || { echo "FAIL: Brain src nahi: $SRC (BRAIN_SRC=... de)"; exit 2; }
LIVE="$SRC/$F"; [ -f "$LIVE" ] || { echo "FAIL: $LIVE nahi"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
show "server/$F" >"$T/new.ts"; [ -s "$T/new.ts" ] || { echo "FAIL: repo se server/$F nahi mila"; exit 2; }
grep -q "$MARK" "$T/new.ts" || { echo "FAIL: repo file mein tenant-isolation marker nahi — kuch nahi badla"; exit 2; }
LS="$(sha256sum "$LIVE" | cut -c1-16)"; NS="$(sha256sum "$T/new.ts" | cut -c1-16)"; echo "live $LS · repo $NS · Brain $SRC"
if [ "$LS" = "$NS" ]; then echo "Pehle se nayi lagi hai."; SKIP=1; else SKIP=0; fi
if [ "$SKIP" = 0 ] && grep -q "$MARK" "$LIVE"; then
  echo "STOP: live crm.ts mein marker hai par repo se alag — kisi ne server par badla. Kuch nahi badla. Diff:"; diff "$LIVE" "$T/new.ts" | head -30; exit 3
fi
if [ "$SKIP" = 0 ]; then
  mkdir -p "$T/pf/routes" "$T/pf/lib"; cp "$T/new.ts" "$T/pf/routes/crm.ts"; cp -r "$SRC/lib/." "$T/pf/lib/"
  "$BUN" build "$T/pf/routes/crm.ts" --target=bun --external '*' --outfile "$T/pf/out.js" >"$T/b.log" 2>&1 || { cat "$T/b.log"; echo "!! nayi file ka syntax/import FAIL — kuch install nahi hua."; exit 1; }
  mkdir -p "$BACKUP"; cp -p "$LIVE" "$BACKUP/crm.ts"; cp "$T/new.ts" "$LIVE"; echo "lagaya. backup: $BACKUP/crm.ts"
fi
if command -v pm2 >/dev/null 2>&1 && [ -z "${NO_PM2:-}" ]; then
  pm2 restart anexomail-leo --update-env >/dev/null 2>&1 && pm2 save >/dev/null 2>&1; sleep 5
  H="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/health)"
  C="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/api/crm/overview)"
  echo "Brain health $H · /api/crm/overview (bina login) $C (401/403 = route zinda aur band)"
  case "$C" in 401|403) OKC=1;; *) OKC=0;; esac
  if [ "$H" != "200" ] || [ "$OKC" != 1 ]; then
    [ "$SKIP" = 0 ] && { cp -p "$BACKUP/crm.ts" "$LIVE"; pm2 restart anexomail-leo --update-env >/dev/null 2>&1; sleep 4; echo "!! check FAIL — purani file wapas, health $(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/health)"; }
    exit 1
  fi
  pm2 status anexomail-leo | head -8
fi
echo "DONE: Brain par CRM tenant isolation."
