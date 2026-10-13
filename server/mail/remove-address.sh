#!/bin/bash
# ANEXOMAIL E24 — deleted account ke mail addresses Postfix se hatao.
#
# WAJAH: install-sync-maps-cron.sh ka cron sirf ADD karta hai, kabhi hata nahi
# karta. account_purge() DB se address hata deta hai, lekin Postfix vmailbox mein
# woh line reh jati hai aur us address ki mail Maildir mein jama hoti rehti hai.
#
# Use (account_purge ke report ki "mail_addresses" se):
#   bash server/mail/remove-address.sh a@anexomail.com [b@...]            # DRY-RUN
#   bash server/mail/remove-address.sh --apply a@anexomail.com [b@...]    # asli
#
# Kya karta hai (--apply):
#   * vmailbox / valias ki backup (.bak-<stamp>), phir sirf us address ki line hatati hai
#   * postmap + postfix reload
#   * Maildir DELETE nahi karta — <virtual_mailbox_base>/_deleted/ mein MOVE karta hai
# Refuse karta hai agar address abhi DB (mail_accounts / mailboxes) mein maujood hai.
# Company-domain ke addresses ke liye bhi chalta hai agar woh isi vmailbox/valias mein hon;
# Postfix ke virtual DOMAIN list ko yeh haath nahi lagata.
# Dovecot ka alag userdb/passdb ho to woh yahan nahi hatta.
export PAGER=cat
V=${V:-/etc/postfix/vmailbox}
VA=${VA:-/etc/postfix/valias}
ENVF=${ENVF:-/etc/anexomail/sync.env}

APPLY=0
if [ "$1" = "--apply" ]; then APPLY=1; shift; fi
if [ $# -lt 1 ]; then
  echo "usage: bash $0 [--apply] address [address ...]   (default = DRY-RUN)"
  exit 2
fi

[ -f "$ENVF" ] && . "$ENVF"
BASE=${MAILBASE:-$(postconf -h virtual_mailbox_base 2>/dev/null)}
STAMP=$(date +%Y%m%d-%H%M%S)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

if [ "$APPLY" = "1" ] && [ -z "$WORKING_URL" ]; then
  echo "STOP: WORKING_URL set nahi ($ENVF) — DB check ke baghair --apply nahi chalta"
  exit 1
fi

removed=0
rc=0
for raw in "$@"; do
  a=$(printf '%s' "$raw" | tr 'A-Z' 'a-z')
  if ! [[ "$a" =~ ^[a-z0-9._+-]+@[a-z0-9.-]+\.[a-z]{2,}$ ]]; then
    echo "SKIP $raw — address ki shakal theek nahi"; rc=1; continue
  fi

  # 1) DB mein abhi bhi hai? to haath nahi lagate
  if [ -n "$WORKING_URL" ]; then
    n=$(psql "$WORKING_URL" -At -c "select (select count(*) from mail_accounts where lower(address)='$a') + (select count(*) from mailboxes where lower(address)='$a')" 2>/dev/null)
    if [ -z "$n" ]; then echo "STOP $a — DB check fail (psql)"; rc=1; continue; fi
    if [ "$n" != "0" ]; then echo "SKIP $a — DB mein abhi maujood hai ($n row). Pehle account_purge chalao."; rc=1; continue; fi
  else
    echo "NOTE $a — WORKING_URL nahi, DB check skip (sirf dry-run mein)"
  fi

  # 2) Postfix lines
  in_v=$(awk -v a="$a" '$1==a' "$V" 2>/dev/null)
  in_va=$(awk -v a="$a" '$1==a' "$VA" 2>/dev/null)
  if [ -z "$in_v" ] && [ -z "$in_va" ]; then echo "NONE $a — vmailbox/valias mein hai hi nahi"; continue; fi
  [ -n "$in_v" ] && echo "FOUND vmailbox: $in_v"
  [ -n "$in_va" ] && echo "FOUND valias:   $in_va"

  # 3) Maildir
  box=$(printf '%s\n' "$in_v" | awk 'NR==1{print $2}')
  dir=""
  if [ -n "$box" ] && [ -n "$BASE" ]; then
    case "$box" in /*) dir="${box%/}" ;; *) dir="${BASE%/}/${box%/}" ;; esac
    case "$dir" in "${BASE%/}"/?*) : ;; *) echo "SKIP maildir $dir — virtual_mailbox_base ke andar nahi"; dir="" ;; esac
  fi
  [ -n "$dir" ] && { if [ -d "$dir" ]; then echo "FOUND maildir:  $dir -> ${BASE%/}/_deleted/"; else echo "NOTE maildir nahi mila: $dir"; dir=""; fi; }

  if [ "$APPLY" != "1" ]; then echo "DRY-RUN $a — kuch badla nahi (--apply se asli)"; continue; fi

  for f in "$V" "$VA"; do
    [ -f "$f" ] || continue
    awk -v a="$a" '$1==a{f=1} END{exit f?0:1}' "$f" || continue
    [ -f "$TMP/backed.$(basename "$f")" ] || { cp -a "$f" "$f.bak-$STAMP" && : > "$TMP/backed.$(basename "$f")"; }
    awk -v a="$a" '$1!=a' "$f" > "$TMP/new" && cat "$TMP/new" > "$f"
    touch "$TMP/changed.$(basename "$f")"
    echo "$(date -u +%FT%TZ) REMOVED $a from $f"
  done
  if [ -n "$dir" ]; then
    mkdir -p "${BASE%/}/_deleted" && mv "$dir" "${BASE%/}/_deleted/$(basename "$dir")-$STAMP" \
      && echo "$(date -u +%FT%TZ) MAILDIR_MOVED $dir"
  fi
  removed=$((removed + 1))
done

if [ "$APPLY" = "1" ] && [ "$removed" -gt 0 ]; then
  [ -f "$TMP/changed.$(basename "$V")" ]  && postmap "$V"
  [ -f "$TMP/changed.$(basename "$VA")" ] && postmap "$VA"
  if [ "$NO_RELOAD" != "1" ]; then postfix reload >/dev/null 2>&1 && echo "$(date -u +%FT%TZ) POSTFIX_RELOADED"; fi
fi
exit $rc
