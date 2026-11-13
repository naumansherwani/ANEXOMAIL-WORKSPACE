#!/bin/bash
# KP2 (founder, 14 Nov 2026): UDP-BLOCKED NETWORK BREAK-GLASS, STEP 1 = READ-ONLY AUDIT. Changes NOTHING.
# Question it answers with measurements, not guesses: if a network blocks UDP (hotel, office, some mobile carriers), HTTP/3 cannot reach the site and tcp 443 is dropped for the founder host on purpose.
# The only way in is an SSH local forward to the loopback listener 127.0.0.1:3210. This checks: is 3210 loopback-only, does sshd allow forwarding, what the listener answers for Host localhost, what the sealed answers look like.
# usage: git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/kp2-audit.sh)
ok=1; stop(){ echo "STOP: $1"; ok=0; }
echo "== 1/5 who listens on 3210 (must be loopback only, owner anexomail-founder)"
ss -H -lntp 2>/dev/null | awk '$4 ~ /:3210$/ {print "   " $4}' | sort -u
ss -H -lnt 2>/dev/null | awk '$4 ~ /:3210$/ {print $4}' | grep -qvE '^(127\.0\.0\.1|\[::1\]):3210$' && stop "3210 is NOT loopback-only"
echo "== 2/5 sshd: port, forwarding, root login, password login (effective config)"
sshd -T 2>/dev/null | grep -E '^(port|allowtcpforwarding|permitrootlogin|passwordauthentication|pubkeyauthentication|permitopen|gatewayports) ' | sed 's/^/   /'
sshd -T 2>/dev/null | grep -qiE '^allowtcpforwarding (no|remote)' && stop "sshd forbids local forwarding (AllowTcpForwarding)"
sshd -T 2>/dev/null | grep -qiE '^gatewayports (yes|clientspecified)' && stop "GatewayPorts open: a forward could be exposed beyond loopback"
echo "== 3/5 ufw: ssh port and tcp 443 state (a UDP-blocked network still reaches tcp ssh)"
ufw status 2>/dev/null | grep -E '(^22|^Status|ssh)' | sed 's/^/   /'
echo "== 4/5 what the loopback listener answers (this is what a tunnelled browser would see)"
for p in /healthz / /founderlogin /founder/v1/me; do printf '   %-22s Host=localhost:3210 -> %s | Host=founderworkspace.anexomail.com -> %s\n' "$p" "$(curl -s -m 4 -o /dev/null -w '%{http_code}' -H 'Host: localhost:3210' http://127.0.0.1:3210$p)" "$(curl -s -m 4 -o /dev/null -w '%{http_code}' -H 'Host: founderworkspace.anexomail.com' http://127.0.0.1:3210$p)"; done
echo "== 5/5 response headers on / (CSP, HSTS, Alt-Svc: tell what a tunnelled browser will enforce)"
curl -s -m 4 -D - -o /dev/null -H 'Host: localhost:3210' http://127.0.0.1:3210/ | grep -iE '^(HTTP|content-security-policy|strict-transport|alt-svc|cross-origin|permissions-policy)' | cut -c1-220 | sed 's/^/   /'
[ $ok = 1 ] && echo "GO: the tunnel path exists. Next: his laptop test (ssh -L 3210:127.0.0.1:3210), measured, then the result goes into the contract." || echo "STOP: see lines above."
