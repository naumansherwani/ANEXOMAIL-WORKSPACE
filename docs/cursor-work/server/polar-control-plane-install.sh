#!/usr/bin/env bash
# ============================================================================
# polar-control-plane-install.sh — B6a: Polar engine par MUHAR + PORTAL + KILL SWITCH
# (21 Oct 2026). Webhook ka raasta (WAL-first) ek byte nahi badalta.
#
#   bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/polar-control-plane-install.sh)
#   (pehle Web pull: bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh))
#
# Kya karta hai (har qadam backup ke saath):
#   1. backup: src/main.rs, Cargo.toml, chalta binary -> /root/anexomail-backups/polar-cp-<stamp>/
#   2. key: /etc/anexomail/pcp.key (600) — pehle se ho to wahi, warna naya (openssl rand)
#   3. repo se main.rs + pcp.rs copy, cargo build --release (FAIL => purani src wapas, service chalti rehti hai)
#   4. pm2 restart, phir PROOF: /ready, webhook test-event (received barhna chahiye),
#      bina muhar portal => 401, muhar ke saath => gate paar
#   5. koi proof fail => purana binary + src wapas, pm2 restart, dobara /ready check
# .env ko haath nahi lagata. Caddy ko haath nahi lagata (woh alag script).
# ============================================================================
set -uo pipefail

WEB="${WEB:-/opt/anexomail-web}"
SRC="$WEB/server/rust/polar-payment"
# Rust files web-manifest mein nahi hote => working tree mein na hon to seedha origin/main (git objects) se nikalo.
if [ ! -f "$SRC/pcp.rs" ] || [ "${FROM_GIT:-1}" = "1" ]; then
  git -C "$WEB" fetch -q origin main </dev/null 2>/dev/null || true
  STAGE="$(mktemp -d)"; SRC="$STAGE"
  for f in main.rs pcp.rs Cargo.toml pcp-call.sh test-event.sh; do
    git -C "$WEB" show "origin/main:server/rust/polar-payment/$f" >"$STAGE/$f" 2>/dev/null </dev/null || rm -f "$STAGE/$f"
  done
fi
ENG="${ENGINE_DIR:-/opt/polar-rust-payment}"
PM2N="polar-rust-payment"
STAMP="$(date +%Y%m%d-%H%M%S)"
BK="/root/anexomail-backups/polar-cp-$STAMP"
KEYF="/etc/anexomail/pcp.key"
PORT="$(grep -E '^PORT=' "$ENG/.env" 2>/dev/null | cut -d= -f2 | tr -d '[:space:]')"; PORT="${PORT:-3400}"
L="http://127.0.0.1:$PORT"

say() { printf '\n==> %s\n' "$*"; }
ok()  { printf '    OK   %s\n' "$*"; }
bad() { printf '    FAIL %s\n' "$*"; }

for f in main.rs pcp.rs Cargo.toml pcp-call.sh; do
  [ -f "$SRC/$f" ] || { echo "!!! $SRC/$f nahi mila — pehle Web pull chalao."; exit 1; }
done
[ -f "$ENG/.env" ] || { echo "!!! $ENG/.env nahi mila."; exit 1; }
command -v cargo >/dev/null || { echo "!!! cargo nahi mila."; exit 1; }
grep -q '^mod pcp;' "$SRC/main.rs" || { echo "!!! repo main.rs mein 'mod pcp;' nahi — galat version."; exit 1; }

say "1/5 backup -> $BK"
mkdir -p "$BK"
cp -a "$ENG/src" "$BK/src" && cp -a "$ENG/Cargo.toml" "$BK/Cargo.toml"
[ -f "$ENG/Cargo.lock" ] && cp -a "$ENG/Cargo.lock" "$BK/Cargo.lock"
BIN="$ENG/target/release/polar-rust-payment"
[ -f "$BIN" ] && cp -a "$BIN" "$BK/polar-rust-payment.bin"
pm2 jlist >"$BK/pm2.json" 2>/dev/null || true
ok "backup mukammal"

restore() {
  echo "!!! ROLLBACK shuru: $1"
  rm -f "$ENG/src/pcp.rs"
  cp -a "$BK/src/." "$ENG/src/"
  cp -a "$BK/Cargo.toml" "$ENG/Cargo.toml"
  [ -f "$BK/Cargo.lock" ] && cp -a "$BK/Cargo.lock" "$ENG/Cargo.lock"
  [ -f "$BK/polar-rust-payment.bin" ] && cp -a "$BK/polar-rust-payment.bin" "$BIN"
  pm2 restart "$PM2N" --update-env >/dev/null 2>&1
  sleep 4
  if curl -fsS -m 8 "$L/ready" | grep -q '"ready":true'; then
    echo "    purana engine wapas chal raha hai (/ready true). Backup: $BK"
  else
    echo "!!! purana engine bhi ready nahi — pm2 logs $PM2N --lines 40 dekho. Backup: $BK"
  fi
  exit 1
}

