# Step 8 — MAIL LAUNCH GATE (18 checks)

Rule: **18/18 green ke baghair mail launch nahi.** Ek bhi red = launch nahi, beta bhi nahi.
Yeh script server par chalao; yeh sirf sach batata hai, kuch fix nahi karta.

```bash
cat > /usr/local/bin/anexomail-mail-gate <<'EOF'
#!/usr/bin/env bash
# ANEXOMAIL — mail launch gate. Har check PASS/FAIL, aakhir mein score.
PASS=0; FAIL=0
chk() { if eval "$2" >/dev/null 2>&1; then echo "PASS  $1"; PASS=$((PASS+1)); else echo "FAIL  $1"; FAIL=$((FAIL+1)); fi; }
IP4=$(curl -4 -s https://ifconfig.co)

chk "01 hostname = mail.anexomail.com"   '[ "$(hostname -f)" = "mail.anexomail.com" ]'
chk "02 A mail.anexomail.com"            "[ -n \"\$(dig +short A mail.anexomail.com)\" ]"
chk "03 MX -> mail.anexomail.com"        "dig +short MX anexomail.com | grep -q mail.anexomail.com"
chk "04 SPF record"                      "dig +short TXT anexomail.com | grep -q 'v=spf1'"
chk "05 DKIM record"                     "dig +short TXT mail._domainkey.anexomail.com | grep -q 'v=DKIM1'"
chk "06 DMARC record"                    "dig +short TXT _dmarc.anexomail.com | grep -q 'v=DMARC1'"
chk "07 PTR = mail.anexomail.com"        "dig +short -x $IP4 | grep -q 'mail.anexomail.com'"
chk "08 postfix running"                 'systemctl is-active --quiet postfix'
chk "09 dovecot running"                 'systemctl is-active --quiet dovecot'
chk "10 opendkim + opendmarc running"    'systemctl is-active --quiet opendkim && systemctl is-active --quiet opendmarc'
chk "11 ports 25/587/993 listening"      "ss -lntH | grep -qE ':25\$' && ss -lntH | grep -qE ':587\$' && ss -lntH | grep -qE ':993\$'"
chk "12 outbound port 25 open"           "timeout 5 bash -c 'cat < /dev/null > /dev/tcp/gmail-smtp-in.l.google.com/25'"
chk "13 TLS cert present"                '[ -s /etc/anexomail/tls/mail.crt ] && [ -s /etc/anexomail/tls/mail.key ]'
chk "14 10 dovecot users"                "[ \"\$(doveadm user '*' 2>/dev/null | wc -l)\" -ge 10 ]"
chk "15 dkim key ok"                     'opendkim-testkey -d anexomail.com -s mail 2>&1 | grep -qi "key ok"'
chk "16 deliver pipe installed"          '[ -x /usr/local/bin/anexomail-deliver ]'
chk "17 supabase creds on server"        'grep -q SUPABASE_SERVICE_ROLE_KEY /etc/anexomail/mail.env'
chk "18 no mail queue backlog"           "[ \"\$(mailq | grep -c '^[A-F0-9]')\" -lt 5 ]"

echo "-----------------------------------------"
echo "PASS=$PASS  FAIL=$FAIL"
[ "$FAIL" -eq 0 ] && echo "MAIL GATE: GREEN — launch allowed" || echo "MAIL GATE: RED — launch BLOCKED"
exit "$FAIL"
EOF
chmod +x /usr/local/bin/anexomail-mail-gate
/usr/local/bin/anexomail-mail-gate
```

## Supabase side (SQL Editor mein, 4 checks)

```sql
select 'mailboxes'   as check, count(*) as n, count(*) = 13 as green from public.mailboxes
union all
select 'inbound_24h', count(*), count(*) > 0 from public.mail_inbound_raw where created_at > now() - interval '24 hours'
union all
select 'outbound_ok', count(*), count(*) > 0 from public.mail_outbox_log where ok and created_at > now() - interval '24 hours'
union all
select 'auth_pass',   count(*), count(*) > 0 from public.mail_messages
 where direction='in' and spf_result='pass' and dkim_result='pass';
```

Chaaron `green = true` hone chahiye.

## Roz ka watchdog (optional, recommended)

```bash
( crontab -l 2>/dev/null; echo "*/30 * * * * /usr/local/bin/anexomail-mail-gate > /var/log/anexomail-mail-gate.log 2>&1" ) | crontab -
```

Gate red hote hi `/var/log/anexomail-mail-gate.log` mein wajah likhi hogi.

## Gate green hone par

`docs/wire/README.md` ki ledger table mein sab dots DONE karo, aur mujhe gate ka output do —
main us ke baad **frontend + Caddy wire book** (step 10 se) shuru karunga.
Jab tak yeh 18 + 4 green nahi, main mail ko "working" nahi kahunga.
