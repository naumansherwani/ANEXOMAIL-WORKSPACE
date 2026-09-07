#!/usr/bin/env bash
# ============================================================================
# REPO-MANAGED CADDY SITE BLOCKS — auto sync (koi nano, koi manual overwrite)
#
#   bash server/caddy/deploy-sites.sh
#
# Kaam:
#   1. repo ke har `server/caddy/*.Caddyfile` ko /etc/caddy/sites/<name>.caddy
#      mein copy (purani file .bak.<timestamp> backup ke saath)
#   2. /etc/caddy/Caddyfile mein `import /etc/caddy/sites/*.caddy` ensure
#   3. log files + permissions
#   4. caddy fmt + validate + reload
#   5. har host ka asli HTTP code print (claim nahi, reading)
#
# Main Caddyfile ke maujooda host blocks ko yeh script KABHI nahi chhedti.
# ============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CADDY_DIR="/etc/caddy/sites"
CADDY_MAIN="/etc/caddy/Caddyfile"
TS="$(date +%s)"

if ! command -v caddy >/dev/null 2>&1; then
  echo "!!! caddy binary nahi mila — kuch install nahi kiya."
  exit 1
fi

mkdir -p "$CADDY_DIR" /var/log/caddy

shopt -s nullglob
for src in "$REPO_DIR"/*.Caddyfile; do
  base="$(basename "$src" .Caddyfile)"
  target="$CADDY_DIR/$base.caddy"
  if [ -f "$target" ]; then
    cp "$target" "$target.bak.$TS"
  fi
  cp "$src" "$target"
  touch "/var/log/caddy/$base.log"
  echo ">>> installed $target"
done
shopt -u nullglob

if id caddy >/dev/null 2>&1; then
  chown -R caddy:caddy /var/log/caddy
fi
chmod 755 /var/log/caddy

if [ -f "$CADDY_MAIN" ] && ! grep -Fqx 'import /etc/caddy/sites/*.caddy' "$CADDY_MAIN"; then
  cp "$CADDY_MAIN" "$CADDY_MAIN.bak.$TS"
  printf '\n# Repo-managed independent site blocks\nimport /etc/caddy/sites/*.caddy\n' >> "$CADDY_MAIN"
  echo ">>> import line added to $CADDY_MAIN"
fi

shopt -s nullglob
for f in "$CADDY_DIR"/*.caddy; do
  caddy fmt --overwrite "$f" || true
done
shopt -u nullglob
caddy validate --config "$CADDY_MAIN"
systemctl reload caddy || systemctl restart caddy

echo "--- ufw (TURN ports, agar ufw active hai) ---"
if command -v ufw >/dev/null 2>&1; then
  ufw allow 3478/udp || true
  ufw allow 3478/tcp || true
  ufw allow 5349/tcp || true
  ufw allow 49152:49500/udp || true
fi

echo "--- live readings ---"
for h in anexovideocall.anexomail.com polarpayments.anexomail.com; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "https://$h" || echo 000)
  echo "$h -> $code"
done
echo "(pehli baar 000 aa sakta hai jab tak cert issue ho raha ho — 20s baad dobara chalao)"
