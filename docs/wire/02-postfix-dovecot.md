# Step 2 — Postfix + Dovecot (virtual mailboxes)

Sab kuch copy-paste. `<IPV4>` ki zaroorat nahi, TLS cert Caddy se aata hai.

## 2A. Packages

```bash
apt update
DEBIAN_FRONTEND=noninteractive apt install -y postfix postfix-pcre dovecot-core dovecot-imapd dovecot-lmtpd opendkim opendkim-tools opendmarc mailutils
```

Postfix installer poochhe to: **Internet Site**, system mail name = `anexomail.com`.

## 2B. TLS cert (Caddy already isay le raha hai)

Caddy ka cert store `caddy:caddy` hota hai, is liye mail services ke liye **copy** banate hain
(cert rule: original ko chhoona mana).

```bash
mkdir -p /etc/anexomail/tls
cat > /usr/local/bin/anexomail-mail-cert.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
BASE=/var/lib/caddy/.local/share/caddy/certificates
SRC=$(find "$BASE" -type d -name 'mail.anexomail.com' | head -n1)
[ -n "$SRC" ] || { echo "cert not found — pehle Caddy par mail.anexomail.com serve karao"; exit 1; }
install -m 644 "$SRC/mail.anexomail.com.crt" /etc/anexomail/tls/mail.crt
install -m 640 -g dovecot "$SRC/mail.anexomail.com.key" /etc/anexomail/tls/mail.key
systemctl reload postfix dovecot || true
EOF
chmod +x /usr/local/bin/anexomail-mail-cert.sh
```

Caddy mein `mail.anexomail.com` ka ek chhota block hona chahiye (sirf cert ke liye):

```caddyfile
mail.anexomail.com {
	respond "ANEXOMAIL mail host" 200
}
```

phir:

```bash
caddy validate --config /etc/caddy/Caddyfile && systemctl reload caddy
sleep 20
/usr/local/bin/anexomail-mail-cert.sh
ls -l /etc/anexomail/tls
```

Roz auto-refresh:

```bash
( crontab -l 2>/dev/null; echo "17 4 * * * /usr/local/bin/anexomail-mail-cert.sh >/dev/null 2>&1" ) | crontab -
```

## 2C. Virtual mail user + folders

```bash
id vmail 2>/dev/null || (groupadd -g 5000 vmail && useradd -g vmail -u 5000 vmail -d /var/mail/vhosts -m)
mkdir -p /var/mail/vhosts/anexomail.com
chown -R vmail:vmail /var/mail/vhosts
chmod -R 770 /var/mail/vhosts
```

## 2D. Mailbox list + passwords

Passwords **sirf server par**. Yeh script random passwords banata hai aur
`/etc/anexomail/mail.env` (chmod 600) mein likhta hai. Repo mein kuch nahi jata.

```bash
mkdir -p /etc/anexomail && touch /etc/anexomail/mail.env && chmod 600 /etc/anexomail/mail.env

cat > /etc/dovecot/anexomail-users.txt <<'EOF'
hello@anexomail.com
moveyourbusiness@anexomail.com
support@anexomail.com
billing@anexomail.com
resolved@anexomail.com
trials@anexomail.com
abuse@anexomail.com
dmarc@anexomail.com
naumansherwani.founder@anexomail.com
leo@anexomail.com
EOF

: > /etc/dovecot/users
while read -r ADDR; do
  [ -z "$ADDR" ] && continue
  PW=$(openssl rand -base64 18 | tr -d '/+=' | cut -c1-20)
  HASH=$(doveadm pw -s SHA512-CRYPT -p "$PW")
  echo "${ADDR}:${HASH}:5000:5000::/var/mail/vhosts/anexomail.com/${ADDR%@*}::" >> /etc/dovecot/users
  KEY=$(echo "MAIL_PW_${ADDR%@*}" | tr 'a-z.-' 'A-Z__')
  echo "${KEY}='${PW}'" >> /etc/anexomail/mail.env
done < /etc/dovecot/anexomail-users.txt
chmod 640 /etc/dovecot/users; chown root:dovecot /etc/dovecot/users
chmod 600 /etc/anexomail/mail.env
echo "passwords likh diye: /etc/anexomail/mail.env (sirf yahan padho, kahin paste na karo)"
```

Aliases (`postmaster@` → `abuse@`, `nauman@` → founder):

```bash
cat > /etc/postfix/virtual-aliases <<'EOF'
postmaster@anexomail.com  abuse@anexomail.com
nauman@anexomail.com      naumansherwani.founder@anexomail.com
noreply@anexomail.com     devnull
EOF
postmap /etc/postfix/virtual-aliases
```

## 2E. `/etc/postfix/main.cf` (poora file — nano select-all → overwrite)

