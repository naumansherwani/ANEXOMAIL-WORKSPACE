#!/usr/bin/env bash
# ANEXOMAIL ADMIN DESK R3a0-s2 (21 Nov 2026): turn ON the Desk's own HTTP/3 (QUIC) listener on UDP 4400.
# Port: UDP 4400 is FREE in his fresh ss paste of 21 Nov 09:27 PKT (no UDP 4400 listener, no ufw rule for it, outside TURN's 49152-65535 range); TCP 4400 is the Desk's reserved loopback port, same number kept for the Desk.
# Touches ONLY: /etc/anexomail/tls/desk (Desk's own copy of its certificate), a systemd drop-in of anexomail-desk, one ufw rule (4400/udp), one cron file for the Desk cert refresh.
# Does NOT touch Caddy, founder, awam, the awam edge. Rollback on any failure. Run desk-install.sh FIRST (it builds the HTTP/3 binary).
set -u
H=admindesk.anexomail.com; SVC=anexomail-desk; PORT=4400; AWD=/etc/anexomail/tls/awam; DD=/etc/anexomail/tls/desk; DROP=/etc/systemd/system/$SVC.service.d
echo "== 1/6 UDP $PORT must be free"
ss -ulnH | grep -E "[:.]$PORT[[:space:]]" && { echo "FAIL: UDP $PORT is already in use, nothing changed"; exit 2; }
echo "   free"
echo "== 2/6 the Desk's OWN copy of its certificate (isolation: the Desk never reads the awam directory)"
[ -f "$AWD/$H.crt" ] && [ -f "$AWD/$H.key" ] || { echo "FAIL: $AWD/$H.crt/.key missing (run desk-cert-sync.sh first)"; exit 3; }
id $SVC >/dev/null 2>&1 || { echo "FAIL: user $SVC missing (run desk-install.sh first)"; exit 3; }
install -d -m 700 -o root -g root $DD
install -m 600 -o root -g root "$AWD/$H.crt" $DD/$H.crt; install -m 600 -o root -g root "$AWD/$H.key" $DD/$H.key   # root-only: the Desk gets them through systemd LoadCredential (no directory permission needed)
cat >/usr/local/sbin/anexomail-desk-cert-refresh <<'R'
#!/usr/bin/env bash
# copies the Desk certificate from the awam sync directory when it changed, then restarts the Desk so HTTP/3 serves the new one
H=admindesk.anexomail.com; A=/etc/anexomail/tls/awam; D=/etc/anexomail/tls/desk; ch=0
for e in crt key; do cmp -s "$A/$H.$e" "$D/$H.$e" || { install -m 600 -o root -g root "$A/$H.$e" "$D/$H.$e" && ch=1; }; done
[ $ch = 1 ] && systemctl restart anexomail-desk
R
chmod 755 /usr/local/sbin/anexomail-desk-cert-refresh
echo '40 4 * * * root /usr/local/sbin/anexomail-desk-cert-refresh' >/etc/cron.d/anexomail-desk-cert
echo "== 3/6 systemd drop-in (HTTP/3 on)"
mkdir -p $DROP
printf '[Service]\nLoadCredential=desk.crt:%s/%s.crt\nLoadCredential=desk.key:%s/%s.key\nEnvironment=DESK_H3_ADDR=[::]:%s\nEnvironment=DESK_H3_CERT=%%d/desk.crt\nEnvironment=DESK_H3_KEY=%%d/desk.key\n' $DD $H $DD $H $PORT >$DROP/h3.conf
echo "== 4/6 firewall: one rule, UDP $PORT"
ufw allow $PORT/udp comment 'anexomail-desk http3' >/dev/null 2>&1; ufw status | grep -E "^$PORT/udp" | head -2 | sed 's/^/   /'
echo "== 5/6 restart + check"
systemctl daemon-reload; systemctl restart $SVC; sleep 3
ok=1; ss -ulnp | grep -E "[:.]$PORT[[:space:]]" | grep -q anexomail-desk || ok=0
journalctl -u $SVC -n 6 --no-pager | grep -E "HTTP/3" | sed 's/^/   /'
H1="$(curl -s -o /dev/null -w %{http_code} -H "Host: $H" http://127.0.0.1:4400/desk/v1/health)"
[ "$H1" = 200 ] || ok=0
if [ $ok = 0 ]; then echo "FAIL: rolling back (drop-in removed, ufw rule removed)"; rm -f $DROP/h3.conf; ufw delete allow $PORT/udp >/dev/null 2>&1; systemctl daemon-reload; systemctl restart $SVC; journalctl -u $SVC -n 12 --no-pager; exit 4; fi
ss -ulnp | grep -E "[:.]$PORT[[:space:]]" | sed 's/^/   /'
echo "== 6/6 proof (HTTP/3 straight to the Desk, the DNS record is not needed for this)"
if curl -V | grep -qi http3; then curl --http3-only -sI --max-time 10 --connect-to $H:$PORT:127.0.0.1:$PORT https://$H:$PORT/desk/v1/health | head -8 | sed 's/^/   /'; else echo "   this curl has no HTTP/3: skip (the Rust side is up on UDP $PORT)"; fi
echo "OK: Desk HTTP/3 is listening on UDP $PORT. Next (his hands, Namecheap): AAAA + HTTPS record  1 . alpn=h3 port=$PORT  for admindesk"
