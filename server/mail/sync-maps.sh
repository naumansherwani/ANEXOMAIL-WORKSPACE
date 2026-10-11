#!/bin/bash
# Sync: DB ke mail_accounts / mailboxes -> Postfix vmailbox (sirf missing add; kuch delete nahi).
export PAGER=cat
V=${V:-/etc/postfix/vmailbox}
VA=${VA:-/etc/postfix/valias}
cp -a "$V" "$V.bak-$(date +%s)" && echo "BACKUP_OK"
psql "$WORKING_URL" -At -c "select lower(address) from mail_accounts union select lower(address) from mailboxes where box_type::text <> 'alias'" > /tmp/addrs.txt || { echo "DB_FAIL"; exit 1; }
added=0
while read -r a; do
  [[ "$a" =~ ^[a-z0-9._-]+@anexomail\.com$ ]] || continue
  postmap -q "$a" hash:$V >/dev/null 2>&1 && continue
  postmap -q "$a" hash:$VA >/dev/null 2>&1 && continue
  printf '%s  anexomail.com/%s/\n' "$a" "${a%@*}" >> "$V"
  echo "ADDED $a"
  added=$((added+1))
done < /tmp/addrs.txt
if [ "$added" -gt 0 ] && [ "$NO_RELOAD" != "1" ]; then
  postmap "$V" && postfix reload >/dev/null 2>&1 && echo "POSTFIX_RELOADED"
fi
echo "added=$added"
