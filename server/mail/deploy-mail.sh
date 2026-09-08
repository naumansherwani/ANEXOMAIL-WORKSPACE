#!/usr/bin/env bash
# ============================================================================
# ANEXOMAIL — MAIL STACK auto-deploy (Postfix + Dovecot + OpenDKIM)
#
#   cd /opt/anexomail-web && git pull && bash server/mail/deploy-mail.sh
#
# Koi nano, koi manual edit. Script khud:
#   1. packages install (agar missing)
#   2. hostname/PTR identity = mail.anexomail.com
#   3. 13 addresses ke mailbox/alias maps (virtual users, koi system user nahi)
#   4. mailbox passwords khud generate -> /etc/anexomail/mail.env (chmod 600)
#      REPO MEIN KABHI NAHI
#   5. inbound pipe -> Supabase (server/mail/deliver-to-supabase.ts, Bun)
#   6. DKIM key + DNS ke liye exact TXT value print
#   7. services restart + reading
# Idempotent: dobara chalane par purani config .bak.<ts> ban kar refresh hoti hai.
# ============================================================================
set -uo pipefail

DOMAIN=anexomail.com
MAILHOST=mail.anexomail.com
REPO=/opt/anexomail-web
ENVFILE=/etc/anexomail/mail.env
STAMP="$(date +%s)"
BUN="$(command -v bun || echo /root/.bun/bin/bun)"

MAILBOXES="hello moveyourbusiness resolved billing trials abuse dmarc naumansherwani.founder leo"
SENDONLY="noreply"
# alias:target
ALIASES="postmaster:abuse nauman:naumansherwani.founder support:resolved"

echo "==> packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq postfix postfix-pcre dovecot-imapd dovecot-lmtpd \
  opendkim opendkim-tools dnsutils curl ca-certificates >/dev/null

echo "==> hostname identity ($MAILHOST)"
hostnamectl set-hostname "$MAILHOST" || true
grep -q "$MAILHOST" /etc/hosts || echo "127.0.1.1 $MAILHOST" >> /etc/hosts

mkdir -p /etc/anexomail /var/mail/vhosts/"$DOMAIN" /var/log/anexomail
id vmail >/dev/null 2>&1 || useradd -r -u 5000 -d /var/mail/vhosts -s /usr/sbin/nologin vmail
chown -R vmail:vmail /var/mail/vhosts

# --------------------------------------------------------------------------
# 1) Passwords: sirf server par, sirf ek dafa generate
# --------------------------------------------------------------------------
touch "$ENVFILE"; chmod 600 "$ENVFILE"
add_pw() {
  local key="MAILPW_$(printf '%s' "$1" | tr '.a-z' '_A-Z')"
  grep -q "^$key=" "$ENVFILE" || printf '%s=%s\n' "$key" "$(openssl rand -base64 24 | tr -d '=+/')" >> "$ENVFILE"
}
for m in $MAILBOXES $SENDONLY; do add_pw "$m"; done
# shellcheck disable=SC1090
set -a; . "$ENVFILE"; set +a

# --------------------------------------------------------------------------
# 2) Dovecot virtual users
# --------------------------------------------------------------------------
# purani/toota local.conf pehle hata do — warna `doveadm pw` bhi usay padh kar
# fail hota hai (yeh "Unknown setting: mail_location" ki asli wajah thi).
if [ -f /etc/dovecot/local.conf ]; then
  mv /etc/dovecot/local.conf /etc/dovecot/local.conf.bak.$STAMP
fi
: > /etc/dovecot/users.tmp
for m in $MAILBOXES $SENDONLY; do
  key="MAILPW_$(printf '%s' "$m" | tr '.a-z' '_A-Z')"
  pw="${!key}"
  hash="$(doveadm pw -s SHA512-CRYPT -p "$pw")"
  printf '%s@%s:%s:5000:5000::/var/mail/vhosts/%s/%s::\n' "$m" "$DOMAIN" "$hash" "$DOMAIN" "$m" >> /etc/dovecot/users.tmp
done
[ -f /etc/dovecot/users ] && cp /etc/dovecot/users /etc/dovecot/users.bak.$STAMP
mv /etc/dovecot/users.tmp /etc/dovecot/users
chown root:dovecot /etc/dovecot/users; chmod 640 /etc/dovecot/users

[ -f /etc/dovecot/local.conf ] && cp /etc/dovecot/local.conf /etc/dovecot/local.conf.bak.$STAMP

# Dovecot 2.4 ne setting ke naam badal diye (mail_location -> mail_driver+mail_path,
# passdb/userdb named blocks, ssl_server block). Version dekh kar sahi config likhi
# jaati hai — is liye 2.3 aur 2.4 dono par service start hoti hai.
DOVEVER="$(doveconf --version 2>/dev/null | awk '{print $1}' || dovecot --version 2>/dev/null | awk '{print $1}')"
case "${DOVEVER:-2.3}" in
  2.4*|3.*) DOVE_NEW=1 ;;
  *)        DOVE_NEW=0 ;;
