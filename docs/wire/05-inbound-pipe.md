# Step 5 — Inbound: Internet → Postfix → Supabase → Inbox

Chain:

```text
Internet → MX → mail.anexomail.com → Postfix → anexomail-deliver (pipe)
        → Supabase mail_ingest() → mail_threads / mail_messages → ANEXOMAIL Inbox
```

Do jagah mail rakhi jati hai — jaan boojh kar:

1. **Dovecot Maildir** (IMAP backup access)
2. **Supabase** (product truth, inbox UI isi se banta hai)

## 5A. Code server par le jao

```bash
cd /opt/anexomail-web && git pull
install -m 755 /dev/null /usr/local/bin/anexomail-deliver
cat > /usr/local/bin/anexomail-deliver <<'EOF'
#!/usr/bin/env bash
exec /usr/local/bin/bun /opt/anexomail-web/server/mail/deliver-to-supabase.ts "$@"
EOF
chmod 755 /usr/local/bin/anexomail-deliver
which bun || ls -l /usr/local/bin/bun     # bun ka path confirm karo
```

`bun` ka path alag ho to upar wali file mein wahi likho (`which bun` ka output).

vmail user ko repo read karna hoga:

```bash
chmod o+rx /opt /opt/anexomail-web /opt/anexomail-web/server /opt/anexomail-web/server/mail
chmod o+r /opt/anexomail-web/server/mail/deliver-to-supabase.ts
setfacl -m u:vmail:r /etc/anexomail/mail.env 2>/dev/null || (apt install -y acl && setfacl -m u:vmail:r /etc/anexomail/mail.env)
```

## 5B. Postfix ko pipe par bhejo (Dovecot + Supabase dono)

`always_bcc` se har aane wali mail ki ek copy pipe par jati hai:

```bash
postconf -e 'anexomail_destination_recipient_limit=1'
postconf -e 'recipient_bcc_maps=pcre:/etc/postfix/ingest-bcc'

cat > /etc/postfix/ingest-bcc <<'EOF'
# har anexomail.com recipient ki ek copy ingest@localhost par
/^(.+)@anexomail\.com$/   ingest+${1}@ingest.local
EOF

cat > /etc/postfix/transport <<'EOF'
ingest.local   anexomail:
EOF
postmap /etc/postfix/transport
postconf -e 'transport_maps=hash:/etc/postfix/transport'
postconf -e 'ingest_local_domains=ingest.local'
systemctl restart postfix
postfix check && echo "CONFIG OK"
```

`noreply@` ki inbound already `devnull` alias par ja rahi hai (step 2), is liye woh Supabase
mein nahi aati — yahi chahiye tha.

## 5C. Test (gate)

Gmail (ya kisi bahar wale address) se `hello@anexomail.com` par ek mail bhejo, subject:
`WIRE TEST 05`. Phir:

```bash
tail -n 40 /var/log/mail.log | grep -Ei 'anexomail-deliver|status=sent|status=bounced'
```

`anexomail-deliver: OK hello@anexomail.com {"ok":true,...}` dikhna chahiye.

Supabase SQL Editor:

```sql
select created_at, envelope_to, raw_size from public.mail_inbound_raw order by created_at desc limit 5;
select t.mailbox_address, t.subject, m.from_address, m.spf_result, m.dkim_result, left(m.body_text,60) as body
  from public.mail_messages m join public.mail_threads t on t.id = m.thread_id
 order by m.created_at desc limit 5;
```

Row dikhe, `spf_result=pass`, `dkim_result=pass` — tabhi green.

## 5D. Reply-chain aur duplicate test

Usi mail ka **reply** bhejo. Dobara query karo:

```sql
select id, subject, message_count from public.mail_threads order by last_message_at desc limit 3;
```

Naya thread **nahi** banna chahiye — usi thread ka `message_count` 2 hona chahiye.
Postfix ki retry par duplicate row bhi nahi banti (`message_id` unique + RPC guard).
