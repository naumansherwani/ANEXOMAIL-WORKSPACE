#!/usr/bin/env bash
# ANEXOMAIL — Brain (anexomail-leo) SAFE install: G38 bheji jane wali mail mein attachments (restore-on-fail).
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/brain-attach-install.sh)
#
# PEHLE: SQL E48 (docs/cursor-work/sql/E48_outgoing_attachments.sql) Supabase SQL editor mein.  PHIR Rust (`MODULES="attach"`).  PHIR yeh.
#
# Kya hota hai (sirf Brain):
#   - naya file mail/attachments.ts (parakhna + multipart/mixed lapetna + commit)
#   - live sendmail.ts / routes/mail.ts / routes/mail-compose.ts / mail-worker.ts mein chhote anchor-based tukde (brain-attach-patch.py)
#   - pehle SAME live files ki copy par patch + syntax + tests (asli SMTP baat-cheet par). Kuch bhi fail => kuch install nahi hota.
#   - restart ke baad health + mail-worker ka queue padhna dekhta hai; fail => purani files wapas (restore-on-fail).
# Rust, web, polar-rust-payment :3400, Postfix ko haath nahi lagata. Dobara chalana safe.
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="/root/anexomail-backups/brain-attach-$STAMP"
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
for f in mail/sendmail.ts routes/mail.ts routes/mail-compose.ts mail-worker.ts; do
  [ -f "$SRC/$f" ] || { echo "STOP: $SRC/$f nahi mila — kuch nahi badla. (live Brain ka naqsha repo se alag hai; Claude ko batayen)"; exit 3; }
done
echo "Brain src: $SRC   bun: $($BUN --version)"

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
for f in server/mail/attachments.ts server/mail/attachments.test.ts server/mail/sendmail.attach.test.ts docs/cursor-work/server/brain-attach-patch.py; do
  show "$f" >"$T/$(basename "$f")"; [ -s "$T/$(basename "$f")" ] || { echo "FAIL: repo (origin/main) se $f nahi mila — git fetch hua?"; exit 2; }
done

# 1) live files ki copy par patch
mkdir -p "$T/try/mail" "$T/try/routes"
cp "$SRC/mail/sendmail.ts" "$T/try/mail/sendmail.ts"
cp "$SRC/routes/mail.ts" "$T/try/routes/mail.ts"
cp "$SRC/routes/mail-compose.ts" "$T/try/routes/mail-compose.ts"
cp "$SRC/mail-worker.ts" "$T/try/mail-worker.ts"
echo "== 1) live files ki copy par patch"
python3 -I "$T/brain-attach-patch.py" "$T/try"; prc=$?
[ $prc -eq 0 ] || { echo "!! patch nahi lag sakta — kuch install nahi hua. Upar wali lines Claude ko bhejein."; exit 4; }

# 2) syntax + tests (patched LIVE sendmail.ts ke saath asli SMTP baat-cheet)
echo "== 2) pre-flight: syntax + tests"
for f in mail/sendmail.ts routes/mail.ts routes/mail-compose.ts mail-worker.ts; do
  "$BUN" build "$T/try/$f" --no-bundle --outfile "$T/x.js" >"$T/build.log" 2>&1 || { cat "$T/build.log"; echo "!! $f ka syntax FAIL — kuch install nahi hua."; exit 1; }
done
cp "$T/attachments.ts" "$T/try/mail/attachments.ts"
cp "$T/attachments.test.ts" "$T/sendmail.attach.test.ts" "$T/try/mail/"
( cd "$T/try" && "$BUN" test mail >"$T/test.log" 2>&1 ); trc=$?
grep -E "^ *[0-9]+ (pass|fail)" "$T/test.log" | tr '\n' ' '; echo
[ "$trc" -eq 0 ] || { tail -25 "$T/test.log"; echo "!! tests FAIL — kuch install nahi hua. Upar ka output Claude ko bhejein."; exit 1; }

# 3) pehle se lagi hui?
same=1
for f in mail/sendmail.ts routes/mail.ts routes/mail-compose.ts mail-worker.ts; do cmp -s "$T/try/$f" "$SRC/$f" || same=0; done
cmp -s "$T/attachments.ts" "$SRC/mail/attachments.ts" 2>/dev/null || same=0
if [ "$same" = 1 ]; then echo "Pehle se lagi hui hai — sirf restart check."; SKIP=1; else SKIP=0; fi

