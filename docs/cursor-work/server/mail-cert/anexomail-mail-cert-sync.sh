#!/usr/bin/env bash
# ============================================================================
# anexomail-mail-cert-sync — mail TLS cert hamesha Caddy ke taza cert ke barabar, aur expire se pehle founder ko alert.
#
# Asli wajah (17 Oct 2026): server/mail/deploy-mail.sh ne Caddy ka cert EK BAAR copy kiya (18 Sep). Caddy apna cert
# khud renew karta hai (har ~60 din), magar /etc/anexomail/mail-cert.pem ki copy ko koi refresh nahi karta tha:
# IMAP (993/143) aur SMTP submission (587/465) ka cert 2 Nov 2026 ko expire hota.
#
# Yeh script (systemd timer se din mein 2 baar):
#   1. Caddy ke store mein mail.anexomail.com ke SAB certs dekhta hai; sab se door ki expiry wala jo (a) abhi valid ho
#      aur (b) jiski key us cert se milti ho.
#   2. Woh installed cert se naya ho to atomic lagata hai (purana backup), postfix + dovecot reload karta hai.
#   3. LIVE verify: 993 (IMAPS) aur 587 (SMTP STARTTLS) par jo cert mil raha hai woh wahi hai jo abhi lagaya.
#      Mismatch ho to Dovecot restart; phir bhi na ho to PURANA WAPAS + alert.
#   4. Installed cert mein <21 din (ya masla) ho to email alert: founder ke inbox + /etc/anexomail/alert.env ka ALERT_TO.
#      Same level ka alert din mein ek hi baar. Sab theek ho to khamosh.
#   5. /var/lib/anexomail/cert-status.json likhta hai (app / monitoring ke liye).
#
# Exit 0 = sab theek; 1 = masla (systemd `--failed` mein dikhega).
# Env overrides (sirf test ke liye): CERT KEY CADDY_ROOTS STATE_DIR SENDMAIL RELOAD_CMD RESTART_DOVECOT_CMD LIVE_CHECKS
# ============================================================================
set -uo pipefail

HOST="${MAILHOST:-mail.anexomail.com}"
CERT="${CERT:-/etc/anexomail/mail-cert.pem}"
KEY="${KEY:-/etc/anexomail/mail-key.pem}"
STATE_DIR="${STATE_DIR:-/var/lib/anexomail}"
ALERT_ENV="${ALERT_ENV:-/etc/anexomail/alert.env}"
WARN_DAYS="${WARN_DAYS:-21}"
URGENT_DAYS="${URGENT_DAYS:-7}"
FOUNDER_INBOX="${FOUNDER_INBOX:-naumansherwani.founder@anexomail.com}"
SENDMAIL="${SENDMAIL:-/usr/sbin/sendmail}"
CADDY_ROOTS="${CADDY_ROOTS:-/var/lib/caddy/.local/share/caddy /root/.local/share/caddy /home/caddy/.local/share/caddy}"
RELOAD_CMD="${RELOAD_CMD:-postfix reload; doveadm reload}"
RESTART_DOVECOT_CMD="${RESTART_DOVECOT_CMD:-systemctl restart dovecot}"
LIVE_CHECKS="${LIVE_CHECKS:-imaps:127.0.0.1:993 smtp:127.0.0.1:587}"
TEST_ALERT="${TEST_ALERT:-0}"
NOW="$(date +%s)"
TODAY="$(date +%F)"

ALERT_TO=""
# shellcheck disable=SC1090
[ -f "$ALERT_ENV" ] && . "$ALERT_ENV"
ALERT_TO="${ALERT_TO:-}"

mkdir -p "$STATE_DIR"

log() { echo "[$(date '+%F %T')] $*"; logger -t anexomail-cert "$*" 2>/dev/null || true; }

end_epoch() { # file -> unix time of notAfter (0 agar parh na sake)
  local e
  e="$(openssl x509 -noout -enddate -in "$1" 2>/dev/null | cut -d= -f2)"
  if [ -n "$e" ]; then date -d "$e" +%s 2>/dev/null || echo 0; else echo 0; fi
}
pub_of_cert() { openssl x509 -noout -pubkey -in "$1" 2>/dev/null | openssl sha256 2>/dev/null | awk '{print $NF}'; }
pub_of_key() { openssl pkey -pubout -in "$1" 2>/dev/null | openssl sha256 2>/dev/null | awk '{print $NF}'; }
iso() { date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "?"; }

