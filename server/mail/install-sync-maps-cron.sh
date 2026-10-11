#!/bin/bash
# Installs auto-sync: DB mailbox addresses -> Postfix vmailbox, every minute (cron). Add-only, backup only on change.
export PAGER=cat
BIN=${BIN:-/usr/local/bin/anexomail-sync-maps.sh}
ENVF=${ENVF:-/etc/anexomail/sync.env}
CRON=${CRON:-/etc/cron.d/anexomail-sync-maps}
[ -n "$WORKING_URL" ] || { echo "STOP: WORKING_URL is terminal mein set nahi"; exit 1; }
mkdir -p "$(dirname "$ENVF")"
( umask 077; printf 'export WORKING_URL=%q\n' "$WORKING_URL" > "$ENVF" )
chmod 600 "$ENVF" && echo "ENV_FILE_OK (600, URL print nahi hota)"

cat > "$BIN" <<'EOS'
#!/bin/bash
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
EOS
chmod 755 "$BIN" && bash -n "$BIN" && echo "SCRIPT_OK $BIN"

printf '* * * * * root . %s && /usr/bin/flock -n /var/lock/anexomail-sync.lock %s >> /var/log/anexomail-sync-maps.log 2>&1\n' "$ENVF" "$BIN" > "$CRON"
chmod 644 "$CRON" && echo "CRON_OK $CRON"
. "$ENVF" && "$BIN"; echo "FIRST_RUN_EXIT=$?"
