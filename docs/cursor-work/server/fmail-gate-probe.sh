#!/usr/bin/env bash
# READ-ONLY (16 Nov 05:58): call the DKIM send gate THE WAY THE RUST SENDER DOES (PostgREST rpc with the service role key) and print HTTP status, seconds and the first 300 chars of the answer.
# Why: psql says the gate is ok:true, but the sender got no answer. The key is read from founder.env and never printed. Changes nothing.
. /etc/anexomail/sync.env 2>/dev/null; U="$(grep -m1 '^SUPABASE4_URL=' /etc/anexomail/founder.env | cut -d= -f2-)"; K="$(grep -m1 '^SUPABASE4_SERVICE_ROLE_KEY=' /etc/anexomail/founder.env | cut -d= -f2-)"
[ -n "$U" ] && [ -n "$K" ] || { echo "FAIL: founder.env has no SUPABASE4 url/key"; exit 2; }
for M in $(psql "$WORKING_URL" -X -At -c "select id from public.fmail_mailboxes"); do
  echo "== mailbox ${M:0:8}"
  for FN in fmail_dkim_send_gate175 fmail_dkim_health175; do
    OUT="$(curl -s -m 12 -o /tmp/gp.$$ -w '%{http_code} %{time_total}s' -X POST "$U/rest/v1/rpc/$FN" -H "apikey: $K" -H "authorization: Bearer $K" -H 'content-type: application/json' -d "{\"p_mailbox\":\"$M\"}")"
    echo "  $FN -> HTTP/time $OUT"; head -c 300 /tmp/gp.$$ | tr -d '\n'; echo; rm -f /tmp/gp.$$
  done
done
echo "DONE: only read, nothing changed."