esac
echo "==> dovecot version ${DOVEVER:-unknown} (new-syntax=$DOVE_NEW)"

if [ "$DOVE_NEW" = "1" ]; then
cat > /etc/dovecot/local.conf <<EOF
dovecot_config_version = 2.4.0
dovecot_storage_version = 2.4.0

protocols = imap lmtp
mail_driver = maildir
mail_path = /var/mail/vhosts/%{user | domain}/%{user | username}
mail_uid = vmail
mail_gid = vmail
first_valid_uid = 5000
auth_allow_cleartext = no
auth_mechanisms = plain login

passdb passwd-file {
  passwd_file_path = /etc/dovecot/users
  default_password_scheme = SHA512-CRYPT
}
userdb passwd-file {
  passwd_file_path = /etc/dovecot/users
  fields {
    uid = vmail
    gid = vmail
    home = /var/mail/vhosts/%{user | domain}/%{user | username}
  }
}

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

ssl = required
ssl_server {
  cert_file = /etc/anexomail/mail-cert.pem
  key_file  = /etc/anexomail/mail-key.pem
}
EOF
else
cat > /etc/dovecot/local.conf <<EOF
protocols = imap lmtp
mail_location = maildir:/var/mail/vhosts/%d/%n
mail_uid = vmail
mail_gid = vmail
first_valid_uid = 5000
disable_plaintext_auth = yes
auth_mechanisms = plain login
passdb {
  driver = passwd-file
  args = scheme=SHA512-CRYPT username_format=%u /etc/dovecot/users
}
userdb {
  driver = passwd-file
  args = username_format=%u /etc/dovecot/users
  default_fields = uid=vmail gid=vmail home=/var/mail/vhosts/%d/%n
}
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
ssl = required
ssl_cert = </etc/anexomail/mail-cert.pem
ssl_key  = </etc/anexomail/mail-key.pem
EOF
fi


# TLS cert: Caddy ka cert copy, warna self-signed (gate sach report karega)
CADDY_CERTS=/var/lib/caddy/.local/share/caddy/certificates
SRC="$(find "$CADDY_CERTS" -type d -name "*$MAILHOST*" 2>/dev/null | head -1 || true)"
if [ -n "${SRC:-}" ] && [ -f "$SRC/$MAILHOST.crt" ]; then
  cp "$SRC/$MAILHOST.crt" /etc/anexomail/mail-cert.pem
  cp "$SRC/$MAILHOST.key" /etc/anexomail/mail-key.pem
  echo ">>> TLS cert Caddy se liya ($MAILHOST)"
elif [ ! -f /etc/anexomail/mail-cert.pem ]; then
  openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
    -subj "/CN=$MAILHOST" -keyout /etc/anexomail/mail-key.pem \
    -out /etc/anexomail/mail-cert.pem >/dev/null 2>&1
  echo ">>> TLS: temporary self-signed (Caddy cert aane par script dobara chalao)"
fi
chmod 600 /etc/anexomail/mail-key.pem

# --------------------------------------------------------------------------
# 3) Postfix maps
# --------------------------------------------------------------------------
{ echo "$DOMAIN OK"; } > /etc/postfix/vdomains
: > /etc/postfix/vmailbox
: > /etc/postfix/valias
for m in $MAILBOXES $SENDONLY; do
  printf '%s@%s  %s/%s/\n' "$m" "$DOMAIN" "$DOMAIN" "$m" >> /etc/postfix/vmailbox
done
for pair in $ALIASES; do
  printf '%s@%s  %s@%s\n' "${pair%%:*}" "$DOMAIN" "${pair##*:}" "$DOMAIN" >> /etc/postfix/valias
done
postmap /etc/postfix/vdomains /etc/postfix/vmailbox /etc/postfix/valias

echo "==> postfix main.cf"
postconf -e "myhostname = $MAILHOST"
postconf -e "myorigin = $DOMAIN"
postconf -e "mydestination = localhost"
postconf -e "inet_interfaces = all"
postconf -e "inet_protocols = ipv4"
postconf -e "virtual_mailbox_domains = hash:/etc/postfix/vdomains"
postconf -e "virtual_mailbox_maps = hash:/etc/postfix/vmailbox"
postconf -e "virtual_alias_maps = hash:/etc/postfix/valias"
postconf -e "virtual_transport = anexopipe:"
postconf -e "smtpd_tls_cert_file = /etc/anexomail/mail-cert.pem"
postconf -e "smtpd_tls_key_file = /etc/anexomail/mail-key.pem"
postconf -e "smtpd_tls_security_level = may"
postconf -e "smtp_tls_security_level = may"
postconf -e "smtpd_sasl_type = dovecot"
postconf -e "smtpd_sasl_path = private/auth"
postconf -e "smtpd_sasl_auth_enable = yes"
postconf -e "smtpd_recipient_restrictions = permit_mynetworks,permit_sasl_authenticated,reject_unauth_destination"
postconf -e "milter_default_action = accept"
postconf -e "smtpd_milters = inet:127.0.0.1:8891"
postconf -e "non_smtpd_milters = inet:127.0.0.1:8891"
postconf -e "message_size_limit = 52428800"

