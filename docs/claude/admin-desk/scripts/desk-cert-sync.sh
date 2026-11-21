#!/usr/bin/env bash
# ANEXOMAIL ADMIN DESK: give the awam AES-256 edge the Desk's certificate NOW (21 Nov 2026, root cause of "admindesk does not open").
# Cause: public TCP 443 -> founder SNI front -> every non-founder name -> awam-edge (TLS 1.3 AES-256 terminator) -> Caddy. The edge only serves names whose certificate it has
# in /etc/anexomail/tls/awam; that directory is refilled by /usr/local/sbin/anexomail-awam-certs-sync once a day (04:27) and re-read every 10 minutes. Caddy got the Desk certificate at 07:51 PKT
# (02:51 UTC), so the edge answered "access denied" for the new name. This script runs that SAME existing sync once, then waits (max 11 min) until the edge serves the host.
# Touches: only the certificate copy directory via the existing sync script. Does NOT restart any service, does NOT touch Caddy, ufw, founder or awam code.
set -u
SYNC=/usr/local/sbin/anexomail-awam-certs-sync; AWD=/etc/anexomail/tls/awam; H=admindesk.anexomail.com
[ -x "$SYNC" ] || { echo "FAIL: $SYNC not found (awam edge not installed?)"; exit 2; }
echo "== 1/3 run the existing certificate sync"; "$SYNC" 2>&1 | tail -3
ls -l "$AWD/$H.crt" "$AWD/$H.key" 2>&1 | sed 's/^/   /'
[ -f "$AWD/$H.crt" ] && [ -f "$AWD/$H.key" ] || { echo "FAIL: the sync did not copy the Desk certificate (is it under /var/lib/caddy/.local/share/caddy/certificates?)"; find /var/lib/caddy -name "$H.crt" 2>/dev/null | sed 's/^/   caddy has: /'; exit 3; }
echo "== 2/3 wait for the edge to re-read its directory (it does every 10 minutes; max 11 min)"
for i in $(seq 1 33); do
  C="$(curl -s -o /dev/null -w %{http_code} --max-time 6 https://$H/desk/v1/health 2>/dev/null)"
  [ "$C" != 000 ] && { echo "   after $((i*20-20))s: HTTPS answers $C"; break; }
  sleep 20
done
echo "== 3/3 what the browser will get"
curl -sI --max-time 8 https://$H/ | head -8 | sed 's/^/   /'
echo | openssl s_client -connect $H:443 -servername $H 2>/dev/null | grep -E "Protocol|Cipher|Verification|Verify return" | sed 's/^/   /'
echo "   health: $(curl -s --max-time 8 https://$H/desk/v1/health)"
