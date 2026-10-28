#!/usr/bin/env bash
# Naya Rust founder ko founderworkspace.anexomail.com par lagana (repo folder se chalao):
#   cd /opt/anexomail-web && git checkout -- . && git pull -q && bash server/caddy/founder-host.sh
# Sirf founder host ka block badalta hai; caddy validate fail ho to backup wapas. Awam hosts/deploy-sites.sh ko nahi chhedta.
set -uo pipefail
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN=/etc/caddy/Caddyfile; SITES=/etc/caddy/sites
command -v caddy >/dev/null || { echo "caddy nahi mila"; exit 1; }
BEFORE="$(ls -t "$MAIN".bak.founder.* "$SITES"/*.bak.founder.* 2>/dev/null | head -1 || true)"
python3 "$D/patch-founder-host.py" "$MAIN" "$SITES"; rc=$?
[ $rc -eq 0 ] || { echo "FAIL (rc=$rc) — Caddy mein kuch nahi badla/reload nahi hua"; exit $rc; }
AFTER="$(ls -t "$MAIN".bak.founder.* "$SITES"/*.bak.founder.* 2>/dev/null | head -1 || true)"
if ! caddy validate --config "$MAIN" >/dev/null 2>&1; then
  echo "FAIL: caddy validate — backup wapas"
  if [ -n "$AFTER" ] && [ "$AFTER" != "$BEFORE" ]; then orig="${AFTER%.bak.founder.*}"; cp "$AFTER" "$orig"; fi
  caddy validate --config "$MAIN" 2>&1 | tail -5; exit 1
fi
systemctl reload caddy || systemctl restart caddy
sleep 2
for p in /f/ /founder/v1/me /app; do printf '%s -> ' "$p"; curl -s -o /dev/null -w '%{http_code}\n' --max-time 20 "https://founderworkspace.anexomail.com$p"; done
echo "(chahiye: /f/ 200 · /founder/v1/me 401 · /app purana jaisa)"
