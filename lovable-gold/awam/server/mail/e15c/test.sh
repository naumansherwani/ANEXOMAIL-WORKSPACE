#!/bin/bash
# E15-C live test: verified test-domain DB mein banao -> sync -> maps/DKIM check -> cleanup. Real mail/DNS nahi chhuta.
export PAGER=cat
O=16e02f4b-cc52-438f-a2e7-bef4ef7f81cb   # basic.test org
D=c-sync-test.example.org
q(){ psql "$WORKING_URL" -At -c "$1"; }
q "delete from public.mail_accounts where address like '%@$D'" >/dev/null
ID=$(q "select (org_domain_add('$O','$D')->'domain'->>'id')")
[ -n "$ID" ] || { echo "T_FAIL add (domain limit? purana test domain pehle hatao)"; exit 1; }
q "select org_domain_set_checks('$ID',true,true,true,true,true)" >/dev/null
q "select org_address_create('$O','$ID','info')" >/dev/null
q "select org_address_create('$O','$ID','team','alias',null,'info@$D')" >/dev/null
/usr/local/bin/anexomail-sync-domains.sh
echo "--- 1 DKIM key DB mein saved?"; q "select dkim_public is not null and length(dkim_public)>300 from org_domains where id='$ID'"
echo "--- 2 postfix"; postmap -q "info@$D" hash:/etc/postfix/vmailbox; postmap -q "team@$D" hash:/etc/postfix/valias; postmap -q "$D" hash:/etc/postfix/vdomains
echo "--- 3 opendkim"; grep -c "$D" /etc/opendkim/KeyTable /etc/opendkim/SigningTable; ls /etc/opendkim/keys/$D
echo "--- 4 purani lines salamat?"; grep -c "anexomail.com" /etc/opendkim/KeyTable; postmap -q humzasherwani@anexomail.com hash:/etc/postfix/vmailbox
echo "--- 5 services"; systemctl is-active opendkim postfix
q "select org_domain_remove('$O','$ID')" >/dev/null
/usr/local/bin/anexomail-sync-domains.sh
echo "--- 6 cleanup: maps se gayab?"; postmap -q "info@$D" hash:/etc/postfix/vmailbox || echo GONE_OK; grep -c "$D" /etc/opendkim/KeyTable
q "delete from public.mail_accounts where address like '%@$D'" >/dev/null; rm -rf /etc/opendkim/keys/$D
echo T_DONE
