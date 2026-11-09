#!/usr/bin/env bash
# K5a (AWAM LANE, 9 Nov 2026, his order "founder aur awam ka mix nahi"): install the awam AES-256 edge as its OWN program: own binary, own user, own env file, own systemd service.
# Technology: server ops (bash) around the Rust crate server/awam-edge (rustls, TLS 1.3, AES-256-GCM only + re-origination tunnel to Caddy). The founder binary has NO awam code.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/awam-edge-install.sh) 2>&1 | tail -40
# What it does: (1) copies server/awam-edge from origin/main to /opt/anexomail-awam-edge/src, runs cargo test (fail = stop), cargo build --release, keeps the old binary as .bak;
# (2) creates the system user anexomail-awam-edge; (3) copies every awam certificate+key that Caddy already obtained (NOT the founder host) to /etc/anexomail/tls/awam (0640 root:anexomail-awam-edge:
# the founder service can no longer read awam keys); (4) writes /etc/anexomail/awam-edge.env (own file) and removes the old FOUNDER_AWAM_TLS_* lines from founder.env (backup first);
# (5) installs the hardened unit + the daily certificate sync cron; (6) starts the service on the SPARE loopback port 18081 and proves it per host (openssl AES-256 ok, AES-128 refused, curl h2 through the tunnel).
# PUBLIC TRAFFIC IS NOT CHANGED: the K4 front still sends the awam names straight to Caddy until the separate, later front switch.
# Rollback: systemctl disable --now anexomail-awam-edge (nothing depends on it yet). Needs: founder-install.sh run first (the founder binary without awam code releases port 18081).
set -u
REPO=/opt/anexomail-web; ROOT=/opt/anexomail-awam-edge; SVC=anexomail-awam-edge; USERN=anexomail-awam-edge; ENVF=/etc/anexomail/awam-edge.env; FENV=/etc/anexomail/founder.env
PORT="${AWAM_EDGE_PORT:-18081}"; UPSTREAM="${AWAM_EDGE_UPSTREAM:-127.0.0.1:18443}"; FHOST="${FOUNDER_HOST:-founderworkspace.anexomail.com}"
CADDY_CERTS="${CADDY_CERTS:-/var/lib/caddy/.local/share/caddy/certificates}"; AWD=/etc/anexomail/tls/awam; SYNC=/usr/local/sbin/anexomail-awam-certs-sync
command -v cargo >/dev/null 2>&1 || export PATH="$HOME/.cargo/bin:$PATH"
command -v cargo >/dev/null 2>&1 || { echo "FAIL: cargo nahi mila"; exit 2; }
git -C "$REPO" fetch -q origin main 2>/dev/null || { echo "FAIL: git fetch"; exit 2; }
git -C "$REPO" cat-file -e origin/main:server/awam-edge/Cargo.toml 2>/dev/null || { echo "FAIL: server/awam-edge origin/main par nahi"; exit 2; }
CRTS="$(find "$CADDY_CERTS" -type f -name '*.crt' 2>/dev/null)"; [ -n "$CRTS" ] || { echo "FAIL: no certificates under $CADDY_CERTS"; exit 2; }
HOLDER="$(ss -tlnp 2>/dev/null | grep ":$PORT " | grep -v "$SVC" | head -1)"
[ -z "$HOLDER" ] || { echo "FAIL: port $PORT is held by: $HOLDER"; echo "  (the old founder binary with awam code? run founder-install.sh first; PORT RED LINE: never stop a listed port)"; exit 3; }
echo "== 1/5 source + tests + build"
mkdir -p "$ROOT/src/src"
for f in Cargo.toml Cargo.lock src/main.rs; do git -C "$REPO" show "origin/main:server/awam-edge/$f" >"$ROOT/src/$f" 2>/dev/null || [ "$f" = Cargo.lock ] || { echo "FAIL: $f"; exit 2; }; done
(cd "$ROOT/src" && cargo test --release 2>&1 | grep -E "test result|FAILED|^error"); (cd "$ROOT/src" && cargo test --release >/dev/null 2>&1) || { echo "FAIL: tests"; exit 3; }
(cd "$ROOT/src" && nice cargo build --release 2>&1 | tail -2); NEW="$ROOT/src/target/release/anexomail-awam-edge"; [ -x "$NEW" ] || { echo "FAIL: build"; exit 3; }
echo "== 2/5 user + certificates"
id "$USERN" >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin "$USERN"
install -d -m 0750 -o root -g "$USERN" "$AWD"
# the awam user must be able to REACH $AWD: give it traverse-only (x, no list/read) on every parent dir; the founder certs stay unreadable to it
P="$(dirname "$AWD")"; while [ "$P" != "/" ]; do
  if command -v setfacl >/dev/null 2>&1; then setfacl -m "u:$USERN:--x" "$P"; else [ "$(stat -c %a "$P" | tail -c 2 | head -c 1)" -ge 1 ] || chmod o+x "$P"; fi
  P="$(dirname "$P")"; done
