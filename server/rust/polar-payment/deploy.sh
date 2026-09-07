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
#   5. polarpayments.anexomail.com ka SECOND Caddy ingress install karti hai
#      (purana anexomail.com endpoint bilkul touch nahi hota)
#   6. /health + /ready + /metrics print karti hai
# ============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE_DIR="${ENGINE_DIR:-/opt/polar-rust-payment}"
PM2_NAME="polar-rust-payment"
STAMP="$(date +%s)"
CADDY_SOURCE="$REPO_DIR/polarpayments.Caddyfile"
CADDY_DIR="/etc/caddy/sites"
CADDY_TARGET="$CADDY_DIR/polarpayments.caddy"
CADDY_MAIN="/etc/caddy/Caddyfile"

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

echo "==> second Polar ingress: polarpayments.anexomail.com"
if [ -f "$CADDY_MAIN" ] && command -v caddy >/dev/null 2>&1; then
  mkdir -p "$CADDY_DIR" /var/log/caddy
  # Log file pehle se bana do, warna Caddy reload "permission denied" par fail hota hai.
  touch /var/log/caddy/polarpayments.log
  if id caddy >/dev/null 2>&1; then
    chown -R caddy:caddy /var/log/caddy
  fi
  chmod 755 /var/log/caddy
  if [ -f "$CADDY_TARGET" ] && ! cmp -s "$CADDY_SOURCE" "$CADDY_TARGET"; then
    cp "$CADDY_TARGET" "$CADDY_TARGET.bak.$STAMP"
  fi
  cp "$CADDY_SOURCE" "$CADDY_TARGET"

  # Sirf ek import line add hoti hai. Existing anexomail.com block/endpoint untouched.
  if ! grep -Fqx 'import /etc/caddy/sites/*.caddy' "$CADDY_MAIN"; then
    cp "$CADDY_MAIN" "$CADDY_MAIN.bak.$STAMP"
    printf '\n# Repo-managed independent site blocks\nimport /etc/caddy/sites/*.caddy\n' >> "$CADDY_MAIN"
  fi

  if command -v ufw >/dev/null 2>&1; then
    ufw allow 443/tcp >/dev/null
    ufw allow 443/udp >/dev/null
  fi
  caddy fmt --overwrite "$CADDY_TARGET"
  caddy validate --config "$CADDY_MAIN"
  systemctl reload caddy || systemctl restart caddy
  echo "    installed: $CADDY_TARGET (h1 + h2 + h3; UDP/TCP 443 allowed)"
else
  echo "!!! Caddy not found; engine is green but second public ingress was not installed."
fi

echo "==> sehat (5 second baad)"
sleep 5
PORT_LOCAL="$(grep -E '^PORT=' "$ENGINE_DIR/.env" | cut -d= -f2 | tr -d '[:space:]')"
PORT_LOCAL="${PORT_LOCAL:-3400}"
echo -n "  health : "; curl -s "http://127.0.0.1:$PORT_LOCAL/health"  || echo "DOWN"; echo
echo -n "  ready  : "; curl -s "http://127.0.0.1:$PORT_LOCAL/ready"   || echo "DOWN"; echo
echo -n "  metrics: "; curl -s "http://127.0.0.1:$PORT_LOCAL/metrics" || echo "DOWN"; echo
echo "==> public second-ingress checks (DNS must already point to 62.238.98.98)"
echo -n "  health : "; curl -fsS --connect-timeout 5 "https://polarpayments.anexomail.com/health" || echo "DNS/TLS NOT READY"; echo
echo -n "  h3 ad  : "; curl -fsSI --connect-timeout 5 "https://polarpayments.anexomail.com/health" | grep -i '^alt-svc:' || echo "Alt-Svc not visible yet"
echo "==> done"