live_end() { # "kind:host:port" -> notAfter jo server abhi de raha hai
  local kind="${1%%:*}" rest="${1#*:}" h p
  h="${rest%%:*}"
  p="${rest##*:}"
  if [ "$kind" = smtp ]; then
    echo | timeout 15 openssl s_client -starttls smtp -connect "$h:$p" -servername "$HOST" 2>/dev/null |
      openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2
  else
    echo | timeout 15 openssl s_client -connect "$h:$p" -servername "$HOST" 2>/dev/null |
      openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2
  fi
}
LIVE_DETAIL=""
live_ok() { # want_epoch -> 0 agar har check wahi cert de raha hai
  local want="$1" c e ep bad=0
  LIVE_DETAIL=""
  for c in $LIVE_CHECKS; do
    e="$(live_end "$c")"
    if [ -n "$e" ]; then ep="$(date -d "$e" +%s 2>/dev/null || echo 0)"; else ep=0; fi
    if [ "$ep" != "$want" ]; then
      bad=1
      LIVE_DETAIL="$LIVE_DETAIL ${c%%:*}(served=${e:-none})"
    fi
  done
  return "$bad"
}

send_alert() { # level subject body — same level din mein ek hi baar (FORCE_ALERT=1 se tod sakte hain)
  local level="$1" subj="$2" body="$3" day_file="$STATE_DIR/alert-$1.day" to
  if [ "${FORCE_ALERT:-0}" != 1 ] && [ -f "$day_file" ] && [ "$(cat "$day_file" 2>/dev/null)" = "$TODAY" ]; then
    log "alert[$level] aaj pehle hi bheja ja chuka"
    return 0
  fi
  log "ALERT[$level] $subj"
  to="$(echo "$FOUNDER_INBOX $ALERT_TO" | tr -s ' ' ',' | sed 's/^,//; s/,$//; s/,/, /g')"
  if printf 'From: ANEXOMAIL Monitor <monitor@anexomail.com>\nTo: %s\nSubject: %s\nDate: %s\nX-Priority: 1\nMIME-Version: 1.0\nContent-Type: text/plain; charset=utf-8\n\n%s\n' \
    "$to" "$subj" "$(date -R)" "$body" | "$SENDMAIL" -t -f monitor@anexomail.com; then
    echo "$TODAY" >"$day_file"
  else
    log "ALERT email bhejna fail ($SENDMAIL) — journal mein hai; agli run dobara koshish karegi"
  fi
}

# ---------------------------------------------------------------------------
# 1) Caddy ka sab se door expiry wala valid, key-matched cert
# ---------------------------------------------------------------------------
cur_end="$(end_epoch "$CERT")"
best=""
best_end=0
for root in $CADDY_ROOTS; do
  [ -d "$root" ] || continue
  while IFS= read -r crt; do
    key="${crt%.crt}.key"
    [ -f "$key" ] || continue
    e="$(end_epoch "$crt")"
    [ "$e" -gt "$NOW" ] || continue
    pc="$(pub_of_cert "$crt")"
    [ -n "$pc" ] && [ "$pc" = "$(pub_of_key "$key")" ] || continue
    if [ "$e" -gt "$best_end" ]; then
      best="$crt"
      best_end="$e"
    fi
  done < <(find "$root" -type f -name "$HOST.crt" 2>/dev/null)
done

SYNCED=0
PROBLEM=""
if [ -z "$best" ]; then
  PROBLEM="Caddy ke store mein $HOST ka valid (key-matched) cert nahi mila. Dekha gaya: $CADDY_ROOTS. Ho sakta hai Caddyfile mein $HOST ka block hata/badal gaya ho — tab Caddy isay renew nahi karta."
elif [ "$best_end" -gt "$cur_end" ]; then
  # ---- 2) atomic install (purana backup) ----
  BK="$STATE_DIR/cert-backup/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$BK"
  cp -p "$CERT" "$BK/cert.pem" 2>/dev/null || true
  cp -p "$KEY" "$BK/key.pem" 2>/dev/null || true
  tc="$(mktemp "$(dirname "$CERT")/.cert.XXXXXX")"
  tk="$(mktemp "$(dirname "$KEY")/.key.XXXXXX")"
  cp "$best" "$tc"
  cp "${best%.crt}.key" "$tk"
  chmod 644 "$tc"
  chmod 600 "$tk"
  mv -f "$tk" "$KEY"
  mv -f "$tc" "$CERT"
  log "naya cert laga diya (notAfter $(iso "$best_end")), reload..."
  eval "$RELOAD_CMD" >/dev/null 2>&1 || log "reload command ne error diya"
  sleep 2
  want="$(end_epoch "$CERT")"
  if ! live_ok "$want"; then
    log "live cert mismatch ($LIVE_DETAIL) — dovecot restart"
    eval "$RESTART_DOVECOT_CMD" >/dev/null 2>&1 || true
    sleep 2
  fi
  if live_ok "$want"; then
    SYNCED=1
  else
    # restore-on-fail: purana cert wapas
    [ -f "$BK/cert.pem" ] && cp -p "$BK/cert.pem" "$CERT"
    [ -f "$BK/key.pem" ] && cp -p "$BK/key.pem" "$KEY"
    eval "$RELOAD_CMD" >/dev/null 2>&1 || true
    PROBLEM="Naya cert lagane ke baad live check fail ($LIVE_DETAIL) — purana cert wapas rakha. Haath se dekhna padega."
  fi
