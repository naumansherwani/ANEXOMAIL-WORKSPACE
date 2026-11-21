#!/usr/bin/env bash
# ANEXOMAIL ADMIN DESK RESTART + LOAD (his 21 Nov 2026 21:42: the third and last allowed Desk command). Restarts the Desk with what is installed, then checks health, host gate and the database door. Builds nothing, changes no file.
SVC=anexomail-desk; H='Host: admindesk.anexomail.com'
systemctl restart $SVC; sleep 3
echo "service: $(systemctl is-active $SVC)"
echo "health: $(curl -s -o /dev/null -w '%{http_code}' -H "$H" http://127.0.0.1:4400/desk/v1/health) (want 200); wrong host: $(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:4400/desk/v1/health) (want 404)"
echo "door: $(curl -s -o /dev/null -w '%{http_code}' -H "$H" -H 'x-desk-nonce: 00112233445566778899aabbccddeeff' http://127.0.0.1:4400/desk/v1/auth/me) (want 401 = alive, no session)"
journalctl -u $SVC --since '-20s' --no-pager 2>/dev/null | grep -E 'desk door|HTTP/3' | tail -3
echo "== DNS facts (read only): what browsers are told for HTTP/3"
for h in admindesk.anexomail.com anexomail.com founderworkspace.anexomail.com; do echo "$h A=$(dig +short A $h | tr '\n' ' ') AAAA=$(dig +short AAAA $h | tr '\n' ' ') HTTPS=$(dig +short TYPE65 $h | tr '\n' ' ')"; done
echo "server IPv6: $(ip -6 -o addr show scope global 2>/dev/null | awk '{print $4}' | tr '\n' ' ')"
echo "IPv6 listeners 443/4400: $(ss -6 -H -lntup 2>/dev/null | grep -E ':(443|4400) ' | awk '{print $1, $5}' | tr '\n' ';')"
