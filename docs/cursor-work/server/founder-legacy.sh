#!/bin/bash
# G-MIX 2d (founder lane, Rule 48: a command lives in the repo BEFORE the founder gets it): cut the OLD awam app away from the founder host.
#   MODE=status (default)  read-only: shows the FOUNDER_LEGACY_UPSTREAM line, the service state and what the founder host answers. Nothing changes.
#   MODE=off               removes the FOUNDER_LEGACY_UPSTREAM line: the founder binary stops forwarding ANY path to the old app (old paths answer 404 or land on /). Needs the native sign-in installed (G-MIX 2a/2c).
# Rollback: cp -p the backup it prints back over founder.env, then systemctl restart anexomail-founder (it does this itself when the service does not come back active or /healthz fails).
set -u
MODE="${MODE:-status}"; ENVF=/etc/anexomail/founder.env; SVC=anexomail-founder
say() { printf '%s\n' "$*"; }
[ -r "$ENVF" ] || { say "FAIL: $ENVF not readable"; exit 2; }
cur="$(grep -E '^FOUNDER_LEGACY_UPSTREAM=' "$ENVF" | tail -1)"
probe() { for p in / /founderlogin /app /api/auth/login; do say "GET $p -> HTTP $(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:3210$p")"; done; say "POST /founder/v1/auth/login (junk) -> HTTP $(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'content-type: application/json' -d '{"email":"x@y.com","password":"x"}' http://127.0.0.1:3210/founder/v1/auth/login)  (401 = native sign-in alive)"; }
case "$MODE" in
  status) say "legacy line: ${cur:-(none) = already cut}"; say "service: $(systemctl is-active "$SVC")"; probe; exit 0 ;;
  off) ;;
  *) say "FAIL: MODE must be status or off"; exit 2 ;;
esac
[ -n "$cur" ] || { say "already cut, nothing to do"; exit 0; }
code="$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'content-type: application/json' -d '{"email":"x@y.com","password":"x"}' http://127.0.0.1:3210/founder/v1/auth/login)"
[ "$code" = 401 ] || { say "FAIL: native sign-in does not answer 401 (got $code): install first (founder-install.sh), nothing changed"; exit 3; }
BAK="$ENVF.bak.legacy.$(date +%s)"; cp -p "$ENVF" "$BAK" || { say "FAIL: backup"; exit 2; }
sed -i '/^FOUNDER_LEGACY_UPSTREAM=/d' "$ENVF"
systemctl restart "$SVC"; sleep 4
hz="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3210/healthz)"
if [ "$(systemctl is-active "$SVC")" = active ] && [ "$hz" = 200 ]; then say "OK legacy upstream cut. service active, healthz 200. Backup: $BAK"; probe; else say "FAIL: service/healthz not ok; rolling back"; cp -p "$BAK" "$ENVF"; systemctl restart "$SVC"; exit 4; fi
