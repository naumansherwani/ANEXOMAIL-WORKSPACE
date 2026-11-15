#!/bin/bash
# K-SERIES + KP3 PROOF ON HIS SERVER (his order 15 Nov 2026 19:38: "yeh K/KP saray phases: server pe commands do, phir Chrome se match kero"). READ-ONLY: changes NOTHING, restarts NOTHING, prints no key, no token, no env VALUE.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-k-proof.sh)
# Each block names the phases it proves. Paste the whole output to Claude; Claude then compares it with the live Chrome look (one table, line by line).
H=founderworkspace.anexomail.com; ENVF=/etc/anexomail/founder.env
echo "== 0 now: $(date -u +%FT%TZ)"
echo "== 1 [K4 K8e KP3 step 1,5] services and the binary that owns each port"
for u in anexomail-founder founder-dns caddy; do printf '   %-18s %s\n' "$u" "$(systemctl is-active $u 2>&1)"; done
for pp in tcp:443 udp:443 udp:4443 udp:53 tcp:53 tcp:3210; do pr=${pp%%:*}; po=${pp##*:}
  o=$(ss -H -l${pr:0:1}np 2>/dev/null | awk -v p=":$po" '$4 ~ p"$" {print $0}' | grep -o 'pid=[0-9]*' | sort -u | while IFS== read -r _ pid; do basename "$(readlink /proc/$pid/exe 2>/dev/null)"; done | sort -u | tr '\n' ' ')
  printf '   %-4s %-5s %s\n' "$pr" "$po" "${o:-<nobody>}"; done
echo "== 2 [K8e] TCP 443 of the founder host speaks NO HTTP (expect http code 000)"
printf '   curl https over TCP: code=%s\n' "$(curl -sk -m 6 -o /dev/null -w '%{http_code}' --resolve $H:443:127.0.0.1 https://$H/healthz 2>/dev/null)"
echo "== 3 [K8a-K8c KP3] HTTP/3 over UDP 443 answered by curl (needs a curl built with HTTP/3)"
if curl --version 2>/dev/null | grep -qi http3; then curl -sk -m 8 -o /dev/null -w '   h3 request: http_version=%{http_version} code=%{http_code}\n' --http3-only --resolve $H:443:127.0.0.1 https://$H/healthz; else echo "   n/a: this curl has no HTTP/3 (not a failure; Chrome shows h3 below)"; fi
echo "== 4 [KP3 step 5] no WebTransport env left, only variable NAMES shown"
grep -c '^FOUNDER_WT_' $ENVF 2>/dev/null | sed 's/^/   FOUNDER_WT_ lines: /'
echo "   env names: $(grep -o '^[A-Z_0-9]*=' $ENVF 2>/dev/null | tr -d '=' | tr '\n' ' ')"
echo "== 5 [K1 K2 K4 K8c] certificate dates (public part only)"
for f in /etc/anexomail/tls/*; do case "$f" in *key*|*KEY*) continue;; esac; d=$(openssl x509 -enddate -noout -in "$f" 2>/dev/null); [ -n "$d" ] && echo "   $(basename $f): $d"; done
echo "== 6 [K6 K8d K8e KP3] what the service itself says on start (last 400 lines, key words only)"
journalctl -u anexomail-founder --no-pager -n 400 2>/dev/null | grep -i -E 'HTTP/3 ON|WebTransport|signing|X25519|ML-KEM|listening|ignored|legacy path|DBSC|ledger|panic|ERROR' | tail -15 | cut -c1-220
echo "== 7 [K7 K7c DBSC] the audit ledger head and the device rows, counts only"
if [ -r "$ENVF" ]; then . "$ENVF"; if [ -n "${SUPABASE4_URL:-}" ] && [ -n "${SUPABASE4_SERVICE_ROLE_KEY:-}" ]; then
  for t in founder_devices founder_audit; do printf '   %-16s rows=%s\n' "$t" "$(curl -s -m 8 -I -H "apikey: $SUPABASE4_SERVICE_ROLE_KEY" -H "authorization: Bearer $SUPABASE4_SERVICE_ROLE_KEY" -H 'Prefer: count=exact' "$SUPABASE4_URL/rest/v1/$t?select=*&limit=1" | tr -d '\r' | awk -F/ 'tolower($1) ~ /content-range/ {print $2}')"; done; fi; fi
echo "OK read-only proof done. Paste this whole output to Claude."
