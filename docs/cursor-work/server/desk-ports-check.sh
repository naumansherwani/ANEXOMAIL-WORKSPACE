#!/bin/bash
# ADMIN DESK R3a0 (21 Nov 2026): PORTS + CADDY CHECK. READ-ONLY: changes NOTHING, installs NOTHING, restarts NOTHING, prints no secret.
# Why (his 07:48 order: "admin desk ke liye port khali rakho, sab awam se alag, ports khali ki command do caddy server ke liye"): the PORT RED LINE needs the FULL listener list, not head -40.
# usage: git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/desk-ports-check.sh) 2>&1 | tail -60
echo "== 1/5 EVERY listener, real binary name (tcp + udp), nothing cut"
ss -H -lntup 2>/dev/null | while read -r proto st rq sq local peer proc; do pid="$(echo "$proc" | grep -o 'pid=[0-9]*' | head -1 | cut -d= -f2)"; nm="$( [ -n "$pid" ] && basename "$(readlink /proc/$pid/exe 2>/dev/null)" )"; printf '   %-4s %-28s %s\n' "$proto" "$local" "${nm:-?}"; done | sort -u
echo "== 2/5 who owns tcp 80 (Caddy asks Let's Encrypt for certificates over it) and the Caddy listeners"
ss -H -lntp 2>/dev/null | awk '$4 ~ /:80$/ {print "   " $4, $6}' | head -3
C="$(curl -s -m 3 http://127.0.0.1:2019/config/apps/http/servers 2>/dev/null)"; [ -n "$C" ] && echo "$C" | python3 -c 'import sys,json
try:
    d=json.load(sys.stdin)
    for k,v in d.items(): print("   caddy server",k,"listen",v.get("listen"))
except Exception as e: print("   cannot read caddy servers:",e)' || echo "   Caddy admin API not answering on 127.0.0.1:2019"
echo "== 3/5 host names Caddy serves (names only)"
curl -s -m 3 http://127.0.0.1:2019/config/ 2>/dev/null | grep -o '"host":\[[^]]*\]' | sort -u | head -12 | sed 's/^/   /'
echo "== 4/5 free ports in the range reserved for the Admin Desk (tcp 3300-3319, udp 3300-3319, loopback use only)"
for p in $(seq 3300 3319); do t="$(ss -H -ltn 2>/dev/null | awk -v q=":$p\$" '$4 ~ q' | wc -l)"; u="$(ss -H -lun 2>/dev/null | awk -v q=":$p\$" '$4 ~ q' | wc -l)"; [ "$t" = 0 ] && [ "$u" = 0 ] && printf '%s ' "$p"; done; echo " <- free (tcp and udp)"
echo "== 5/5 where the Caddyfile is (path only)"
ls -l /etc/caddy/Caddyfile 2>/dev/null | awk '{print "   " $NF, $5 " bytes", $6, $7, $8}'
echo; echo "READ-ONLY: nothing was changed. The Admin Desk needs NO new public port (UDP 443 is shared by SNI); the reserved range is only for a later own-binary split on loopback. Send this output to Claude."
