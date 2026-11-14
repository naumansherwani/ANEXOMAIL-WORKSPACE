#!/bin/bash
# KP1 (founder, 13 Nov 2026): PORTS / CADDY / SNI FRONT / UDP / DNS AUDIT. READ-ONLY: changes NOTHING, installs NOTHING, restarts NOTHING.
# Why: every port scare so far came from guessing. This reads the server itself: real process names from /proc (ss cuts them at 15 characters), Caddy's own admin config, the founder ports (no secrets printed), the journal, DNS, the firewall per port.
# It ends with GO / STOP for the K8e install (HTTP/3 only). usage: git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-ports-audit.sh)
H=founderworkspace.anexomail.com; ENVF=/etc/anexomail/founder.env; ok=1; stop(){ echo "STOP: $1"; ok=0; }
owner(){ # $1 proto(tcp|udp) $2 port -> real binary name(s) listening there
  ss -H -l${1:0:1}np 2>/dev/null | awk -v p=":$2" '$4 ~ p"$" {print $0}' | grep -o 'pid=[0-9]*' | sort -u | while IFS== read -r _ pid; do basename "$(readlink /proc/$pid/exe 2>/dev/null)" ; done | sort -u | tr '\n' ' '; }
echo "== 1/7 who owns the ports that matter (real names from /proc, not cut at 15 letters)"
for pp in tcp:443 udp:443 udp:4443 tcp:8443 udp:3443 udp:18443 tcp:3210; do pr=${pp%%:*}; po=${pp##*:}; o="$(owner $pr $po)"; printf '   %-4s %-6s %s\n' "$pr" "$po" "${o:-<nobody>}"; done
[ "$(owner udp 443)" = "anexomail-founder " ] && echo "OK: udp 443 = anexomail-founder (HTTP/3)" || stop "udp 443 is not owned by anexomail-founder alone: [$(owner udp 443)]"
[ -z "$(owner udp 4443)" ] && echo "OK: udp 4443 is closed (KP3 step 5: WebTransport runs on udp 443 only)" || stop "udp 4443 is still listening: [$(owner udp 4443)] (run founder-wt-off.sh)"
echo "== 2/7 every listener on 443 / 4443 / 8443 / 3443 / 18443 (anything unexpected shows here)"
ss -H -lntup 2>/dev/null | awk '$5 ~ /:(443|4443|8443|3443|18443)$/ {print "   " $1, $5}' | sort -u
echo "== 3/7 Caddy (its own admin API, read-only): which addresses it listens on"
C="$(curl -s -m 3 http://127.0.0.1:2019/config/apps/http/servers 2>/dev/null)"; [ -n "$C" ] && echo "$C" | python3 -c 'import sys,json
try:
    d=json.load(sys.stdin)
    for k,v in d.items(): print("   server",k,"listen",v.get("listen"),"protocols",v.get("protocols","default"))
except Exception as e: print("   cannot read:",e)' || echo "   Caddy admin API not answering on 127.0.0.1:2019 (not a failure by itself)"
echo "== 4/7 founder ports from $ENVF (only these keys, never a secret)"
grep -E '^FOUNDER_(H3|TLS256|WT|TLS_PROXY|FRONT)[A-Z_]*_?(ADDR|HOST)?=' "$ENVF" 2>/dev/null | grep -vE 'KEY|SECRET|TOKEN|PASS' | sed 's/^/   /'
echo "== 5/7 what the service itself says (journal)"
J="$(journalctl -u anexomail-founder -n 600 --no-pager 2>/dev/null)"
for k in "HTTP/3 ON" "TLS-256 terminator ON" "WebTransport" "tcp 443 is closed on purpose"; do l="$(echo "$J" | grep -F "$k" | tail -1 | cut -c1-170)"; echo "   ${l:-<no line for: $k>}"; done
echo "$J" | grep -q "HTTP/3 ON" || stop "no 'HTTP/3 ON' line in the journal"
echo "== 6/7 DNS: HTTPS record (RFC 9460) and A / AAAA against this server's own addresses"
R="$( (dig +short HTTPS $H 2>/dev/null || host -t type65 $H 2>/dev/null) | head -3)"; echo "   HTTPS: ${R:-<none>}"
echo "$R" | grep -qi 'h3' || stop "no HTTPS record with alpn=h3 for $H (add: Type HTTPS, Name founderworkspace, Priority 1, Target ., Value alpn=\"h3\", TTL 300)"
MY="$(ip -o addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1)"
for t in A AAAA; do d="$(dig +short $t $H 2>/dev/null | head -2 | tr '\n' ' ')"; echo "   $t: ${d:-<none>}"; for a in $d; do echo "$MY" | grep -qxF "$a" && echo "      $a = this server" || echo "      $a is NOT an address of this server (a proxy/CDN in front would stop QUIC: check)"; done; done
echo "== 7/7 firewall, per port (udp 443 must be open; 4443 is gone since KP3 step 5)"
for p in 443; do if ufw status 2>/dev/null | grep -qE "^$p/udp .*ALLOW" || iptables -S 2>/dev/null | grep -qE -- "-p udp .*--dport $p .*ACCEPT"; then echo "   udp $p: open"; else stop "udp $p: no ALLOW rule found in ufw/iptables"; fi; done
echo; [ "$ok" = 1 ] && echo "GO: the K8e install (HTTP/3 only) is safe to run" || echo "STOP: do not run the K8e install yet. Send this output to Claude. Nothing was changed by this audit."
