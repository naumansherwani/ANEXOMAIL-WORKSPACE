#!/bin/bash
# K4.3 cert refresh check (15 Nov 2026). READ-ONLY. His K proof showed the founder cert copy expires 5 Jan 2027; this shows whether Caddy already holds a newer one and whether the daily copy job exists. Prints only dates and file names, never a key.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/cert-refresh-check.sh)
H=founderworkspace.anexomail.com; CC="${CADDY_CERTS:-/var/lib/caddy/.local/share/caddy/certificates}"; TD=/etc/anexomail/tls
echo "== now: $(date -u +%FT%TZ)"
echo "== 1 the copy the founder binary uses: $(openssl x509 -enddate -noout -in $TD/$H.crt 2>/dev/null)"
c=$(find "$CC" -type f -name "$H.crt" 2>/dev/null | head -1)
if [ -n "$c" ]; then echo "== 2 Caddy's own certificate: $(openssl x509 -enddate -noout -in "$c" 2>/dev/null)"; cmp -s "$c" "$TD/$H.crt" && echo "   same file content as the copy" || echo "   DIFFERENT from the copy (the daily job should copy it)"; else echo "== 2 Caddy certificate not found under $CC"; fi
echo "== 3 the daily copy job:"; if [ -r /etc/cron.d/anexomail-founder-tls ]; then sed 's/\\\$/$/g' /etc/cron.d/anexomail-founder-tls | cut -c1-120 | head -3; else echo "   /etc/cron.d/anexomail-founder-tls NOT FOUND"; fi
echo "OK read-only. Paste this whole output to Claude."
