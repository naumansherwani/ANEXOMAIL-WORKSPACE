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

# ---------------------------------------------------------------------------
# SELF-HEAL: Caddy ki apni certificate store ka ownership. Agar kabhi coturn ke
# liye Caddy ki key par chown/chmod kar diya gaya ho to Caddy apni hi private
# key nahi padh sakta -> TLS "internal error" -> curl 000. Yahan wapas theek.
# coturn ko cert ki COPY di jati hai, original kabhi nahi chhoora jata.
# ---------------------------------------------------------------------------
CADDY_CERT_ROOT="/var/lib/caddy/.local/share/caddy"
if [ -d "$CADDY_CERT_ROOT" ] && id caddy >/dev/null 2>&1; then
  chown -R caddy:caddy "$CADDY_CERT_ROOT"
  find "$CADDY_CERT_ROOT/certificates" -type f -name '*.key' -exec chmod 600 {} \; 2>/dev/null || true
  find "$CADDY_CERT_ROOT/certificates" -type f -name '*.crt' -exec chmod 644 {} \; 2>/dev/null || true
  echo ">>> caddy certificate store ownership fixed (caddy:caddy)"
fi

# coturn ke liye cert ki alag copy (TURN host)
TURN_CERT_SRC="$(find "$CADDY_CERT_ROOT/certificates" -type d -name '*anexovideocall.anexomail.com*' 2>/dev/null | head -1 || true)"
if [ -n "${TURN_CERT_SRC:-}" ] && id turnserver >/dev/null 2>&1; then
  mkdir -p /etc/anexochat/turn
  cp "$TURN_CERT_SRC"/anexovideocall.anexomail.com.crt /etc/anexochat/turn/fullchain.pem
  cp "$TURN_CERT_SRC"/anexovideocall.anexomail.com.key /etc/anexochat/turn/privkey.pem
  chown turnserver:turnserver /etc/anexochat/turn/fullchain.pem /etc/anexochat/turn/privkey.pem
  chmod 640 /etc/anexochat/turn/fullchain.pem /etc/anexochat/turn/privkey.pem
  systemctl restart coturn >/dev/null 2>&1 || true
  echo ">>> coturn cert copy refreshed (/etc/anexochat/turn)"
fi


if [ -f "$CADDY_MAIN" ] && ! grep -Fqx 'import /etc/caddy/sites/*.caddy' "$CADDY_MAIN"; then
  cp "$CADDY_MAIN" "$CADDY_MAIN.bak.$TS"
  printf '\n# Repo-managed independent site blocks\nimport /etc/caddy/sites/*.caddy\n' >> "$CADDY_MAIN"
  echo ">>> import line added to $CADDY_MAIN"
fi

# ---------------------------------------------------------------------------
# MAIN CADDYFILE AUTO-PATCH (Phase 13/14/15): har /rpc/* wale host block mein
# /file/*, /wt/* -> Rust 3200 aur request_body 32MB ensure. Idempotent.
# ---------------------------------------------------------------------------
if [ -f "$CADDY_MAIN" ]; then
  # duplicate host (repo site file + main file) -> caddy validate fail -> host 000
  python3 "$REPO_DIR/strip-dup-hosts.py" "$CADDY_MAIN" "$CADDY_DIR"
  python3 "$REPO_DIR/patch-main-caddyfile.py" "$CADDY_MAIN"
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

echo "--- DNS readings (registrar ka sach) ---"
for h in anexochat.anexomail.com anexovideocall.anexomail.com; do
  echo "$h A -> $(getent hosts "$h" | awk '{print $1}' | head -1 || echo none)"
done
echo "--- live readings ---"
for h in anexochat.anexomail.com anexovideocall.anexomail.com polarpayments.anexomail.com; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "https://$h" || echo 000)
  echo "$h -> $code"
done
echo "--- file engine readings (200 expected) ---"
for h in anexomail.com founderworkspace.anexomail.com ai.anexomail.com; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "https://$h/file/ping" || echo 000)
  echo "$h/file/ping -> $code"
done
for h in anexomail.com polarpayments.anexomail.com anexovideocall.anexomail.com; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "https://$h/" || echo 000)
  echo "$h/ -> $code"
done
echo "(pehli baar 000 aa sakta hai jab tak cert issue ho raha ho — 20s baad dobara chalao)"
