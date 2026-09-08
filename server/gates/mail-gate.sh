#!/usr/bin/env bash
# ============================================================================
# GATE 4 — MAIL (anexomail.com · 13 addresses) + round-trip
#   bash server/gates/mail-gate.sh
# DNS/PTR aap ke registrar par hai (wohi ek manual hissa) — yeh gate usay padhta hai.
# ============================================================================
set -uo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

DOMAIN=anexomail.com
MAILHOST=mail.anexomail.com
IP="$(curl -s --max-time 10 https://api.ipify.org || echo '')"
DKIM_FILE="/etc/opendkim/keys/$DOMAIN/mail.txt"
EXPECTED_SPF='v=spf1 mx -all'
EXPECTED_DMARC='v=DMARC1;p=reject;rua=mailto:dmarc@anexomail.com;adkim=s;aspf=s'

dns_txt() {
  dig +short TXT "$1" | tr -d '"\n'
}

local_dkim() {
  awk -F'"' '{ for (i=2; i<=NF; i+=2) printf "%s", $i } END { print "" }' "$DKIM_FILE"
}

echo "=== GATE 4 · MAIL ==="

echo "--- DNS chain ---"
check_cmd "A $MAILHOST" bash -c "dig +short A $MAILHOST | grep -q ."
check_cmd "MX $DOMAIN -> $MAILHOST" bash -c "dig +short MX $DOMAIN | grep -qi '$MAILHOST'"
SPF="$(dig +short TXT "$DOMAIN" | tr -d '"' | grep '^v=spf1 ' | head -1)"
[ "$SPF" = "$EXPECTED_SPF" ] && ok "SPF exact + aligned" || bad "SPF exact + aligned" "expected: $EXPECTED_SPF"

if [ -f "$DKIM_FILE" ]; then
  LOCAL_DKIM="$(local_dkim | tr -d '[:space:]')"
  DNS_DKIM="$(dns_txt "mail._domainkey.$DOMAIN" | tr -d '[:space:]')"
  [ -n "$LOCAL_DKIM" ] && [ "$DNS_DKIM" = "$LOCAL_DKIM" ] \
    && ok "DKIM DNS = server public key" \
    || bad "DKIM DNS = server public key" "Namecheap TXT mail._domainkey mein deploy-mail.sh ka exact output paste karo"
else
  bad "DKIM server public key" "$DKIM_FILE nahi mila"
fi

DMARC="$(dns_txt "_dmarc.$DOMAIN" | tr -d '[:space:]')"
[ "$DMARC" = "$EXPECTED_DMARC" ] \
  && ok "DMARC exact strict alignment" \
  || bad "DMARC exact strict alignment" "expected: v=DMARC1; p=reject; rua=mailto:dmarc@anexomail.com; adkim=s; aspf=s"
if [ -n "$IP" ]; then
  check_cmd "PTR $IP -> $MAILHOST" bash -c "dig +short -x $IP | grep -qi '$MAILHOST'"
else
  bad "PTR check" "public IP nahi mila"
fi

echo "--- mail server ---"
check_cmd "postfix active" systemctl is-active --quiet postfix
check_cmd "dovecot active" systemctl is-active --quiet dovecot
check_cmd "opendkim active" systemctl is-active --quiet opendkim
check_port "smtp 25" 25
check_port "submission 587" 587
check_port "imaps 993" 993
check_cmd "myhostname = $MAILHOST" bash -c "postconf -h myhostname | grep -qi '$MAILHOST'"
check_cmd "envelope domain = $DOMAIN (SPF aligned)" bash -c "[ \"\$(postconf -h myorigin)\" = '$DOMAIN' ]"
check_cmd "OpenDKIM selector/key valid" opendkim-testkey -d "$DOMAIN" -s mail -k /etc/opendkim/keys/$DOMAIN/mail.private
check_cmd "outbound port 25 khula" bash -c "timeout 8 bash -c '</dev/tcp/gmail-smtp-in.l.google.com/25'"
check_cmd "mail queue saaf" bash -c "[ \"\$(mailq | grep -c '^[A-F0-9]')\" -eq 0 ]"

echo "--- 13 addresses DB mein ---"
check_sql "mailboxes = 13" "select count(*) from public.mailboxes where address like '%@$DOMAIN';" "13"
for a in hello moveyourbusiness resolved billing noreply leo; do
  check_sql "address $a@$DOMAIN" \
    "select count(*)>0 from public.mailboxes where address='$a@$DOMAIN';" "t"
done

echo "--- inbound pipe + inbox (round trip) ---"
BEFORE="$(bash /opt/anexomail-web/sql/run.sh --query 'select count(*) from public.mail_messages;' 2>/dev/null | tr -d '[:space:]')"
printf 'Subject: ANEXOMAIL gate %s\n\ngate round-trip\n' "$(date -u +%s)" \
  | sendmail -f "noreply@$DOMAIN" "hello@$DOMAIN" && ok "test mail bheji" || bad "test mail bhejna" "sendmail fail"
sleep 20
AFTER="$(bash /opt/anexomail-web/sql/run.sh --query 'select count(*) from public.mail_messages;' 2>/dev/null | tr -d '[:space:]')"
if [ -n "$AFTER" ] && [ -n "$BEFORE" ] && [ "$AFTER" -gt "$BEFORE" ]; then
  ok "inbound pipe -> mail_messages ($BEFORE -> $AFTER)"
else
  bad "inbound pipe -> mail_messages" "count nahi barha ($BEFORE -> $AFTER); /var/log/mail.log dekho"
fi
check_sql "inbound raw proof table maujood" "select count(*)>0 from information_schema.tables where table_schema='public' and table_name='mail_inbound_raw';" "t"
check_http "inbox UI zinda" "https://anexomail.com/app/mail" 200

gate_result "MAIL 13 ADDRESSES"
