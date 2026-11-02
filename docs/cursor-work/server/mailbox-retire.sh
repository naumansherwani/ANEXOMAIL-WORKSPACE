#!/usr/bin/env bash
# ANEXOMAIL — retire the MAIL-SERVER mailboxes of the two deleted test accounts (basic.test@ and alikhan@; their database rows went in E126).
# Founder 2 Nov 2026 ("tune 4 ghantay pehle research ki thi ... complete nahi kiya"). Nothing is destroyed: the mail folders are MOVED to /var/retired-mailboxes/<date>/,
# the Postfix map lines are commented out (backup first), Postfix is reloaded. Delete the moved folders yourself later, when you are sure.
#   plan  (default, READ-ONLY): shows the map lines, the mail folders and their size, nothing changes.
#   apply : backup -> move folders -> comment map lines -> postmap -> reload -> prove the address is now refused (SMTP 550).
# Use:  git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/mailbox-retire.sh) plan
#       git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/mailbox-retire.sh) apply
set -uo pipefail
MODE="${1:-plan}"
ADDRS="${ADDRS:-basic.test@anexomail.com alikhan@anexomail.com}"
case "$ADDRS" in *masoodsherwani*|*founder*|*humza*|*raana*) echo "STOP: a protected address is in the list."; exit 3;; esac
STAMP="$(date +%Y%m%d-%H%M%S)"; DEST="/var/retired-mailboxes/$STAMP"
MAPS="$(postconf -h virtual_mailbox_maps virtual_alias_maps 2>/dev/null | tr ',' ' ' | sed -E 's/^[a-z]+://' | sort -u)"
BASE="$(postconf -h virtual_mailbox_base 2>/dev/null)"
echo "== maps: ${MAPS:-none}   mailbox base: ${BASE:-none}   mode: $MODE"
found=0
for a in $ADDRS; do
  echo "-- $a"
  for f in $MAPS; do [ -f "$f" ] && grep -nE "^[[:space:]]*${a//./\\.}([[:space:]]|$)" "$f" | sed "s|^|   map $f: |"; done
  dom="${a#*@}"; user="${a%@*}"
  for d in "$BASE/$dom/$user" "$BASE/$a" "/var/mail/vhosts/$dom/$user" "/var/vmail/$dom/$user" "/home/vmail/$dom/$user"; do
    [ -d "$d" ] && { echo "   folder: $d ($(du -sh "$d" 2>/dev/null | cut -f1), $(find "$d" -type f 2>/dev/null | wc -l) files)"; found=1; }
  done
done
[ "$MODE" = "apply" ] || { echo; echo "PLAN ONLY — nothing changed. Run 'apply' to move the folders and switch the addresses off."; exit 0; }
mkdir -p "$DEST" || exit 1
for f in $MAPS; do [ -f "$f" ] && cp -a "$f" "$DEST/$(basename "$f").bak"; done
for a in $ADDRS; do
  dom="${a#*@}"; user="${a%@*}"
  for d in "$BASE/$dom/$user" "$BASE/$a" "/var/mail/vhosts/$dom/$user" "/var/vmail/$dom/$user" "/home/vmail/$dom/$user"; do
    [ -d "$d" ] && { mkdir -p "$DEST/$dom"; mv "$d" "$DEST/$dom/$user" && echo "moved $d -> $DEST/$dom/$user"; }
  done
  for f in $MAPS; do
    [ -f "$f" ] && sed -i -E "s|^([[:space:]]*${a//./\\.}([[:space:]].*)?)$|# retired $STAMP: \1|" "$f" && { case "$f" in *.db|*.lmdb) ;; *) postmap "$f" 2>/dev/null;; esac; }
  done
done
postfix reload >/dev/null 2>&1 && echo "postfix reloaded"
for a in $ADDRS; do
  r="$( { exec 3<>/dev/tcp/127.0.0.1/25 || exit 1
          read -r -t 5 _ <&3; printf 'EHLO probe.local\r\n' >&3; sleep 0.4
          printf 'MAIL FROM:<probe@probe.local>\r\nRCPT TO:<%s>\r\nQUIT\r\n' "$a" >&3
          timeout 4 cat <&3 | tr -d '\r' | grep -E '^(250|251|450|451|452|550|551|553|554) ' | sed -n '2,3p' | tail -1; } 2>/dev/null )"
  printf '   %-34s %s   (5xx = refused = retired)\n' "$a" "${r:-(no answer)}"
done
echo "Backups of the map files + moved folders: $DEST"
