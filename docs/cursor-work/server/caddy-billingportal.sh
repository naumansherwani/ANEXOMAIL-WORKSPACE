#!/usr/bin/env bash
# ============================================================================
# caddy-billingportal.sh — P1: billingportal.anexomail.com ka ADDITIVE Caddy block + branded placeholder.
#   plan (default): sirf dikhata hai · MODE=apply: backup -> likho -> caddy validate -> reload -> test -> fail par rollback
#   bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/caddy-billingportal.sh)
#   MODE=apply bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/caddy-billingportal.sh)
# Caddy KHUD rehta hai; sirf ek NAYI file /etc/caddy/sites/billingportal.caddy. Baqi sites ko haath nahi.
# ============================================================================
set -uo pipefail
MODE="${MODE:-plan}"; HOST=billingportal.anexomail.com; WEB="${WEB:-/opt/anexomail-web}"
ROOT=/var/www/billingportal; SITE=/etc/caddy/sites/billingportal.caddy; MAIN=/etc/caddy/Caddyfile
STAMP="$(date +%Y%m%d-%H%M%S)"; BK="/root/anexomail-backups/caddy-billingportal-$STAMP"
IP_WANT="$(curl -s -m 5 https://api.ipify.org 2>/dev/null || echo '?')"
echo "==> server IP (bahar se): $IP_WANT"
echo "==> DNS $HOST:  $(getent hosts $HOST | awk '{print $1}' | head -1 || true)  (upar wale IP se milna chahiye)"
[ -f "$MAIN" ] || { echo "!!! $MAIN nahi mila"; exit 1; }
grep -Fq 'import /etc/caddy/sites/*.caddy' "$MAIN" || { echo "!!! Caddyfile mein 'import /etc/caddy/sites/*.caddy' nahi — pehle deploy.sh wali import line chahiye. Kuch nahi badla."; exit 1; }
grep -Eq "^[[:space:]]*billingportal\.anexomail\.com[[:space:]]*\{" "$MAIN" && { echo "==> $HOST pehle se $MAIN mein hai (haath se joda hua). Duplicate block se Caddy fail hota hai, isliye kuch nahi badla."; exit 0; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
git -C "$WEB" show origin/main:portal/public/index.html >"$T/index.html" 2>/dev/null && [ -s "$T/index.html" ] || { echo "!!! repo se portal/public/index.html nahi mila (git fetch?)"; exit 1; }
cat >"$T/site.caddy" <<CADDY
# BILLING PORTAL (P1) — static SPA; /rpc aur /sse P2 mein judenge. Repo-managed: docs/cursor-work/server/caddy-billingportal.sh
$HOST {
	encode zstd gzip
	header {
		Strict-Transport-Security "max-age=31536000; includeSubDomains"
		X-Content-Type-Options "nosniff"
		X-Frame-Options "DENY"
		Referrer-Policy "no-referrer"
		Permissions-Policy "camera=(), microphone=(), geolocation=()"
		Content-Security-Policy "default-src 'self'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src https://fonts.gstatic.com; img-src 'self' data:; script-src 'self'; connect-src 'self' https://anexomail.com; frame-ancestors 'none'; base-uri 'none'; form-action 'self'"
		-Server
	}
	root * $ROOT
	@assets path /assets/*
	header @assets Cache-Control "public, max-age=31536000, immutable"
	try_files {path} /index.html
	file_server
	log {
		output file /var/log/caddy/billingportal.log
		format json
	}
}
CADDY
echo; echo "==> PLAN: $ROOT/index.html (placeholder) + $SITE"
sed 's/^/    /' "$T/site.caddy" | head -30
[ "$MODE" = "apply" ] || { echo; echo "Yeh sirf PLAN tha. Kuch nahi badla. Chalane ke liye: MODE=apply ..."; exit 0; }

mkdir -p "$BK" /var/log/caddy; [ -f "$SITE" ] && cp -a "$SITE" "$BK/billingportal.caddy"
touch /var/log/caddy/billingportal.log; id caddy >/dev/null 2>&1 && chown caddy:caddy /var/log/caddy/billingportal.log
mkdir -p "$ROOT" && cp "$T/index.html" "$ROOT/index.html" && chmod -R a+rX /var/www/billingportal
rollback() { echo "!!! ROLLBACK: $1"; if [ -f "$BK/billingportal.caddy" ]; then cp -a "$BK/billingportal.caddy" "$SITE"; else rm -f "$SITE"; fi
  caddy validate --config "$MAIN" >/dev/null 2>&1 && systemctl reload caddy; echo "    purani Caddy config wapas. Backup: $BK"; exit 1; }
mkdir -p /etc/caddy/sites; cp "$T/site.caddy" "$SITE"
caddy fmt --overwrite "$SITE" >/dev/null 2>&1 || true
caddy validate --config "$MAIN" 2>&1 | tail -2; caddy validate --config "$MAIN" >/dev/null 2>&1 || rollback "caddy validate fail"
systemctl reload caddy || rollback "caddy reload fail"
sleep 4
FAIL=0
H="$(curl -s -m 15 -o /dev/null -w '%{http_code}' https://$HOST/)"; [ "$H" = "200" ] && echo "    OK   https://$HOST/ => 200" || { echo "    NOTE https://$HOST/ => $H (DNS abhi na phaila ho ya certificate ban raha ho — 1-2 minute baad dobara: curl -I https://$HOST/)"; }
M="$(curl -s -m 10 -o /dev/null -w '%{http_code}' https://anexomail.com/)"; [ "$M" = "200" ] && echo "    OK   anexomail.com => 200 (baqi site salamat)" || { echo "    FAIL anexomail.com => $M"; FAIL=1; }
W="$(curl -s -m 10 -o /dev/null -w '%{http_code}' -X POST -H 'content-type: application/json' -d '{}' https://anexomail.com/api/v1/polar-webhook)"; [ "$W" = "401" ] && echo "    OK   webhook darwaaza ab bhi khula (401)" || { echo "    FAIL webhook => $W"; FAIL=1; }
[ "$FAIL" = "0" ] || rollback "post-check fail"
echo; echo "==> BILLING PORTAL P1 TAYYAR. Backup: $BK"
echo "    Rollback haath se: rm -f $SITE && systemctl reload caddy"
