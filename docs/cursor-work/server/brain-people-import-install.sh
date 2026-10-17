#!/usr/bin/env bash
# ANEXOMAIL — Brain (anexomail-leo) SAFE install: "bring your address book" (People import + Leads import + Move to People).
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/brain-people-import-install.sh)
#
# Kya hota hai:
#   * 2 nayi files Brain mein jaati hain:  routes/people-import.ts  aur  lib/import-rows.ts   (live crm.ts / contacts.ts ko haath nahi lagta)
#   * live index.ts mein 2 line judti hain (anchor-based, idempotent): import + app.use("/api", peopleImport) — contactsRouter ke baad, crm se pehle.
#   * Pehle tests live index.ts ki copy par chalte hain; fail => kuch install nahi hota. Build/health fail => purani files wapas.
# Kuch bhejta nahi: import sirf rows likhta hai (na mail, na invite). Rust, web, polar-rust-payment :3400 ko haath nahi lagata.
# Zaroori: live lib/supa.ts mein `admin` aur live lib/plan.ts mein `resolvePlan` hona chahiye (script pehle yehi dekhta hai).
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="/root/anexomail-backups/brain-people-import-$STAMP"
BUN="$(command -v bun || echo /root/.bun/bin/bun)"
show() { git -C "$REPO" show "origin/main:$1" 2>/dev/null; }

BR="$(find "${BRAIN:-/opt/anexomail}" -type d -name routes -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | head -1)"
[ -n "$BR" ] || { echo "FAIL: live Brain routes/ nahi mila (BRAIN=${BRAIN:-/opt/anexomail}?)"; exit 2; }
SRC="$(dirname "$BR")"; LIB="$SRC/lib"; IDX="$SRC/index.ts"
[ -d "$LIB" ] && [ -f "$IDX" ] || { echo "FAIL: $LIB ya $IDX nahi mili"; exit 2; }
[ -x "$BUN" ] || { echo "FAIL: bun nahi mila"; exit 2; }
echo "Brain src: $SRC   bun: $($BUN --version)"

echo "== 0) live Brain mein zaroori cheezein hain?"
grep -Eq 'export (const|let) admin\b' "$LIB/supa.ts" 2>/dev/null || { echo "FAIL: live lib/supa.ts mein 'export const admin' nahi mila — install nahi hua. Output Claude ko paste karein."; exit 2; }
grep -Eq 'export (async )?function resolvePlan\b|export const resolvePlan\b' "$LIB/plan.ts" 2>/dev/null || { echo "FAIL: live lib/plan.ts mein resolvePlan nahi mila — install nahi hua. Output Claude ko paste karein."; exit 2; }
grep -Eq 'export type PlanTier\b' "$LIB/plan.ts" 2>/dev/null || echo "   (note: live plan.ts mein 'export type PlanTier' nahi — bun type ko ignore karta hai, build par asar nahi)"
echo "   supa.ts: admin OK   plan.ts: resolvePlan OK"

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
for f in server/routes/people-import.ts server/lib/import-rows.ts server/routes/people-import.test.ts; do
  show "$f" >"$T/$(basename "$f")"; [ -s "$T/$(basename "$f")" ] || { echo "FAIL: repo (origin/main) se $f nahi mili — git fetch hua?"; exit 2; }
done

# live index.ts par patch (idempotent) — pre-flight aur asli install dono mein yehi function
patch_index() { python3 - "$1" <<'PY'
import sys,re
p=sys.argv[1]; s=open(p).read()
if "peopleImport" in s:
    print("index.ts: peopleImport pehle se hai"); sys.exit(0)
imp='import { peopleImport } from "./routes/people-import";'
m=list(re.finditer(r'^import .*;\s*$', s, re.M))
if not m: print("PATCH FAIL: index.ts mein koi import line nahi mili"); sys.exit(4)
s=s[:m[-1].end()]+"\n"+imp+s[m[-1].end():]
mount='// Bring-your-own address book: contacts/import, crm/leads/import, crm/leads/move-to-people (own file, own org scope).\napp.use("/api", peopleImport);\n'
a=re.search(r'^app\.use\("/api", contactsRouter\);[^\n]*\n', s, re.M)
if a:
    s=s[:a.end()]+mount+s[a.end():]
else:
    b=re.search(r'^app\.use\("/api", crm\);[^\n]*\n', s, re.M)
    if not b: print('PATCH FAIL: app.use("/api", contactsRouter) / app.use("/api", crm) anchor index.ts mein nahi mila'); sys.exit(4)
    s=s[:b.start()]+mount+s[b.start():]
open(p,"w").write(s); print("index.ts: peopleImport lag gaya")
PY
}

