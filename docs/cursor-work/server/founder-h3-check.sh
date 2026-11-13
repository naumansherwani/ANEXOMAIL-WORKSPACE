#!/bin/bash
# K8e READ-ONLY CHECK (his order 13 Nov 20:30: HTTP/1.1 and h2 are gone, HTTP/3 only). Changes NOTHING. Run it BEFORE the install that removes tcp 443.
# It says GO / STOP so the founder cannot lock himself out: H3-only needs (1) UDP 443 really owned by anexomail-founder, (2) the DNS HTTPS record alpn=h3, (3) the firewall open for UDP 443.
H=founderworkspace.anexomail.com; ok=1
echo "== 1/4 UDP 443 listener (who owns it)"; ss -lunp 2>/dev/null | grep -E ':443\b' | head -3 || true
ss -lunp 2>/dev/null | grep -E ':443\b' | grep -q anexomail-founder && echo "OK: anexomail-founder owns udp 443" || { echo "STOP: udp 443 is NOT owned by anexomail-founder"; ok=0; }
echo "== 2/4 service says HTTP/3 ON"; journalctl -u anexomail-founder -n 400 --no-pager 2>/dev/null | grep -o "founder: HTTP/3 ON udp [^ ]*" | tail -1 || true
journalctl -u anexomail-founder -n 400 --no-pager 2>/dev/null | grep -q "founder: HTTP/3 ON" && echo "OK" || { echo "STOP: no 'HTTP/3 ON' line in the journal"; ok=0; }
echo "== 3/4 DNS HTTPS record (RFC 9460) must contain alpn=h3"
R="$( (dig +short HTTPS $H 2>/dev/null || host -t type65 $H 2>/dev/null) | head -3)"; echo "${R:-<none>}"
echo "$R" | grep -qi 'h3' && echo "OK: the HTTPS record names h3" || { echo "STOP: no HTTPS record with alpn=h3 for $H. Add at your DNS: $H HTTPS 1 . alpn=\"h3\""; ok=0; }
echo "== 4/4 firewall for UDP 443"; (ufw status 2>/dev/null | grep -E '443' | head -4; iptables -S 2>/dev/null | grep -E 'udp.*443' | head -3) || true
[ "$ok" = 1 ] && echo "GO: h3-only install is safe to run" || echo "STOP: do not run the h3-only install yet (rollback exists: fmail-ui-rollback.sh)"
