#!/bin/bash
# K7 DBSC (founder lane, Rule 48: a command lives in the repo BEFORE the founder gets it): device-bound sessions switch for the founder service.
#   MODE=status (default)  read-only: shows the FOUNDER_DBSC line, the service state and the founder routes. Nothing changes.
#   MODE=observe           register + refresh + ledger, NEVER blocks (would-block is only logged). Safe first step.
#   MODE=enforce           a device that is bound to its TPM key must show the bound cookie to get a founder token. Only with his word.
#   MODE=off               removes the line: every DBSC route answers 404 and nothing is checked (the default of the binary).
# Needs the E149 SQL first (sql-run.sh E149_founder_dbsc CHECK_E149) and the new binary (founder-install.sh).
# Unbound devices (phone, Firefox, Safari) are never blocked in any mode.
# Rollback: MODE=off, or cp -p the backup it prints back over founder.env, then systemctl restart anexomail-founder.
set -u
MODE="${MODE:-status}"; ENVF=/etc/anexomail/founder.env; SVC=anexomail-founder
say() { printf '%s\n' "$*"; }
[ -r "$ENVF" ] || { say "FAIL: $ENVF not readable"; exit 2; }
cur="$(grep -E '^FOUNDER_DBSC=' "$ENVF" | tail -1)"
case "$MODE" in
  status) say "dbsc line: ${cur:-(none) = OFF}"; say "service: $(systemctl is-active "$SVC")"
          for p in dbsc/start dbsc/refresh; do say "POST /founder/v1/$p without proof -> HTTP $(curl -s -o /dev/null -w '%{http_code}' -X POST "http://127.0.0.1:3210/founder/v1/$p")  (404 = off, 400 = on)"; done; exit 0 ;;
  observe|enforce|off) ;;
  *) say "FAIL: MODE must be status, observe, enforce or off"; exit 2 ;;
esac
want="FOUNDER_DBSC=$MODE"; [ "$MODE" = off ] && want=""
if [ "$cur" = "$want" ]; then say "already $MODE, nothing to do"; exit 0; fi
BAK="$ENVF.bak.dbsc.$(date +%s)"; cp -p "$ENVF" "$BAK" || { say "FAIL: backup"; exit 2; }
sed -i '/^FOUNDER_DBSC=/d' "$ENVF"
if [ "$MODE" != off ]; then [ -n "$(tail -c1 "$ENVF")" ] && echo >> "$ENVF"; echo "$want" >> "$ENVF"; fi
systemctl restart "$SVC"; sleep 4
if [ "$(systemctl is-active "$SVC")" = active ]; then say "OK dbsc $MODE. service active. Backup: $BAK"; else say "FAIL: service not active; rolling back"; cp -p "$BAK" "$ENVF"; systemctl restart "$SVC"; exit 4; fi
