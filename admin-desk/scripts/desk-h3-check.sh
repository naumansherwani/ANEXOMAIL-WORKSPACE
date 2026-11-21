#!/usr/bin/env bash
# ANEXOMAIL ADMIN DESK R3a0-s2 (21 Nov 2026): READ-ONLY proof that the Desk really answers HTTP/3 (QUIC). Changes nothing.
# His server curl has no HTTP/3, so the proof client is the Desk binary itself: `anexomail-desk h3check` offers ONLY X25519MLKEM768 + AES-256-GCM, trusts the Desk certificate, asks /desk/v1/health over HTTP/3.
H=admindesk.anexomail.com; B=/opt/anexomail-desk/anexomail-desk; C=/etc/anexomail/tls/desk/$H.crt; IP=$(ip -4 route get 1.1.1.1 2>/dev/null | sed -n 's/.* src \([0-9.]*\).*/\1/p')
echo "== 1/4 listener + journal"; ss -ulnp | grep -E "[:.]4400[[:space:]]" | sed 's/^/   /'; journalctl -u anexomail-desk --no-pager -n 40 | grep -E "HTTP/3" | tail -1 | sed 's/^/   /'
echo "== 2/4 firewall"; ufw status | grep -E "^4400/udp" | sed 's/^/   /'
echo "== 3/4 HTTP/3 proof (loopback, then the server public address)"
"$B" h3check 127.0.0.1:4400 $H $C 2>&1 | sed 's/^/   loopback: /'
[ -n "$IP" ] && "$B" h3check $IP:4400 $H $C 2>&1 | sed "s/^/   $IP: /"
echo "== 4/4 what a browser sees on the TCP side (the Alt-Svc lines)"; curl -sI --max-time 8 https://$H/ | grep -i -E "^alt-svc" | sed 's/^/   /'
