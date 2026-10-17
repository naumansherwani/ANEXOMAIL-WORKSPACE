#!/usr/bin/env bash
# ANEXOMAIL — Rust engine SAFE deploy (restore-on-fail). Founder ek command chalata hai:
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-safe-deploy.sh)
#
# Kya karta hai (sirf anexomail-rust; polar-rust-payment :3400, Brain, web ko haath nahi lagata):
#   1. repo (origin/main) ki server/rust/main.rs ko server ki src/main.rs se milata hai (farq dikhata hai); same ho to kuch nahi karta.
#   2. src/main.rs aur chalti binary ka backup (.bak.<ts>), phir naya main.rs, phir `cargo build --release`.
#   3. Build FAIL -> src wapas, binary ko haath nahi laga (purani chalti rehti hai), error ke line dikhata hai.
#   4. Build OK -> `pm2 restart anexomail-rust --update-env && pm2 save`, /rpc/health 200 na aaye to purani binary + src wapas.
#   5. Naya proc route hua ya nahi (nakli token se 401 = Rust ne pakda; 404 = purani binary).
# Cargo.toml / .env ko haath nahi lagata.
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"
TARGET="${TARGET:-/opt/anexomail-rust}"
RPC="${RPC:-http://127.0.0.1:3200}"
STAMP="$(date +%s)"
BIN="$TARGET/target/release/anexomail-rust"
NEW="$(mktemp /tmp/.rust-main.XXXXXX)"
LOG="/tmp/anexomail-rust-build-$STAMP.log"
trap 'rm -f "$NEW"' EXIT

git -C "$REPO" show origin/main:server/rust/main.rs >"$NEW" 2>/dev/null && [ -s "$NEW" ] || { echo "FAIL: repo se server/rust/main.rs nahi mili (git fetch hua?)"; exit 2; }
[ -f "$TARGET/src/main.rs" ] || { echo "FAIL: $TARGET/src/main.rs nahi mili — Rust engine yahan install nahi hai"; exit 2; }

echo "== 1) repo vs server main.rs"
if cmp -s "$NEW" "$TARGET/src/main.rs"; then
  echo "   bilkul same — build ki zaroorat nahi"
else
  add="$(diff "$TARGET/src/main.rs" "$NEW" | grep -c '^>')"
  del="$(diff "$TARGET/src/main.rs" "$NEW" | grep -c '^<')"
  echo "   farq: +$add lines (repo mein naye), -$del lines (server par jo repo mein nahi)"
  [ "$del" -gt "$add" ] && echo "   DHYAN: server par repo se zyada code tha — backup src/main.rs.bak.$STAMP mein rahega"
  cp -p "$TARGET/src/main.rs" "$TARGET/src/main.rs.bak.$STAMP"
  [ -f "$BIN" ] && cp -p "$BIN" "$BIN.bak.$STAMP"
  cp "$NEW" "$TARGET/src/main.rs"
  echo "== 2) cargo build --release (kuch minute lag sakte hain, log: $LOG)"
  ( cd "$TARGET" && cargo build --release >"$LOG" 2>&1 ); brc=$?
  if [ "$brc" -ne 0 ]; then
    cp -p "$TARGET/src/main.rs.bak.$STAMP" "$TARGET/src/main.rs"
    echo "!! BUILD FAIL — src wapas kar diya, purani binary chal rahi hai (kuch restart nahi hua). Pehle errors:"
    grep -E '^(error|warning: unused)' -A7 "$LOG" | head -60 | cut -c1-200
    echo "   (poora log: $LOG) — upar wale lines chat mein Claude ko paste karein."
    exit 1
  fi
  echo "   build OK ($(tail -1 "$LOG" | cut -c1-100))"
  echo "== 3) pm2 restart + health"
  pm2 restart anexomail-rust --update-env >/dev/null 2>&1 || { echo "!! pm2 restart fail"; }
  pm2 save >/dev/null 2>&1
  sleep 3
  code="$(curl -s -m 8 -o /dev/null -w '%{http_code}' "$RPC/rpc/health" 2>/dev/null)"
  if [ "$code" != "200" ]; then
    echo "!! naye build par /rpc/health = $code — PURANI binary + src wapas laga raha hoon"
    [ -f "$BIN.bak.$STAMP" ] && cp -p "$BIN.bak.$STAMP" "$BIN"
    cp -p "$TARGET/src/main.rs.bak.$STAMP" "$TARGET/src/main.rs"
    pm2 restart anexomail-rust --update-env >/dev/null 2>&1; pm2 save >/dev/null 2>&1
    sleep 3
    echo "   ab health: $(curl -s -m 8 -o /dev/null -w '%{http_code}' "$RPC/rpc/health" 2>/dev/null)"
    exit 1
  fi
fi

echo "== 4) live"
echo "   /rpc/health: $(curl -s -m 8 -o /dev/null -w '%{http_code}' "$RPC/rpc/health" 2>/dev/null)"
r="$(curl -s -m 8 -w ' [HTTP %{http_code}]' -X POST -H 'authorization: Bearer not-a-real-token' -H 'content-type: application/json' -d '{}' "$RPC/rpc/founder.expiry.watch" 2>/dev/null)"
echo "   founder.expiry.watch (nakli token): $r"
case "$r" in
  *"HTTP 401"*) echo "   -> Rust ne proc pakda (nakli token par 401 = theek)";;
  *"HTTP 404"*) echo "   -> ABHI PURANI binary (404) — build/restart dobara dekhna padega";;
  *) echo "   -> aur jawab aaya — upar dekhein";;
esac
pm2 describe anexomail-rust 2>/dev/null | grep -E "status|restarts|uptime" | sed 's/^/   /' | head -4
echo "   (polar-rust-payment :3400 aur Brain ko haath nahi lagaya)"
