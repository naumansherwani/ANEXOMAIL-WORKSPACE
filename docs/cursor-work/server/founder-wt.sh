#!/bin/bash
# K6 (founder lane): switch on the founder WebTransport (QUIC/HTTP3, AES-256) on its own UDP port. Default OFF in the binary; this script adds the env lines.
# Needs: founder-install.sh (binary with wt.rs) and the K4 certificate copies in /etc/anexomail/tls. Changes ONLY /etc/anexomail/founder.env (backup first) and ufw (one UDP rule).
# Rollback: restore the backup it prints, systemctl restart anexomail-founder; ufw delete allow 4443/udp.
set -u
HOST="${HOST:-founderworkspace.anexomail.com}"; PORT="${WT_PORT:-4443}"; TLSD=/etc/anexomail/tls; ENVF=/etc/anexomail/founder.env; SVC=anexomail-founder
say() { printf '%s\n' "$*"; }
[ -r "$TLSD/$HOST.crt" ] && [ -r "$TLSD/$HOST.key" ] || { say "FAIL: no certificate copy for $HOST in $TLSD (run founder-tls256.sh first)"; exit 2; }
strings /opt/anexomail-founder/anexomail-founder 2>/dev/null | grep -q "FOUNDER_WT_ADDR" || { say "FAIL: the installed founder binary has no WebTransport code yet: run founder-install.sh first"; exit 2; }
# PORT RED LINE: the port must be absent from a FRESH list (and not already ours)
if ss -lun 2>/dev/null | grep -q ":$PORT "; then grep -q "^FOUNDER_WT_ADDR=.*:$PORT" "$ENVF" || { say "FAIL: UDP $PORT is used by something else"; ss -lunp | grep ":$PORT "; exit 3; }; fi
BAK="$ENVF.bak.k6.$(date +%s)"; cp -p "$ENVF" "$BAK" || { say "FAIL: backup"; exit 2; }
setenv() { if grep -q "^$1=" "$ENVF"; then sed -i "s|^$1=.*|$1=$2|" "$ENVF"; else echo "$1=$2" >>"$ENVF"; fi; }
setenv FOUNDER_WT_ADDR "0.0.0.0:$PORT"; setenv FOUNDER_WT_HOST "$HOST"; setenv FOUNDER_WT_CERT "$TLSD/$HOST.crt"; setenv FOUNDER_WT_KEY "$TLSD/$HOST.key"
if command -v ufw >/dev/null 2>&1; then ufw allow "$PORT/udp" >/dev/null 2>&1 && say "ufw: allow $PORT/udp"; fi
systemctl restart $SVC; sleep 4
say "== journal"; journalctl -u $SVC -n 40 --no-pager 2>/dev/null | grep -E "WebTransport" | tail -3
say "== socket (must show the founder program on udp $PORT)"; ss -lunp | grep ":$PORT "
if ss -lunp | grep ":$PORT " | grep -q anexomail-found; then say "OK K6 server side: WebTransport listening on udp $PORT. Backup: $BAK"; else say "FAIL: not listening; rolling back"; cp -p "$BAK" "$ENVF"; systemctl restart $SVC; exit 4; fi
