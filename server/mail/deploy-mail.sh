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
#   4. mailbox passwords khud generate -> /etc/anexomail/mail.env (chmod 640 root:vmail)
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
BUNSRC="$(command -v bun || echo /root/.bun/bin/bun)"
# Postfix ka pipe vmail user se chalta hai; /root/... kabhi read nahi kar sakta
# (execvp ... Permission denied). Is liye bun ki ek copy sab ke liye readable jagah par.
BUN=/usr/local/bin/anexo-bun

      # FINAL LIST (locked 8 Sep 2026, founder ka faisla)
#   real mailbox: hello moveyourbusiness resolved billing leo
#                 naumansherwani.founder (founder ka ek hi inbox)
#                 humzasherwani (brother) raanasherwani (mother) — aam user premium
#   sendonly:     noreply
#   forward-only: postmaster abuse dmarc  -> sab resolved@ (koi inbox/password nahi)
#   DELETED:      nauman support trials   (backup ke baad root se)
MAILBOXES="hello moveyourbusiness resolved billing leo naumansherwani.founder humzasherwani raanasherwani"
SENDONLY="noreply"
# alias:target
ALIASES="postmaster:resolved abuse:resolved dmarc:resolved"
# in addresses ka mailbox/alias khatam — maildir backup ke baad delete
REMOVED="nauman support trials abuse dmarc postmaster"

# FOUNDER SINGLE INBOX (locked 8 Sep 2026)
#   - founder ka ek hi inbox: naumansherwani.founder@anexomail.com
#   - company addresses ki mail apni box mein bhi rehti hai AUR founder inbox mein
#     bhi copy hoti hai. Family accounts (humza/raana) ki mail KABHI copy nahi hoti.
#   - founder-side logins ka password EK; family accounts ka apna password
#   - recovery account: anexomail27@gmail.com (password kabhi print nahi hota)
FOUNDER_INBOX="naumansherwani.founder"
FOUNDER_COPY="hello moveyourbusiness resolved billing leo"
FAMILY_BOXES="humzasherwani raanasherwani"
FOUNDER_RECOVERY="anexomail27@gmail.com"


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
# Pipe vmail user se chalti hai, is liye env file vmail GROUP ko readable honi
# chahiye (600 root-only tha — asli wajah ke "SUPABASE_URL missing in
# /etc/anexomail/mail.env" queue mein aata tha). World-readable kabhi nahi.
touch "$ENVFILE"; chown root:vmail "$ENVFILE"; chmod 640 "$ENVFILE"
chmod 755 /etc/anexomail

# Inbound pipe ko do server values chahiye. Unhein repo mein rakhna mana hai,
# is liye existing protected app env se mail.env mein one-time sync karte hain.
# Value kabhi terminal par print nahi hoti aur existing mail.env value overwrite
# nahi hoti. Agar kisi source mein na mile to deploy foran exact reason se rukta hai.
sync_secret() {
  local target="$1" source_key="$2" source value
  grep -q -E "^${target}=.+" "$ENVFILE" && return 0
  for source in /root/.anexomail.env /opt/anexomail/.env /opt/anexomail-web/.env; do
    [ -r "$source" ] || continue
    value="$(grep -am1 -E "^[[:space:]]*(export[[:space:]]+)?${source_key}=" "$source" | cut -d= -f2- || true)"
    value="${value#\"}"; value="${value%\"}"; value="${value#\'}"; value="${value%\'}"
    if [ -n "$value" ]; then
      printf '%s=%s\n' "$target" "$value" >> "$ENVFILE"
      echo ">>> $target protected env se mail pipe mein sync"
      return 0
    fi
  done
  return 1
}

sync_database_value() {
  local target="$1" primary="$2" fallback="$3"
  sync_secret "$target" "$primary" || sync_secret "$target" "$fallback" || {
    echo ">>> RED: $primary / $fallback kisi protected server env mein nahi mila"
    return 1
  }
}

MAIL_ENV_OK=1
sync_database_value SUPABASE_URL SUPABASE4_URL SUPABASE_URL || MAIL_ENV_OK=0
sync_database_value SUPABASE_SERVICE_ROLE_KEY SUPABASE4_SERVICE_ROLE_KEY SUPABASE_SERVICE_ROLE_KEY || MAIL_ENV_OK=0
if [ "$MAIL_ENV_OK" -ne 1 ]; then
  echo ">>> /root/.anexomail.env ya /opt/anexomail/.env mein missing value rakho, phir yahi deploy command dobara chalao."
  exit 2
fi

# FOUNDER SINGLE PASSWORD: ek hi value founder-side mailboxes par. Sirf ek dafa
# banti hai, terminal par kabhi print nahi hoti, existing value overwrite nahi hoti.
grep -q -E '^FOUNDER_MAIL_PASSWORD=.+' "$ENVFILE" || \
  printf 'FOUNDER_MAIL_PASSWORD=%s\n' "$(openssl rand -base64 24 | tr -d '=+/')" >> "$ENVFILE"
grep -q -E '^FOUNDER_MAIL_RECOVERY=' "$ENVFILE" || \
  printf 'FOUNDER_MAIL_RECOVERY=%s\n' "$FOUNDER_RECOVERY" >> "$ENVFILE"
