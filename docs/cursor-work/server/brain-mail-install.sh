#!/usr/bin/env bash
# ANEXOMAIL — Brain (Bun :3100) B3: mail queue "claim" (ek mail ek hi worker se, Rust worker ke saath safe) + undo-send cancel jo uthayi hui row par nahi chalta.
#   bash <(git -C /opt/anexomail-web fetch -q origin main; git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/brain-mail-install.sh)
# PEHLE SQL E54 (sql-run.sh E54_mail_queue_claim CHECK_E54). Sirf 2 files, 2 surgical jagah: mail-worker.ts (select -> mail_queue_claim), routes/mail-compose.ts (cancel -> mail_queue_cancel).
# E54 na ho to bhi purana tareeqa chalta rehta hai (mail rukti nahi). Backup + bun build pre-flight + health + restore-on-fail. Rust, web, polar, .env ko haath nahi.
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"; SRC="${BRAIN_SRC:-/opt/anexomail/src}"
BUN="$(command -v bun || echo /root/.bun/bin/bun)"; STAMP="$(date +%Y%m%d-%H%M%S)"; B="/root/anexomail-backups/brain-mail-$STAMP"
WK="$SRC/mail-worker.ts"; CP="$SRC/routes/mail-compose.ts"
[ -f "$WK" ] && [ -f "$CP" ] && [ -f "$SRC/index.ts" ] || { echo "FAIL: Brain src nahi mili: $SRC"; exit 2; }
git -C "$REPO" fetch -q origin main 2>/dev/null
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
git -C "$REPO" show origin/main:docs/cursor-work/server/brain_mail_patch.py > "$T/patch.py"; [ -s "$T/patch.py" ] || { echo "FAIL: repo se brain_mail_patch.py nahi mila"; exit 2; }
envv(){ for f in /opt/anexomail/.env /opt/anexomail-rust/.env /etc/anexomail/sync.env; do [ -r "$f" ] && grep -m1 -E "^$1=" "$f" | cut -d= -f2- | sed -e "s/^[\"']//" -e "s/[\"']$//"; done | head -1; }
SBU="$(envv SUPABASE4_URL)"; SBK="$(envv SUPABASE4_SERVICE_ROLE_KEY)"; SBU="${SBU%/}"
[ -n "$SBU" ] && [ -n "$SBK" ] || { echo "FAIL: SUPABASE4_URL / SERVICE_ROLE_KEY nahi mili"; exit 2; }
Z="00000000-0000-0000-0000-000000000000"
E="$(curl -s -m 10 -X POST -H "apikey: $SBK" -H "authorization: Bearer $SBK" -H 'content-type: application/json' -d "{\"_id\":\"$Z\",\"_user\":\"$Z\",\"_org\":\"$Z\"}" "$SBU/rest/v1/rpc/mail_queue_cancel")"
[ "$E" = "false" ] || { echo "STOP: SQL E54 abhi nahi laga (jawab: ${E:0:100}). Pehle: sql-run.sh E54_mail_queue_claim CHECK_E54 — phir yeh script."; exit 4; }
echo "E54 theek."
ST="$(python3 -I "$T/patch.py" "$WK" "$CP" "$T/mail-worker.ts" "$T/mail-compose.ts")"; RC=$?
[ "$RC" = 0 ] || { echo "$ST"; echo "(live file ke markers alag hain — kuch nahi badla. Output Claude ko bhejein.)"; exit 3; }
echo "status: $ST"
[ "$ST" = same ] && { echo "Pehle se lagi hai."; exit 0; }
NM=""; d="$SRC"; for _ in 1 2 3; do [ -d "$d/node_modules" ] && { NM="$d/node_modules"; break; }; d="$(dirname "$d")"; done
[ -n "$NM" ] || { echo "FAIL: Brain ka node_modules nahi mila"; exit 2; }
mkdir -p "$T/pf/app/src"; (cd "$SRC" && tar cf - --exclude=node_modules .) | (cd "$T/pf/app/src" && tar xf -); ln -s "$NM" "$T/pf/app/node_modules"
cp "$T/mail-worker.ts" "$T/pf/app/src/mail-worker.ts"; cp "$T/mail-compose.ts" "$T/pf/app/src/routes/mail-compose.ts"
"$BUN" build "$T/pf/app/src/index.ts" --target=bun --outfile "$T/pf/out.js" >"$T/b.log" 2>&1 || { tail -20 "$T/b.log"; echo "!! nayi files ka build FAIL — kuch install nahi hua."; exit 1; }
W0="$(pm2 logs anexomail-leo --lines 200 --nostream 2>/dev/null | grep -c 'queue fetch failed')"
mkdir -p "$B"; cp -p "$WK" "$B/mail-worker.ts"; cp -p "$CP" "$B/mail-compose.ts"; cp "$T/mail-worker.ts" "$WK"; cp "$T/mail-compose.ts" "$CP"
echo "lagaya. backup: $B"
restore() { cp -p "$B/mail-worker.ts" "$WK"; cp -p "$B/mail-compose.ts" "$CP"; pm2 restart anexomail-leo --update-env >/dev/null 2>&1; }
pm2 restart anexomail-leo --update-env >/dev/null 2>&1 && pm2 save >/dev/null 2>&1; sleep 7
H="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/health)"
# nakli token par cancel: 401 (route zinda, patch ne kuch toda nahi)
C="$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'authorization: Bearer not-a-real-token' -H 'content-type: application/json' -d '{}' "http://127.0.0.1:3100/api/mail/schedule/$Z/cancel")"
# worker ne claim RPC se queue padhi? (log mein "queue fetch failed" na ho)
W1="$(pm2 logs anexomail-leo --lines 200 --nostream 2>/dev/null | grep -c 'queue fetch failed')"; W=$((W1-W0))
echo "Brain health $H (200) · nakli token par undo-cancel $C (401) · naye 'queue fetch failed' log lines: $W (0 chahiye)"
if [ "$H" != "200" ] || [ "$C" != "401" ] || [ "$W" != "0" ]; then restore; echo "!! check FAIL — purani files wapas, health $(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/health)"; exit 1; fi
pm2 status anexomail-leo | head -6
echo "DONE: Brain mail queue claim + cancel guard. Ab Rust: rust-mail-install.sh."
