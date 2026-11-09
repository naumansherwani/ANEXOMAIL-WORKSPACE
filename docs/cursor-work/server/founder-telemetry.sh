#!/bin/bash
# K6.4 (founder lane, Rule 48: a command lives in the repo BEFORE the founder gets it): live-session telemetry switch for the founder service.
#   MODE=status (default)  read-only: shows whether FOUNDER_TELEMETRY is set. Nothing changes.
#   MODE=on                backup of /etc/anexomail/founder.env, sets FOUNDER_TELEMETRY=on (once), restarts the service, proves it is active.
#   MODE=off               backup, removes the line, restarts, proves it is active.
# Privacy: the rows hold only transport kind, counts, times, reasons (E111/E148): no uid, IP, token, user agent.
# Rollback: cp -p the backup it prints back over founder.env, then systemctl restart anexomail-founder.
set -u
MODE="${MODE:-status}"; ENVF=/etc/anexomail/founder.env; SVC=anexomail-founder
say() { printf '%s\n' "$*"; }
[ -r "$ENVF" ] || { say "FAIL: $ENVF not readable"; exit 2; }
cur="$(grep -E '^FOUNDER_TELEMETRY=' "$ENVF" | tail -1)"
case "$MODE" in
  status) if [ -n "$cur" ]; then say "telemetry line: $cur"; else say "telemetry line: (none) = telemetry OFF"; fi; exit 0 ;;
  on|off) ;;
  *) say "FAIL: MODE must be status, on or off"; exit 2 ;;
esac
if [ "$MODE" = on ] && [ "$cur" = "FOUNDER_TELEMETRY=on" ]; then say "already ON, nothing to do"; exit 0; fi
if [ "$MODE" = off ] && [ -z "$cur" ]; then say "already OFF, nothing to do"; exit 0; fi
BAK="$ENVF.bak.tel.$(date +%s)"; cp -p "$ENVF" "$BAK" || { say "FAIL: backup"; exit 2; }
sed -i '/^FOUNDER_TELEMETRY=/d' "$ENVF"
if [ "$MODE" = on ]; then [ -n "$(tail -c1 "$ENVF")" ] && echo >> "$ENVF"; echo "FOUNDER_TELEMETRY=on" >> "$ENVF"; fi
systemctl restart "$SVC"; sleep 4
if [ "$(systemctl is-active "$SVC")" = active ]; then say "OK telemetry $MODE. service active. Backup: $BAK"; else say "FAIL: service not active; rolling back"; cp -p "$BAK" "$ENVF"; systemctl restart "$SVC"; exit 4; fi
