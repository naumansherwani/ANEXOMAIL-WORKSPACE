#!/usr/bin/env bash
# ANEXOMAIL — Rust engine: wtransport 0.1.14 -> 0.7.2 (quinn 0.10 -> 0.11, rustls 0.21 -> 0.23 saath). TECH-MAP 0a, Rule 25. SAFE: backup, restore-on-fail.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/wtransport-upgrade.sh)
#
# Sandbox mein (repo ka poora Rust code, installer jaisa patch): wtransport 0.7.2 build OK (sirf 1 line badli), purane quinn 0.10 / rustls 0.21 /
# ring 0.16 ke duplicate khatam. Chromium 141 ka asli `new WebTransport()` dono par ~10 ms mein session tak; native client 3 round x 4 case: stages same;
# HTTP 26/26 same. Sirf anexomail-rust; polar :3400, Brain, web, Caddy, mail ko haath nahi.
#   0. wtcheck (chhota test client, repo: docs/cursor-work/server/wtcheck) /tmp mein build -> abhi ke UDP 3443 par asli WebTransport handshake (PEHLE) + 13 HTTP requests.
#      PEHLE hi WebTransport handshake fail => kuch nahi badalta (pehle woh theek ho).
#   1. patch COPY par try (wt7_patch.py). Anchor/istemal alag => kuch nahi badla.
#   2. backup -> patch -> `cargo update -p wtransport` -> `nice cargo build --release`. Fail => sab wapas; purani binary chalti rehti hai.
#   3. pm2 restart -> health 200, UDP 3443, wohi WebTransport stages + 13 HTTP (BAAD). Ek bhi farq => purani binary + src wapas, restart.
set -uo pipefail
TARGET="${TARGET:-/opt/anexomail-rust}"; RPC="${RPC:-http://127.0.0.1:3200}"; REPO="${REPO:-/opt/anexomail-web}"
STAMP="$(date +%s)"; BIN="$TARGET/target/release/anexomail-rust"; LOG="/tmp/anexomail-wt7-$STAMP.log"; WTC="/tmp/wtcheck-$STAMP"
T="$(mktemp -d)"; trap 'rm -rf "$T" "$WTC"' EXIT
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

wtstages() { "$WTC/target/release/wtcheck" "https://127.0.0.1:3443/" >"$1.raw" 2>&1; local rc=$?; cut -d'|' -f1-2 "$1.raw" >"$1"; sed 's/^/      /' "$1.raw"; return $rc; }

echo "== 0) abhi"
OLD="$(lockver wtransport)"
echo "   wtransport (Cargo.lock): ${OLD:-?}   quinn: $(lockver quinn)  rustls: $(lockver rustls)   /rpc/health: $(health)   UDP 3443: $(udp3443)"
case " $OLD " in *" 0.7."*) echo "OK — wtransport pehle se 0.7 hai ($OLD), kuch nahi badla"; exit 0;; esac
[ "$(health)" = "200" ] || { echo "FAIL: abhi hi /rpc/health 200 nahi — pehle yeh theek ho, upgrade nahi kiya"; exit 2; }
[ "$(udp3443)" = "yes" ] || { echo "FAIL: abhi hi UDP 3443 nahi sun raha — pehle yeh theek ho, upgrade nahi kiya"; exit 2; }
echo "   wtcheck build (test client, /tmp; ~1-2 min)"
mkdir -p "$WTC/src" && git -C "$REPO" show origin/main:docs/cursor-work/server/wtcheck/Cargo.toml >"$WTC/Cargo.toml" && git -C "$REPO" show origin/main:docs/cursor-work/server/wtcheck/src/main.rs >"$WTC/src/main.rs" \
  || { echo "FAIL: repo mein wtcheck nahi — git fetch hua?"; exit 2; }
( cd "$WTC" && nice -n 10 cargo build --release >"$WTC/build.log" 2>&1 ) || { echo "FAIL: wtcheck build nahi hua (live ko kuch nahi hua):"; grep -E '^error' -A5 "$WTC/build.log" | head -20; exit 2; }
echo "   PEHLE WebTransport:"; wtstages "$T/wt_before.txt" || { echo "FAIL: abhi hi WebTransport handshake poora nahi — upgrade nahi kiya. Upar wali lines Claude ko paste karein."; exit 2; }
battery >"$T/before.txt"; echo "   PEHLE HTTP: $(tr '\n' ' ' <"$T/before.txt")"

