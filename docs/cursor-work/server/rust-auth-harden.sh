#!/usr/bin/env bash
# ANEXOMAIL — Rust :3200: LOGIN-LOOP FIX (founder "haan" 21 Oct 2026, Rule 35). SIRF `auth_user()` badalta hai — baqi live main.rs
# (mod lines, mig/attach patches, sab) jaisa hai waisa rahta hai. Koi naya crate nahi. Latest toolchain (rust-toolchain.toml) wahi.
#   bash <(git -C /opt/anexomail-web fetch -q origin main; git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-auth-harden.sh)
# Sabab: auth_user har request par Supabase /auth/v1/user poochta tha; temporary error/429/5xx => None => 401 => app sign-out.
# Ab: 20 s cache + sirf temporary masle par 3 retry; asli invalid token (400/401/403/422) foran 401.
# Safety: backup (src + binary) -> sirf us function ka hissa badalta hai -> cargo build --release (nice) -> FAIL => src wapas, purani binary chalti rehti hai
#         -> OK => pm2 restart + /rpc/health 200 + nakli token = 401; fail => binary + src wapas + restart. polar/Caddy/Bun ko haath nahi.
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"; TARGET="${TARGET:-/opt/anexomail-rust}"; RPC="${RPC:-http://127.0.0.1:3200}"
STAMP="$(date +%s)"; BIN="$TARGET/target/release/anexomail-rust"; LOG="/tmp/anexomail-rust-auth-harden-$STAMP.log"
S="$TARGET/src/main.rs"; A='/// Identity Supabase Auth se'; Z='/// Gate DB ka `chat_access()`'
command -v cargo >/dev/null 2>&1 || export PATH="$HOME/.cargo/bin:$PATH"
command -v cargo >/dev/null 2>&1 || { echo "FAIL: cargo nahi mila"; exit 2; }
[ -f "$S" ] || { echo "FAIL: $S nahi mili"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
git -C "$REPO" fetch -q origin main 2>/dev/null
git -C "$REPO" show origin/main:server/rust/main.rs > "$T/repo_main.rs" 2>/dev/null; [ -s "$T/repo_main.rs" ] || { echo "FAIL: repo se server/rust/main.rs nahi mili"; exit 2; }
grep -q 'static AUTH_CACHE' "$T/repo_main.rs" || { echo "FAIL: repo main.rs mein AUTH_CACHE patch nahi — git fetch hua?"; exit 2; }
if grep -q 'static AUTH_CACHE' "$S"; then echo "Pehle se lagi hai (AUTH_CACHE live main.rs mein maujood)."; exit 0; fi
grep -qF "$A" "$S" && grep -qF "$Z" "$S" || { echo "STOP: live main.rs mein auth_user ke markers nahi mile — kisi ne badla hai. Kuch nahi badla."; exit 3; }
python3 - "$S" "$T/repo_main.rs" "$T/new_main.rs" <<'PY' || { echo "FAIL: patch nahi ban saka"; exit 3; }
import sys
live,repo,out=sys.argv[1:4]
A='/// Identity Supabase Auth se'; Z='/// Gate DB ka `chat_access()`'
l=open(live).read(); r=open(repo).read()
blk=r[r.index(A):r.index(Z)]
la=l.index(A); lz=l.index(Z)
assert la<lz
open(out,'w').write(l[:la]+blk+l[lz:])
PY
echo "== 1) backup (src + binary)"
cp -p "$S" "$S.bak.$STAMP"; [ -f "$BIN" ] && cp -p "$BIN" "$BIN.bak.$STAMP"
restore_src() { cp -p "$S.bak.$STAMP" "$S"; }
cp "$T/new_main.rs" "$S"
echo "== 2) cargo build --release (kuch minute; log: $LOG)"
( cd "$TARGET" && nice -n 10 cargo build --release >"$LOG" 2>&1 ); brc=$?
if [ "$brc" -ne 0 ]; then
  restore_src; echo "!! BUILD FAIL — src wapas, purani binary chal rahi hai (restart nahi hua). Errors:"; grep -E '^error' -A9 "$LOG" | head -50 | cut -c1-200; exit 1
fi
echo "   build OK"
echo "== 3) pm2 restart + health"
pm2 restart anexomail-rust --update-env >/dev/null 2>&1; pm2 save >/dev/null 2>&1; sleep 4
H="$(curl -s -m 8 -o /dev/null -w '%{http_code}' "$RPC/rpc/health" 2>/dev/null)"
P="$(curl -s -m 8 -o /dev/null -w '%{http_code}' -X POST -H 'authorization: Bearer not-a-real-token' -H 'content-type: application/json' -d '{"input":{}}' "$RPC/rpc/chat.conversations.list" 2>/dev/null)"
echo "   /rpc/health $H · nakli token par rpc $P (401/403/404 = theek, 5xx = masla)"
case "$P" in 5*) BADP=1;; *) BADP=0;; esac
if [ "$H" != "200" ] || [ "$BADP" = 1 ]; then
  echo "!! check FAIL — PURANI binary + src wapas"
  [ -f "$BIN.bak.$STAMP" ] && cp -p "$BIN.bak.$STAMP" "$BIN.new.$STAMP" && mv -f "$BIN.new.$STAMP" "$BIN"
  restore_src; pm2 restart anexomail-rust --update-env >/dev/null 2>&1; pm2 save >/dev/null 2>&1; sleep 3
  echo "   ab health: $(curl -s -m 8 -o /dev/null -w '%{http_code}' "$RPC/rpc/health" 2>/dev/null)"; exit 1
fi
pm2 status anexomail-rust | head -6
echo "DONE: Rust auth_user login-loop fix. backup: $S.bak.$STAMP"
