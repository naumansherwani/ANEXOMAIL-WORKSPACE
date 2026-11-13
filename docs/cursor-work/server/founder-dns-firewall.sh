#!/usr/bin/env bash
# KP1b STEP B (founder 13 Nov 2026): open port 53 (udp + tcp) ONLY to the two addresses founder-dns binds, with ufw. Nothing else is changed.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-dns-firewall.sh)
# Safety: if ufw is not active the script STOPS and touches nothing. Rollback (printed at the end): ufw delete the 4 rules it lists.
# After it: from HIS OWN computer (outside the server) he runs one PowerShell line (printed at the end) to prove port 53 answers from outside.
set -uo pipefail
[ "$(id -u)" -eq 0 ] || { echo "FAIL: root needed"; exit 2; }
V4="$(ip -o -4 addr show scope global | awk '{print $4}' | cut -d/ -f1 | head -1)"; V6="$(ip -o -6 addr show scope global | awk '{print $4}' | cut -d/ -f1 | head -1)"
[ -n "$V4" ] || { echo "FAIL: no public IPv4"; exit 3; }
systemctl is-active --quiet founder-dns || { echo "STOP: founder-dns is not running (run STEP A first). Nothing changed."; exit 3; }
ufw status 2>/dev/null | grep -q "^Status: active" || { echo "STOP: ufw is not active, so this script does not know your firewall. Nothing changed. Send this line to Claude."; exit 3; }
echo "== before (port 53 rules)"; ufw status | grep -E "(^|[ \[])53([ /]|$)" | sed 's/^/   /' || true; echo "   (end)"
ufw allow proto udp from any to "$V4" port 53 comment 'founder-dns udp' >/dev/null && echo "   added: udp 53 -> $V4"
ufw allow proto tcp from any to "$V4" port 53 comment 'founder-dns tcp' >/dev/null && echo "   added: tcp 53 -> $V4"
if [ -n "$V6" ]; then ufw allow proto udp from any to "$V6" port 53 comment 'founder-dns udp6' >/dev/null && echo "   added: udp 53 -> $V6"; ufw allow proto tcp from any to "$V6" port 53 comment 'founder-dns tcp6' >/dev/null && echo "   added: tcp 53 -> $V6"; fi
echo "== after (port 53 rules)"; ufw status | grep -E "(^|[ \[])53([ /]|$)" | sed 's/^/   /'
echo "== sanity: the services that must stay up"; for s in founder-dns anexomail-founder caddy; do printf '   %-18s %s\n' $s "$(systemctl is-active $s 2>/dev/null)"; done
echo; echo "NEXT, from YOUR OWN computer (not the server), PowerShell, one line each, send Claude both outputs:"
echo "   Resolve-DnsName founderworkspace.anexomail.com -Type A -Server $V4"
echo "   Resolve-DnsName founderworkspace.anexomail.com -Type A -Server $V4 -TcpOnly"
echo "Rollback if ever needed: ufw status numbered, then ufw delete <number> for the 'founder-dns' rules."
