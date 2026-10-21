#!/usr/bin/env bash
# ANEXOMAIL — 10 locked addresses: kaun si asli taur par bani hain? (READ-ONLY — kuch nahi badalta, koi secret print nahi)
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/mailbox-facts.sh)
# Kyun: founder page ka "Provision" sirf DB mein provision_requested_at likhta hai; us ko koi job utha ke Postfix mein nahi banati.
# Yeh script 4 jagah dekhti hai: (1) Postfix recipient maps, (2) asli SMTP RCPT test, (3) DB mailboxes row, (4) Dovecot/anexopipe.
set -uo pipefail
ADDR="naumansherwani.founder@anexomail.com humzasherwani@anexomail.com raanasherwani@anexomail.com masoodsherwani@anexomail.com resolved@anexomail.com moveyourbusiness@anexomail.com hello@anexomail.com billing@anexomail.com noreply@anexomail.com leo@anexomail.com"
echo "== 1) Postfix recipient settings"
postconf -n 2>/dev/null | grep -E '^(virtual_|mydestination|relay_domains|local_recipient|alias_maps|alias_database|smtpd_recipient_restrictions|smtpd_relay_restrictions|transport_maps|default_transport|mailbox_transport)' | sed -E 's/(password|pass)=[^ ,]+/\1=***/g'
echo; echo "== 2) master.cf — anexopipe"; grep -n -A4 '^anexopipe' /etc/postfix/master.cf 2>/dev/null | head -8
echo; echo "== 3) map files (passwords chhupe hue)"
for f in $(postconf -h virtual_mailbox_maps virtual_alias_maps transport_maps 2>/dev/null | tr ',' ' ' | sed -E 's/^[a-z]+://' | sort -u); do
  [ -f "$f" ] && { echo "--- $f"; sed -E 's/(password|passwd|pass) *= *.*/\1 = ***/I' "$f" | head -40; }
done
echo; echo "== 4) asli SMTP RCPT test (127.0.0.1:25) — 250 = qubool, 550/5xx = Postfix is address ko jaanta hi nahi"
for a in $ADDR; do
  r="$( { exec 3<>/dev/tcp/127.0.0.1/25 || exit 1
          read -r -t 5 _ <&3; printf 'EHLO probe.local\r\n' >&3; sleep 0.4
          printf 'MAIL FROM:<probe@probe.local>\r\nRCPT TO:<%s>\r\nQUIT\r\n' "$a" >&3
          timeout 4 cat <&3 | tr -d '\r' | grep -E '^(250|251|450|451|452|550|551|553|554) ' | sed -n '2,3p' | tail -1; } 2>/dev/null )"
  printf '  %-42s %s\n' "$a" "${r:-(jawab nahi)}"
done
echo; echo "== 5) DB: mailboxes table (founder page isi ko padhta hai)"
envv(){ for f in /opt/anexomail/.env /etc/anexomail/sync.env; do [ -r "$f" ] && grep -m1 -E "^$1=" "$f" | cut -d= -f2- | sed -e "s/^[\"']//" -e "s/[\"']$//"; done | head -1; }
U="$(envv SUPABASE4_URL)"; K="$(envv SUPABASE4_SERVICE_ROLE_KEY)"; U="${U%/}"
if [ -n "$U" ] && [ -n "$K" ]; then
  curl -s -m 15 -H "apikey: $K" -H "authorization: Bearer $K" "$U/rest/v1/mailboxes?select=address,provisioned,provision_requested_at,created_at&order=address.asc&limit=100" \
   | python3 -c 'import sys,json
try: rows=json.load(sys.stdin)
except Exception: rows=None
if not isinstance(rows,list): print("  (jawab padh nahi saka — table/columns dekhein)"); sys.exit()
want="'"$ADDR"'".split()
have={r["address"].lower():r for r in rows}
for a in want:
    r=have.get(a)
    print("  %-42s %s"%(a, "ROW NAHI" if not r else "provisioned=%s requested=%s"%(r.get("provisioned"),r.get("provision_requested_at"))))
extra=[a for a in have if a not in want]
if extra: print("  (list ke bahar ki rows: %d)"%len(extra))'
else echo "  (SUPABASE4 env nahi mila)"; fi; unset K
echo; echo "== 6) Dovecot / mail store"
command -v doveadm >/dev/null && doveadm user '*' 2>/dev/null | head -20 || echo "  doveadm nahi"
ls -ld /var/mail/vhosts/anexomail.com 2>/dev/null; du -sh /var/mail/vhosts/anexomail.com 2>/dev/null
echo; echo "== 7) pichle 24 ghante mein in addresses par reject/bounce (maillog)"
for a in $ADDR; do n="$(journalctl -u postfix --since '24 hours ago' 2>/dev/null | grep -c "to=<$a>")"; r="$(journalctl -u postfix --since '24 hours ago' 2>/dev/null | grep "to=<$a>" | grep -c -E 'status=(bounced|deferred)|reject')"; printf '  %-42s mails=%s  bounce/reject=%s\n' "$a" "$n" "$r"; done
echo; echo "DONE (read-only). Output bhej dein."
