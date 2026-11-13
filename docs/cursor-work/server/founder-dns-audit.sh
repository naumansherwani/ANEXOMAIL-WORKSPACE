#!/bin/bash
# KP1b (founder, 13 Nov 2026 22:05): PORT 53 + SUBDOMAIN RECORDS AUDIT for his OWN Rust authoritative DNS (zone founderworkspace.anexomail.com only, delegated by NS from his Namecheap). READ-ONLY: changes nothing, installs nothing, restarts nothing.
# Why: Namecheap has no HTTPS record type (his screenshot 13 Nov 22:03). No third-party vendor (docs/claude/FOUNDER-VENDOR-BAN-13NOV.md). Before any listener on 53 (PORT RED LINE) we read the server itself.
# usage: git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-dns-audit.sh)
Z=founderworkspace.anexomail.com; P=anexomail.com; ok=1; stop(){ echo "STOP: $1"; ok=0; }
owner(){ ss -H -l${1:0:1}np 2>/dev/null | awk -v p=":$2" '$4 ~ p"$" {print $0}' | grep -o 'pid=[0-9]*' | sort -u | while IFS== read -r _ pid; do basename "$(readlink /proc/$pid/exe 2>/dev/null)"; done | tr '\n' ' '; }
echo "== 1/6 who listens on port 53 (every address, real process name from /proc)"
ss -H -lntup 2>/dev/null | awk '$5 ~ /:53$/ {print "   " $1, $5}' | sort -u
for pr in udp tcp; do o="$(owner $pr 53)"; echo "   $pr 53 owner: ${o:-<nobody>}"; done
ss -H -lntup 2>/dev/null | awk '$5 ~ /^(0\.0\.0\.0|\*|\[::\]|62\.238\.98\.98):53$/ {f=1} END{exit !f}' && stop "something already listens on 53 on a public or wildcard address (see list above)" || echo "OK: nothing listens on 53 on a public or wildcard address (127.0.0.53 stub is loopback only and does not clash with a bind on the public address)"
echo "== 2/6 the local resolver stub (systemd-resolved), read-only"
systemctl is-active systemd-resolved 2>/dev/null | sed 's/^/   systemd-resolved: /'
grep -E '^(DNSStubListener|DNS=)' /etc/systemd/resolved.conf 2>/dev/null | sed 's/^/   /'
echo "== 3/6 firewall for port 53 (udp and tcp)"
for pr in udp tcp; do if ufw status 2>/dev/null | grep -qE "^53(/$pr)? .*ALLOW" || iptables -S 2>/dev/null | grep -qE -- "-p $pr .*--dport 53 .*ACCEPT"; then echo "   $pr 53: open"; else echo "   $pr 53: NOT open yet (a later install step opens it, with his word)"; fi; done
echo "== 4/6 DNSSEC of the parent zone $P (a DS record means it is signed)"
d="$(dig +short DS $P 2>/dev/null | head -2)"; echo "   DS: ${d:-<none> (parent not signed at the registry)}"
echo "== 5/6 what the subdomain holds today at his DNS host (these must be carried into the new zone, nothing may be lost)"
for t in A AAAA MX TXT CAA NS CNAME; do r="$(dig +short $t $Z 2>/dev/null | tr '\n' ' ' | cut -c1-200)"; echo "   $t: ${r:-<none>}"; done
for n in ns1 ns2; do r="$(dig +short A $n.$P 2>/dev/null | tr '\n' ' ')"; echo "   $n.$P A: ${r:-<none>}"; done
echo "== 6/6 this server's own public addresses, and a second server for NS2 (read-only facts)"
ip -o addr show scope global 2>/dev/null | awk '{print "   " $2, $4}'
[ -n "$(dig +short A $Z)" ] || stop "$Z has no A record today: nothing to carry over, tell Claude"
echo; [ "$ok" = 1 ] && echo "GO: port 53 is free, Claude may now write the Rust DNS (zone $Z only)" || echo "STOP: do not install anything on port 53. Send this output to Claude. Nothing was changed by this audit."
