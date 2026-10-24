#!/usr/bin/env bash
# ANEXOMAIL — Brain (Bun :3100, pm2 anexomail-leo) FALLBACK fixes for the Pro package (24 Oct 2026). Koi SQL nahi. Rust/Web ko haath nahi.
#   bash <(git -C /opt/anexomail-web fetch -q origin main; git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/brain-pro-install.sh)
# Kya: routes/mail.ts (snooze ab folder nahi badalta + galat date par process crash band + Pro gate, status/move/labels validation, Snoozed folder),
#      routes/mail-compose.ts (templates save/delete + Pro gate, schedule send Pro gate), routes/calendar.ts (thread note 20,000 limit), assign (E85: ek function, null = hatao). draft autosave (galat column naam), follow-up date guard. SQL E85 + E86 PEHLE.
# Safety: live files par anchor-based hunks (kuch na mile => kuch nahi badla), backup, `bun build` pre-flight, health, restore-on-fail.
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"; SRC="${BRAIN_SRC:-/opt/anexomail/src}"; R="$SRC/routes"
BUN="$(command -v bun || echo /root/.bun/bin/bun)"; STAMP="$(date +%Y%m%d-%H%M%S)"; B="/root/anexomail-backups/brain-pro-$STAMP"
for f in mail.ts mail-compose.ts calendar.ts; do [ -f "$R/$f" ] || { echo "FAIL: $R/$f nahi mili"; exit 2; }; done
[ -f "$SRC/lib/plan.ts" ] || { echo "FAIL: $SRC/lib/plan.ts nahi mili (resolvePlan chahiye)"; exit 2; }
git -C "$REPO" fetch -q origin main 2>/dev/null
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT; mkdir -p "$T/out"
git -C "$REPO" show origin/main:docs/cursor-work/server/brain_pro_patch.py > "$T/patch.py"; git -C "$REPO" show origin/main:docs/cursor-work/server/brain_pro_hunks.json > "$T/hunks.json"; git -C "$REPO" show origin/main:docs/cursor-work/server/brain_pro2_hunks.json > "$T/hunks2.json"; git -C "$REPO" show origin/main:docs/cursor-work/server/brain_pro3_hunks.json > "$T/hunks3.json"; git -C "$REPO" show origin/main:docs/cursor-work/server/brain_pro4_hunks.json > "$T/hunks4.json"
[ -s "$T/patch.py" ] && [ -s "$T/hunks.json" ] && [ -s "$T/hunks2.json" ] && [ -s "$T/hunks3.json" ] && [ -s "$T/hunks4.json" ] || { echo "FAIL: repo se patch/hunks nahi mile — git fetch hua?"; exit 2; }
ST="$(python3 -I "$T/patch.py" "$R" "$T/out" "$T/hunks.json" "$T/hunks2.json" "$T/hunks3.json" "$T/hunks4.json")"; RC=$?
[ "$RC" = 0 ] || { echo "$ST"; echo "(live file ke markers alag hain — kuch nahi badla. Output Claude ko bhejein.)"; exit 3; }
echo "status: $ST"
[ "$ST" = same ] && { echo "Pehle se lagi hai."; exit 0; }
NM=""; d="$SRC"; for _ in 1 2 3; do [ -d "$d/node_modules" ] && { NM="$d/node_modules"; break; }; d="$(dirname "$d")"; done
[ -n "$NM" ] || { echo "FAIL: Brain ka node_modules nahi mila"; exit 2; }
mkdir -p "$T/pf/app/src"; (cd "$SRC" && tar cf - --exclude=node_modules .) | (cd "$T/pf/app/src" && tar xf -); ln -s "$NM" "$T/pf/app/node_modules"
for f in mail.ts mail-compose.ts calendar.ts; do cp "$T/out/$f" "$T/pf/app/src/routes/$f"; done
"$BUN" build "$T/pf/app/src/index.ts" --target=bun --outfile "$T/pf/out.js" >"$T/b.log" 2>&1 || { tail -20 "$T/b.log"; echo "!! nayi files ka build FAIL — kuch install nahi hua."; exit 1; }
mkdir -p "$B"; for f in mail.ts mail-compose.ts calendar.ts; do cp -p "$R/$f" "$B/$f"; cp "$T/out/$f" "$R/$f"; done
echo "lagaya. backup: $B"
restore() { for f in mail.ts mail-compose.ts calendar.ts; do cp -p "$B/$f" "$R/$f"; done; pm2 restart anexomail-leo --update-env >/dev/null 2>&1; }
pm2 restart anexomail-leo --update-env >/dev/null 2>&1 && pm2 save >/dev/null 2>&1; sleep 7
H="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/health)"
Z="00000000-0000-0000-0000-000000000000"
S="$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'authorization: Bearer not-a-real-token' -H 'content-type: application/json' -d '{"until":"garbage"}' "http://127.0.0.1:3100/api/mail/thread/$Z/snooze")"
echo "Brain health $H (200) · nakli token + galat date par snooze $S (401, process zinda)"
H2="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/health)"
if [ "$H" != "200" ] || [ "$S" != "401" ] || [ "$H2" != "200" ]; then restore; echo "!! check FAIL — purani files wapas, health $(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/health)"; exit 1; fi
pm2 status anexomail-leo | head -6
echo "DONE: Brain Pro fallback fixes."
