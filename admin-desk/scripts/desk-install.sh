#!/usr/bin/env bash
# ANEXOMAIL ADMIN DESK installer R3a0 (21 Nov 2026). DESK ISOLATION: its own user, own dir /opt/anexomail-desk, own unit anexomail-desk, loopback 127.0.0.1:4400.
# Does NOT touch: anexomail-founder, anexomail-rust, Caddy, ufw, any env of another service. Rerun is safe (old binary backed up, rollback on failure).
set -u
REPO="${REPO:-/opt/anexomail-web}"; ROOT=/opt/anexomail-desk; SVC=anexomail-desk; export CARGO_TARGET_DIR="$ROOT/target"
command -v cargo >/dev/null 2>&1 || export PATH="$HOME/.cargo/bin:$PATH"
command -v cargo >/dev/null 2>&1 || { echo "FAIL: cargo not found"; exit 2; }
git -C "$REPO" fetch -q origin main || { echo "FAIL: fetch"; exit 2; }
show() { git -C "$REPO" show "origin/main:$1"; }
echo "== 1/4 source (admin-desk/server from origin/main)"
mkdir -p "$ROOT/src/src"; show admin-desk/server/Cargo.toml >"$ROOT/src/Cargo.toml"; show admin-desk/server/src/main.rs >"$ROOT/src/src/main.rs"
echo "== 2/4 build"; (cd "$ROOT/src" && nice cargo build --release 2>&1 | tail -3); NEW="$ROOT/target/release/anexomail-desk"; [ -x "$NEW" ] || { echo "FAIL: build"; exit 3; }
echo "== 3/4 user + files"
id $SVC >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin $SVC
[ -f "$ROOT/anexomail-desk" ] && cp "$ROOT/anexomail-desk" "$ROOT/anexomail-desk.bak.$(date +%s)"
install -m 755 "$NEW" "$ROOT/anexomail-desk.new" && mv -f "$ROOT/anexomail-desk.new" "$ROOT/anexomail-desk"
rm -rf "$ROOT/dist-desk.new"; mkdir -p "$ROOT/dist-desk.new"
for f in $(git -C "$REPO" ls-tree -r --name-only origin/main founder-web/dist-desk); do rel="${f#founder-web/dist-desk/}"; mkdir -p "$ROOT/dist-desk.new/$(dirname "$rel")"; show "$f" >"$ROOT/dist-desk.new/$rel"; done
if [ -f "$ROOT/dist-desk.new/desk.html" ]; then rm -rf "$ROOT/dist-desk.old"; [ -d "$ROOT/dist-desk" ] && mv "$ROOT/dist-desk" "$ROOT/dist-desk.old"; mv "$ROOT/dist-desk.new" "$ROOT/dist-desk"; else echo "   note: founder-web/dist-desk/desk.html not in the repo yet; pages stay as before"; rm -rf "$ROOT/dist-desk.new"; fi
chown -R $SVC:$SVC "$ROOT/dist-desk" 2>/dev/null
cat >/etc/systemd/system/$SVC.service <<U
[Unit]
Description=Anexomail Admin Desk (own process, loopback 4400)
After=network.target
[Service]
User=$SVC
ExecStart=$ROOT/anexomail-desk
Restart=on-failure
RestartSec=2
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
PrivateDevices=true
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
MemoryDenyWriteExecute=true
[Install]
WantedBy=multi-user.target
U
# the awam AES-256 edge serves only names whose certificate it has copied; run the existing sync so a new Desk host is not refused for up to a day
[ -x /usr/local/sbin/anexomail-awam-certs-sync ] && /usr/local/sbin/anexomail-awam-certs-sync >/dev/null 2>&1
echo "== 4/4 start + check"
systemctl daemon-reload && systemctl enable $SVC >/dev/null 2>&1; systemctl restart $SVC; sleep 2
H="$(curl -s -o /dev/null -w %{http_code} -H 'Host: admindesk.anexomail.com' http://127.0.0.1:4400/desk/v1/health)"
W="$(curl -s -o /dev/null -w %{http_code} -H 'Host: founderworkspace.anexomail.com' http://127.0.0.1:4400/desk/v1/health)"
echo "   health with the Desk host: $H (want 200); wrong host: $W (want 404)"
echo "   listener:"; ss -ltnp | grep ':4400' | sed 's/^/     /'
if [ "$H" != 200 ] || [ "$W" != 404 ]; then echo "FAIL: rollback"; systemctl stop $SVC; B="$(ls -t $ROOT/anexomail-desk.bak.* 2>/dev/null | head -1)"; [ -n "$B" ] && cp "$B" "$ROOT/anexomail-desk" && systemctl start $SVC; journalctl -u $SVC -n 15 --no-pager; exit 4; fi
echo "   public: curl -sI https://admindesk.anexomail.com | head -3"; curl -sI --max-time 10 https://admindesk.anexomail.com | head -3
echo "OK: anexomail-desk is up on 127.0.0.1:4400 (login door not connected until R3a2)"
