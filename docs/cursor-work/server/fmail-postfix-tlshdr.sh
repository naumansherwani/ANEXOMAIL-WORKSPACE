#!/usr/bin/env bash
# Q1b4 e (his 17 Nov 04:57 paste: smtpd_tls_received_header = no, smtpd_tls_loglevel = 0): Postfix does not write the TLS facts into the Received header, so the trust ring can only say "TLS not recorded".
# This changes ONE main.cf parameter: smtpd_tls_received_header = yes. Postfix then adds "(using TLSv1.3 with cipher ... key-exchange X25519MLKEM768 ...)" to the Received line of every mail it receives; the Rust verifier reads it.
# Postfix carries both sides' mail, so it proves before it keeps: backup, set, postfix check, reload, a real local handshake still works. Any failure restores main.cf and reloads.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/fmail-postfix-tlshdr.sh) 2>&1 | tail -15
# Rollback later: cp /etc/postfix/main.cf.pre-tlshdr /etc/postfix/main.cf && systemctl reload postfix
set -uo pipefail
MC=/etc/postfix/main.cf; BK=$MC.pre-tlshdr
[ "$(id -u)" -eq 0 ] || { echo "FAIL: root needed"; exit 2; }
undo() { echo "== ROLLBACK ($1)"; [ -f "$BK" ] && cp -p "$BK" "$MC"; postfix check; systemctl reload postfix; echo "main.cf restored: smtpd_tls_received_header = $(postconf -h smtpd_tls_received_header)"; exit 1; }
echo "== 1/4 now: smtpd_tls_received_header = $(postconf -h smtpd_tls_received_header)"; [ -f "$BK" ] || cp -p "$MC" "$BK"; echo "   backup $BK"
echo "== 2/4 set"; postconf -e "smtpd_tls_received_header = yes" || undo set
echo "== 3/4 postfix check + reload"; postfix check 2>&1 | grep -v "not owned by root: /var/spool/postfix/etc/resolv.conf"; [ "${PIPESTATUS[0]}" = 0 ] || undo check; systemctl reload postfix || undo reload; sleep 2
echo "== 4/4 a real handshake still works"; H="$(timeout 10 openssl s_client -connect 127.0.0.1:25 -starttls smtp </dev/null 2>&1)"; echo "$H" | grep -E "Protocol|Cipher is|alert" | sed 's/^/   /'
echo "$H" | grep -q "Cipher is TLS_AES_256_GCM_SHA384" || undo "handshake did not complete"
echo "OK - smtpd_tls_received_header = $(postconf -h smtpd_tls_received_header). The NEXT mail that arrives over TLS carries its TLS facts; send one from Gmail and the ring shows TLS."
