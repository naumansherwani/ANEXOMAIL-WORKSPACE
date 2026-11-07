#!/usr/bin/env bash
# GEO1 - Caddy country wall: Afghanistan, Israel, North Korea, Syria get 403 on every anexomail.com site (founder 2 Nov 2026, Syria added 7 Nov 2026 "HAAN"; Caddy is the edge; list = banned-countries/banned.json).
#   PLAN  (reads only, changes nothing):  git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:server/caddy/geoblock.sh) plan
#   APPLY (backup -> write -> validate -> reload, restore on failure): ... geoblock.sh apply
# Needs: curl, python3, caddy. Data: public RIR lists (APNIC for AF + KP, RIPE NCC for IL + SY). No account, no key, no plugin.
set -uo pipefail
MODE="${1:-plan}"; REPO="${REPO:-/opt/anexomail-web}"; D="$(mktemp -d)"; trap 'rm -rf "$D"' EXIT
MAIN=/etc/caddy/Caddyfile; SITES=/etc/caddy/sites; SNIP=/etc/caddy/geoblock.caddy; TS="$(date +%s)"
command -v caddy >/dev/null || { echo "caddy nahi mila - kuch nahi badla"; exit 1; }
git -C "$REPO" show origin/main:server/caddy/geoblock-gen.py > "$D/gen.py" || { echo "geoblock-gen.py origin/main se nahi mili"; exit 1; }
curl -fsS --max-time 120 -o "$D/apnic" https://ftp.apnic.net/stats/apnic/delegated-apnic-latest || { echo "FAIL: APNIC list nahi aayi - kuch nahi badla"; exit 1; }
curl -fsS --max-time 180 -o "$D/ripe" https://ftp.ripe.net/pub/stats/ripencc/delegated-ripencc-latest || { echo "FAIL: RIPE list nahi aayi - kuch nahi badla"; exit 1; }
python3 "$D/gen.py" gen "$D/apnic" "$D/ripe" "$D/geoblock.caddy" || exit 1
echo "-- site blocks that get 'import geoblock':"
python3 "$D/gen.py" wire "$MAIN" "$SITES" --dry
if [ "$MODE" != "apply" ]; then echo "(plan only - kuch nahi badla. Apply: ... geoblock.sh apply)"; exit 0; fi
mkdir -p /root/i9; cp -a /etc/caddy "/root/i9/caddy-geoblock-$TS"
cp "$D/geoblock.caddy" "$SNIP"
python3 "$D/gen.py" wire "$MAIN" "$SITES"
if ! caddy validate --config "$MAIN" >/dev/null 2>&1; then
  echo "FAIL: caddy validate - backup wapas"; rm -rf /etc/caddy && cp -a "/root/i9/caddy-geoblock-$TS" /etc/caddy
  caddy validate --config "$MAIN" 2>&1 | tail -5; exit 1
fi
systemctl reload caddy || systemctl restart caddy
sleep 2
for h in anexomail.com founderworkspace.anexomail.com; do printf '%s -> ' "$h"; curl -s -o /dev/null -w '%{http_code}\n' --max-time 20 "https://$h/"; done
echo "(chahiye: dono 200 - hamara apna IP block nahi hota. Backup: /root/i9/caddy-geoblock-$TS)"
