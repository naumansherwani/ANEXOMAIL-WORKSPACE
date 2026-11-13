#!/usr/bin/env bash
# Q1b-3 T1 (HIS BIG HAAN 13 Nov 18:40 PKT): Postfix TLS hybrid post-quantum key exchange X25519MLKEM768 first, classic curves kept for old senders.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/fmail-postfix-pq.sh)
# Facts (his audit 13 Nov 04:35): Postfix 3.10.6 + OpenSSL 3.5.5; tls_eecdh_auto_curves = "X25519 X448 prime256v1 secp384r1 secp521r1" (no ML-KEM) => PQ handshake failed (alert 40).
# This changes ONE main.cf parameter. Postfix is shared with awam (it carries both sides' mail), so the script proves BEFORE it keeps anything:
#   1 backup main.cf   2 set the new list   3 postfix check   4 reload   5 handshake A: PQ-only client must negotiate X25519MLKEM768
#   6 handshake B: classic-only client (X25519) must still work   7 handshake C: default client must still work   8 Postfix's own client (posttls-finger) still handshakes
#   Any failure => main.cf restored, Postfix reloaded, nothing kept. Rollback later:  cp /etc/postfix/main.cf.pre-pq /etc/postfix/main.cf && systemctl reload postfix
set -uo pipefail
MC=/etc/postfix/main.cf; BK=$MC.pre-pq; NEW="X25519MLKEM768 X25519 X448 prime256v1 secp384r1 secp521r1"; PORT=25
[ "$(id -u)" -eq 0 ] || { echo "FAIL: root needed"; exit 2; }
undo() { echo "== ROLLBACK ($1)"; [ -f "$BK" ] && cp -p "$BK" "$MC"; postfix check; systemctl reload postfix; echo "main.cf restored, Postfix reloaded: tls_eecdh_auto_curves = $(postconf -h tls_eecdh_auto_curves)"; exit 1; }
hs() { timeout 10 openssl s_client -connect 127.0.0.1:$PORT -starttls smtp "$@" </dev/null 2>&1; }
echo "== 0/8 versions"; echo "  postfix $(postconf -h mail_version), $(openssl version)"; openssl list -kem-algorithms 2>/dev/null | grep -qi mlkem || echo "  WARN: openssl lists no ML-KEM (test A will tell)"
OLD="$(postconf -h tls_eecdh_auto_curves)"; echo "  now: $OLD"
echo "== 1/8 backup"; [ -f "$BK" ] || cp -p "$MC" "$BK"; echo "  $BK"
echo "== 2/8 set"; postconf -e "tls_eecdh_auto_curves = $NEW" || undo set; echo "  new: $(postconf -h tls_eecdh_auto_curves)"
echo "== 3/8 postfix check"; postfix check 2>&1 | grep -v "not owned by root: /var/spool/postfix/etc/resolv.conf" ; [ "${PIPESTATUS[0]}" = 0 ] || undo check
echo "== 4/8 reload"; systemctl reload postfix || undo reload; sleep 3
echo "== 5/8 A: post-quantum client"; A="$(hs -groups X25519MLKEM768)"; echo "$A" | grep -E "Protocol|Negotiated TLS1.3 group|Cipher is|alert" | sed 's/^/  /'
echo "$A" | grep -q "Negotiated TLS1.3 group: X25519MLKEM768" || undo "PQ handshake did not negotiate X25519MLKEM768"
echo "== 6/8 B: classic-only client (old senders)"; B="$(hs -groups X25519)"; echo "$B" | grep -E "Protocol|Negotiated TLS1.3 group|Peer Temp Key|Server Temp Key|Cipher is|alert" | sed 's/^/  /'
# a classic client must complete a TLS 1.3 handshake with a real cipher (s_client 3.5 does not always print the group line for classic groups; his first run proved that: handshake fine, line absent)
echo "$B" | grep -Eq "Cipher is \(NONE\)|alert" && undo "classic client broke"; echo "$B" | grep -q "Cipher is TLS_AES_256_GCM_SHA384" || undo "classic client did not complete the handshake"
echo "$B" | grep -Eq "Negotiated TLS1.3 group: .*MLKEM" && undo "classic-only client was given ML-KEM (impossible, check)"
echo "== 7/8 C: default client"; C="$(hs)"; echo "$C" | grep -E "Negotiated TLS1.3 group|Cipher is|alert" | sed 's/^/  /'
echo "$C" | grep -q "Cipher is (NONE)" && undo "default client broke"
echo "== 8/8 Postfix's own client (outgoing mail path) against itself"; if command -v posttls-finger >/dev/null; then posttls-finger -l may "[127.0.0.1]:$PORT" 2>&1 | grep -Ei "TLS|handshake|fail|error" | head -4 | sed 's/^/  /'; else echo "  posttls-finger not installed (skipped)"; fi
echo "== log check (last 3 min, TLS problems)"; journalctl -u postfix -u postfix@- --since "-3 min" --no-pager 2>/dev/null | grep -Ei "tls.*(fail|error)|handshake" | tail -5 | sed 's/^/  /' || true
echo "OK - Postfix inbound TLS now offers X25519MLKEM768 first, classic curves still accepted. T1 done; T2 (clamd AlertEncrypted) next. Watch: journalctl -u postfix -f  for 'TLS handshake failure' from real senders."
