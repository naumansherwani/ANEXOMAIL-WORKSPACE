#!/usr/bin/env bash
# KP1b STEP A (founder 13 Nov 2026): install the founder's OWN authoritative DNS (server/founder-dns, Rust + tokio) as its own systemd service on port 53.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-dns-install.sh)
# What it does NOT touch: anexomail-founder, anexomail-rust, Caddy, systemd-resolved, the firewall (ufw/iptables are NOT changed here: step B opens port 53 later, with his word), DNS at Namecheap (nothing delegates to this server yet, so NOTHING changes for any visitor).
# What it does: 1) copies server/founder-dns from origin/main, cargo test (fail = stop, nothing replaced) 2) cargo build --release 3) user `founder-dns` (no shell) + /etc/anexomail/founder-dns.env (created once, never overwritten)
#   4) systemd unit (CAP_NET_BIND_SERVICE only, ProtectSystem=strict, NoNewPrivileges, no new address families) 5) start 6) proof from the server itself: ss owner of port 53 on the PUBLIC addresses, dig @62.238.98.98 for HTTPS / A / AAAA / SOA / NS, REFUSED for another zone.
# Rollback: systemctl disable --now founder-dns  (nothing else depends on it).
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"; ROOT=/opt/founder-dns; SVC=founder-dns; ENVF=/etc/anexomail/founder-dns.env; STAMP="$(date +%s)"
Z=founderworkspace.anexomail.com
command -v cargo >/dev/null 2>&1 || export PATH="$HOME/.cargo/bin:$PATH"
command -v cargo >/dev/null 2>&1 || { echo "FAIL: cargo not found"; exit 2; }
[ "$(id -u)" -eq 0 ] || { echo "FAIL: root needed"; exit 2; }
echo "cargo: $(cargo --version)"
show() { git -C "$REPO" show "origin/main:$1"; }
mkdir -p "$ROOT/src/src" "$ROOT/src/tests" /etc/anexomail
for f in Cargo.toml Cargo.lock $(git -C "$REPO" ls-tree --name-only origin/main server/founder-dns/src/ | sed "s#^server/founder-dns/##" | grep -E "\.rs$") tests/wire.rs; do show "server/founder-dns/$f" >"$ROOT/src/$f" || { echo "FAIL: server/founder-dns/$f is not in the repo"; exit 2; }; done
echo "== 1/6 tests (a failure stops here, nothing is replaced)"
(cd "$ROOT/src" && cargo test --release 2>&1 | grep -E "test result|FAILED|^error|panicked" | head -8); (cd "$ROOT/src" && cargo test --release >/dev/null 2>&1) || { echo "FAIL: tests"; exit 3; }
echo "== 2/6 build"; (cd "$ROOT/src" && nice cargo build --release 2>&1 | tail -2); NEW="$ROOT/src/target/release/founder-dns"; [ -x "$NEW" ] || { echo "FAIL: build"; exit 3; }
[ -x "$ROOT/founder-dns" ] && cp "$ROOT/founder-dns" "$ROOT/founder-dns.bak.$STAMP"
echo "== 3/6 user + env"
id founder-dns >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin founder-dns
V4="$(ip -o -4 addr show scope global | awk '{print $4}' | cut -d/ -f1 | head -1)"; V6="$(ip -o -6 addr show scope global | awk '{print $4}' | cut -d/ -f1 | head -1)"
[ -n "$V4" ] || { echo "FAIL: no public IPv4 address found"; exit 3; }
if [ ! -f "$ENVF" ]; then
  BIND="$V4:53"; [ -n "$V6" ] && BIND="$BIND,[$V6]:53"
  umask 077; cat >"$ENVF" <<ENV
DNS_ZONE=$Z.
DNS_NS=ns1.anexomail.com.,ns2.anexomail.com.
DNS_HOSTMASTER=hostmaster.anexomail.com.
DNS_SERIAL=$(date +%Y%m%d)01
DNS_V4=$V4
DNS_V6=$V6
DNS_ALPN=h3
DNS_TTL=300
DNS_BIND=$BIND
ENV
  chown root:founder-dns "$ENVF"; chmod 640 "$ENVF"
fi
grep -E '^DNS_(ZONE|NS|V4|V6|ALPN|BIND)=' "$ENVF" | sed 's/^/   /'
install -m 755 "$NEW" "$ROOT/founder-dns"
echo "== 4/6 systemd unit"
cat >/etc/systemd/system/$SVC.service <<UNIT
[Unit]
Description=founder-dns: the founder's own authoritative DNS (zone $Z only)
After=network-online.target
Wants=network-online.target
[Service]
User=founder-dns
Group=founder-dns
EnvironmentFile=$ENVF
ExecStart=$ROOT/founder-dns
Restart=on-failure
RestartSec=2
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
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
SystemCallFilter=@system-service
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload; echo "== 5/6 start"; systemctl enable --now $SVC; sleep 2; systemctl is-active $SVC
journalctl -u $SVC -n 6 --no-pager 2>/dev/null | cut -c1-170 | sed 's/^/   /'
echo "== 6/6 proof from this server (the firewall is NOT opened by this script)"
ss -H -lntup 2>/dev/null | awk '$5 ~ /:53$/ {print "   " $1, $5}' | sort -u
for t in HTTPS A AAAA SOA NS; do printf '   %-6s ' $t; dig +short @"$V4" $t $Z 2>/dev/null | tr '\n' ' '; echo; done
printf '   other zone (must be REFUSED): '; dig @"$V4" google.com A 2>/dev/null | grep -o 'status: [A-Z]*'
printf '   nonexistent name (must be NXDOMAIN): '; dig @"$V4" nope.$Z A 2>/dev/null | grep -o 'status: [A-Z]*'
printf '   over TCP: '; dig +tcp +short @"$V4" HTTPS $Z 2>/dev/null
echo; if dig +short @"$V4" HTTPS $Z 2>/dev/null | grep -q h3; then echo "OK: founder-dns answers HTTPS alpn=h3 (nobody delegates to it yet; no visitor is affected). Send this output to Claude."; else echo "STOP: no HTTPS h3 answer. Rollback: systemctl disable --now founder-dns. Send this output to Claude."; fi
