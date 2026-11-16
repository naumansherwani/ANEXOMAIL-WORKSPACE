#!/usr/bin/env bash
# Q1d-2b: switch the founder mail SENDER on (FMAIL_SEND=on). His haan is given (16 Nov). The per-send key touch is OFF (E177), the 30 s undo hold stays.
#   direct MX:      git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/fmail-send-on.sh) 2>&1 | tail -15
#   loopback relay: FMAIL_SMTP_RELAY_VALUE=127.0.0.1:25 bash <(...same...)   (only if fmail-send-probe.sh said port 25 is BLOCKED and a loopback Postfix exists)
# Any failure => env restored, service restarted, nothing left half. Rollback after the fact: cp /etc/anexomail/founder.env.pre-send /etc/anexomail/founder.env && systemctl restart anexomail-founder
set -uo pipefail
ENVF=/etc/anexomail/founder.env; SVC=anexomail-founder; BK="$ENVF.pre-send"; RELAY="${FMAIL_SMTP_RELAY_VALUE:-}"; HELO="${FMAIL_SMTP_HELO_VALUE:-}"
[ "$(id -u)" -eq 0 ] || { echo "FAIL: root needed"; exit 2; }
undo() { echo "== ROLLBACK"; [ -f "$BK" ] && cp -p "$BK" "$ENVF" && systemctl restart "$SVC"; echo "env restored, service restarted"; exit "${1:-1}"; }
[ -z "$RELAY" ] || case "$RELAY" in 127.0.0.1:*) ;; *) echo "FAIL: only a loopback relay (127.0.0.1:PORT) is accepted"; exit 2;; esac
echo "== 1/4 env"; [ -f "$BK" ] || cp -p "$ENVF" "$BK"; echo "backup $BK"
setv() { grep -q "^$1=" "$ENVF" && sed -i "s|^$1=.*|$1=$2|" "$ENVF" || echo "$1=$2" >>"$ENVF"; }
setv FMAIL_SEND on; [ -z "$RELAY" ] || setv FMAIL_SMTP_RELAY "$RELAY"; [ -z "$HELO" ] || setv FMAIL_SMTP_HELO "$HELO"
echo "== 2/4 restart"; SINCE="$(date '+%Y-%m-%d %H:%M:%S')"; systemctl restart "$SVC"; OK=0
for i in $(seq 1 25); do sleep 1; journalctl -u "$SVC" --since "$SINCE" --no-pager 2>/dev/null | grep -q "mail sender ON" && { OK=1; break; }; done
journalctl -u "$SVC" --since "$SINCE" --no-pager 2>/dev/null | grep -E "mail sender|mail intake|panic" | sed 's/^/  /'
[ $OK = 1 ] || { echo "FAIL: no 'mail sender ON' line"; undo 2; }
echo "== 3/4 service"; for i in $(seq 1 15); do C="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3210/healthz)"; [ "$C" = 200 ] && break; sleep 1; done; echo "  healthz=$C"; [ "$C" = 200 ] || undo 3
echo "== 4/4 result"; grep -E '^FMAIL_SEND=|^FMAIL_SMTP_RELAY=|^FMAIL_SMTP_HELO=' "$ENVF" | sed 's/^/  /'
echo "OK - sender ON. Compose a mail to your Gmail: it waits 30 s (undo), then leaves within about 1 s and moves from Outbox to Sent."
