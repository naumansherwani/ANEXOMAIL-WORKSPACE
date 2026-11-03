#!/bin/bash
# anexomail-sync-domains (E15-C): DB (org_domains/org_addresses) -> DKIM keys + Postfix maps + OpenDKIM tables.
# Har minute cron se. Sirf apna "# E15-BEGIN..# E15-END" block badalta hai; baqi file ko haath nahi lagata.
export PAGER=cat
. /etc/anexomail/sync.env 2>/dev/null
[ -n "$WORKING_URL" ] || { echo "$(date -u +%FT%TZ) NO_URL"; exit 1; }
exec 9>/var/lock/anexomail-sync-domains.lock; flock -n 9 || exit 0
log(){ echo "$(date -u +%FT%TZ) $*"; }

RE_DOM='^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$'
RE_SEL='^[a-z0-9]{1,30}$'
RE_UUID='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
RE_ADDR='^[a-z0-9]([a-z0-9._-]{0,62}[a-z0-9])?@[a-z0-9.-]+$'
RE_PUB='^[A-Za-z0-9+/=]{300,}$'

ST=$(psql "$WORKING_URL" -At -c "select org_mail_sync_state()") || { log DB_FAIL; exit 1; }
LINES=$(printf '%s' "$ST" | python3 -c '
import sys,json
d=json.load(sys.stdin)
for x in d["pending_dkim"]: print("P",x["id"],x["domain"],x["selector"],"-",sep="\t")
for x in d["domains"]: print("D",x["id"],x["domain"],x["selector"],"-",sep="\t")
for x in d["addresses"]: print("A",x["address"],x["kind"],x.get("alias_target") or "-","-",sep="\t")
') || { log PARSE_FAIL; exit 1; }

VD=""; VM=""; VA=""; KT=""; ST_=""
declare -A OKDOM
while IFS=$'\t' read -r t a b c _; do
  case "$t" in
  P)
    [[ $a =~ $RE_UUID && $b =~ $RE_DOM && $c =~ $RE_SEL ]] || continue
    [[ $b == anexomail.com || $b == *.anexomail.com ]] && continue
    K=/etc/opendkim/keys/$b
    if [ ! -f "$K/$c.private" ]; then
      mkdir -p "$K" && opendkim-genkey -b 2048 -d "$b" -D "$K" -s "$c" || { log "GENKEY_FAIL $b"; continue; }
      chown -R opendkim:opendkim "$K"; chmod 600 "$K/$c.private"; log "DKIM_KEY_NEW $b"
    fi
    PUB=$(tr -d '\n\t "' < "$K/$c.txt" | sed -E 's#.*[;(]p=([A-Za-z0-9+/=]+).*#\1#')
    [[ $PUB =~ $RE_PUB ]] || { log "PUB_BAD $b"; continue; }
    echo "select org_domain_set_dkim('$a'::uuid, '$PUB');" | psql "$WORKING_URL" -At >/dev/null && log "DKIM_SAVED $b"
    ;;
  D)
    [[ $b =~ $RE_DOM && $c =~ $RE_SEL ]] || continue
    [[ $b == anexomail.com || $b == *.anexomail.com ]] && continue
    OKDOM[$b]=1
    VD+="$b OK"$'\n'
    if [ -f "/etc/opendkim/keys/$b/$c.private" ]; then
      KT+="$c._domainkey.$b $b:$c:/etc/opendkim/keys/$b/$c.private"$'\n'
      ST_+="*@$b $c._domainkey.$b"$'\n'
    fi
    ;;
  A)
    [[ $a =~ $RE_ADDR ]] || continue
    dom=${a#*@}; loc=${a%@*}
    [ -n "${OKDOM[$dom]}" ] || continue
    if [ "$b" = "alias" ]; then
      [[ $c =~ $RE_ADDR ]] || continue
      VA+="$a  $c"$'\n'
    else
      VM+="$a  $dom/$loc/"$'\n'
    fi
    ;;
  esac
done <<< "$LINES"

apply_block(){ # file, new-block-text -> 0 agar badla
  local f=$1 new=$2 tmp; tmp=$(mktemp)
  [ -f "$f" ] || : > "$f"
  sed '/^# E15-BEGIN/,/^# E15-END/d' "$f" > "$tmp"
  if [ -n "$new" ]; then
    [ -s "$tmp" ] && [ -n "$(tail -c1 "$tmp")" ] && echo >> "$tmp"
    { echo "# E15-BEGIN (auto-generated, haath se mat badlo)"; printf '%s' "$new"; echo "# E15-END"; } >> "$tmp"
  fi
  if cmp -s "$tmp" "$f"; then rm -f "$tmp"; return 1; fi
  cp -a "$f" "$f.bak-e15"; cat "$tmp" > "$f"; rm -f "$tmp"; return 0
}

PF=0; DK=0
apply_block /etc/postfix/vdomains  "$VD" && { postmap /etc/postfix/vdomains;  PF=1; log "vdomains updated"; }
apply_block /etc/postfix/vmailbox  "$VM" && { postmap /etc/postfix/vmailbox;  PF=1; log "vmailbox updated"; }
apply_block /etc/postfix/valias    "$VA" && { postmap /etc/postfix/valias;    PF=1; log "valias updated"; }
apply_block /etc/opendkim/KeyTable "$KT" && { DK=1; log "KeyTable updated"; }
apply_block /etc/opendkim/SigningTable "$ST_" && { DK=1; log "SigningTable updated"; }
[ $DK -eq 1 ] && { systemctl restart opendkim && log "opendkim restarted"; }
[ $PF -eq 1 ] && { postfix check 2>&1 | head -3; postfix reload >/dev/null 2>&1 && log "postfix reloaded"; }
exit 0