if [ "$SKIP" = 0 ]; then
  echo "== 3) backup + install"
  mkdir -p "$BACKUP/mail" "$BACKUP/routes"
  for f in mail/sendmail.ts routes/mail.ts routes/mail-compose.ts mail-worker.ts; do cp -p "$SRC/$f" "$BACKUP/$f"; done
  [ -f "$SRC/mail/attachments.ts" ] && cp -p "$SRC/mail/attachments.ts" "$BACKUP/mail/attachments.ts.prev"
  for f in mail/sendmail.ts routes/mail.ts routes/mail-compose.ts mail-worker.ts; do cp "$T/try/$f" "$SRC/$f"; done
  cp "$T/attachments.ts" "$SRC/mail/attachments.ts"
  echo "lagaya. backup: $BACKUP"
fi

restore() {
  [ "$SKIP" = 0 ] || return 0
  for f in mail/sendmail.ts routes/mail.ts routes/mail-compose.ts mail-worker.ts; do cp -p "$BACKUP/$f" "$SRC/$f"; done
  if [ -f "$BACKUP/mail/attachments.ts.prev" ]; then cp -p "$BACKUP/mail/attachments.ts.prev" "$SRC/mail/attachments.ts"; else rm -f "$SRC/mail/attachments.ts"; fi
  pm2 restart anexomail-leo --update-env >/dev/null 2>&1; sleep 4
  echo "!! check FAIL — purani files wapas, Brain dobara chala: health $(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/health)"
}

if command -v pm2 >/dev/null 2>&1 && [ -z "${NO_PM2:-}" ]; then
  echo "== 4) restart + saboot"
  pm2 restart anexomail-leo --update-env >/dev/null 2>&1 && pm2 save >/dev/null 2>&1
  sleep 8
  H="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/health)"
  S="$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'content-type: application/json' -d '{}' http://127.0.0.1:3100/api/mail/send)"
  C="$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'content-type: application/json' -d '{}' http://127.0.0.1:3100/api/mail/schedule)"
  echo "Brain health $H · bina login /api/mail/send $S · /api/mail/schedule $C (401 = routes zinda)"
  # sirf SCHEMA ki shikayat (attachment_ids column / 42703) E48 na chalne ka saboot hai. "Gateway Timeout" Supabase ka wakti masla hai — fail nahi.
  WLOG="$(pm2 logs anexomail-leo --nostream --lines 80 2>/dev/null | grep -E 'mail-worker\]' | grep -iE 'attachment_ids|42703|does not exist' | tail -1)"
  TLOG="$(pm2 logs anexomail-leo --nostream --lines 80 2>/dev/null | grep -E 'mail-worker\] queue fetch failed' | tail -1)"
  [ -n "$TLOG" ] && [ -z "$WLOG" ] && echo "(info: mail-worker ne Supabase ka wakti masla dekha — '$(echo "$TLOG" | cut -c1-90)' — E48 ka masla nahi, install ko nahi rokta)"
  if [ "$H" != "200" ] || [ "$S" != "401" ] || [ "$C" != "401" ] || [ -n "$WLOG" ]; then
    [ -n "$WLOG" ] && echo "mail-worker: $WLOG   -> SQL E48 (attachment_ids column) shayad abhi nahi chali: docs/cursor-work/sql/E48_outgoing_attachments.sql"
    restore; exit 1
  fi
  pm2 status anexomail-leo | head -8
else
  echo "(pm2 nahi mila / NO_PM2 — restart nahi kiya)"
fi
ROOT="${ATTACH_DIR:-/mnt/anexomail-box/attachments}"
if [ -d "$ROOT" ]; then echo "Storage: $ROOT maujood hai."; else echo "dhyan: $ROOT abhi nahi hai — Storage Box mount check: bash docs/cursor-work/server/attach-check.sh (upload tab tak 503 deta hai, kuch lagta nahi)"; fi
echo "DONE: Brain par G38 attachments (bhejna)."