sudo -u "$USERN" -- test -r "$AWD" 2>/dev/null || runuser -u "$USERN" -- ls "$AWD" >/dev/null 2>&1 || { echo "FAIL: $USERN cannot read $AWD"; ls -ld /etc/anexomail /etc/anexomail/tls "$AWD"; exit 4; }
N=0
while IFS= read -r crt; do
  host="$(basename "$crt" .crt)"; key="${crt%.crt}.key"
  [ "$host" = "$FHOST" ] && continue
  printf '%s' "$host" | grep -Eq '^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$' || { echo "  skip (not a plain host name): $host"; continue; }
  [ -r "$key" ] || { echo "  skip (no key): $host"; continue; }
  install -m 0640 -o root -g "$USERN" "$crt" "$AWD/$host.crt" && install -m 0640 -o root -g "$USERN" "$key" "$AWD/$host.key" && N=$((N+1))
done <<<"$CRTS"
echo "   $N awam hosts copied"
echo "== 3/5 own env file (founder.env loses the old awam lines)"
[ -f "$ENVF" ] && cp -p "$ENVF" "$ENVF.bak.$(date +%s)"
printf '%s\n' "AWAM_EDGE_ADDR=127.0.0.1:$PORT" "AWAM_EDGE_DIR=$AWD" "AWAM_EDGE_UPSTREAM=$UPSTREAM" "AWAM_EDGE_PROXY=on" "AWAM_EDGE_MAX=20000" >"$ENVF"
chown root:"$USERN" "$ENVF"; chmod 0640 "$ENVF"
if grep -q '^FOUNDER_AWAM_TLS_' "$FENV" 2>/dev/null; then cp -p "$FENV" "$FENV.bak.noawam.$(date +%s)"; sed -i '/^FOUNDER_AWAM_TLS_/d' "$FENV"; echo "   removed FOUNDER_AWAM_TLS_* from founder.env"; fi
echo "== 4/5 service + certificate sync"
[ -x "$ROOT/$SVC" ] && cp -p "$ROOT/$SVC" "$ROOT/$SVC.bak.$(date +%s)"
install -m 0755 "$NEW" "$ROOT/$SVC"
cat >/etc/systemd/system/$SVC.service <<UNIT
[Unit]
Description=ANEXOMAIL awam edge (AES-256 TLS 1.3 terminator + tunnel to Caddy)
After=network-online.target
[Service]
User=$USERN
EnvironmentFile=$ENVF
ExecStart=$ROOT/$SVC
Restart=always
RestartSec=2
LimitNOFILE=65536
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictAddressFamilies=AF_INET AF_INET6
RestrictNamespaces=yes
LockPersonality=yes
MemoryDenyWriteExecute=yes
CapabilityBoundingSet=
ReadOnlyPaths=$AWD
[Install]
WantedBy=multi-user.target
UNIT
cat >"$SYNC" <<SCRIPT
#!/usr/bin/env bash
# keeps $AWD fresh (Caddy renews the certificates): atomic rename per file, only when something changed; the service re-reads the directory every 10 minutes
find "$CADDY_CERTS" -type f -name '*.crt' | while IFS= read -r c; do
  h="\$(basename "\$c" .crt)"; k="\${c%.crt}.key"; [ "\$h" = "$FHOST" ] && continue; [ -r "\$k" ] || continue
  printf '%s' "\$h" | grep -Eq '^[a-z0-9]([a-z0-9.-]*[a-z0-9])?\$' || continue
  for f in key crt; do s="\$k"; [ "\$f" = crt ] && s="\$c"; d="$AWD/\$h.\$f"
    cmp -s "\$s" "\$d" || { install -m 0640 -o root -g $USERN "\$s" "\$d.new" && mv -f "\$d.new" "\$d"; }
  done
done
SCRIPT
chmod 0755 "$SYNC"
printf '%s\n' '# daily copy of the awam certificates for the awam edge (the service re-reads every 10 minutes)' "27 4 * * * root $SYNC" >/etc/cron.d/anexomail-awam-tls
rm -f /etc/cron.d/anexomail-awam-tls.old
systemctl daemon-reload; systemctl enable $SVC >/dev/null 2>&1; systemctl restart $SVC; sleep 3
echo "== 5/5 proof on the spare port $PORT (public traffic unchanged)"
systemctl is-active $SVC || { echo "FAIL: service not active"; journalctl -u $SVC -n 15 --no-pager | cut -c1-200; exit 4; }
journalctl -u $SVC -n 20 --no-pager 2>/dev/null | grep -E "awam-edge" | tail -2 | cut -c1-260
for h in anexomail.com app.anexomail.com; do
  echo "-- $h"
  openssl s_client -connect "127.0.0.1:$PORT" -servername "$h" -tls1_3 -alpn h2 </dev/null 2>/dev/null | grep -E "Cipher    :|ALPN protocol|Verification"
  openssl s_client -connect "127.0.0.1:$PORT" -servername "$h" -tls1_3 -ciphersuites TLS_AES_128_GCM_SHA256 </dev/null 2>&1 | grep -E "alert|handshake failure" | head -1
  curl -sS -o /dev/null --http2 --resolve "$h:$PORT:127.0.0.1" -w "   request via the tunnel: %{http_code} %{http_version}\n" "https://$h:$PORT/" 2>&1 | tail -1
done
echo "DONE. Own program: systemctl status $SVC. Founder service untouched except its env lines. Rollback: systemctl disable --now $SVC."
