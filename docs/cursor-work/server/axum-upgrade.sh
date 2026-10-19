#!/usr/bin/env bash
# ANEXOMAIL — Rust engine: axum 0.7.x -> 0.8.x (TECH-MAP 0a, Rule 25). SAFE: backup, restore-on-fail, pehle/baad same jawab ka saboot.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/axum-upgrade.sh)
#
# Sandbox mein yehi patch repo ke poore Rust code (cal+people+team+mig, installer jaisa) par: axum 0.8.9 build OK, aur purani (0.7.9) vs nayi
# binary ko 26 ek jaisi requests => 26 ke 26 jawab same (status + body).  Sirf anexomail-rust; polar :3400, Brain, web, Caddy, mail ko haath nahi.
#   0. abhi ka haal + 13 requests ke jawab (PEHLE) note.
#   1. patch COPY par try (axum8_patch.py). Anchor na mile => kuch nahi badla, ruk jata hai.
#   2. backup (main.rs, Cargo.toml, Cargo.lock, binary) -> patch -> `cargo update -p axum` -> `nice cargo build --release`. Fail => sab wapas; purani binary chalti rehti hai.
#   3. pm2 restart -> health 200, UDP 3443, wohi 13 requests (BAAD). Ek bhi farq => purani binary + src wapas, restart.
set -uo pipefail
TARGET="${TARGET:-/opt/anexomail-rust}"; RPC="${RPC:-http://127.0.0.1:3200}"; REPO="${REPO:-/opt/anexomail-web}"
STAMP="$(date +%s)"; BIN="$TARGET/target/release/anexomail-rust"; LOG="/tmp/anexomail-axum8-$STAMP.log"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cd "$TARGET" || { echo "FAIL: $TARGET nahi"; exit 2; }
command -v cargo >/dev/null || { [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"; }
command -v cargo >/dev/null || { echo "FAIL: cargo nahi mila"; exit 2; }
lockver() { awk -v c="$1" '$0=="name = \""c"\""{getline; gsub(/version = |"/,""); print}' Cargo.lock | tr '\n' ' '; }
health() { curl -s -m 8 -o /dev/null -w '%{http_code}' "$RPC/rpc/health" 2>/dev/null; }
udp3443() { ss -ulnp 2>/dev/null | grep -q ':3443 ' && echo yes || echo NO; }
c() { curl -s -m 10 -o /dev/null -w '%{http_code}' "$@" 2>/dev/null; }
battery() {  # sirf status codes (body mein waqt/uptime badalta hai)
  echo "health_get $(c "$RPC/rpc/health")"
  echo "health_post $(c -X POST "$RPC/rpc/health")"
  echo "turn_health $(c -X POST "$RPC/rpc/chat.turn.health" -H 'content-type: application/json' -d '{}')"
  echo "no_bearer $(c -X POST "$RPC/rpc/dashboard.summary" -H 'content-type: application/json' -d '{}')"
  echo "fake_json $(c -X POST "$RPC/rpc/dashboard.summary" -H 'authorization: Bearer x' -H 'content-type: application/json' -d '{}')"
  echo "fake_textplain $(c -X POST "$RPC/rpc/dashboard.summary" -H 'authorization: Bearer x' -H 'content-type: text/plain' -d '{"input":{}}')"
  echo "fake_formurl $(c -X POST "$RPC/rpc/dashboard.summary" -H 'authorization: Bearer x' -d '{}')"
  echo "fake_badjson $(c -X POST "$RPC/rpc/dashboard.summary" -H 'authorization: Bearer x' -H 'content-type: application/json' -d '{bad')"
  echo "fake_emptyjson $(c -X POST "$RPC/rpc/dashboard.summary" -H 'authorization: Bearer x' -H 'content-type: application/json')"
  echo "migration $(c -X POST "$RPC/rpc/migration.providers" -H 'authorization: Bearer x' -H 'content-type: application/json' -d '{}')"
  echo "team $(c -X POST "$RPC/rpc/team.members.list" -H 'authorization: Bearer x' -H 'content-type: application/json' -d '{}')"
  echo "unknown_proc $(c -X POST "$RPC/rpc/no.such.proc" -H 'authorization: Bearer x' -H 'content-type: application/json' -d '{}')"
  echo "file_ping $(c "$RPC/file/ping")"
}

echo "== 0) abhi"
OLD="$(lockver axum)"
echo "   axum (Cargo.lock): ${OLD:-?}   Cargo.toml: $(grep -E '^axum[[:space:]]*=' Cargo.toml)   /rpc/health: $(health)   UDP 3443: $(udp3443)"
case " $OLD " in *" 0.8."*) echo "OK — axum pehle se 0.8 hai ($OLD), kuch nahi badla"; exit 0;; esac
[ "$(health)" = "200" ] || { echo "FAIL: abhi hi /rpc/health 200 nahi — pehle yeh theek ho, upgrade nahi kiya"; exit 2; }
battery >"$T/before.txt"; echo "   PEHLE: $(tr '\n' ' ' <"$T/before.txt")"

echo "== 1) patch copy par try"
git -C "$REPO" show origin/main:docs/cursor-work/server/axum8_patch.py >"$T/axum8_patch.py" 2>/dev/null
[ -s "$T/axum8_patch.py" ] || { echo "FAIL: repo mein axum8_patch.py nahi — git fetch hua?"; exit 2; }
cp Cargo.toml "$T/Cargo.toml.try"; cp src/main.rs "$T/main.rs.try"
python3 -I "$T/axum8_patch.py" "$T/Cargo.toml.try" "$T/main.rs.try" || { echo "!! patch nahi lag sakta — KUCH NAHI BADLA. Upar wali lines Claude ko paste karein."; exit 4; }

echo "== 2) backup + patch + cargo update -p axum + build (log: $LOG)"
for f in Cargo.toml Cargo.lock src/main.rs; do cp -p "$f" "$f.bak.$STAMP" || { echo "FAIL: backup $f"; exit 2; }; done
cp -p "$BIN" "$BIN.bak.$STAMP" || { echo "FAIL: binary backup"; exit 2; }
restore_src() { for f in Cargo.toml Cargo.lock src/main.rs; do cp -p "$f.bak.$STAMP" "$f"; done; }
cp "$T/Cargo.toml.try" Cargo.toml; cp "$T/main.rs.try" src/main.rs
if ! cargo update -p axum >"$LOG" 2>&1; then echo "!! cargo update fail — sab wapas:"; tail -10 "$LOG" | sed 's/^/   /'; restore_src; exit 1; fi
grep -E "Updating|Adding|Removing" "$LOG" | sed 's/^/   /' | head -12
if ! nice -n 10 cargo build --release >>"$LOG" 2>&1; then
  echo "!! build FAIL — src + lock wapas; purani binary chalti rehti hai (restart nahi hua). Errors:"; grep -E "^error" -A7 "$LOG" | head -40 | sed 's/^/   /'
  restore_src; exit 1
fi
echo "   build OK ($(grep -E 'Finished' "$LOG" | tail -1 | sed 's/^ *//'))"

echo "== 3) pm2 restart + health + WebTransport + wohi requests"
pm2 restart anexomail-rust --update-env >/dev/null 2>&1
for i in $(seq 1 15); do sleep 2; [ "$(health)" = "200" ] && break; done
battery >"$T/after.txt"; H="$(health)"; U="$(udp3443)"
echo "   BAAD:  $(tr '\n' ' ' <"$T/after.txt")"
echo "   /rpc/health: $H   UDP 3443: $U"
if [ "$H" != "200" ] || [ "$U" != "yes" ] || ! diff -q "$T/before.txt" "$T/after.txt" >/dev/null; then
  echo "!! farq mila — PURANI binary + src wapas:"; diff "$T/before.txt" "$T/after.txt" | sed 's/^/   /'
  cp -p "$BIN.bak.$STAMP" "$BIN.new.$STAMP" && mv -f "$BIN.new.$STAMP" "$BIN"; restore_src
  pm2 restart anexomail-rust --update-env >/dev/null 2>&1; sleep 4
  echo "   ab: /rpc/health $(health)   UDP 3443 $(udp3443)"; pm2 save >/dev/null 2>&1; exit 1
fi
pm2 save >/dev/null 2>&1
echo "OK — axum: $OLD -> $(lockver axum)  (13/13 jawab pehle jaise, health 200, WebTransport 3443 sun raha)"
echo "   wapas lene ke liye: cd $TARGET && for f in Cargo.toml Cargo.lock src/main.rs; do cp \$f.bak.$STAMP \$f; done && cp $BIN.bak.$STAMP $BIN.new && mv -f $BIN.new $BIN && pm2 restart anexomail-rust --update-env"