```bash
cp /etc/postfix/main.cf /etc/postfix/main.cf.bak.$(date +%s)
cat > /etc/postfix/main.cf <<'EOF'
# ANEXOMAIL — /etc/postfix/main.cf
compatibility_level = 3.6
smtpd_banner = $myhostname ESMTP
biff = no
append_dot_mydomain = no
readme_directory = no

myhostname = mail.anexomail.com
myorigin = /etc/mailname
mydestination = localhost
mynetworks = 127.0.0.0/8 [::1]/128
inet_interfaces = all
inet_protocols = all
mailbox_size_limit = 0
message_size_limit = 52428800
recipient_delimiter = +

# TLS (cert copy Caddy se)
smtpd_tls_cert_file = /etc/anexomail/tls/mail.crt
smtpd_tls_key_file  = /etc/anexomail/tls/mail.key
smtpd_tls_security_level = may
smtpd_tls_protocols = >=TLSv1.2
smtp_tls_security_level = may
smtp_tls_protocols = >=TLSv1.2
smtpd_tls_session_cache_database = btree:${data_directory}/smtpd_scache

# SASL via Dovecot (sirf submission par lazmi)
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_auth_enable = no

smtpd_relay_restrictions = permit_mynetworks permit_sasl_authenticated defer_unauth_destination
smtpd_recipient_restrictions = permit_mynetworks permit_sasl_authenticated reject_unauth_destination

# virtual domains -> Dovecot LMTP, plus ANEXOMAIL pipe
virtual_mailbox_domains = anexomail.com
virtual_mailbox_maps = hash:/etc/postfix/virtual-mailboxes
virtual_alias_maps = hash:/etc/postfix/virtual-aliases
virtual_transport = lmtp:unix:private/dovecot-lmtp

# DKIM / DMARC milters
milter_default_action = accept
milter_protocol = 6
smtpd_milters = inet:127.0.0.1:8891, inet:127.0.0.1:8893
non_smtpd_milters = inet:127.0.0.1:8891
EOF
echo anexomail.com > /etc/mailname

# mailbox map Dovecot users file se
awk -F: '{print $1" "$1}' /etc/dovecot/users > /etc/postfix/virtual-mailboxes
postmap /etc/postfix/virtual-mailboxes
```

## 2F. `/etc/postfix/master.cf` — submission 587 + smtps 465 + devnull

```bash
cp /etc/postfix/master.cf /etc/postfix/master.cf.bak.$(date +%s)
python3 - <<'EOF'
p='/etc/postfix/master.cf'
s=open(p).read()
add = """
submission inet n       -       y       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
smtps     inet  n       -       y       -       -       smtpd
  -o syslog_name=postfix/smtps
  -o smtpd_tls_wrappermode=yes
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
devnull   unix  -       n       n       -       -       pipe
  flags=  user=nobody argv=/bin/cat
anexomail  unix  -       n       n       -       10      pipe
  flags=DRhu user=vmail argv=/usr/local/bin/anexomail-deliver ${sender} ${recipient}
"""
if 'syslog_name=postfix/submission' not in s:
    s = s.rstrip() + add
open(p,'w').write(s)
print("master.cf updated")
EOF
```

## 2G. Dovecot config

```bash
cat > /etc/dovecot/local.conf <<'EOF'
protocols = imap lmtp
listen = *, ::
mail_location = maildir:/var/mail/vhosts/anexomail.com/%n
mail_privileged_group = vmail
first_valid_uid = 5000
first_valid_gid = 5000

passdb {
  driver = passwd-file
  args = scheme=SHA512-CRYPT username_format=%u /etc/dovecot/users
}
userdb {
  driver = passwd-file
  args = username_format=%u /etc/dovecot/users
  default_fields = uid=vmail gid=vmail home=/var/mail/vhosts/anexomail.com/%n
}

ssl = yes
ssl_cert = </etc/anexomail/tls/mail.crt
ssl_key  = </etc/anexomail/tls/mail.key
ssl_min_protocol = TLSv1.2

service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0660
    user = postfix
    group = postfix
  }
}
service lmtp {
  unix_listener /var/spool/postfix/private/dovecot-lmtp {
    mode = 0600
    user = postfix
    group = postfix
  }
}
protocol lmtp {
  mail_plugins = $mail_plugins sieve
}
EOF

systemctl restart dovecot postfix
systemctl --no-pager -l status dovecot postfix | head -30
```

## 2H. Verify (gate)

```bash
ss -lntp | grep -E ':(25|465|587|993)\b'
doveadm user '*' | head
echo | openssl s_client -connect 127.0.0.1:993 -quiet 2>&1 | head -3
postfix check && echo "POSTFIX CONFIG OK"
```

Sab lines aayein tabhi step 3. `journalctl -u postfix -n 50` se error dekh sakte ho.
