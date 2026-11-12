#!/usr/bin/env bash
# Q1b-3 step 1b: founder mail intake ON, SERVICE ONLY. Postfix is NOT touched (that is step 1c, only after his "haan").
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/fmail-intake-on.sh)
# What it does (his ss output 13 Nov 04:10: 127.0.0.1:18025 free, clamd on 127.0.0.1:3310):
#   1. refuses unless the port is still free (or already ours) in a FRESH ss list (PORT RED LINE)
#   2. backs up /etc/anexomail/founder.env, adds FMAIL_LMTP_BIND=127.0.0.1:18025 and FMAIL_CLAMD=127.0.0.1:3310 (idempotent, loopback only)
#   3. restarts anexomail-founder, waits for the journal line "mail intake (LMTP) ON"
#   4. proves it with a harmless LMTP talk on loopback (LHLO, MAIL, RCPT for a made-up address = must be 550, QUIT; no DATA, nothing stored) and checks the port is loopback-only
#   5. ANY failure => env restored from the backup, service restarted, exit 1 (rollback is automatic)
#   Manual rollback: cp /etc/anexomail/founder.env.bak-fmail-intake /etc/anexomail/founder.env && systemctl restart anexomail-founder
set -uo pipefail
ENVF=/etc/anexomail/founder.env; BAK=$ENVF.bak-fmail-intake; SVC=anexomail-founder
BIND="${FMAIL_LMTP_BIND_WANT:-127.0.0.1:18025}"; CLAMD="${FMAIL_CLAMD_WANT:-127.0.0.1:3310}"; PORT="${BIND##*:}"; HOST="${BIND%:*}"
[ "$(id -u)" -eq 0 ] || { echo "FAIL: root chahiye"; exit 2; }
[ "$HOST" = "127.0.0.1" ] || { echo "FAIL: bind must be 127.0.0.1 (loopback only)"; exit 2; }
[ -r "$ENVF" ] || { echo "FAIL: $ENVF nahi mila"; exit 2; }
echo "== 1/4 fresh ss"; L="$(ss -H -tlnp 2>/dev/null | awk -v p=":$PORT" '$4 ~ p"$"')"
if [ -n "$L" ] && ! echo "$L" | grep -q "anexomail-found"; then echo "FAIL: port $PORT is used by another process (red line):"; echo "$L"; exit 3; fi
echo "   port $PORT free or already ours"
echo "== 2/4 env (backup $BAK)"; [ -e "$BAK" ] || cp -p "$ENVF" "$BAK"
setkv() { if grep -q "^$1=" "$ENVF"; then sed -i "s#^$1=.*#$1=$2#" "$ENVF"; else printf '%s=%s\n' "$1" "$2" >>"$ENVF"; fi; }
setkv FMAIL_LMTP_BIND "$BIND"; setkv FMAIL_CLAMD "$CLAMD"; chmod 600 "$ENVF"; grep -E '^FMAIL_(LMTP_BIND|CLAMD)=' "$ENVF" | sed 's/^/   /'
rollback() { echo "ROLLBACK: $1"; cp -p "$BAK" "$ENVF"; systemctl restart "$SVC"; sleep 2; systemctl is-active "$SVC"; exit 1; }
echo "== 3/4 restart"; systemctl restart "$SVC" || rollback "restart failed"
OK=0; for i in $(seq 1 20); do sleep 1; journalctl -u "$SVC" --since "-30 sec" --no-pager 2>/dev/null | grep -q "mail intake (LMTP) ON" && { OK=1; break; }; done
[ $OK -eq 1 ] || { journalctl -u "$SVC" -n 8 --no-pager | sed 's/^/   /'; rollback "no 'mail intake (LMTP) ON' line"; }
journalctl -u "$SVC" --since "-30 sec" --no-pager | grep "mail intake" | tail -1 | sed 's/^/   /'
echo "== 4/4 saboot (no DATA, nothing stored)"
LIS="$(ss -H -tlnp | awk -v p=":$PORT" '$4 ~ p"$" {print $4}')"; echo "   listening: $LIS"; [ "$LIS" = "$BIND" ] || rollback "listener is not exactly $BIND"
exec 3<>"/dev/tcp/$HOST/$PORT" || rollback "cannot connect"
rd() { local l; IFS= read -r -t 5 l <&3 && printf '   < %s\n' "${l%$'\r'}"; }
rd; printf 'LHLO probe\r\n' >&3; for i in 1 2 3 4 5; do rd; done
printf 'MAIL FROM:<probe@localhost>\r\n' >&3; rd
printf 'RCPT TO:<no-such-box-probe@anexomail.com>\r\n' >&3; R="$(IFS= read -r -t 5 l <&3; echo "${l%$'\r'}")"; echo "   < $R"
printf 'QUIT\r\n' >&3; rd; exec 3>&-
case "$R" in 550*) echo "   OK: unknown address refused with 550 (door works)";; *) rollback "expected 550 for a made-up address, got: $R";; esac
echo "   service: $(systemctl is-active $SVC)   healthz: $(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3210/healthz)"
echo "OK - intake listener ON (loopback only, ClamAV $CLAMD). Postfix is unchanged, so no real mail comes in yet. Next = step 1c (Postfix per-address entry), only after your haan."
