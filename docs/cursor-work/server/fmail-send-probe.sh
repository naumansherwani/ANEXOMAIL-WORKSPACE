#!/usr/bin/env bash
# Q1d-2a: READ-ONLY proof of the OUTGOING mail path before the sender is switched on. Changes nothing, sends no mail.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/fmail-send-probe.sh) 2>&1 | tail -30
# Shows: 1) is outbound port 25 open from this server (many hosts block it), 2) does the receiver offer STARTTLS and which TLS version, cipher and key exchange group is negotiated
# (the founder law is TLS 1.3 with X25519MLKEM768 where the receiver supports it), 3) is a loopback relay (Postfix on 127.0.0.1:25) there, 4) the PTR (reverse DNS) of this server,
# 5) whether the sender is already ON. Every step has a timeout; nothing is written.
set -uo pipefail
MX="${1:-gmail-smtp-in.l.google.com}"
echo "== 1/5 outbound port 25 to $MX"
if timeout 8 bash -c "exec 3<>/dev/tcp/$MX/25 && head -c 60 <&3" 2>/dev/null | head -1 | grep -q '^220'; then echo "OPEN: $MX answered 220"; P25=open; else echo "BLOCKED or no answer: direct delivery is not possible from here, a loopback relay is needed"; P25=blocked; fi
echo "== 2/5 STARTTLS to $MX (TLS 1.3 asked, X25519MLKEM768 offered first)"
if [ "$P25" = open ] && command -v openssl >/dev/null; then
  echo "openssl: $(openssl version)"
  O="$(echo | timeout 15 openssl s_client -connect "$MX:25" -starttls smtp -tls1_3 -groups X25519MLKEM768:X25519 -brief 2>&1 | head -14)"; echo "$O" | grep -Ei "protocol|ciphersuite|negotiated|temp key|group|verification|error" | sed 's/^/  /'
else echo "skipped (port 25 blocked or openssl missing)"; fi
echo "== 3/5 loopback relay on 127.0.0.1:25"
ss -H -tlnp 2>/dev/null | grep -E '127\.0\.0\.1:25\b' | sed 's/^/  /' || true; ss -H -tln 2>/dev/null | grep -Eq '127\.0\.0\.1:25\b' && echo "relay present" || echo "no loopback relay on 25"
echo "== 4/5 PTR (reverse DNS) of this server"
IP="$(curl -s -m 5 https://api.ipify.org 2>/dev/null || true)"; echo "  public ip: ${IP:-unknown}"; if [ -n "$IP" ]; then (command -v dig >/dev/null && dig +short -x "$IP" | head -2 | sed 's/^/  PTR: /') || (command -v host >/dev/null && host "$IP" | head -2 | sed 's/^/  /') || echo "  (no dig/host)"; fi
echo "== 5/5 sender state"
grep -E '^FMAIL_SEND=|^FMAIL_SMTP_RELAY=|^FMAIL_SMTP_HELO=' /etc/anexomail/founder.env 2>/dev/null | sed 's/^/  /' || true; journalctl -u anexomail-founder --no-pager -n 400 2>/dev/null | grep -E "mail sender" | tail -2 | sed 's/^/  /'
echo "DONE: only read, nothing changed, no mail sent."
