#!/usr/bin/env bash
# Q1b-3 step 1 (founder mail intake ON): READ-ONLY preflight. Changes NOTHING (no listener, no Postfix, no env, no restart).
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/fmail-intake-check.sh)
# It reads the server itself (PORT RED LINE: fresh ss list first) and answers four questions:
#   1) which loopback port is free for the founder LMTP listener (must be absent from ss AND from the red-line file, below the ephemeral range 32768)
#   2) is ClamAV reachable (fail-closed scan needs it; without it intake would store "skipped")
#   3) what does Postfix do today with the founder address and its domain (awam mail shares anexomail.com, so ONLY a per-address transport entry is safe)
#   4) is the founder service already carrying FMAIL_LMTP_BIND
# Output ends with the exact next commands, none of them run here. Postfix changes need his "haan".
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"; ENVF=/etc/anexomail/founder.env; ADDR="${FOUNDER_MAIL_ADDR:-naumansherwani.founder@anexomail.com}"
say() { printf '%-5s %s\n' "$1" "$2"; }
echo "== 1) ports (fresh ss, process names)"; SS="$(ss -H -tulnp 2>/dev/null)"; echo "$SS" | awk '{print $1, $5, $7}' | sort -u | head -60
RED="$(git -C "$REPO" show origin/main:docs/claude/SERVER-PORTS-RED-LINE-08NOV.md 2>/dev/null)"
PORT=""; for p in 18025 18026 18027 18028 18029 18030; do
  echo "$SS" | awk '{print $5}' | grep -Eq "[:.]$p\$" && continue
  echo "$RED" | grep -Eq "(^|[^0-9])$p([^0-9]|\$)" && continue
  PORT=$p; break; done
[ -n "$PORT" ] && say OK "free loopback port for LMTP: 127.0.0.1:$PORT (absent from ss and from the red-line file, below 32768)" || say FAIL "no free candidate port 18025-18030; send me this output"
echo "== 2) ClamAV"; CL=""
for u in clamav-daemon clamd@scan clamd; do systemctl is-active --quiet "$u" 2>/dev/null && { say OK "service $u active"; CL="$u"; }; done
for s in /var/run/clamav/clamd.ctl /run/clamav/clamd.ctl /var/run/clamd.scan/clamd.sock; do [ -S "$s" ] && { say OK "clamd socket $s ($(stat -c %U:%G "$s"))"; SOCK="$s"; }; done
echo "$SS" | grep -E '127\.0\.0\.1:3310 .*clamd' | head -1 | grep -q . && say OK "clamd itself listens on 127.0.0.1:3310 (TCP): FMAIL_CLAMD=127.0.0.1:3310 (the socket is clamav-owned, the founder user cannot open it)"
[ -z "$CL" ] && say WARN "no clamd service active: intake would store scan='skipped'. Decide: install clamav-daemon first (recommended) or accept skipped (not advance, not recommended)"
echo "== 3) Postfix (read only)"
if command -v postconf >/dev/null 2>&1; then
  for k in myhostname mydestination virtual_mailbox_domains virtual_alias_domains virtual_transport transport_maps virtual_mailbox_maps virtual_alias_maps local_recipient_maps message_size_limit smtpd_milters; do printf '  %s = %s\n' "$k" "$(postconf -h "$k" 2>/dev/null)"; done
  say INFO "address lookup for $ADDR:"
  postmap -q "$ADDR" $(postconf -h transport_maps 2>/dev/null | sed 's/,/ /g') 2>/dev/null | sed 's/^/  transport: /'
  postmap -q "$ADDR" $(postconf -h virtual_alias_maps 2>/dev/null | sed 's/,/ /g') 2>/dev/null | sed 's/^/  alias: /'
  postmap -q "$ADDR" $(postconf -h virtual_mailbox_maps 2>/dev/null | sed 's/,/ /g') 2>/dev/null | sed 's/^/  mailbox: /'
else say WARN "postconf not found"; fi
echo "== 4) founder service"; if [ -r "$ENVF" ]; then grep -E '^FMAIL_(LMTP_BIND|CLAMD|SEND|SMTP_RELAY|SMTP_HELO)=' "$ENVF" | sed 's/^/  /' || true; grep -q '^FMAIL_LMTP_BIND=' "$ENVF" && say INFO "FMAIL_LMTP_BIND already set" || say INFO "FMAIL_LMTP_BIND not set (intake OFF)"; else say WARN "$ENVF unreadable (run as root)"; fi
journalctl -u anexomail-founder -n 400 --no-pager 2>/dev/null | grep -E "mail intake|mail sender" | tail -3 | sed 's/^/  /'
echo; echo "== NEXT (nothing above changed anything)"
echo "  a) send me this whole output"
echo "  b) I write fmail-intake-on.sh from it: env lines + restart + rollback (service only, Postfix untouched)"
echo "  c) only after your haan: one per-address Postfix transport entry for $ADDR -> lmtp:inet:127.0.0.1:${PORT:-PORT} (awam addresses untouched), with a rollback line"