# inbound pipe -> Supabase (Bun). Supabase down ho to mail queue mein rukti hai.
cp /etc/postfix/master.cf /etc/postfix/master.cf.bak.$STAMP
grep -q '^anexopipe' /etc/postfix/master.cf || cat >> /etc/postfix/master.cf <<EOF

anexopipe unix  -       n       n       -       10      pipe
  flags=DRhu user=vmail argv=$BUN $REPO/server/mail/deliver-to-supabase.ts \${recipient} \${sender}
EOF

# submission (587)
grep -qE '^submission' /etc/postfix/master.cf || cat >> /etc/postfix/master.cf <<'EOF'

submission inet n       -       y       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
EOF

# implicit TLS submission (465)
grep -qE '^submissions[[:space:]]' /etc/postfix/master.cf || cat >> /etc/postfix/master.cf <<'EOF'

submissions inet n       -       y       -       -       smtpd
  -o syslog_name=postfix/submissions
  -o smtpd_tls_wrappermode=yes
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
EOF

# --------------------------------------------------------------------------
# 4) OpenDKIM
# --------------------------------------------------------------------------
echo "==> DKIM"
mkdir -p /etc/opendkim/keys/$DOMAIN
if [ ! -f /etc/opendkim/keys/$DOMAIN/mail.private ]; then
  opendkim-genkey -b 2048 -d "$DOMAIN" -D /etc/opendkim/keys/$DOMAIN -s mail
fi
chown -R opendkim:opendkim /etc/opendkim
chmod 600 /etc/opendkim/keys/$DOMAIN/mail.private
printf 'mail._domainkey.%s %s:mail:/etc/opendkim/keys/%s/mail.private\n' "$DOMAIN" "$DOMAIN" "$DOMAIN" > /etc/opendkim/KeyTable
printf '*@%s mail._domainkey.%s\n' "$DOMAIN" "$DOMAIN" > /etc/opendkim/SigningTable
printf '127.0.0.1\nlocalhost\n%s\n' "$DOMAIN" > /etc/opendkim/TrustedHosts
[ -f /etc/opendkim.conf ] && cp /etc/opendkim.conf /etc/opendkim.conf.bak.$STAMP
cat > /etc/opendkim.conf <<'EOF'
Syslog                  yes
UMask                   007
Mode                    sv
Canonicalization        relaxed/simple
KeyTable                /etc/opendkim/KeyTable
SigningTable            refile:/etc/opendkim/SigningTable
ExternalIgnoreList      /etc/opendkim/TrustedHosts
InternalHosts           /etc/opendkim/TrustedHosts
Socket                  inet:8891@127.0.0.1
PidFile                 /run/opendkim/opendkim.pid
OversignHeaders         From
UserID                  opendkim:opendkim
EOF

echo "==> firewall (agar ufw active)"
if command -v ufw >/dev/null 2>&1; then
  for p in 25/tcp 465/tcp 587/tcp 993/tcp; do ufw allow "$p" >/dev/null 2>&1 || true; done
fi

echo "==> restart services"
systemctl enable --now opendkim >/dev/null 2>&1 || true
systemctl restart opendkim
if ! doveconf -n >/dev/null 2>/tmp/anexo-dovecot.err; then
  echo ">>> DOVECOT CONFIG ERROR:"; cat /tmp/anexo-dovecot.err
fi
systemctl restart dovecot || journalctl -xeu dovecot --no-pager | tail -n 20

systemctl restart postfix

echo
echo "=============================================================="
echo "DNS ke liye DKIM TXT value (registrar par name: mail._domainkey)"
echo "=============================================================="
awk -F'"' '{ for (i=2; i<=NF; i+=2) printf "%s", $i } END { print "" }' \
  /etc/opendkim/keys/$DOMAIN/mail.txt
echo
echo "=============================================================="
echo "readings:"
for s in postfix dovecot opendkim; do printf '  %-9s %s\n' "$s" "$(systemctl is-active $s)"; done
echo "  passwords: $ENVFILE (chmod 600, repo mein kuch nahi)"
echo "  next: cd $REPO && bash server/gates/mail-gate.sh"
