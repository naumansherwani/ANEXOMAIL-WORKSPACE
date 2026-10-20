#!/usr/bin/env bash
# ANEXOMAIL — Rust engine: rustc 1.97.x -> 1.99.1 (latest stable, blog.rust-lang.org 15 Oct 2026) + edition 2021 -> 2024. TECH-MAP 0a, Rule 25.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rustc-edition-upgrade.sh)
#
# Toolchain SIRF is project ke liye pin hota hai (`/opt/anexomail-rust/rust-toolchain.toml`) — server ka default rustc, polar :3400 aur baqi kuch nahi badalta.
# Sandbox (poora live-jaisa code): edition 2024 build OK (1 line: `err() -> impl IntoResponse + use<>`), core unit tests 2024 par 113 pass,
# WebTransport native 12 + Chromium 6 + HTTP 26: 2021 vs 2024 sab same, panic 0. (Sandbox se rustup ka server band tha — 1.99.1 ka build yahin server par hota hai.)
#   0. rustup se 1.99.1 install (default nahi badalta). wtcheck + PEHLE: WebTransport handshake/frames + 13 HTTP.
#   1. core unit tests 1.99.1 + edition 2024 par; patch copy par try (edition24_patch.py). Kuch fail => kuch nahi badla.
#   2. backup -> patch + rust-toolchain.toml -> `cargo build --release` (1.99.1). Fail => sab wapas; purani binary chalti rehti hai.
#   3. restart -> BAAD: stages same, frames 12/12, HTTP same. Warna purani binary + src + toolchain file wapas.
set -uo pipefail
TARGET="${TARGET:-/opt/anexomail-rust}"; RPC="${RPC:-http://127.0.0.1:3200}"; REPO="${REPO:-/opt/anexomail-web}"
STAMP="$(date +%s)"; BIN="$TARGET/target/release/anexomail-rust"; LOG="/tmp/anexomail-rustc-$STAMP.log"; TOOL="${TOOL:-1.99.1}"; WTC="/tmp/wtcheck-$STAMP"
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
command -v rustup >/dev/null || { echo "FAIL: rustup nahi mila — toolchain is tareeqe se nahi badal sakta (kuch nahi badla)"; exit 2; }
CUR="$(rustc --version 2>/dev/null | cut -d' ' -f2)"; ED="$(grep -E '^edition' Cargo.toml | head -1 | tr -d ' "' | cut -d= -f2)"
echo "   rustc (is folder mein): $CUR   edition: $ED   toolchain file: $([ -f rust-toolchain.toml ] && tr '\n' ' ' <rust-toolchain.toml || echo nahi)   /rpc/health: $(health)   UDP 3443: $(udp3443)"
if [ "$ED" = "2024" ] && grep -qx "channel = \"$TOOL\"" rust-toolchain.toml 2>/dev/null; then echo "OK — pehle se rustc $TOOL + edition 2024, kuch nahi badla"; exit 0; fi
[ "$(health)" = "200" ] || { echo "FAIL: abhi hi /rpc/health 200 nahi — upgrade nahi kiya"; exit 2; }
[ "$(udp3443)" = "yes" ] || { echo "FAIL: abhi hi UDP 3443 nahi sun raha — upgrade nahi kiya"; exit 2; }
echo "   rustup toolchain install $TOOL (minimal; default nahi badalta)"
rustup toolchain install "$TOOL" --profile minimal >"$LOG" 2>&1 || { echo "FAIL: $TOOL install nahi hua (kuch nahi badla):"; tail -6 "$LOG" | sed 's/^/   /'; exit 2; }
EXP="$(rustup run "$TOOL" rustc --version 2>/dev/null | cut -d' ' -f2)"; [ -n "$EXP" ] || { echo "FAIL: $TOOL chal nahi raha (kuch nahi badla)"; exit 2; }
echo "   naya compiler: rustc $EXP"
echo "   wtcheck build (test client, /tmp; ~1-2 min)"
mkdir -p "$WTC/src" && git -C "$REPO" show origin/main:docs/cursor-work/server/wtcheck/Cargo.toml >"$WTC/Cargo.toml" && git -C "$REPO" show origin/main:docs/cursor-work/server/wtcheck/src/main.rs >"$WTC/src/main.rs" \
  || { echo "FAIL: repo mein wtcheck nahi — git fetch hua?"; exit 2; }
( cd "$WTC" && nice -n 10 cargo build --release >"$WTC/build.log" 2>&1 ) || { echo "FAIL: wtcheck build nahi hua (live ko kuch nahi hua):"; grep -E '^error' -A5 "$WTC/build.log" | head -20; exit 2; }
echo "   PEHLE WebTransport:"; wtstages "$T/wt_before.txt" || { echo "FAIL: abhi hi WebTransport handshake poora nahi — upgrade nahi kiya."; exit 2; }
battery >"$T/before.txt"; echo "   PEHLE HTTP: $(tr '\n' ' ' <"$T/before.txt")"

