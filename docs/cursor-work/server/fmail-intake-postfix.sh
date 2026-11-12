#!/usr/bin/env bash
# Q1b-3 step 1c: ONE per-address Postfix transport entry (ONLY WITH HIS "HAAN"): naumansherwani.founder@anexomail.com -> lmtp:inet:127.0.0.1:18025.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/fmail-intake-postfix.sh)
# Facts (his postconf 13 Nov 04:11): virtual_transport = anexopipe (awam), transport_maps was EMPTY. This adds a map that holds ONE line, so every other address keeps going to anexopipe.
# Effect: new mail for the founder address no longer goes to the old anexopipe path; it is sealed by the founder service. Mail already stored there stays where it is.
# Safety: main.cf backed up, `postfix check` must pass, auto rollback on any failure, intake listener must answer first.
# Rollback later:  cp /etc/postfix/main.cf.pre-founder-intake /etc/postfix/main.cf && systemctl reload postfix
set -uo pipefail
ADDR="${FOUNDER_MAIL_ADDR:-naumansherwani.founder@anexomail.com}"; BIND=127.0.0.1:18025; MAP=/etc/postfix/founder-transport; MC=/etc/postfix/main.cf; BK=$MC.pre-founder-intake
[ "$(id -u)" -eq 0 ] || { echo "FAIL: root needed"; exit 2; }
undo() { echo "== ROLLBACK"; [ -f "$BK" ] && cp -p "$BK" "$MC"; rm -f "$MAP" "$MAP.db"; postfix check && systemctl reload postfix; echo "main.cf restored, map removed, Postfix reloaded"; exit "${1:-1}"; }
echo "== 1/5 intake listener must be up"; ss -H -tlnp | grep -q "127.0.0.1:18025.*anexomail-found" || { echo "FAIL: founder LMTP is not listening (run fmail-intake-on.sh first)"; exit 3; }
echo "== 2/5 transport_maps today: '$(postconf -h transport_maps)'"; [ -z "$(postconf -h transport_maps)" ] || [ "$(postconf -h transport_maps)" = "hash:$MAP" ] || { echo "FAIL: transport_maps is already used by something else, stop and send me this"; exit 3; }
echo "== 3/5 map + main.cf"; [ -f "$BK" ] || cp -p "$MC" "$BK"; echo "backup $BK"
printf '%s lmtp:inet:%s\n' "$ADDR" "$BIND" >"$MAP"; chmod 644 "$MAP"; postmap "$MAP" || undo 3
postconf -e "transport_maps = hash:$MAP" || undo 3
echo "== 4/5 postfix check + reload"; postfix check || undo 4; systemctl reload postfix || undo 4
echo "== 5/5 proof"; echo "  lookup: $(postmap -q "$ADDR" hash:$MAP)"; echo "  other address: '$(postmap -q someone-else@anexomail.com hash:$MAP)' (empty = still anexopipe)"
echo "  transport_maps = $(postconf -h transport_maps)"
echo "OK - now send ONE mail from your other address to $ADDR, then: journalctl -u anexomail-founder -n 20 --no-pager | tail; and look at the Inbox."
