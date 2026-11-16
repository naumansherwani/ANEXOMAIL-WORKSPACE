#!/usr/bin/env bash
# READ-ONLY (16 Nov 05:50): why did a mail in the Outbox fail? Prints the last outbox rows (state, attempts, error, smtp reply, tls, dkim) + sender journal lines. Changes nothing, prints no secret, no recipient.
ENV_FILE="${ENV_FILE:-/etc/anexomail/sync.env}"; . "$ENV_FILE" 2>/dev/null
echo "== 1/2 outbox rows (newest 5)"
psql "$WORKING_URL" -X -A -t -F ' | ' -c "select state, attempts, to_char(next_attempt at time zone 'Asia/Karachi','HH24:MI:SS') as next_try, coalesce(tls_out,'-') tls, dkim_signed, coalesce(left(last_error,160),'-') err, coalesce(left(smtp_reply,120),'-') reply from public.fmail_outbox order by created_at desc limit 5" 2>&1 | head -8
echo "== 2/2 sender journal (last 30 min)"
journalctl -u anexomail-founder --since '30 min ago' --no-pager 2>/dev/null | grep -iE 'mail send|smtp|dkim|outbox|sender' | sed 's/^.*anexomail-founder\[[0-9]*\]: //' | tail -12 | cut -c1-240
echo "DONE: only read, nothing changed."