echo "== 1) patch copy par try"
git -C "$REPO" show origin/main:docs/cursor-work/server/wt7_patch.py >"$T/wt7_patch.py" 2>/dev/null
[ -s "$T/wt7_patch.py" ] || { echo "FAIL: repo mein wt7_patch.py nahi — git fetch hua?"; exit 2; }
cp Cargo.toml "$T/Cargo.toml.try"; cp src/main.rs "$T/main.rs.try"
python3 -I "$T/wt7_patch.py" "$T/Cargo.toml.try" "$T/main.rs.try" || { echo "!! patch nahi lag sakta — KUCH NAHI BADLA. Upar wali lines Claude ko paste karein."; exit 4; }

echo "== 2) backup + patch + cargo update -p wtransport + build (log: $LOG)"
for f in Cargo.toml Cargo.lock src/main.rs; do cp -p "$f" "$f.bak.$STAMP" || { echo "FAIL: backup $f"; exit 2; }; done
cp -p "$BIN" "$BIN.bak.$STAMP" || { echo "FAIL: binary backup"; exit 2; }
restore_src() { for f in Cargo.toml Cargo.lock src/main.rs; do cp -p "$f.bak.$STAMP" "$f"; done; }
cp "$T/Cargo.toml.try" Cargo.toml; cp "$T/main.rs.try" src/main.rs
if ! cargo update -p wtransport >"$LOG" 2>&1; then echo "!! cargo update fail — sab wapas:"; tail -10 "$LOG" | sed 's/^/   /'; restore_src; exit 1; fi
grep -E "Updating (wtransport|quinn|rustls|ring) |Removing (quinn|rustls|ring) " "$LOG" | sed 's/^/   /' | head -12
if ! nice -n 10 cargo build --release >>"$LOG" 2>&1; then
  echo "!! build FAIL — src + lock wapas; purani binary chalti rehti hai (restart nahi hua). Errors:"; grep -E "^error" -A7 "$LOG" | head -40 | sed 's/^/   /'
  restore_src; exit 1
fi
echo "   build OK ($(grep -E 'Finished' "$LOG" | tail -1 | sed 's/^ *//'))"

echo "== 3) pm2 restart + health + WebTransport handshake + wohi requests"
pm2 restart anexomail-rust --update-env >/dev/null 2>&1
for i in $(seq 1 15); do sleep 2; [ "$(health)" = "200" ] && break; done
for i in $(seq 1 10); do [ "$(udp3443)" = "yes" ] && break; sleep 1; done
echo "   BAAD WebTransport:"; wtstages "$T/wt_after.txt"; WRC=$?
battery >"$T/after.txt"; H="$(health)"; U="$(udp3443)"
echo "   BAAD HTTP:  $(tr '\n' ' ' <"$T/after.txt")"
echo "   /rpc/health: $H   UDP 3443: $U"
if [ "$H" != "200" ] || [ "$U" != "yes" ] || ! diff -q "$T/before.txt" "$T/after.txt" >/dev/null || [ "$WRC" -ne 0 ] || ! diff -q "$T/wt_before.txt" "$T/wt_after.txt" >/dev/null; then
  echo "!! farq mila — PURANI binary + src wapas:"; diff "$T/before.txt" "$T/after.txt" | sed 's/^/   /'; diff "$T/wt_before.txt" "$T/wt_after.txt" | sed 's/^/   WT /'
  cp -p "$BIN.bak.$STAMP" "$BIN.new.$STAMP" && mv -f "$BIN.new.$STAMP" "$BIN"; restore_src
  pm2 restart anexomail-rust --update-env >/dev/null 2>&1; sleep 4
  echo "   ab: /rpc/health $(health)   UDP 3443 $(udp3443)"; pm2 save >/dev/null 2>&1; exit 1
fi
pm2 save >/dev/null 2>&1
echo "OK — wtransport: $OLD -> $(lockver wtransport)  quinn: $(lockver quinn)  rustls: $(lockver rustls)  (WebTransport handshake 4/4 pehle jaisa, HTTP 13/13 same, health 200)"
echo "   wapas lene ke liye: cd $TARGET && for f in Cargo.toml Cargo.lock src/main.rs; do cp \$f.bak.$STAMP \$f; done && cp $BIN.bak.$STAMP $BIN.new && mv -f $BIN.new $BIN && pm2 restart anexomail-rust --update-env"
