#!/usr/bin/env bash
# ANEXOMAIL — mail TLS cert monitor install (idempotent). Founder ek hi command chalata hai (memory file section 13.9):
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/mail-cert/install.sh)
# Kya karta hai: monitor + systemd timer lagata hai, ABHI ek baar chalata hai (cert sync), test alert bhejta hai, aur
# phir haal dikhata hai. Koi secret print nahi hota. Postfix/Dovecot sirf tab reload hote hain jab naya cert lagta hai.
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"
DIR="docs/cursor-work/server/mail-cert"
BIN="${BIN:-/usr/local/bin/anexomail-mail-cert-sync}"
UNITS="${UNITS:-/etc/systemd/system}"
CERT="${CERT:-/etc/anexomail/mail-cert.pem}"

src_get() { # SRC_DIR (test) ya git origin/main se
  if [ -n "${SRC_DIR:-}" ]; then cat "$SRC_DIR/$1"; else git -C "$REPO" show "origin/main:$DIR/$1"; fi
}
dates() { openssl x509 -noout -subject -issuer -dates -in "$1" 2>&1 | sed 's/^/   /'; }
served() { # kind host port
  if [ "$1" = smtp ]; then echo | timeout 15 openssl s_client -starttls smtp -connect "$2:$3" -servername mail.anexomail.com 2>/dev/null | openssl x509 -noout -enddate 2>&1
  else echo | timeout 15 openssl s_client -connect "$2:$3" -servername mail.anexomail.com 2>/dev/null | openssl x509 -noout -enddate 2>&1; fi
}

echo "== 1) pehle ka haal (installed cert)"; dates "$CERT"

mkdir -p /var/lib/anexomail /etc/anexomail "$(dirname "$BIN")" "$UNITS"
for f in anexomail-mail-cert-sync.sh anexomail-mail-cert.service anexomail-mail-cert.timer; do
  src_get "$f" >"/tmp/.amc.$f" 2>/dev/null && [ -s "/tmp/.amc.$f" ] || { echo "FAIL: $f repo se nahi mili (git fetch hua?)"; exit 2; }
done
install -m 755 /tmp/.amc.anexomail-mail-cert-sync.sh "$BIN"
install -m 644 /tmp/.amc.anexomail-mail-cert.service "$UNITS/anexomail-mail-cert.service"
install -m 644 /tmp/.amc.anexomail-mail-cert.timer "$UNITS/anexomail-mail-cert.timer"
rm -f /tmp/.amc.*
if [ ! -f /etc/anexomail/alert.env ]; then
  printf '# Founder inbox (naumansherwani.founder@anexomail.com) par alert HAMESHA jata hai.\n# Bahar ke email par bhi chahiye to yahan likho (space se alag), jaise:\n# ALERT_TO="aap@gmail.com"\n' >/etc/anexomail/alert.env
  chmod 640 /etc/anexomail/alert.env
fi
if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
  systemctl daemon-reload
  systemctl enable --now anexomail-mail-cert.timer >/dev/null 2>&1 || echo "WARN: timer enable nahi hua"
else
  echo "WARN: systemd nahi mila — timer nahi laga (script haath se chala sakte hain)"
fi
echo "== 2) abhi ek baar sync + test alert (Caddy ka naya cert ho to lagega)"
TEST_ALERT=1 "$BIN"; rc=$?
echo "   exit code: $rc  (0 = sab theek)"

sleep 4
echo " -- Postfix ne alert mail ka kya kiya (mail.log, aakhri 4 line):"
grep -h "monitor@anexomail.com" /var/log/mail.log 2>/dev/null | tail -4 | cut -c1-200 | sed 's/^/   /'
grep -h "status=" /var/log/mail.log 2>/dev/null | grep "naumansherwani.founder@" | tail -2 | cut -c1-200 | sed 's/^/   /'

echo "== 3) baad ka haal"
echo " -- installed cert"; dates "$CERT"
echo " -- jo server abhi de raha hai:"
echo "    993 (IMAPS)  : $(served imaps 127.0.0.1 993)"
echo "    587 (SMTP)   : $(served smtp 127.0.0.1 587)"
echo " -- status file"; cat "${STATE_DIR:-/var/lib/anexomail}/cert-status.json" 2>&1 | sed 's/^/   /'
echo " -- timer"; systemctl list-timers anexomail-mail-cert.timer --no-pager 2>&1 | sed 's/^/   /' | head -4
echo " -- Caddy ke store ke mail.anexomail.com certs (sirf dekha)"
for r in ${CADDY_ROOTS:-/var/lib/caddy/.local/share/caddy /root/.local/share/caddy /home/caddy/.local/share/caddy}; do
  [ -d "$r" ] && find "$r" -type f -name 'mail.anexomail.com.crt' 2>/dev/null | while read -r c; do echo "    $c  $(openssl x509 -noout -enddate -in "$c" 2>&1)"; done
done
echo " -- Caddyfile mein mail.anexomail.com (sirf dekha, badla nahi)"; grep -n "mail.anexomail.com" /etc/caddy/Caddyfile 2>&1 | head -5 | sed 's/^/   /'
echo "== 4) alert ka rasta: founder inbox mein '[ANEXOMAIL] Test alert' aani chahiye (1-2 minute). Bahar ke email ke liye /etc/anexomail/alert.env"
exit "$rc"