echo "== 1) pre-flight: wahi tests server par (live index.ts ki copy par patch laga kar) — kuch install nahi hua abhi"
mkdir -p "$T/pf/server/routes" "$T/pf/server/lib"
cp "$T/people-import.ts" "$T/pf/server/routes/people-import.ts"
cp "$T/people-import.test.ts" "$T/pf/server/routes/people-import.test.ts"
cp "$T/import-rows.ts" "$T/pf/server/lib/import-rows.ts"
# test supa/plan/express ko mock karta hai; mock ko jaane ke liye files chahiye (asli live files ki zaroorat nahi)
echo 'export const admin: any = null;' >"$T/pf/server/lib/supa.ts"
echo 'export type PlanTier = "basic"|"pro"|"business"; export async function resolvePlan(_u: string, _e: string): Promise<PlanTier> { return "basic"; }' >"$T/pf/server/lib/plan.ts"
cp "$IDX" "$T/pf/server/index.ts"; patch_index "$T/pf/server/index.ts" || { echo "!! live index.ts par patch nahi lag sakta — kuch install nahi hua."; exit 4; }
( cd "$T/pf" && "$BUN" test server >"$T/test.log" 2>&1 ); trc=$?
tail -6 "$T/test.log"
[ "$trc" -eq 0 ] || { echo "!! pre-flight tests FAIL — kuch install nahi hua. Upar ka output Claude ko paste karein."; exit 1; }

echo "== 2) pehle se install hai?"
if [ -f "$BR/people-import.ts" ] && cmp -s "$T/people-import.ts" "$BR/people-import.ts" && cmp -s "$T/import-rows.ts" "$LIB/import-rows.ts" 2>/dev/null && grep -q peopleImport "$IDX"; then
  echo "   pehle se install hai (files same) — kuch nahi karna."; exit 0
fi
for f in "$BR/people-import.ts" "$LIB/import-rows.ts"; do
  if [ -f "$f" ] && [ "${FORCE:-}" != "1" ] && ! cmp -s "$f" "$T/$(basename "$f")"; then
    echo "!! $f pehle se maujood hai aur repo se alag hai (live par kisi ne badla). Overwrite chahiye to: FORCE=1 bash <(git -C $REPO show origin/main:docs/cursor-work/server/brain-people-import-install.sh)"; exit 3
  fi
done

echo "== 3) backup + install"
mkdir -p "$BACKUP"; cp -p "$IDX" "$BACKUP/index.ts"
[ -f "$BR/people-import.ts" ] && cp -p "$BR/people-import.ts" "$BACKUP/people-import.ts"
[ -f "$LIB/import-rows.ts" ] && cp -p "$LIB/import-rows.ts" "$BACKUP/import-rows.ts"
restore() {
  cp -p "$BACKUP/index.ts" "$IDX"
  [ -f "$BACKUP/people-import.ts" ] && cp -p "$BACKUP/people-import.ts" "$BR/people-import.ts" || rm -f "$BR/people-import.ts"
  [ -f "$BACKUP/import-rows.ts" ] && cp -p "$BACKUP/import-rows.ts" "$LIB/import-rows.ts" || rm -f "$LIB/import-rows.ts"
  pm2 restart anexomail-leo --update-env >/dev/null 2>&1; pm2 save >/dev/null 2>&1
}
cp "$T/import-rows.ts" "$LIB/import-rows.ts"; cp "$T/people-import.ts" "$BR/people-import.ts"
patch_index "$IDX" || { echo "!! index.ts patch fail — purani files wapas"; restore; exit 4; }
"$BUN" build "$IDX" --target bun --outfile /tmp/.brain-pi-build-check.js >/tmp/.brain-pi-build.log 2>&1 || { echo "!! bun build FAIL (import/syntax) — purani files wapas:"; head -20 /tmp/.brain-pi-build.log | cut -c1-180; restore; exit 4; }
rm -f /tmp/.brain-pi-build-check.js

echo "== 4) pm2 restart anexomail-leo + health"
pm2 restart anexomail-leo --update-env >/dev/null 2>&1; pm2 save >/dev/null 2>&1; sleep 4
code="$(curl -s -m 8 -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/health 2>/dev/null)"
if [ "$code" != "200" ]; then echo "!! health=$code — PURANI files wapas laga raha hoon"; restore; sleep 4; echo "   ab health: $(curl -s -m 8 -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/health)"; exit 1; fi

echo "== 5) live check (bina login teeno route 401 dene chahiye; 404 = mount nahi hua)"
for p in /api/contacts/import /api/crm/leads/import /api/crm/leads/move-to-people; do
  printf '   POST %-34s %s\n' "$p" "$(curl -s -m 8 -X POST -H 'content-type: application/json' -d '{}' -o /dev/null -w '%{http_code}' http://127.0.0.1:3100$p)"
done
echo "OK — Brain par People import live (Rust port baad mein, Rule 22). Backup: $BACKUP"
echo "   wapas lene ke liye: cp $BACKUP/index.ts $IDX && rm -f $BR/people-import.ts $LIB/import-rows.ts && pm2 restart anexomail-leo --update-env"
