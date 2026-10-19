#!/usr/bin/env bash
# ANEXOMAIL — NOTE N7 fix: WebTransport error frame ab browser tak pahunchta hai (pehle "Connection lost", koi wajah nahi). SAFE: backup, restore-on-fail.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/wt-n7-fix.sh)
#
# Sandbox: Chromium 141 — pehle 6 mein se 3 error frame pahunchte the, ab 6/6; native client 5 round: ab 20/20. HTTP 26/26 same, panic 0.
# Sirf anexomail-rust ka src/main.rs (wt_session ke 5 error raaste + 1 helper); Cargo.toml/lock nahi badalte. polar :3400, Brain, web, Caddy, mail ko haath nahi.
#   0. wtcheck build -> PEHLE handshake + 13 HTTP.  1. patch copy par try (wt_n7_patch.py).  2. backup -> patch -> build (fail => wapas).
#   3. restart -> BAAD: stages same, HTTP same, aur 3 round x 4 case = 12/12 frame pahunche. Warna purani binary + src wapas.
set -uo pipefail
TARGET="${TARGET:-/opt/anexomail-rust}"; RPC="${RPC:-http://127.0.0.1:3200}"; REPO="${REPO:-/opt/anexomail-web}"
STAMP="$(date +%s)"; BIN="$TARGET/target/release/anexomail-rust"; LOG="/tmp/anexomail-wtn7-$STAMP.log"; WTC="/tmp/wtcheck-$STAMP"
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
echo "   wtransport (Cargo.lock): ${OLD:-?}   /rpc/health: $(health)   UDP 3443: $(udp3443)"
case " $OLD " in *" 0.7."*) ;; *) echo "FAIL: wtransport 0.7 nahi ($OLD) — pehle wtransport-upgrade.sh"; exit 2;; esac
grep -q 'async fn wt_send_final(' src/main.rs && { echo "OK — N7 pehle se laga hua, kuch nahi badla"; exit 0; }
[ "$(health)" = "200" ] || { echo "FAIL: abhi hi /rpc/health 200 nahi — pehle yeh theek ho, upgrade nahi kiya"; exit 2; }
[ "$(udp3443)" = "yes" ] || { echo "FAIL: abhi hi UDP 3443 nahi sun raha — pehle yeh theek ho, upgrade nahi kiya"; exit 2; }
echo "   wtcheck build (test client, /tmp; ~1-2 min)"
mkdir -p "$WTC/src" && git -C "$REPO" show origin/main:docs/cursor-work/server/wtcheck/Cargo.toml >"$WTC/Cargo.toml" && git -C "$REPO" show origin/main:docs/cursor-work/server/wtcheck/src/main.rs >"$WTC/src/main.rs" \
  || { echo "FAIL: repo mein wtcheck nahi — git fetch hua?"; exit 2; }
( cd "$WTC" && nice -n 10 cargo build --release >"$WTC/build.log" 2>&1 ) || { echo "FAIL: wtcheck build nahi hua (live ko kuch nahi hua):"; grep -E '^error' -A5 "$WTC/build.log" | head -20; exit 2; }
echo "   PEHLE WebTransport:"; wtstages "$T/wt_before.txt" || { echo "FAIL: abhi hi WebTransport handshake poora nahi — upgrade nahi kiya. Upar wali lines Claude ko paste karein."; exit 2; }
battery >"$T/before.txt"; echo "   PEHLE HTTP: $(tr '\n' ' ' <"$T/before.txt")"

echo "== 1) patch copy par try"
git -C "$REPO" show origin/main:docs/cursor-work/server/wt_n7_patch.py >"$T/wt_n7_patch.py" 2>/dev/null
[ -s "$T/wt_n7_patch.py" ] || { echo "FAIL: repo mein wt_n7_patch.py nahi — git fetch hua?"; exit 2; }
mkdir -p "$T/try/src"; cp Cargo.toml "$T/try/Cargo.toml"; cp src/main.rs "$T/try/src/main.rs"
python3 -I "$T/wt_n7_patch.py" "$T/try/src/main.rs" || { echo "!! patch nahi lag sakta — KUCH NAHI BADLA. Upar wali lines Claude ko paste karein."; exit 4; }

echo "== 2) backup + patch + build (log: $LOG)"
for f in Cargo.toml Cargo.lock src/main.rs; do cp -p "$f" "$f.bak.$STAMP" || { echo "FAIL: backup $f"; exit 2; }; done
cp -p "$BIN" "$BIN.bak.$STAMP" || { echo "FAIL: binary backup"; exit 2; }
restore_src() { for f in Cargo.toml Cargo.lock src/main.rs; do cp -p "$f.bak.$STAMP" "$f"; done; }
cp "$T/try/src/main.rs" src/main.rs
if ! nice -n 10 cargo build --release >"$LOG" 2>&1; then
  echo "!! build FAIL — src + lock wapas; purani binary chalti rehti hai (restart nahi hua). Errors:"; grep -E "^error" -A7 "$LOG" | head -40 | sed 's/^/   /'
  restore_src; exit 1
fi
echo "   build OK ($(grep -E 'Finished' "$LOG" | tail -1 | sed 's/^ *//'))"

echo "== 3) pm2 restart + health + WebTransport handshake + wohi requests"
pm2 restart anexomail-rust --update-env >/dev/null 2>&1
for i in $(seq 1 15); do sleep 2; [ "$(health)" = "200" ] && break; done
for i in $(seq 1 10); do [ "$(udp3443)" = "yes" ] && break; sleep 1; done
echo "   BAAD WebTransport:"; wtstages "$T/wt_after.txt"; WRC=$?
FR=0; for r in 1 2 3; do "$WTC/target/release/wtcheck" "https://127.0.0.1:3443/" >"$T/fr$r.txt" 2>&1 || WRC=1; FR=$((FR + $(awk -F'|' '$3!=""' "$T/fr$r.txt" | wc -l))); done
echo "   error frame pahunche: $FR/12 (3 round x 4 case)"; [ "$FR" -eq 12 ] || WRC=1
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
echo "OK — N7 theek: WebTransport error frame $FR/12 browser tak; handshake pehle jaisa, HTTP 13/13 same, health 200"
echo "   wapas lene ke liye: cd $TARGET && for f in Cargo.toml Cargo.lock src/main.rs; do cp \$f.bak.$STAMP \$f; done && cp $BIN.bak.$STAMP $BIN.new && mv -f $BIN.new $BIN && pm2 restart anexomail-rust --update-env"
