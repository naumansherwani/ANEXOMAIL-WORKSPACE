#!/usr/bin/env bash
# Q1b-3 step 1b: switch the founder LMTP intake ON, SERVICE ONLY. Postfix is NOT touched here (no mail flows in yet).
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/fmail-intake-on.sh)
# Facts from his ss/postconf output of 13 Nov 04:11: 127.0.0.1:18025 free; clamd listens on 127.0.0.1:3310 (socket is clamav:clamav, the founder user cannot use it, so TCP loopback);
# Postfix: virtual_transport = anexopipe, transport_maps empty, the founder address is a vmailbox entry.
# Steps (any failure => env restored, service restarted, nothing left half):
#   1 re-check the port is still free (PORT RED LINE)   2 clamd answers PING   3 back up founder.env, add FMAIL_LMTP_BIND + FMAIL_CLAMD
#   4 restart + wait for the journal line   5 the listener belongs to anexomail-founder and is loopback only
#   6 LMTP self-test (LHLO, MAIL, RCPT founder address expects 250; RCPT unknown expects 550; RSET; QUIT) - NO message is sent, nothing is stored
# Rollback after the fact:  cp /etc/anexomail/founder.env.pre-intake /etc/anexomail/founder.env && systemctl restart anexomail-founder
set -uo pipefail
ENVF=/etc/anexomail/founder.env; SVC=anexomail-founder; BIND="${FMAIL_LMTP_BIND_VALUE:-127.0.0.1:18025}"; CLAMD="${FMAIL_CLAMD_VALUE:-127.0.0.1:3310}"
ADDR="${FOUNDER_MAIL_ADDR:-naumansherwani.founder@anexomail.com}"; PORT="${BIND##*:}"; HOST="${BIND%:*}"; BK="$ENVF.pre-intake"
[ "$(id -u)" -eq 0 ] || { echo "FAIL: root needed"; exit 2; }
[ "$HOST" = "127.0.0.1" ] || { echo "FAIL: loopback only"; exit 2; }
undo() { echo "== ROLLBACK"; [ -f "$BK" ] && cp -p "$BK" "$ENVF" && systemctl restart "$SVC"; echo "env restored, service restarted"; exit "${1:-1}"; }
echo "== 1/6 port $PORT"; ss -H -tuln | awk '{print $5}' | grep -Eq "[:.]$PORT\$" && { if grep -q "^FMAIL_LMTP_BIND=$BIND\$" "$ENVF" 2>/dev/null; then echo "already ours (re-run)"; else echo "FAIL: $PORT is in use now (red line): stop"; exit 3; fi; }
echo "== 2/6 clamd $CLAMD"; CH="${CLAMD%:*}"; CP="${CLAMD##*:}"
R="$(exec 3<>"/dev/tcp/$CH/$CP" 2>/dev/null && printf 'zPING\0' >&3 && timeout 3 head -c 8 <&3 | tr -d '\0\n')"; [ "$R" = "PONG" ] || { echo "FAIL: clamd at $CLAMD did not answer PONG (got '$R')"; exit 3; }; echo "clamd PONG"
echo "== 3/6 env"; [ -f "$BK" ] || cp -p "$ENVF" "$BK"; echo "backup $BK"
grep -q '^FMAIL_LMTP_BIND=' "$ENVF" && sed -i "s|^FMAIL_LMTP_BIND=.*|FMAIL_LMTP_BIND=$BIND|" "$ENVF" || echo "FMAIL_LMTP_BIND=$BIND" >>"$ENVF"
grep -q '^FMAIL_CLAMD=' "$ENVF" && sed -i "s|^FMAIL_CLAMD=.*|FMAIL_CLAMD=$CLAMD|" "$ENVF" || echo "FMAIL_CLAMD=$CLAMD" >>"$ENVF"
echo "== 4/6 restart"; SINCE="$(date '+%Y-%m-%d %H:%M:%S')"; systemctl restart "$SVC"; OK=0
for i in $(seq 1 20); do sleep 1; journalctl -u "$SVC" --since "$SINCE" --no-pager 2>/dev/null | grep -q "mail intake (LMTP) ON" && { OK=1; break; }; done
journalctl -u "$SVC" --since "$SINCE" --no-pager 2>/dev/null | grep -E "mail intake|mail sender|healthz|panic" | sed 's/^/  /'
[ $OK = 1 ] || { echo "FAIL: no 'mail intake (LMTP) ON' line"; undo 4; }
echo "== 5/6 listener"; L="$(ss -H -tlnp | grep -E "[:.]$PORT\b")"; echo "  $L"
echo "$L" | grep -q "127.0.0.1:$PORT" && echo "$L" | grep -q "anexomail-found" || { echo "FAIL: not a loopback listener of anexomail-founder"; undo 5; }
curl -s -o /dev/null -w '  healthz=%{http_code}\n' http://127.0.0.1:3210/healthz
echo "== 6/6 LMTP self-test (no message is sent)"
T="$(mktemp)"; cat >"$T" <<'EOS'
exec 4<>"/dev/tcp/$LHOST/$LPORT" || exit 1
rd() { local l; while IFS= read -r -t 5 l <&4; do l="${l%$'\r'}"; echo "<< $l"; [ "${l:3:1}" = " " ] && return; done; }
wr() { printf '%s\r\n' "$1" >&4; echo ">> $1"; }
rd; wr "LHLO selftest.local"; rd; wr "MAIL FROM:<selftest@example.org>"; rd
wr "RCPT TO:<$LADDR>"; rd; wr "RCPT TO:<nobody-here-$$@anexomail.com>"; rd; wr "RSET"; rd; wr "QUIT"; rd
EOS
LHOST="$HOST" LPORT="$PORT" LADDR="$ADDR" timeout 25 bash "$T" | tee /tmp/fmail-lmtp.$$; RC=${PIPESTATUS[0]}; rm -f "$T"
[ "$RC" = 0 ] || { echo "FAIL: cannot talk LMTP"; rm -f /tmp/fmail-lmtp.$$; undo 6; }
grep -q '^<< 250 2.1.5' /tmp/fmail-lmtp.$$ || { echo "FAIL: founder RCPT was not 250 (see above; 450 = key/pause problem, 550 = address)"; rm -f /tmp/fmail-lmtp.$$; undo 6; }
grep -Eq '^<< 5[0-9][0-9] ' /tmp/fmail-lmtp.$$ || { echo "FAIL: unknown RCPT was not refused 5xx"; rm -f /tmp/fmail-lmtp.$$; undo 6; }
rm -f /tmp/fmail-lmtp.$$
echo "OK - intake ON on $BIND (loopback), ClamAV $CLAMD, founder RCPT accepted, unknown refused. Postfix NOT changed: no real mail flows in yet."
echo "NEXT (needs his haan): ONE per-address Postfix transport entry for $ADDR -> lmtp:inet:127.0.0.1:$PORT."
