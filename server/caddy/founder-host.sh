#!/usr/bin/env bash
# Naya Rust founder ko founderworkspace.anexomail.com par lagana (repo folder se chalao):
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:server/caddy/founder-host.sh)
# (server ka working tree sync nahi hota, isliye git pull NAHI — sab origin/main se; patch script bhi wahin se uthti hai.)
# Sirf founder host ka block badalta hai; caddy validate fail ho to backup wapas. Awam hosts/deploy-sites.sh ko nahi chhedta.
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"; D="$(mktemp -d)"; trap 'rm -rf "$D"' EXIT
git -C "$REPO" show origin/main:server/caddy/patch-founder-host.py > "$D/patch-founder-host.py" || { echo "patch script origin/main se nahi mili"; exit 1; }
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
for p in / /_cc/ /founder/v1/me /app /founderlogin; do printf '%s -> ' "$p"; curl -s -o /dev/null -w '%{http_code}\n' --max-time 20 "https://founderworkspace.anexomail.com$p"; done
echo "(chahiye: / 200 (Command Center) · /_cc/ 200 · /founder/v1/me 401 · /app aur /founderlogin 200)"
