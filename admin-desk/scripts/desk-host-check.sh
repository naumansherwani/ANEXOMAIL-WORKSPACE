#!/bin/bash
# ADMIN DESK R3a0 (21 Nov 2026): HOST CHECK. READ-ONLY: changes NOTHING, installs NOTHING, restarts NOTHING, prints no secret.
# Question it answers: what does the server already know about admindesk.anexomail.com (DNS he added at Namecheap, ports, Caddy, certificate files)?
# usage: git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/desk-host-check.sh) 2>&1 | tail -40
H=admindesk.anexomail.com; F=founderworkspace.anexomail.com
echo "== 1/6 who owns the ports (real names from /proc)"
for pp in tcp:443 udp:443 udp:18443 tcp:3200; do pr=${pp%%:*}; po=${pp##*:}; o="$(ss -H -l${pr:0:1}np 2>/dev/null | awk -v p=":$po" '$4 ~ p"$" {print $0}' | grep -o 'pid=[0-9]*' | sort -u | while IFS== read -r _ pid; do basename "$(readlink /proc/$pid/exe 2>/dev/null)"; done | sort -u | tr '\n' ' ')"; printf '   %-4s %-6s %s\n' "$pr" "$po" "${o:-<nobody>}"; done
echo "== 2/6 DNS for $H (A, AAAA, HTTPS alpn, CAA) and for $F to compare"
MY="$(ip -o addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1)"
for h in $H $F; do for t in A AAAA HTTPS CAA; do d="$(dig +short $t $h 2>/dev/null | head -3 | tr '\n' ' ')"; echo "   $h $t: ${d:-<none>}"; done; done
for a in $(dig +short A $H 2>/dev/null) $(dig +short AAAA $H 2>/dev/null); do echo "$MY" | grep -qxF "$a" && echo "   $a = THIS server" || echo "   $a = NOT this server"; done
echo "== 3/6 Caddy (read-only admin API): does it know the host name"
C="$(curl -s -m 3 http://127.0.0.1:2019/config/ 2>/dev/null)"; if [ -n "$C" ]; then echo "$C" | grep -o "$H" | sort -u | sed 's/^/   caddy config names: /'; echo "$C" | grep -q "$H" || echo "   caddy config does not mention $H"; else echo "   Caddy admin API not answering"; fi
echo "== 4/6 certificate files that mention the host (names only)"
ls -d /etc/anexomail/* /etc/ssl/anexomail* /var/lib/caddy/.local/share/caddy/certificates/*/* 2>/dev/null | grep -i -E "admindesk|founderworkspace" | sed 's/^/   /'; echo "   (end of list)"
echo "== 5/6 founder service host lines in the journal (last)"
journalctl -u anexomail-founder -n 800 --no-pager 2>/dev/null | grep -i -E "host|sni|cert" | tail -4 | cut -c1-170 | sed 's/^/   /'
echo "== 6/6 firewall udp 443"
if ufw status 2>/dev/null | grep -qE "^443/udp .*ALLOW" || iptables -S 2>/dev/null | grep -qE -- "-p udp .*--dport 443 .*ACCEPT"; then echo "   udp 443: open"; else echo "   udp 443: no ALLOW rule found"; fi
echo; echo "READ-ONLY: nothing was changed. Send this output to Claude."
