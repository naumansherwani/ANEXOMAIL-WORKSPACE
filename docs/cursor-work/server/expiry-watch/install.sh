#!/usr/bin/env bash
# ANEXOMAIL — expiry watch install (idempotent). Founder ek hi command chalata hai (memory file section 13.10):
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/expiry-watch/install.sh)
# Kya karta hai: monitor + systemd timer lagata hai, ABHI ek baar poora check chalata hai, founder ko pehla poora report
# email karta hai (test), aur natija table mein dikhata hai. Koi secret print nahi hota. Mail/DNS/Caddy kuch nahi badalta
# (sirf parhta hai).
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"
DIR="docs/cursor-work/server/expiry-watch"
BIN="${BIN:-/usr/local/bin/anexomail-expiry-watch}"
UNITS="${UNITS:-/etc/systemd/system}"
STATE_DIR="${STATE_DIR:-/var/lib/anexomail}"

src_get() { # SRC_DIR (test) ya git origin/main se
  if [ -n "${SRC_DIR:-}" ]; then cat "$SRC_DIR/$1"; else git -C "$REPO" show "origin/main:$DIR/$1"; fi
}

command -v python3 >/dev/null 2>&1 || { echo "FAIL: python3 nahi mila (apt-get install -y python3)"; exit 2; }
command -v openssl >/dev/null 2>&1 || { echo "FAIL: openssl nahi mila (apt-get install -y openssl)"; exit 2; }
echo "== 1) install ($(python3 --version 2>&1), $(openssl version 2>&1 | cut -d' ' -f1-2))"
mkdir -p "$STATE_DIR" /etc/anexomail "$(dirname "$BIN")" "$UNITS"
for f in anexomail-expiry-watch.py anexomail-expiry-watch.service anexomail-expiry-watch.timer; do
  src_get "$f" >"/tmp/.aew.$f" 2>/dev/null && [ -s "/tmp/.aew.$f" ] || { echo "FAIL: $f repo se nahi mili (git fetch hua?)"; rm -f /tmp/.aew.*; exit 2; }
done
install -m 755 /tmp/.aew.anexomail-expiry-watch.py "$BIN"
install -m 644 /tmp/.aew.anexomail-expiry-watch.service "$UNITS/anexomail-expiry-watch.service"
install -m 644 /tmp/.aew.anexomail-expiry-watch.timer "$UNITS/anexomail-expiry-watch.timer"
rm -f /tmp/.aew.*
if [ ! -f /etc/anexomail/expiry-watch.env ]; then
  cat >/etc/anexomail/expiry-watch.env <<'ENVEOF'
# Optional — sab default par chalta hai. Zaroorat ho to # hata kar badlein.
# Extra domains jinki registration expiry dekhni hai (Caddyfile ke hosts se domain khud nikalte hain):
# WATCH_DOMAINS="axonetis.com nexatect.com"
# Extra website hosts jo Caddyfile se nahi milte:
# WATCH_WEB_HOSTS="status.anexomail.com"
# Jinhe nahi dekhna:
# WATCH_SKIP_WEB_HOSTS=""
# WATCH_SKIP_DOMAINS=""
# OpenDKIM key table agar alag jagah ho:
# DKIM_KEYTABLE="/etc/opendkim/KeyTable"
ENVEOF
  chmod 640 /etc/anexomail/expiry-watch.env
fi
[ -f /etc/anexomail/alert.env ] || printf '# Founder inbox par alert HAMESHA jata hai.\n# Bahar ke email par bhi chahiye to: ALERT_TO="aap@gmail.com"\n' >/etc/anexomail/alert.env
if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
  systemctl daemon-reload
  systemctl enable --now anexomail-expiry-watch.timer >/dev/null 2>&1 || echo "WARN: timer enable nahi hua"
else
  echo "WARN: systemd nahi mila — timer nahi laga (script haath se chala sakte hain)"
fi

echo "== 2) abhi ek baar poora check + pehla report email (founder inbox)"
"$BIN" --test-alert >/tmp/.aew.run 2>&1; rc=$?
tail -3 /tmp/.aew.run | cut -c1-200 | sed 's/^/   /'; rm -f /tmp/.aew.run
echo "   exit code: $rc  (0 = sab theek ya sirf unknown; 1 = kuch warn/crit)"

echo "== 3) natija"
python3 - "$STATE_DIR/expiry-watch.json" <<'PYEOF'
import json, sys
try:
    r = json.load(open(sys.argv[1]))
except Exception as e:
    print("   report file nahi parhi:", e); sys.exit(0)
print("   checked_at:", r.get("checked_at"), " overall:", r.get("overall", "?").upper())
print("   %-8s %-46s %-5s %s" % ("STATUS", "KYA (target)", "DIN", "DETAIL"))
for i in sorted(r.get("items", []), key=lambda x: {"crit": 0, "warn": 1, "unknown": 2, "ok": 3}.get(x["status"], 4)):
    print("   %-8s %-46s %-5s %s" % (i["status"].upper(), (i["label"] + " " + i["target"])[:46], i.get("days_left", "-"), i["detail"][:110]))
PYEOF
echo " -- timer"; systemctl list-timers anexomail-expiry-watch.timer --no-pager 2>&1 | sed 's/^/   /' | head -4
sleep 3
echo " -- Postfix ne email ka kya kiya (mail.log):"
grep -h "monitor@anexomail.com" /var/log/mail.log 2>/dev/null | tail -2 | cut -c1-180 | sed 's/^/   /'
grep -h "status=" /var/log/mail.log 2>/dev/null | grep "naumansherwani.founder@" | tail -2 | cut -c1-180 | sed 's/^/   /'
echo "== 4) founder inbox mein '[ANEXOMAIL] Expiry watch chalu hai' aani chahiye. Founder dashboard par bhi tile (Rust build ke baad)."
exit "$rc"
