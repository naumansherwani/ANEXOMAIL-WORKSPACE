#!/bin/bash
. /etc/anexomail/sync.env
export PAGER=cat
V=${V:-/etc/postfix/vmailbox}
VA=${VA:-/etc/postfix/valias}
psql "$WORKING_URL" -At -c "select lower(address) from mail_accounts union select lower(address) from mailboxes where box_type::text <> 'alias'" > /tmp/sync-addrs.txt || { echo "$(date -u +%FT%TZ) DB_FAIL"; exit 1; }
: > /tmp/sync-missing.txt
while read -r a; do
  [[ "$a" =~ ^[a-z0-9._-]+@anexomail\.com$ ]] || continue
  postmap -q "$a" hash:$V >/dev/null 2>&1 && continue
  postmap -q "$a" hash:$VA >/dev/null 2>&1 && continue
  echo "$a" >> /tmp/sync-missing.txt
done < /tmp/sync-addrs.txt
[ -s /tmp/sync-missing.txt ] || exit 0
cp -a "$V" "$V.bak-$(date +%s)"
while read -r a; do
  printf '%s  anexomail.com/%s/\n' "$a" "${a%@*}" >> "$V"
  echo "$(date -u +%FT%TZ) ADDED $a"
done < /tmp/sync-missing.txt
if [ "$NO_RELOAD" != "1" ]; then postmap "$V" && postfix reload >/dev/null 2>&1 && echo "$(date -u +%FT%TZ) POSTFIX_RELOADED"; fi
