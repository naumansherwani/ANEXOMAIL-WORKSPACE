#!/usr/bin/env bash
# ANEXOMAIL — Rust engine: EK crate ka version upgrade, SAFE (Cargo.lock only), restore-on-fail. TECH-MAP 0a / Rule 25.
#   git -C /opt/anexomail-web fetch -q origin main && CRATE=tokio VER=1.53.3 bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-crate-upgrade.sh)
#
# Kya karta hai (sirf anexomail-rust; polar-rust-payment :3400, Brain, web, Caddy ko haath nahi):
#   0. abhi ka version (Cargo.lock) + health dikhata hai. Pehle se wohi version => kuch nahi karta.
#   1. backup: Cargo.lock, Cargo.toml, chalti binary (.bak.<ts>).
#   2. `cargo update -p CRATE --precise VER` — sirf Cargo.lock badalta hai (Cargo.toml nahi). Fail => lock wapas, ruk jata hai.
#   3. `nice cargo build --release`. Fail => lock wapas; purani binary chalti rehti hai (kuch nahi tootta).
#   4. pm2 restart + /rpc/health 200 + WebTransport UDP 3443 sun raha + Rust procs ka jawab. Koi bhi fail => purani binary + lock wapas, restart.
# Sirf semver-compatible upgrade (jaise tokio 1.53.1 -> 1.53.3). Bade upgrade (axum 0.8, wtransport 0.7) Cargo.toml + code badalte hain — woh alag script.
set -uo pipefail
TARGET="${TARGET:-/opt/anexomail-rust}"; RPC="${RPC:-http://127.0.0.1:3200}"
CRATE="${CRATE:-}"; VER="${VER:-}"
[ -n "$CRATE" ] && [ -n "$VER" ] || { echo "usage: CRATE=tokio VER=1.53.3 bash <(...)"; exit 2; }
[[ "$CRATE" =~ ^[a-z0-9_-]+$ && "$VER" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "FAIL: CRATE/VER ajeeb"; exit 2; }
STAMP="$(date +%s)"; BIN="$TARGET/target/release/anexomail-rust"; LOG="/tmp/anexomail-crate-$CRATE-$STAMP.log"
cd "$TARGET" || { echo "FAIL: $TARGET nahi"; exit 2; }
command -v cargo >/dev/null || { [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"; }
command -v cargo >/dev/null || { echo "FAIL: cargo nahi mila"; exit 2; }
lockver() { awk -v c="$1" '$0=="name = \""c"\""{getline; gsub(/version = |"/,""); print}' Cargo.lock | tr '\n' ' '; }
health() { curl -s -m 8 -o /dev/null -w '%{http_code}' "$RPC/rpc/health" 2>/dev/null; }
udp3443() { ss -ulnp 2>/dev/null | grep -q ':3443 ' && echo yes || echo NO; }
probe() { curl -s -m 8 -o /dev/null -w '%{http_code}' -X POST "$RPC/rpc/$1" -H 'authorization: Bearer x' -H 'content-type: application/json' -d '{}' 2>/dev/null; }

echo "== 0) abhi"
OLD="$(lockver "$CRATE")"
echo "   $CRATE (Cargo.lock): ${OLD:-nahi mila}   rustc: $(rustc --version 2>/dev/null | cut -d' ' -f2)   /rpc/health: $(health)   UDP 3443: $(udp3443)"
[ -n "$OLD" ] || { echo "FAIL: $CRATE Cargo.lock mein nahi"; exit 2; }
case " $OLD " in *" $VER "*) echo "OK — $CRATE pehle se $VER hai, kuch nahi badla"; exit 0;; esac

echo "== 1) backup"
cp -p Cargo.lock "Cargo.lock.bak.$STAMP" && cp -p Cargo.toml "Cargo.toml.bak.$STAMP" && cp -p "$BIN" "$BIN.bak.$STAMP" || { echo "FAIL: backup nahi bana — kuch nahi badla"; exit 2; }
restore_lock() { cp -p "Cargo.lock.bak.$STAMP" Cargo.lock; }

echo "== 2) cargo update -p $CRATE --precise $VER (sirf Cargo.lock)"
if ! cargo update -p "$CRATE" --precise "$VER" >"$LOG" 2>&1; then
  echo "!! update fail — Cargo.lock wapas. Wajah:"; tail -15 "$LOG" | sed 's/^/   /'; restore_lock; exit 1
fi
grep -E "Updating|Adding|Removing|Downgrading" "$LOG" | sed 's/^/   /' | head -20

echo "== 3) cargo build --release (kuch minute; log: $LOG)"
if ! nice -n 10 cargo build --release >>"$LOG" 2>&1; then
  echo "!! build FAIL — Cargo.lock wapas; purani binary chalti rehti hai. Errors:"; grep -E "^error" -A6 "$LOG" | head -40 | sed 's/^/   /'
  restore_lock; exit 1
fi
echo "   build OK ($(grep -E 'Finished' "$LOG" | tail -1 | sed 's/^ *//'))"

echo "== 4) pm2 restart + health + WebTransport + procs"
pm2 restart anexomail-rust --update-env >/dev/null 2>&1
ok=1
for i in 1 2 3 4 5 6 7 8 9 10; do sleep 2; [ "$(health)" = "200" ] && break; done
H="$(health)"; U="$(udp3443)"
P1="$(probe dashboard.summary)"; P2="$(probe migration.providers)"; P3="$(probe team.members.list)"
echo "   /rpc/health: $H   UDP 3443: $U   procs (nakli token => 401 = theek): dashboard $P1, migration $P2, team $P3"
[ "$H" = "200" ] || ok=0; [ "$U" = "yes" ] || ok=0
for c in "$P1" "$P2" "$P3"; do [ "$c" = "401" ] || ok=0; done
if [ "$ok" != 1 ]; then
  echo "!! naye build par kuch theek nahi — PURANI binary + Cargo.lock wapas"
  cp -p "$BIN.bak.$STAMP" "$BIN"; restore_lock
  pm2 restart anexomail-rust --update-env >/dev/null 2>&1; sleep 4
  echo "   ab: /rpc/health $(health)   UDP 3443 $(udp3443)"; pm2 save >/dev/null 2>&1; exit 1
fi
pm2 save >/dev/null 2>&1
echo "OK — $CRATE: $OLD -> $(lockver "$CRATE")   (health 200, WebTransport 3443 sun raha, procs jawab de rahe)"
echo "   wapas lene ke liye: cd $TARGET && cp Cargo.lock.bak.$STAMP Cargo.lock && cp $BIN.bak.$STAMP $BIN && pm2 restart anexomail-rust --update-env"
