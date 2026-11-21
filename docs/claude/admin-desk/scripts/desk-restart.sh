#!/usr/bin/env bash
# ANEXOMAIL ADMIN DESK RESTART + LOAD (his 21 Nov 2026 21:42: the third and last allowed Desk command). Restarts the Desk with what is installed, then checks health, host gate and the database door. Builds nothing, changes no file.
SVC=anexomail-desk; H='Host: admindesk.anexomail.com'
systemctl restart $SVC; sleep 3
echo "service: $(systemctl is-active $SVC)"
echo "health: $(curl -s -o /dev/null -w '%{http_code}' -H "$H" http://127.0.0.1:4400/desk/v1/health) (want 200); wrong host: $(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:4400/desk/v1/health) (want 404)"
echo "door: $(curl -s -o /dev/null -w '%{http_code}' -H "$H" http://127.0.0.1:4400/desk/v1/auth/me) (want 401 = alive, no session)"
journalctl -u $SVC --since '-20s' --no-pager 2>/dev/null | grep -E 'desk door|HTTP/3' | tail -3
