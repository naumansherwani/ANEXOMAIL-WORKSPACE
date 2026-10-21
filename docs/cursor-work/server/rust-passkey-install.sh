#!/usr/bin/env bash
# ANEXOMAIL — Rust :3200 B2: PASSKEY + RECOVERY-CODE LOGIN (G42). Rule 35: surgical + restore-on-fail. Bun /api/auth/passkey/* fallback rehta hai.
#   bash <(git -C /opt/anexomail-web fetch -q origin main; git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-passkey-install.sh)
# Pehle: B1 (rust-jwt-install) lagi ho (ring dependency). Naya SQL nahi (E43 pehle se live). Baad mein Web pull (client Rust-pehle calls).
# Kya lagta hai: naya server/rust/passkey_core.rs (std-only, unit tests) + passkey_glue.rs, aur live main.rs mein 3 chhoti jagah
#   (`mod passkey_core; mod passkey_glue;`, public hook bearer se pehle, authenticated hook whoami se pehle) — docs/cursor-work/server/passkey_patch.py.
#   Cargo.toml: sirf ring (pehle se) — naya crate nahi.
# Safety: src + Cargo + binary backup -> core unit tests (rustc --test) -> build -> health -> ASLI SABOOT (passkey-proof.py: software authenticator,
#   tamper/replay/clone/ghalat origin/recovery) -> koi bhi FAIL => purani binary + src wapas. Proof ke baad test credential/challenge/session saaf.
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"; TARGET="${TARGET:-/opt/anexomail-rust}"; RPC="${RPC:-http://127.0.0.1:3200}"; BRAIN="${BRAIN:-http://127.0.0.1:3100}"
EMAIL="${EMAIL:-basic.test@anexomail.com}"
STAMP="$(date +%s)"; BIN="$TARGET/target/release/anexomail-rust"; LOG="/tmp/anexomail-rust-passkey-$STAMP.log"
S="$TARGET/src/main.rs"; C="$TARGET/Cargo.toml"; L="$TARGET/Cargo.lock"
command -v cargo >/dev/null 2>&1 || export PATH="$HOME/.cargo/bin:$PATH"
command -v cargo >/dev/null 2>&1 || { echo "FAIL: cargo nahi mila"; exit 2; }
command -v openssl >/dev/null 2>&1 || { echo "FAIL: openssl nahi mila (saboot ke liye)"; exit 2; }
[ -f "$S" ] && [ -f "$C" ] || { echo "FAIL: $TARGET/src/main.rs ya Cargo.toml nahi mili"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
git -C "$REPO" fetch -q origin main 2>/dev/null
show() { git -C "$REPO" show "origin/main:$1" 2>/dev/null; }
for f in passkey_core.rs passkey_glue.rs; do show "server/rust/$f" > "$T/$f"; [ -s "$T/$f" ] || { echo "FAIL: repo (origin/main) se $f nahi mili — git fetch hua?"; exit 2; }; done
show docs/cursor-work/server/passkey_patch.py > "$T/passkey_patch.py"; show docs/cursor-work/server/passkey-proof.py > "$T/passkey-proof.py"
[ -s "$T/passkey_patch.py" ] && [ -s "$T/passkey-proof.py" ] || { echo "FAIL: repo se patch/proof script nahi mili"; exit 2; }
grep -qE '^ring *=' "$C" || { echo "STOP: Cargo.toml mein ring nahi — pehle B1 (rust-jwt-install.sh) chalayen."; exit 3; }
grep -q 'mod jwt_core;' "$S" || { echo "STOP: B1 (jwt) live main.rs mein nahi — pehle rust-jwt-install.sh."; exit 3; }
for h in 'fn sb()' 'fn sb_select(' 'fn sb_insert(' 'fn sb_patch(' 'fn sb_upsert(' 'fn sb_count(' 'fn sb_rpc(' 'fn auth_user(' 'fn http(' 'fn env_var(' 'fn ok(' 'fn err('; do
  grep -qF "$h" "$S" || { echo "STOP: live main.rs mein '$h' nahi mila — kuch nahi badla."; exit 3; }
done
if grep -q 'mod passkey_glue;' "$S" && cmp -s "$T/passkey_glue.rs" "$TARGET/src/passkey_glue.rs" && cmp -s "$T/passkey_core.rs" "$TARGET/src/passkey_core.rs"; then
  echo "Pehle se lagi hai (same files). Sirf saboot dobara:"; SKIP_BUILD=1
fi

envv(){ for f in /opt/anexomail-rust/.env /opt/anexomail/.env /etc/anexomail/sync.env; do [ -r "$f" ] && grep -m1 -E "^$1=" "$f" | cut -d= -f2- | sed -e "s/^[\"']//" -e "s/[\"']$//"; done | head -1; }
SBU="$(envv SUPABASE4_URL)"; SBK="$(envv SUPABASE4_SERVICE_ROLE_KEY)"; SBU="${SBU%/}"
[ -n "$SBU" ] && [ -n "$SBK" ] || { echo "FAIL: SUPABASE4_URL / SERVICE_ROLE_KEY nahi mili"; exit 2; }

if [ -z "${SKIP_BUILD:-}" ]; then
  echo "== 1) passkey_core unit tests (server par, std-only rustc)"
  EDITION="$(grep -E '^edition[[:space:]]*=' "$C" | head -1 | tr -d ' "' | cut -d= -f2)"; EDITION="${EDITION:-2021}"
  ( cd "$TARGET" && R="$(rustup which rustc 2>/dev/null || command -v rustc)"; cd "$T" && "$R" --edition "$EDITION" --test passkey_core.rs -o pkcore_test >"$T/rustc.log" 2>&1 && ./pkcore_test >"$T/test.log" 2>&1 ) \
    || { echo "!! unit tests FAIL — kuch nahi badla:"; head -20 "$T/rustc.log" | cut -c1-180; tail -15 "$T/test.log" 2>/dev/null | cut -c1-180; exit 1; }
  grep -E '^test result' "$T/test.log" | head -1
  echo "== 2) main.rs patch (copy par try)"
  cp "$S" "$T/main.rs.try"; python3 -I "$T/passkey_patch.py" "$T/main.rs.try" || { echo "!! patch nahi lag sakta — kuch install nahi hua. Output Claude ko paste karein."; exit 4; }
  echo "== 3) backup + install"
  cp -p "$S" "$S.bak.$STAMP"; cp -p "$C" "$C.bak.$STAMP"; [ -f "$L" ] && cp -p "$L" "$L.bak.$STAMP"; [ -f "$BIN" ] && cp -p "$BIN" "$BIN.bak.$STAMP"
  for f in passkey_core.rs passkey_glue.rs; do [ -f "$TARGET/src/$f" ] && cp -p "$TARGET/src/$f" "$TARGET/src/$f.bak.$STAMP"; done
  restore_all() { cp -p "$S.bak.$STAMP" "$S"; cp -p "$C.bak.$STAMP" "$C"; [ -f "$L.bak.$STAMP" ] && cp -p "$L.bak.$STAMP" "$L"
    for f in passkey_core.rs passkey_glue.rs; do if [ -f "$TARGET/src/$f.bak.$STAMP" ]; then cp -p "$TARGET/src/$f.bak.$STAMP" "$TARGET/src/$f"; else rm -f "$TARGET/src/$f"; fi; done; }
  rollback() { echo "!! $1 — PURANI binary + src wapas"; [ -f "$BIN.bak.$STAMP" ] && cp -p "$BIN.bak.$STAMP" "$BIN.new.$STAMP" && mv -f "$BIN.new.$STAMP" "$BIN"; restore_all
    pm2 restart anexomail-rust --update-env >/dev/null 2>&1; pm2 save >/dev/null 2>&1; sleep 3; echo "   ab health: $(curl -s -m 8 -o /dev/null -w '%{http_code}' "$RPC/rpc/health" 2>/dev/null)"; exit 1; }
  cp "$T/passkey_core.rs" "$T/passkey_glue.rs" "$TARGET/src/"; cp "$T/main.rs.try" "$S"
  echo "== 4) cargo build --release (kuch minute; log: $LOG)"
  ( cd "$TARGET" && nice -n 10 cargo build --release >"$LOG" 2>&1 ); brc=$?
  if [ "$brc" -ne 0 ]; then restore_all; echo "!! BUILD FAIL — src wapas, purani binary chal rahi hai. Errors:"; grep -E '^error' -A9 "$LOG" | head -60 | cut -c1-200; exit 1; fi
  echo "   build OK"
  echo "== 5) pm2 restart + health"
  pm2 restart anexomail-rust --update-env >/dev/null 2>&1; pm2 save >/dev/null 2>&1; sleep 4
  H="$(curl -s -m 8 -o /dev/null -w '%{http_code}' "$RPC/rpc/health" 2>/dev/null)"
  P="$(curl -s -m 8 -o /dev/null -w '%{http_code}' -X POST -H 'authorization: Bearer not-a-real-token' -H 'content-type: application/json' -d '{"input":{}}' "$RPC/rpc/auth.passkey.status" 2>/dev/null)"
  echo "   /rpc/health $H · auth.passkey.status nakli token par $P (401 chahiye)"
  [ "$H" = "200" ] || rollback "health $H"
  [ "$P" = "401" ] || rollback "nakli token par $P (Rust ne naya proc pakda nahi)"
else
  rollback() { echo "!! $1"; exit 1; }
fi

echo "== 6) ASLI SABOOT: software authenticator ($EMAIL) — poora passkey login Rust par"
RPC="$RPC" BRAIN="$BRAIN" SBU="$SBU" SBK="$SBK" EMAIL="$EMAIL" python3 -I "$T/passkey-proof.py"; prc=$?
unset SBK
[ "$prc" -eq 0 ] || rollback "saboot FAIL (upar FAIL lines dekhein) — Rust par passkey login galat tha, isliye wapas"
pm2 status anexomail-rust | head -6
echo "DONE: passkey + recovery login Rust par. backup: $S.bak.$STAMP — ab Web pull (client Rust-pehle)."
