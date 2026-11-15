#!/usr/bin/env bash
# READ-ONLY (Q1d-1a, his 16 Nov 03:46 order: "namecheap ka command chat pe do, server se copy hoga").
# Prints, for every ACTIVE DKIM key of every founder mailbox, the exact DNS TXT record to paste at the DNS provider (host + value), then who answers DNS for the domain
# and what DNS answers right now for each record (so he sees "paste hua ya nahi"). Writes nothing: the database session is read-only, no DNS change is made here.
ENV_FILE="${ENV_FILE:-/etc/anexomail/sync.env}"
[ -f "$ENV_FILE" ] && set -a && . "$ENV_FILE" && set +a
[ -n "${WORKING_URL:-}" ] || { echo "FAIL: WORKING_URL nahi mila ($ENV_FILE)"; exit 2; }
command -v psql >/dev/null || { echo "FAIL: psql nahi mila"; exit 2; }
ROWS="$(PGOPTIONS='-c default_transaction_read_only=on' psql "$WORKING_URL" -X -At -F '|' -c "select split_part(m.address,'@',2), k.selector, k.alg, 'v=DKIM1; k=' || case when k.alg = 'ed25519-sha256' then 'ed25519' else 'rsa' end || '; p=' || public.fmail_b64_169(k.public_key) from public.fmail_dkim_keys k join public.fmail_mailboxes m on m.id = k.mailbox_id where k.status = 'active' order by m.address, k.created_at" 2>&1)"
case "$ROWS" in ERROR*|psql:*|*FATAL*) echo "FAIL: $ROWS"; exit 3;; esac
[ -n "$ROWS" ] || { echo "Abhi koi active DKIM key nahi: pehle Systems > Mail signing mein New Ed25519 key / New RSA-2048 key (touch)."; exit 0; }
look() { if command -v dig >/dev/null; then dig +short "$@" 2>&1; elif command -v host >/dev/null; then host -t "$1" "$2" 2>&1; else echo "(dig/host nahi)"; fi; }
DOMS=""
echo "== PASTE HONE WALE TXT RECORDS (Type = TXT; Host = sirf pehla hissa, domain khud lagta hai)"
while IFS='|' read -r dom sel alg val; do
  echo
  echo "KEY $sel ($alg)"
  echo "  Host : ${sel}._domainkey"
  echo "  Type : TXT"
  echo "  Value: ${val}"
  case " $DOMS " in *" $dom "*) ;; *) DOMS="$DOMS $dom";; esac
done <<< "$ROWS"
echo
echo "== DNS ABHI KYA JAWAB DETA HAI (khali = abhi paste nahi hua ya DNS ne abhi nahi uthaya)"
for dom in $DOMS; do
  echo "Domain $dom: nameservers:"; look NS "$dom" | sed 's/^/  /'
  while IFS='|' read -r d sel alg val; do
    [ "$d" = "$dom" ] || continue
    r="$(look TXT "${sel}._domainkey.${dom}")"
    if [ "$r" = "(dig/host nahi)" ]; then echo "  $sel._domainkey: (is server par dig/host nahi, Systems mein Check DNS dabayein)"
    elif [ -z "$r" ]; then echo "  $sel._domainkey: KHALI (paste nahi hua)"; else echo "  $sel._domainkey: ${r:0:70}... ($(printf %s "$r" | tr -d ' "' | grep -c "p=${val##*p=}") match)"; fi
  done <<< "$ROWS"
done
echo "DONE: sirf padha, kuch badla nahi."
