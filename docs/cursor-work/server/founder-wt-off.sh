#!/bin/bash
# KP3 step 5 / STEP 3 (founder lane, 14 Nov 2026, his order): remove the OLD separate WebTransport port UDP 4443 from the server side.
# Why: WebTransport now runs ONLY on the HTTP/3 endpoint (UDP 443, same origin). The binary (step 2) no longer binds 4443 and ignores FOUNDER_WT_*; this script removes what is left:
#   (1) the four FOUNDER_WT_* lines in /etc/anexomail/founder.env (backup first), (2) the ufw rule 4443/udp (v4 + v6), (3) restart, (4) PROOF: no udp 4443 listener, HTTP/3 + WebTransport still ON UDP 443, healthz 200.
# Touches NOTHING else: not udp 443, not 18443 (Caddy / awam), not 3443 (anexomail-rust), not the certificates in /etc/anexomail/tls (443 may share them).
# Idempotent (safe to run twice). Rollback is automatic on a failed proof: the env backup is put back, ufw allow 4443/udp, restart.
# usage: git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-wt-off.sh)
set -u
ENVF="${ENVF:-/etc/anexomail/founder.env}"; SVC="${SVC:-anexomail-founder}"; PORT=4443; DRY="${DRY:-0}"
say() { printf '%s\n' "$*"; }
[ -r "$ENVF" ] && [ -w "$ENVF" ] || { say "FAIL: cannot read/write $ENVF"; exit 2; }
BAK="$ENVF.bak.wtoff.$(date +%s)"; cp -p "$ENVF" "$BAK" || { say "FAIL: backup"; exit 2; }
say "== 1/4 env: before (only the FOUNDER_WT_ keys; cert/key are paths, not secrets)"; grep -c '^FOUNDER_WT_' "$ENVF" | sed 's/^/   lines: /'
sed -i '/^FOUNDER_WT_\(ADDR\|HOST\|CERT\|KEY\)=/d' "$ENVF"
say "== 1/4 env: after"; grep -c '^FOUNDER_WT_' "$ENVF" | sed 's/^/   lines: /'
if [ "$DRY" = 1 ]; then say "DRY run: env edited ($BAK kept), nothing else touched"; exit 0; fi
say "== 2/4 firewall"
if command -v ufw >/dev/null 2>&1; then ufw status | grep -E "^$PORT/udp" >/dev/null && { ufw delete allow "$PORT/udp" >/dev/null 2>&1; say "   ufw: deleted allow $PORT/udp (v4 + v6)"; } || say "   ufw: no $PORT/udp rule (already gone)"; else say "   ufw not installed: nothing to do"; fi
say "== 3/4 restart"; systemctl restart "$SVC"; sleep 5
say "== 4/4 proof"
LISTEN="$(ss -lunp 2>/dev/null | grep ":$PORT " || true)"
J="$(journalctl -u "$SVC" -n 200 --no-pager 2>/dev/null)"
H3="$(echo "$J" | grep -c 'HTTP/3 ON udp')"; WT="$(echo "$J" | grep -c 'WebTransport ON the HTTP/3 endpoint')"
HZ="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3210/healthz)"; ME="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3210/founder/v1/me)"
U443="$(ss -lunp 2>/dev/null | grep ':443 ' | grep -c anexomail-found)"
say "   udp $PORT listener: ${LISTEN:-<none>}"; say "   journal: HTTP/3 ON lines=$H3, WebTransport-on-HTTP/3 lines=$WT"; say "   udp 443 owned by anexomail-found: $U443 (1 or more wanted); healthz=$HZ (200); me without token=$ME (401)"
if [ -z "$LISTEN" ] && [ "$H3" -ge 1 ] && [ "$WT" -ge 1 ] && [ "$U443" -ge 1 ] && [ "$HZ" = 200 ] && [ "$ME" = 401 ]; then
  say "OK KP3 step 5 server side: UDP $PORT is gone, WebTransport + HTTP/3 are on UDP 443. Env backup: $BAK"; say "NOW paste this whole output to Claude."; else
  say "FAIL: proof not met; ROLLING BACK (env backup, ufw allow $PORT/udp, restart)"; cp -p "$BAK" "$ENVF"; command -v ufw >/dev/null 2>&1 && ufw allow "$PORT/udp" >/dev/null 2>&1; systemctl restart "$SVC"; journalctl -u "$SVC" -n 15 --no-pager; exit 4; fi