say "2/5 muhar ki chaabi ($KEYF)"
mkdir -p /etc/anexomail && chmod 755 /etc/anexomail
if [ -s "$KEYF" ]; then
  ok "pehle se maujood — wahi rehne di"
else
  umask 077
  openssl rand -hex 32 >"$KEYF" && chmod 600 "$KEYF"
  ok "nayi chaabi bani (64 hex, 600)"
fi
cp "$SRC/pcp-call.sh" /usr/local/bin/pcp-call && chmod 755 /usr/local/bin/pcp-call

say "3/5 build (service abhi purane binary par chal rahi hai)"
cp "$SRC/Cargo.toml" "$ENG/Cargo.toml"
cp "$SRC/main.rs" "$ENG/src/main.rs"
cp "$SRC/pcp.rs" "$ENG/src/pcp.rs"
if ! (cd "$ENG" && cargo build --release 2>&1 | tail -15); then
  restore "cargo build fail"
fi
[ -x "$BIN" ] || restore "binary nahi bana"
ok "build theek"

say "4/5 restart + PROOF"
pm2 restart "$PM2N" --update-env >/dev/null 2>&1 || restore "pm2 restart fail"
pm2 save >/dev/null 2>&1 || true
for i in $(seq 1 30); do
  curl -fsS -m 3 "$L/ready" 2>/dev/null | grep -q '"ready":true' && break
  sleep 1
done

FAIL=0
# metrics process-local hain (restart par zero) => baseline restart KE BAAD lena zaroori hai
M0="$(curl -fsS -m 6 "$L/metrics" 2>/dev/null | grep -o '"received": *[0-9]*' | grep -o '[0-9]*$' || echo 0)"
curl -fsS -m 8 "$L/ready" | grep -q '"ready":true' && ok "/ready true" || { bad "/ready"; FAIL=1; }
H="$(curl -fsS -m 8 "$L/health" 2>/dev/null)"
echo "$H" | grep -q '"webhook_secret":true' && ok "/health: webhook secrets loaded" || { bad "/health webhook secret nahi"; FAIL=1; }

if [ -x "$SRC/test-event.sh" ] || [ -f "$SRC/test-event.sh" ]; then
  T="$(bash "$SRC/test-event.sh" 2>&1 | tail -12)"
  echo "$T" | sed 's/^/      /'
  M1="$(curl -fsS -m 6 "$L/metrics" 2>/dev/null | grep -o '"received": *[0-9]*' | grep -o '[0-9]*$' || echo 0)"
  if [ "${M1:-0}" -gt "${M0:-0}" ]; then ok "webhook test: received $M0 -> $M1 (WAL-first zinda)"; else bad "webhook test: received nahi badha ($M0 -> $M1)"; FAIL=1; fi
fi

U="$(curl -s -m 8 -o /tmp/pcp-u.json -w '%{http_code}' -X POST -H 'content-type: application/json' -d '{"user_id":"00000000-0000-4000-8000-000000000000"}' "$L/api/v1/portal")"
[ "$U" = "401" ] && grep -q signature_required /tmp/pcp-u.json && ok "bina muhar portal => 401" || { bad "bina muhar portal => $U (401 chahiye)"; FAIL=1; }
XF="$(curl -s -m 8 -o /dev/null -w '%{http_code}' -H 'x-forwarded-for: 1.2.3.4' "$L/api/v1/billing/00000000-0000-4000-8000-000000000000")"
[ "$XF" = "403" ] && ok "proxy-header wali billing => 403" || { bad "billing + X-Forwarded-For => $XF (403 chahiye)"; FAIL=1; }

[ "$FAIL" = "0" ] || restore "proof fail"

say "5/5 muhar-wala asli sawal (Polar tak): koi nakli UUID"
R="$(bash "$SRC/pcp-call.sh" POST /api/v1/portal '{"user_id":"00000000-0000-4000-8000-000000000000"}' 2>&1)"
echo "$R" | sed 's/^/      /'
if echo "$R" | tail -1 | grep -qE '^(404|200)$'; then
  ok "gate paar + Polar se jawab aaya"
elif echo "$R" | tail -1 | grep -qE '^50[23]$'; then
  echo "    NOTE: gate theek, magar Polar wala hissa 5xx de raha hai — upar ka jawab mujhe bhejo (webhook/payment par asar nahi)."
else
  echo "    NOTE: ajeeb jawab — mujhe upar ka output bhejo."
fi

echo
echo "==> TAYYAR. Backup: $BK"
echo "    Kill switch:   touch $ENG/PAUSE_PORTAL   (rukne ke liye)   |   rm $ENG/PAUSE_PORTAL (chalu)"
echo "    Muhar se call: pcp-call POST /api/v1/portal '{\"user_id\":\"<uuid>\"}'"
echo "    Rollback haath se: cp $BK/polar-rust-payment.bin $BIN; cp -a $BK/src/. $ENG/src/; pm2 restart $PM2N"