fi

# ---------------------------------------------------------------------------
# 3) Haal + status file
# ---------------------------------------------------------------------------
cert_end="$(end_epoch "$CERT")"
days_left=$(((cert_end - NOW) / 86400))
[ "$cert_end" -eq 0 ] && days_left=-9999
OK=true
{ [ -n "$PROBLEM" ] || [ "$days_left" -lt "$WARN_DAYS" ]; } && OK=false
esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' '; }
cat >"$STATE_DIR/cert-status.json.tmp" <<JSON
{"checked_at":"$(iso "$NOW")","host":"$HOST","not_after":"$(iso "$cert_end")","days_left":$days_left,"caddy_cert_found":$([ -n "$best" ] && echo true || echo false),"synced_now":$([ "$SYNCED" = 1 ] && echo true || echo false),"ok":$OK,"problem":"$(esc "$PROBLEM")"}
JSON
chmod 644 "$STATE_DIR/cert-status.json.tmp"
mv -f "$STATE_DIR/cert-status.json.tmp" "$STATE_DIR/cert-status.json"
log "haal: notAfter=$(iso "$cert_end") days_left=$days_left synced_now=$SYNCED ok=$OK ${PROBLEM:+problem=$PROBLEM}"

# ---------------------------------------------------------------------------
# 4) Alerts
# ---------------------------------------------------------------------------
FIX="Kya karna hai (server par, root):
  1) systemctl start anexomail-mail-cert.service ; journalctl -u anexomail-mail-cert.service -n 40 --no-pager
  2) cat /var/lib/anexomail/cert-status.json
  3) Caddy ne $HOST ka cert renew kiya? : journalctl -u caddy --no-pager | grep -i '$HOST' | tail -20
     aur Caddyfile mein $HOST ka block hona chahiye: grep -n '$HOST' /etc/caddy/Caddyfile
  4) Agar sab theek lage to chat mein yeh output Claude ko paste karein."

level=""
if [ "$days_left" -lt "$URGENT_DAYS" ]; then
  level=urgent
elif [ "$days_left" -lt "$WARN_DAYS" ]; then
  level=warn
elif [ -n "$PROBLEM" ]; then
  level=problem
fi

if [ "$level" = urgent ]; then
  send_alert urgent "[ANEXOMAIL URGENT] Mail TLS cert $( [ "$days_left" -le 0 ] && echo EXPIRE HO CHUKA || echo "sirf $days_left din ka") — IMAP/SMTP tootne wala hai" \
    "Mail server ka TLS cert ($HOST) $(iso "$cert_end") par expire hota hai ($days_left din).
Expire hua to phone/Outlook se IMAP/SMTP login aur kai servers se TLS mail fail hogi.
${PROBLEM:+Masla: $PROBLEM
}
$FIX"
elif [ "$level" = warn ]; then
  send_alert warn "[ANEXOMAIL] Mail TLS cert $days_left din mein expire — auto-renew nahi hua" \
    "Mail server ka TLS cert ($HOST) $(iso "$cert_end") par expire hota hai ($days_left din). Normal halat mein yeh monitor Caddy ka naya cert khud laga deta hai; abhi nahi laga.
${PROBLEM:+Masla: $PROBLEM
}
$FIX"
elif [ "$level" = problem ]; then
  send_alert problem "[ANEXOMAIL] Mail TLS cert monitor ko masla mila" \
    "Cert abhi theek hai ($days_left din baqi) lekin monitor ko masla mila:
$PROBLEM

$FIX"
fi

if [ "$SYNCED" = 1 ]; then
  send_alert renewed "[ANEXOMAIL] Mail TLS cert taza ho gaya (khud)" \
    "Monitor ne Caddy ka naya cert $HOST par laga diya, postfix + dovecot reload kiye aur live (993 aur 587) verify kiya.
Naya cert $(iso "$cert_end") tak valid ($days_left din). Kuch karne ki zaroorat nahi."
fi

if [ "$TEST_ALERT" = 1 ]; then
  FORCE_ALERT=1 send_alert test "[ANEXOMAIL] Test alert — mail TLS monitor chalu hai" \
    "Yeh test email hai: agar yeh aap ko mili to alert ka rasta theek hai.
Mail cert ($HOST): $(iso "$cert_end") tak valid, $days_left din baqi. Status: $($OK && echo theek || echo 'DHYAN DEIN — upar wali alert dekhein').
Monitor din mein 2 baar chalta hai (03:17 aur 15:17 server ka waqt). <$WARN_DAYS din ya masla ho to is tarah email aayegi; roz ek baar jab tak theek na ho."
fi

$OK && exit 0 || exit 1
