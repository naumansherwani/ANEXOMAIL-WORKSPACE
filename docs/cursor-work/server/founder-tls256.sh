#!/usr/bin/env bash
# T256-1 (founder, 1 Nov 2026): switch ON the AES-256-only TLS 1.3 terminator of the founder binary on a TEST PORT (default 8443).
# Technology: server ops (bash). Caddy, the awam site, ports 80/443/udp 443/3443 are NOT touched. Default = DRY RUN (prints what it would do); APPLY=1 does it.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-tls256.sh)            # dry run
#   git -C /opt/anexomail-web fetch -q origin main && APPLY=1 bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-tls256.sh)      # do it
# What APPLY=1 does: (1) copies the founder host certificate + key that Caddy already obtained into /etc/anexomail/tls (0640 root:anexomail-founder, only that host),
# (2) backs up /etc/anexomail/founder.env, then adds FOUNDER_TLS256_* + FOUNDER_TLS_PROBE lines (idempotent), (3) restarts the founder service, (4) weekly cron keeps the copy fresh
# (restarts only if the certificate really changed), (5) proves it with openssl: a normal client must land on TLS_AES_256_GCM_SHA384, an AES-128-only client must be refused.
# Rollback: restore the .bak env file, `systemctl restart anexomail-founder`; delete /etc/cron.d/anexomail-founder-tls. Needs the Rust binary with tls256.rs (founder-install.sh first).
set -u
HOST="${HOST:-founderworkspace.anexomail.com}"; PORT="${TLS_PORT:-8443}"; APPLY="${APPLY:-0}"
CADDY_CERTS="${CADDY_CERTS:-/var/lib/caddy/.local/share/caddy/certificates}"; TLSD=/etc/anexomail/tls; ENVF=/etc/anexomail/founder.env; SVC=anexomail-founder
say() { printf '%s\n' "$*"; }; run() { if [ "$APPLY" = 1 ]; then "$@"; else say "  [dry-run] $*"; fi; }
CRT="$(find "$CADDY_CERTS" -type f -name "$HOST.crt" 2>/dev/null | head -1)"; KEY="${CRT%.crt}.key"
[ -n "$CRT" ] && [ -r "$KEY" ] || { say "FAIL: no certificate+key for $HOST under $CADDY_CERTS (Caddy has not issued it, or another path: CADDY_CERTS=...)"; exit 2; }
id anexomail-founder >/dev/null 2>&1 || { say "FAIL: user anexomail-founder missing (run founder-install.sh first)"; exit 2; }
[ -r "$ENVF" ] || { say "FAIL: $ENVF missing (run founder-install.sh first)"; exit 2; }
strings /opt/anexomail-founder/anexomail-founder 2>/dev/null | grep -q "FOUNDER_TLS256_ADDR" || { say "FAIL: the installed founder binary has no TLS-256 code yet: run founder-install.sh first"; exit 2; }
say "== $HOST on test port $PORT   cert: $CRT   mode: $([ "$APPLY" = 1 ] && echo APPLY || echo DRY-RUN)"
ss -tln 2>/dev/null | grep -q ":$PORT " && ! grep -q "^FOUNDER_TLS256_ADDR=.*:$PORT" "$ENVF" && { say "FAIL: port $PORT is used by something else"; exit 3; }
run install -d -m 0750 -o root -g anexomail-founder "$TLSD"
run install -m 0640 -o root -g anexomail-founder "$CRT" "$TLSD/$HOST.crt"
run install -m 0640 -o root -g anexomail-founder "$KEY" "$TLSD/$HOST.key"
run cp -p "$ENVF" "$ENVF.bak.$(date +%s)"
setenv() { if grep -q "^$1=" "$ENVF"; then run sed -i "s|^$1=.*|$1=$2|" "$ENVF"; else if [ "$APPLY" = 1 ]; then echo "$1=$2" >>"$ENVF"; else say "  [dry-run] echo $1=$2 >> $ENVF"; fi; fi; }
setenv FOUNDER_TLS256_ADDR "0.0.0.0:$PORT"; setenv FOUNDER_TLS256_CERT "$TLSD/$HOST.crt"; setenv FOUNDER_TLS256_KEY "$TLSD/$HOST.key"
setenv FOUNDER_TLS_PROBE "$HOST:443,$HOST:$PORT,anexomail.com:443"
if [ "$APPLY" = 1 ]; then
  cat >/etc/cron.d/anexomail-founder-tls <<CRON
# keeps the founder TLS-256 certificate copy fresh (Caddy renews it); restarts the service only if the certificate changed
17 4 * * 1 root c="\$(find $CADDY_CERTS -type f -name $HOST.crt | head -1)"; [ -n "\$c" ] && ! cmp -s "\$c" $TLSD/$HOST.crt && install -m 0640 -o root -g anexomail-founder "\$c" $TLSD/$HOST.crt && install -m 0640 -o root -g anexomail-founder "\${c%.crt}.key" $TLSD/$HOST.key && systemctl restart $SVC
CRON
  systemctl restart $SVC; sleep 3
  journalctl -u $SVC -n 40 --no-pager 2>/dev/null | grep -E "TLS-256" | tail -2
  say "== proof (normal client, then AES-128-only client)"
  openssl s_client -connect "127.0.0.1:$PORT" -servername "$HOST" -tls1_3 </dev/null 2>/dev/null | grep -E "Protocol  :|Cipher    :|Verify return|Verification" 
  say "-- AES-128-only must FAIL:"
  openssl s_client -connect "127.0.0.1:$PORT" -servername "$HOST" -tls1_3 -ciphersuites TLS_AES_128_GCM_SHA256 </dev/null 2>&1 | grep -E "alert|handshake failure|Cipher    :|no cipher" | head -2
  say "DONE. If the proof above is wrong: cp the .bak back over $ENVF and systemctl restart $SVC. Firewall: if 8443 is closed from outside, open it for the Chrome test (ufw allow $PORT/tcp) — not done here."
else
  say "DRY-RUN finished. Nothing changed. Re-run with APPLY=1."
fi
