#!/usr/bin/env bash
# ANEXOMAIL — Rust :3200 B4: EVENT-DRIVEN LIVE PUSH (R5) poori website ke liye (har plan, har account: family bhi — hub org-membership se chalta hai, plan se nahi).
# Rule 35: surgical + restore-on-fail. Purana 700 ms poll EVENTS=off par fallback rehta hai.
#   bash <(git -C /opt/anexomail-web fetch -q origin main; git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-events-install.sh)
# Kya lagta hai: server/rust/events_core.rs (std-only, unit tests) + events_glue.rs, aur live main.rs mein 3 chhoti jagah (mod lines, WebTransport hello hook, /internal/event + publish layer) — events_patch.py.
#   Cargo.toml: koi naya crate nahi. EVENT_SECRET (48 hex) /opt/anexomail-rust/.env aur /etc/anexomail/mail.env mein SIRF agar maujood na ho (inbound mail pipe isi se push deta hai).
# Safety: src + Cargo + binary backup -> core unit tests -> build -> health -> ASLI SABOOT (events-proof.py) -> koi FAIL => purani binary + src wapas.
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"; TARGET="${TARGET:-/opt/anexomail-rust}"; RPC="${RPC:-http://127.0.0.1:3200}"
EMAIL="${EMAIL:-basic.test@anexomail.com}"; MAILENV="${MAILENV:-/etc/anexomail/mail.env}"
STAMP="$(date +%s)"; BIN="$TARGET/target/release/anexomail-rust"; LOG="/tmp/anexomail-rust-events-$STAMP.log"
S="$TARGET/src/main.rs"; C="$TARGET/Cargo.toml"; L="$TARGET/Cargo.lock"; ENVF="$TARGET/.env"
command -v cargo >/dev/null 2>&1 || export PATH="$HOME/.cargo/bin:$PATH"
command -v cargo >/dev/null 2>&1 || { echo "FAIL: cargo nahi mila"; exit 2; }
[ -f "$S" ] && [ -f "$C" ] || { echo "FAIL: $TARGET/src/main.rs ya Cargo.toml nahi mili"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
git -C "$REPO" fetch -q origin main 2>/dev/null
show() { git -C "$REPO" show "origin/main:$1" 2>/dev/null; }
for f in events_core.rs events_glue.rs; do show "server/rust/$f" > "$T/$f"; [ -s "$T/$f" ] || { echo "FAIL: repo (origin/main) se $f nahi mili — git fetch hua?"; exit 2; }; done
show docs/cursor-work/server/events_patch.py > "$T/events_patch.py"; show docs/cursor-work/server/events-proof.py > "$T/events-proof.py"
[ -s "$T/events_patch.py" ] && [ -s "$T/events-proof.py" ] || { echo "FAIL: repo se patch/proof script nahi mili"; exit 2; }
grep -q 'mod mail_glue;' "$S" || { echo "STOP: B3 (mail_glue) live main.rs mein nahi — pehle rust-mail-install.sh (events mail_inbox_stamp / mail hook ke saath chalta hai)."; exit 3; }
for h in 'fn mail_inbox_stamp(' 'fn mail_identity(' 'fn auth_user(' 'fn wt_send_final(' 'fn env_var(' 'async fn wt_session('; do
  grep -qF "$h" "$S" || { echo "STOP: live main.rs mein '$h' nahi mila — kuch nahi badla."; exit 3; }
done
envv(){ for f in "$ENVF" /opt/anexomail/.env /etc/anexomail/sync.env; do [ -r "$f" ] && grep -m1 -E "^$1=" "$f" | cut -d= -f2- | sed -e "s/^[\"']//" -e "s/[\"']$//"; done | head -1; }
SBU="$(envv SUPABASE4_URL)"; SBK="$(envv SUPABASE4_SERVICE_ROLE_KEY)"; SBU="${SBU%/}"
[ -n "$SBU" ] && [ -n "$SBK" ] || { echo "FAIL: SUPABASE4_URL / SERVICE_ROLE_KEY nahi mili"; exit 2; }
if grep -q 'mod events_glue;' "$S" && cmp -s "$T/events_glue.rs" "$TARGET/src/events_glue.rs" && cmp -s "$T/events_core.rs" "$TARGET/src/events_core.rs"; then
  echo "Pehle se lagi hai (same files). Sirf secret + saboot:"; SKIP_BUILD=1
fi

echo "== 0) EVENT_SECRET (sirf agar maujood na ho)"
SECRET="$(grep -m1 -E '^EVENT_SECRET=' "$ENVF" 2>/dev/null | cut -d= -f2-)"
if [ "${#SECRET}" -lt 24 ]; then
  SECRET="$(openssl rand -hex 24 2>/dev/null || head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n')"
  cp -p "$ENVF" "$ENVF.bak.$STAMP" 2>/dev/null; sed -i '/^EVENT_SECRET=/d' "$ENVF" 2>/dev/null; printf 'EVENT_SECRET=%s\n' "$SECRET" >> "$ENVF"; chmod 600 "$ENVF" 2>/dev/null
  NEWSECRET=1; echo "   naya EVENT_SECRET $ENVF mein likha (print nahi)"
else echo "   EVENT_SECRET pehle se hai"; fi
if [ -f "$MAILENV" ]; then
  if ! grep -qE '^EVENT_SECRET=.{24,}' "$MAILENV"; then
    sed -i '/^EVENT_SECRET=/d' "$MAILENV"; printf 'EVENT_SECRET=%s\n' "$SECRET" >> "$MAILENV"; echo "   $MAILENV mein bhi (inbound mail pipe ke liye)"
  else
    [ "$(grep -m1 -E '^EVENT_SECRET=' "$MAILENV" | cut -d= -f2-)" = "$SECRET" ] || { sed -i '/^EVENT_SECRET=/d' "$MAILENV"; printf 'EVENT_SECRET=%s\n' "$SECRET" >> "$MAILENV"; echo "   $MAILENV ka secret engine se mila diya"; }
  fi
fi

if [ -z "${SKIP_BUILD:-}" ]; then
  echo "== 1) events_core unit tests (server par, std-only rustc)"
  EDITION="$(grep -E '^edition[[:space:]]*=' "$C" | head -1 | tr -d ' "' | cut -d= -f2)"; EDITION="${EDITION:-2021}"
  ( R="$(rustup which rustc 2>/dev/null || command -v rustc)"; cd "$T" && "$R" --edition "$EDITION" --test events_core.rs -o evcore_test >"$T/rustc.log" 2>&1 && ./evcore_test >"$T/test.log" 2>&1 ) \
    || { echo "!! unit tests FAIL — kuch nahi badla:"; head -20 "$T/rustc.log" | cut -c1-180; tail -15 "$T/test.log" 2>/dev/null | cut -c1-180; exit 1; }
  grep -E '^test result' "$T/test.log" | head -1
  echo "== 2) main.rs patch (copy par try)"
  cp "$S" "$T/main.rs.try"; python3 -I "$T/events_patch.py" "$T/main.rs.try" || { echo "!! patch nahi lag sakta — kuch install nahi hua. Output Claude ko paste karein."; exit 4; }
  echo "== 3) backup + install"
  cp -p "$S" "$S.bak.$STAMP"; cp -p "$C" "$C.bak.$STAMP"; [ -f "$L" ] && cp -p "$L" "$L.bak.$STAMP"; [ -f "$BIN" ] && cp -p "$BIN" "$BIN.bak.$STAMP"
  for f in events_core.rs events_glue.rs; do [ -f "$TARGET/src/$f" ] && cp -p "$TARGET/src/$f" "$TARGET/src/$f.bak.$STAMP"; done
  restore_all() { cp -p "$S.bak.$STAMP" "$S"; cp -p "$C.bak.$STAMP" "$C"; [ -f "$L.bak.$STAMP" ] && cp -p "$L.bak.$STAMP" "$L"
    for f in events_core.rs events_glue.rs; do if [ -f "$TARGET/src/$f.bak.$STAMP" ]; then cp -p "$TARGET/src/$f.bak.$STAMP" "$TARGET/src/$f"; else rm -f "$TARGET/src/$f"; fi; done; }
  rollback() { echo "!! $1 — PURANI binary + src wapas"; [ -f "$BIN.bak.$STAMP" ] && cp -p "$BIN.bak.$STAMP" "$BIN.new.$STAMP" && mv -f "$BIN.new.$STAMP" "$BIN"; restore_all
    pm2 restart anexomail-rust --update-env >/dev/null 2>&1; pm2 save >/dev/null 2>&1; sleep 3; echo "   ab health: $(curl -s -m 8 -o /dev/null -w '%{http_code}' "$RPC/rpc/health" 2>/dev/null)"; exit 1; }
  cp "$T/events_core.rs" "$T/events_glue.rs" "$TARGET/src/"; cp "$T/main.rs.try" "$S"
  echo "== 4) cargo build --release (kuch minute; log: $LOG)"
  ( cd "$TARGET" && nice -n 10 cargo build --release >"$LOG" 2>&1 ); brc=$?
  if [ "$brc" -ne 0 ]; then restore_all; echo "!! BUILD FAIL — src wapas, purani binary chal rahi hai. Errors:"; grep -E '^error' -A9 "$LOG" | head -60 | cut -c1-200; exit 1; fi
  echo "   build OK"
  echo "== 5) pm2 restart + health"
  pm2 restart anexomail-rust --update-env >/dev/null 2>&1; pm2 save >/dev/null 2>&1; sleep 5
  H="$(curl -s -m 8 -o /dev/null -w '%{http_code}' "$RPC/rpc/health" 2>/dev/null)"
  echo "   /rpc/health $H"
  [ "$H" = "200" ] || rollback "health $H"
else
  rollback() { echo "!! $1"; exit 1; }
  if [ -n "${NEWSECRET:-}" ]; then pm2 restart anexomail-rust --update-env >/dev/null 2>&1; pm2 save >/dev/null 2>&1; sleep 5; fi
fi

echo "== 6) ASLI SABOOT: /internal/event + publish layer + FAMILY accounts"
RPC="$RPC" SBU="$SBU" SBK="$SBK" EMAIL="$EMAIL" EVENT_SECRET="$SECRET" python3 -I "$T/events-proof.py"; prc=$?
unset SBK SECRET
[ "$prc" -eq 0 ] || rollback "saboot FAIL (upar FAIL lines dekhein) — events Rust par galat thi, isliye wapas"
pm2 status anexomail-rust | head -6
echo "DONE: event-driven live push (mail/calendar/crm/work/people/org) Rust par, har plan + family. backup: $S.bak.$STAMP"
echo "AGLA: inbound mail ko foran push dene ke liye rust-deliver-install.sh dobara chalayein (deliver binary ab hub ko batati hai)."