# FAMILY ACCOUNTS: apna alag password (founder ka password unke pass nahi jata)
for f in $FAMILY_BOXES; do
  key="FAMILY_$(echo "$f" | tr 'a-z.' 'A-Z_')_PASSWORD"
  grep -q -E "^${key}=.+" "$ENVFILE" || \
    printf '%s=%s\n' "$key" "$(openssl rand -base64 24 | tr -d '=+/')" >> "$ENVFILE"
done
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
FOUNDER_HASH="$(doveadm pw -s SHA512-CRYPT -p "$FOUNDER_MAIL_PASSWORD")"
for m in $MAILBOXES $SENDONLY; do
  HASH="$FOUNDER_HASH"
  case " $FAMILY_BOXES " in
    *" $m "*)
      key="FAMILY_$(echo "$m" | tr 'a-z.' 'A-Z_')_PASSWORD"
      HASH="$(doveadm pw -s SHA512-CRYPT -p "$(eval "printf '%s' \"\$$key\"")")"
      ;;
  esac
  printf '%s@%s:%s:5000:5000::/var/mail/vhosts/%s/%s::\n' "$m" "$DOMAIN" "$HASH" "$DOMAIN" "$m" >> /etc/dovecot/users.tmp
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
# IMAP 143 internal path ke liye (plaintext auth band hai), IMAPS 993 public.
# Firewall mein 143 kabhi allow nahi hota — bahar se sirf 993 pohanchta hai.
service imap-login {
  inet_listener imap {
    port = 143
  }
  inet_listener imaps {
    port = 993
    ssl = yes
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
# IMAP 143 internal (plaintext auth band), IMAPS 993 public. 143 firewall mein band.
service imap-login {
  inet_listener imap {
    port = 143
  }
  inet_listener imaps {
    port = 993
    ssl = yes
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
# FOUNDER SINGLE INBOX: sirf company addresses ki copy founder inbox mein jaati hai.
# Family accounts (humza/raana) ki mail founder inbox mein KABHI nahi.
for m in $FOUNDER_COPY; do
  [ "$m" = "$FOUNDER_INBOX" ] && continue
  printf '%s@%s  %s@%s, %s@%s\n' "$m" "$DOMAIN" "$m" "$DOMAIN" "$FOUNDER_INBOX" "$DOMAIN" >> /etc/postfix/valias
done
postmap /etc/postfix/vdomains /etc/postfix/vmailbox /etc/postfix/valias

# --------------------------------------------------------------------------
# 3b) DELETED addresses — backup pehle, phir root se delete
# --------------------------------------------------------------------------
BACKUPDIR=/var/backups/anexomail/maildirs-$STAMP
for m in $REMOVED; do
  BOX="/var/mail/vhosts/$DOMAIN/$m"
  if [ -d "$BOX" ]; then
    mkdir -p "$BACKUPDIR"
    cp -a "$BOX" "$BACKUPDIR/$m"
    rm -rf "$BOX"
    echo ">>> deleted mailbox $m@$DOMAIN (backup: $BACKUPDIR/$m)"
  fi
done


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

# bun ki readable copy (pipe vmail user se chalti hai)
echo "==> bun runtime copy for postfix pipe"
if [ -x "$BUNSRC" ]; then
  install -m 0755 -o root -g root "$BUNSRC" "$BUN"
else
  echo ">>> bun nahi mila ($BUNSRC) — inbound pipe kaam nahi karegi"
fi
# repo path bhi vmail ke liye traversable hona chahiye
chmod o+rx /opt /opt/anexomail-web 2>/dev/null || true
chmod -R o+rX "$REPO/server/mail" 2>/dev/null || true

# inbound pipe -> Supabase (Bun). Supabase down ho to mail queue mein rukti hai.
cp /etc/postfix/master.cf /etc/postfix/master.cf.bak.$STAMP
# purani anexopipe entry (galat bun path) hamesha refresh — warna Permission denied rehta hai
sed -i '/^anexopipe/,+1d' /etc/postfix/master.cf
cat >> /etc/postfix/master.cf <<EOF

anexopipe unix  -       n       n       -       10      pipe
  flags=DRhu user=vmail argv=$BUN $REPO/server/mail/deliver-to-supabase.ts \${sender} \${recipient}
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
DKIM_CREATED=0
if [ ! -f /etc/opendkim/keys/$DOMAIN/mail.private ]; then
  opendkim-genkey -b 2048 -d "$DOMAIN" -D /etc/opendkim/keys/$DOMAIN -s mail
  DKIM_CREATED=1
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
postqueue -f >/dev/null 2>&1 || true

if [ "$DKIM_CREATED" -eq 1 ] || [ "${SHOW_DKIM_TXT:-0}" = "1" ]; then
echo
echo "=============================================================="
echo "DNS ke liye DKIM TXT value (registrar par name: mail._domainkey)"
echo "=============================================================="
awk -F'"' '{ for (i=2; i<=NF; i+=2) printf "%s", $i } END { print "" }' \
  /etc/opendkim/keys/$DOMAIN/mail.txt
echo
fi
opendkim-testkey -d "$DOMAIN" -s mail -k /etc/opendkim/keys/"$DOMAIN"/mail.private >/dev/null 2>&1 || true
echo "=============================================================="
echo "readings:"
for s in postfix dovecot opendkim; do printf '  %-9s %s\n' "$s" "$(systemctl is-active $s)"; done
echo "  passwords: $ENVFILE (chmod 640 root:vmail, repo mein kuch nahi)"
echo "  inbound DB env: ready (values hidden)"
echo "  next: cd $REPO && bash server/gates/mail-gate.sh"