echo "== 1) core unit tests ($TOOL, edition 2024) + patch copy par try"
for f in src/*_core.rs; do
  [ -f "$f" ] || continue; n="$(basename "$f" .rs)"
  ( cd src && rustup run "$TOOL" rustc --edition 2024 --test "$n.rs" -o "$T/$n.test" >"$T/$n.log" 2>&1 && "$T/$n.test" >"$T/$n.out" 2>&1 ) \
    || { echo "!! $n tests FAIL ($TOOL / 2024) — kuch nahi badla:"; head -15 "$T/$n.log" "$T/$n.out" 2>/dev/null | cut -c1-180; exit 1; }
  echo "   $n: $(grep -E '^test result' "$T/$n.out" | head -1)"
done
git -C "$REPO" show origin/main:docs/cursor-work/server/edition24_patch.py >"$T/edition24_patch.py" 2>/dev/null
[ -s "$T/edition24_patch.py" ] || { echo "FAIL: repo mein edition24_patch.py nahi — git fetch hua?"; exit 2; }
cp Cargo.toml "$T/Cargo.toml.try"; cp src/main.rs "$T/main.rs.try"
python3 -I "$T/edition24_patch.py" "$T/Cargo.toml.try" "$T/main.rs.try" || { echo "!! patch nahi lag sakta — KUCH NAHI BADLA. Upar wali lines Claude ko paste karein."; exit 4; }

echo "== 2) backup + patch + rust-toolchain.toml + build $TOOL (log: $LOG)"
for f in Cargo.toml Cargo.lock src/main.rs; do cp -p "$f" "$f.bak.$STAMP" || { echo "FAIL: backup $f"; exit 2; }; done
HAD_TC=0; [ -f rust-toolchain.toml ] && { HAD_TC=1; cp -p rust-toolchain.toml "rust-toolchain.toml.bak.$STAMP"; }
cp -p "$BIN" "$BIN.bak.$STAMP" || { echo "FAIL: binary backup"; exit 2; }
restore_src() { for f in Cargo.toml Cargo.lock src/main.rs; do cp -p "$f.bak.$STAMP" "$f"; done
  if [ "$HAD_TC" = 1 ]; then cp -p "rust-toolchain.toml.bak.$STAMP" rust-toolchain.toml; else rm -f rust-toolchain.toml; fi; }
cp "$T/Cargo.toml.try" Cargo.toml; cp "$T/main.rs.try" src/main.rs
printf '# ANEXOMAIL — sirf is Rust engine ka compiler (TECH-MAP 0a). Server ka default rustc aur polar :3400 is se nahi badalte.\n[toolchain]\nchannel = "%s"\nprofile = "minimal"\n' "$TOOL" > rust-toolchain.toml
NOW="$(rustc --version 2>/dev/null | cut -d' ' -f2)"; echo "   is folder mein ab rustc: $NOW"
[ "$NOW" = "$EXP" ] || { echo "!! toolchain file ne kaam nahi kiya — sab wapas"; restore_src; exit 1; }
if ! nice -n 10 cargo build --release >>"$LOG" 2>&1; then
  echo "!! build FAIL — src + toolchain wapas; purani binary chalti rehti hai (restart nahi hua). Errors:"; grep -E "^error" -A7 "$LOG" | head -40 | sed 's/^/   /'
  restore_src; exit 1
fi
echo "   build OK ($(grep -E 'Finished' "$LOG" | tail -1 | sed 's/^ *//'))"

echo "== 3) pm2 restart + health + WebTransport + wohi requests"
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
  echo "!! farq mila — PURANI binary + src + toolchain wapas:"; diff "$T/before.txt" "$T/after.txt" | sed 's/^/   /'; diff "$T/wt_before.txt" "$T/wt_after.txt" | sed 's/^/   WT /'
  cp -p "$BIN.bak.$STAMP" "$BIN.new.$STAMP" && mv -f "$BIN.new.$STAMP" "$BIN"; restore_src
  pm2 restart anexomail-rust --update-env >/dev/null 2>&1; sleep 4
  echo "   ab: /rpc/health $(health)   UDP 3443 $(udp3443)"; pm2 save >/dev/null 2>&1; exit 1
fi
pm2 save >/dev/null 2>&1
echo "OK — rustc: $CUR -> $(rustc --version | cut -d' ' -f2), edition: $ED -> 2024  (WebTransport frames $FR/12, handshake pehle jaisa, HTTP 13/13 same, health 200)"
echo "   wapas lene ke liye: cd $TARGET && for f in Cargo.toml Cargo.lock src/main.rs; do cp \$f.bak.$STAMP \$f; done && $( [ "$HAD_TC" = 1 ] && echo "cp rust-toolchain.toml.bak.$STAMP rust-toolchain.toml" || echo "rm -f rust-toolchain.toml" ) && cp $BIN.bak.$STAMP $BIN.new && mv -f $BIN.new $BIN && pm2 restart anexomail-rust --update-env"
