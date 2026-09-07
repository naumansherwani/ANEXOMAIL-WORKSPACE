#!/usr/bin/env bash
# ============================================================================
# ANEXOMAIL — POLAR RUST PAYMENT ENGINE deploy (auto-sync, zero manual editing)
#
# Nauman ke liye poora kaam sirf yeh 2 line:
#   cd /opt/anexomail-web && git pull && bash server/rust/polar-payment/deploy.sh
#
# Yeh script:
#   1. repo se engine files /opt/polar-rust-payment mein copy karti hai (backup ke saath)
#   2. .env ko KABHI touch nahi karti (secrets sirf server par rehte hain)
#   3. WAL folders banati hai (pending/done/dead)
#   4. cargo build --release + pm2 start/restart
#   5. /health + /ready + /metrics print karti hai
# ============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE_DIR="${ENGINE_DIR:-/opt/polar-rust-payment}"
PM2_NAME="polar-rust-payment"
STAMP="$(date +%s)"

echo "==> engine dir: $ENGINE_DIR"
mkdir -p "$ENGINE_DIR/src" "$ENGINE_DIR/wal/pending" "$ENGINE_DIR/wal/done" "$ENGINE_DIR/wal/dead"

for pair in "Cargo.toml:Cargo.toml" "main.rs:src/main.rs"; do
  src="$REPO_DIR/${pair%%:*}"
  dst="$ENGINE_DIR/${pair##*:}"
  if [ -f "$dst" ] && ! cmp -s "$src" "$dst"; then
    cp "$dst" "$dst.bak.$STAMP"
    echo "    backup: $dst.bak.$STAMP"
  fi
  cp "$src" "$dst"
  echo "    synced: $dst"
done

if [ ! -f "$ENGINE_DIR/.env" ]; then
  echo "!!! $ENGINE_DIR/.env maujood nahi — secrets ke baghair engine nahi chalegi."
  echo "!!! docs/polar-rust-payment.md ka .env block bharo, phir yeh script dobara chalao."
  exit 1
fi

echo "==> cargo build --release"
cd "$ENGINE_DIR"
cargo build --release

echo "==> pm2"
if pm2 describe "$PM2_NAME" >/dev/null 2>&1; then
  pm2 restart "$PM2_NAME" --update-env
else
  pm2 start "$ENGINE_DIR/target/release/$PM2_NAME" --name "$PM2_NAME" --cwd "$ENGINE_DIR"
fi
pm2 save

echo "==> sehat (5 second baad)"
sleep 5
PORT_LOCAL="$(grep -E '^PORT=' "$ENGINE_DIR/.env" | cut -d= -f2 | tr -d '[:space:]')"
PORT_LOCAL="${PORT_LOCAL:-3400}"
echo -n "  health : "; curl -s "http://127.0.0.1:$PORT_LOCAL/health"  || echo "DOWN"; echo
echo -n "  ready  : "; curl -s "http://127.0.0.1:$PORT_LOCAL/ready"   || echo "DOWN"; echo
echo -n "  metrics: "; curl -s "http://127.0.0.1:$PORT_LOCAL/metrics" || echo "DOWN"; echo
echo "==> done"
