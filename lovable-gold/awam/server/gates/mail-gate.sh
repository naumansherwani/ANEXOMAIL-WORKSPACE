#!/usr/bin/env bash
# ============================================================================
# GATE 4 — MAIL (anexomail.com · 10 mailbox/sendonly + 3 forward, incl. Masood Pro) + round-trip
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
check_port "submissions TLS 465" 465
check_port "imaps 993" 993
check_cmd "myhostname = $MAILHOST" bash -c "postconf -h myhostname | grep -qi '$MAILHOST'"
check_cmd "envelope domain = $DOMAIN (SPF aligned)" bash -c "[ \"\$(postconf -h myorigin)\" = '$DOMAIN' ]"
check_cmd "OpenDKIM selector/key valid" opendkim-testkey -d "$DOMAIN" -s mail -k /etc/opendkim/keys/$DOMAIN/mail.private
check_cmd "outbound port 25 khula" bash -c "timeout 8 bash -c '</dev/tcp/gmail-smtp-in.l.google.com/25'"

# Purani deferred delivery ko pehle foran retry karo. Queue ko delete nahi karte:
# asli mail mehfooz rehti hai, aur agar remote server ab bhi mana kare to exact
# queue ID + reason isi gate output mein nazar aata hai.
postqueue -f >/dev/null 2>&1 || true
for _ in $(seq 1 15); do
  QUEUED="$(postqueue -j 2>/dev/null | awk 'NF {n++} END {print n+0}')"
  [ "$QUEUED" -eq 0 ] && break
  sleep 2
done
QUEUED="$(postqueue -j 2>/dev/null | awk 'NF {n++} END {print n+0}')"
if [ "$QUEUED" -eq 0 ]; then
  ok "mail queue saaf"
else
  bad "mail queue saaf" "$QUEUED message abhi queued — neeche exact Postfix reason"
  postqueue -p
  echo "--- recent Postfix delivery reason ---"
  journalctl -u postfix --since '-15 minutes' --no-pager 2>/dev/null \
    | grep -E 'status=(deferred|bounced)|warning:|fatal:' | tail -n 20 || true
fi

echo "--- final address list DB mein (10 mailbox/sendonly + 3 forward) ---"
check_sql "mailboxes = 13" "select count(*) from public.mailboxes where address like '%@$DOMAIN' and active;" "13"
for a in hello moveyourbusiness resolved billing noreply leo naumansherwani.founder humzasherwani raanasherwani masoodsherwani; do
  check_sql "address $a@$DOMAIN" \
    "select count(*)>0 from public.mailboxes where address='$a@$DOMAIN';" "t"
done
for a in postmaster abuse dmarc; do
  check_sql "$a@$DOMAIN sirf forward -> resolved@" \
    "select count(*)>0 from public.mailboxes where address='$a@$DOMAIN' and box_type='alias' and alias_target='resolved@$DOMAIN';" "t"
done
for a in nauman support trials; do
  check_sql "$a@$DOMAIN delete ho chuka" \
    "select count(*)=0 from public.mailboxes where address='$a@$DOMAIN';" "t"
done
check_sql "mail_messages.spf_result column maujood" \
  "select count(*)>0 from information_schema.columns where table_schema='public' and table_name='mail_messages' and column_name='spf_result';" "t"
check_sql "mailboxes.org_id compatibility maujood" \
  "select count(*)>0 from information_schema.columns where table_schema='public' and table_name='mailboxes' and column_name='org_id';" "t"
check_sql "mail_messages.cc_addrs legacy API compatibility maujood" \
  "select count(*)>0 from information_schema.columns where table_schema='public' and table_name='mail_messages' and column_name='cc_addrs';" "t"
check_sql "mail_ingest final function zinda" \
  "select count(*)>0 from pg_proc where pronamespace='public'::regnamespace and proname='mail_ingest';" "t"
check_sql "mail_ingest canonical v59" \
  "select coalesce(obj_description('public.mail_ingest(jsonb)'::regprocedure),'');" "anexomail-mail-contract-v59"


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

gate_result "MAIL FINAL ADDRESS LIST"
