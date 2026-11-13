#!/usr/bin/env bash
# Q1b-3 T3 helper (READ-ONLY): did the real test mail reach the founder intake? Run it BEFORE (state) and AFTER sending one mail from his other address.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/fmail-intake-watch.sh)
# Shows: 1) founder LMTP listener + intake lines in the journal (still ON after every install?) 2) Postfix delivery lines for the founder address (relay=127.0.0.1[127.0.0.1]:18025, status=sent/deferred/bounced)
#        3) the Postfix inbound TLS line of the sender (does the sending server use TLS, which group) 4) clamd answers in the last minutes. Changes nothing.
set -uo pipefail
ADDR="${FOUNDER_MAIL_ADDR:-naumansherwani.founder@anexomail.com}"
echo "== 1) founder intake"; ss -H -tlnp | grep "127.0.0.1:18025" | sed 's/^/  /' || echo "  NOT listening on 127.0.0.1:18025 (intake OFF: run fmail-intake-on.sh)"
journalctl -u anexomail-founder --no-pager 2>/dev/null | grep -E "mail intake" | tail -2 | sed 's/^/  /'
echo "== 2) Postfix lines for $ADDR (last 30 min)"
LOG=/var/log/mail.log; if [ -r "$LOG" ]; then grep -F "$ADDR" "$LOG" | tail -6 | cut -c1-260 | sed 's/^/  /'; else journalctl -u postfix --since "-30 min" --no-pager 2>/dev/null | grep -F "$ADDR" | tail -6 | cut -c1-260 | sed 's/^/  /'; fi
echo "  delivery results to the founder LMTP:"; { [ -r "$LOG" ] && grep -E "relay=127\.0\.0\.1\[127\.0\.0\.1\]:18025" "$LOG" || journalctl -u postfix --since "-30 min" --no-pager 2>/dev/null | grep -E "relay=127\.0\.0\.1\[127\.0\.0\.1\]:18025"; } | tail -4 | cut -c1-300 | sed 's/^/    /'
echo "== 3) sender TLS (inbound smtpd)"; { [ -r "$LOG" ] && grep -E "TLS connection established from" "$LOG" || journalctl -u postfix --since "-30 min" --no-pager 2>/dev/null | grep -E "TLS connection established from"; } | tail -4 | cut -c1-260 | sed 's/^/  /'
echo "== 4) founder service last lines"; journalctl -u anexomail-founder -n 8 --no-pager 2>/dev/null | cut -c1-240 | sed 's/^/  /'
echo "READ: status=sent (250 2.0.0 stored) = the mail is sealed in the founder Inbox; status=deferred = founder service said 451/connection problem (Postfix retries, nothing lost); no line = the mail did not reach Postfix yet."
