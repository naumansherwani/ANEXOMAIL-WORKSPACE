#!/usr/bin/env bash
# K5a (founder lane build, 9 Nov 2026): switch ON the AES-256-only TLS 1.3 terminator + re-origination tunnel for the AWAM hosts, on a SPARE loopback port (default 18081).
# Technology: server ops (bash) around the Rust module server/founder/src/awamtls.rs. NOTHING public changes here: the K4 front still sends the awam names straight to Caddy (18443).
# Default = DRY RUN; APPLY=1 does it:
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/awam-tls256.sh)           # dry run
#   git -C /opt/anexomail-web fetch -q origin main && APPLY=1 bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/awam-tls256.sh)     # do it
# What APPLY=1 does: (1) copies every awam certificate + key that Caddy already obtained (not the founder host) into /etc/anexomail/tls/awam (0640 root:anexomail-founder),
# (2) backs up /etc/anexomail/founder.env and adds FOUNDER_AWAM_TLS_* lines (idempotent), (3) installs /usr/local/sbin/anexomail-awam-certs-sync + a DAILY cron (atomic rename, only when a file changed;
# the service re-reads the directory every 10 minutes, a bad file never replaces a good one), (4) restarts the founder service, (5) proves it on the spare port with openssl + curl.
# Rollback: cp the .bak env back over /etc/anexomail/founder.env, systemctl restart anexomail-founder, rm /etc/cron.d/anexomail-awam-tls. Needs the Rust binary with awamtls.rs (founder-install.sh first).
set -u
APPLY="${APPLY:-0}"; PORT="${AWAM_TLS_PORT:-18081}"; UPSTREAM="${AWAM_TLS_UPSTREAM:-127.0.0.1:18443}"; FHOST="${FOUNDER_HOST:-founderworkspace.anexomail.com}"
CADDY_CERTS="${CADDY_CERTS:-/var/lib/caddy/.local/share/caddy/certificates}"; AWD=/etc/anexomail/tls/awam; ENVF=/etc/anexomail/founder.env; SVC=anexomail-founder; SYNC=/usr/local/sbin/anexomail-awam-certs-sync
say() { printf '%s\n' "$*"; }; run() { if [ "$APPLY" = 1 ]; then "$@"; else say "  [dry-run] $*"; fi; }
id anexomail-founder >/dev/null 2>&1 || { say "FAIL: user anexomail-founder missing (run founder-install.sh first)"; exit 2; }
[ -r "$ENVF" ] || { say "FAIL: $ENVF missing (run founder-install.sh first)"; exit 2; }
strings /opt/anexomail-founder/anexomail-founder 2>/dev/null | grep -q "FOUNDER_AWAM_TLS_ADDR" || { say "FAIL: the installed founder binary has no awam TLS-256 code yet: run founder-install.sh first"; exit 2; }
ss -tln 2>/dev/null | grep -q ":$PORT " && ! grep -q "^FOUNDER_AWAM_TLS_ADDR=.*:$PORT" "$ENVF" && { say "FAIL: port $PORT is used by something else (PORT RED LINE: pick another from a fresh ss list)"; exit 3; }
CRTS="$(find "$CADDY_CERTS" -type f -name '*.crt' 2>/dev/null)"
[ -n "$CRTS" ] || { say "FAIL: no certificates under $CADDY_CERTS (CADDY_CERTS=...)"; exit 2; }
say "== awam AES-256 terminator on 127.0.0.1:$PORT -> Caddy $UPSTREAM   mode: $([ "$APPLY" = 1 ] && echo APPLY || echo DRY-RUN)"
run install -d -m 0750 -o root -g anexomail-founder "$AWD"
N=0
while IFS= read -r crt; do
  host="$(basename "$crt" .crt)"; key="${crt%.crt}.key"
  [ "$host" = "$FHOST" ] && continue
  printf '%s' "$host" | grep -Eq '^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$' || { say "  skip (not a plain host name): $host"; continue; }
  [ -r "$key" ] || { say "  skip (no key): $host"; continue; }
  run install -m 0640 -o root -g anexomail-founder "$crt" "$AWD/$host.crt"; run install -m 0640 -o root -g anexomail-founder "$key" "$AWD/$host.key"; N=$((N+1))
done <<<"$CRTS"
say "  $N awam hosts copied"
run cp -p "$ENVF" "$ENVF.bak.k5a.$(date +%s)"
setenv() { if grep -q "^$1=" "$ENVF"; then run sed -i "s|^$1=.*|$1=$2|" "$ENVF"; else if [ "$APPLY" = 1 ]; then echo "$1=$2" >>"$ENVF"; else say "  [dry-run] echo $1=$2 >> $ENVF"; fi; fi; }
setenv FOUNDER_AWAM_TLS_ADDR "127.0.0.1:$PORT"; setenv FOUNDER_AWAM_TLS_DIR "$AWD"; setenv FOUNDER_AWAM_TLS_UPSTREAM "$UPSTREAM"; setenv FOUNDER_AWAM_TLS_PROXY on
if [ "$APPLY" = 1 ]; then
  cat >"$SYNC" <<SCRIPT
#!/usr/bin/env bash
# keeps $AWD fresh (Caddy renews the certificates): atomic rename per file, only when something changed
find "$CADDY_CERTS" -type f -name '*.crt' | while IFS= read -r c; do
  h="\$(basename "\$c" .crt)"; k="\${c%.crt}.key"; [ "\$h" = "$FHOST" ] && continue; [ -r "\$k" ] || continue
  printf '%s' "\$h" | grep -Eq '^[a-z0-9]([a-z0-9.-]*[a-z0-9])?\$' || continue
  for f in key crt; do s="\$k"; [ "\$f" = crt ] && s="\$c"; d="$AWD/\$h.\$f"
    cmp -s "\$s" "\$d" || { install -m 0640 -o root -g anexomail-founder "\$s" "\$d.new" && mv -f "\$d.new" "\$d"; }
  done
done
SCRIPT
  chmod 0755 "$SYNC"
  printf '%s\n' '# daily copy of the awam certificates for the founder AES-256 terminator (the service re-reads every 10 minutes)' "27 4 * * * root $SYNC" >/etc/cron.d/anexomail-awam-tls
  systemctl restart $SVC; sleep 4
  journalctl -u $SVC -n 40 --no-pager 2>/dev/null | grep -E "awam TLS-256" | tail -3
  say "== proof on the spare port (normal client, AES-128-only client, then a real request over h2)"
  for h in anexomail.com app.anexomail.com; do
    say "-- $h"
    openssl s_client -connect "127.0.0.1:$PORT" -servername "$h" -tls1_3 -alpn h2 </dev/null 2>/dev/null | grep -E "Cipher    :|ALPN protocol|Verification"
    openssl s_client -connect "127.0.0.1:$PORT" -servername "$h" -tls1_3 -ciphersuites TLS_AES_128_GCM_SHA256 </dev/null 2>&1 | grep -E "alert|handshake failure" | head -1
    curl -sS -o /dev/null --http2 --resolve "$h:$PORT:127.0.0.1" -w "   request via the tunnel: %{http_code} %{http_version}\n" "https://$h:$PORT/" 2>&1 | tail -1
  done
  say "DONE. Public traffic is unchanged (the front still goes straight to Caddy). If the proof above is wrong: cp the .bak.k5a env back over $ENVF and systemctl restart $SVC."
else
  say "DRY-RUN finished. Nothing changed. Re-run with APPLY=1."
fi
