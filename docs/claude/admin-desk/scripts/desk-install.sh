#!/usr/bin/env bash
# ANEXOMAIL ADMIN DESK installer R3a0 (21 Nov 2026). DESK ISOLATION: its own user, own dir /opt/anexomail-desk, own unit anexomail-desk, loopback 127.0.0.1:4400.
# Does NOT touch: anexomail-founder, anexomail-rust, ufw, any env of another service. Step 6/6 touches ONLY the admindesk block of the Caddyfile (one header line, backup + validate + rollback). Rerun is safe (old binary backed up, rollback on failure).
set -u
REPO="${REPO:-/opt/anexomail-web}"; ROOT=/opt/anexomail-desk; SVC=anexomail-desk; export CARGO_TARGET_DIR="$ROOT/target"
command -v cargo >/dev/null 2>&1 || export PATH="$HOME/.cargo/bin:$PATH"
command -v cargo >/dev/null 2>&1 || { echo "FAIL: cargo not found"; exit 2; }
git -C "$REPO" fetch -q origin main || { echo "FAIL: fetch"; exit 2; }
show() { git -C "$REPO" show "origin/main:$1"; }
echo "== 1/4 source (admin-desk/server from origin/main)"
mkdir -p "$ROOT/src/src"; show admin-desk/server/Cargo.toml >"$ROOT/src/Cargo.toml"; rm -f "$ROOT"/src/src/*.rs; for f in $(git -C "$REPO" ls-tree --name-only origin/main admin-desk/server/src/ | grep "\.rs$"); do show "$f" >"$ROOT/src/src/$(basename "$f")"; done; echo "   rust files: $(ls "$ROOT"/src/src/*.rs | xargs -n1 basename | tr "
" " ")"; show admin-desk/server/Cargo.lock >"$ROOT/src/Cargo.lock" 2>/dev/null
echo "== 2/4 build"; NEW="$ROOT/target/release/anexomail-desk"; rm -f "$NEW"; (cd "$ROOT/src" && nice cargo build --release >"$ROOT/build.log" 2>&1); RC=$?; if [ $RC != 0 ] || [ ! -x "$NEW" ]; then echo "FAIL: build (nothing installed, the running Desk is untouched)"; grep -E "^error" -A6 "$ROOT/build.log" | head -20; exit 3; fi; tail -1 "$ROOT/build.log"
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
echo "OK: anexomail-desk is up on 127.0.0.1:4400"
# 5/5 (his 21 Nov 2026 21:41: ONE install command does everything): the Desk's own database login + database CA, kept if it works, renewed if it does not
echo "== 5/5 database login (desk_app)"
if [ -r /etc/anexomail-desk/db.env ]; then bash <(show admin-desk/scripts/desk-appdb.sh) --ensure || exit $?; else echo "   skipped: /etc/anexomail-desk/db.env not there yet"; fi
# 6/6 (his 22 Nov 2026 00:43 'haan advance only'): tell browsers the Desk speaks QUIC on UDP 4400 (Alt-Svc). Only the admindesk block of the Caddyfile changes: ONE header line.
echo "== 6/6 Alt-Svc for the Desk (HTTP/3 on UDP 4400)"
CF=/etc/caddy/Caddyfile; BK=/root/caddy-backups; LINE='    header Alt-Svc `h3=":4400"; ma=86400`'
if [ ! -f "$CF" ]; then echo "   skipped: $CF not found"
elif awk '/^admindesk\.anexomail\.com[[:space:]]*\{/{i=1} i&&/Alt-Svc/{f=1} i&&/^\}/{i=0} END{exit !f}' "$CF"; then echo "   already set in the admindesk block, nothing changed"
else
  mkdir -p "$BK"; B="$BK/Caddyfile.admindesk-altsvc.$(date +%Y%m%d-%H%M%S)"; cp -a "$CF" "$B"; echo "   backup: $B"
  awk -v L="$LINE" '/^admindesk\.anexomail\.com[[:space:]]*\{/{i=1} {print} i&&/reverse_proxy 127\.0\.0\.1:4400/{print L} i&&/^\}/{i=0}' "$B" >"$CF.new" && cp "$CF.new" "$CF" && rm -f "$CF.new"
  if caddy validate --config "$CF" --adapter caddyfile >/dev/null 2>&1 && systemctl reload caddy; then
    sleep 2; AS="$(curl -sI --max-time 10 https://admindesk.anexomail.com/ | grep -i '^alt-svc' | tr -d '\r')"; echo "   alt-svc now: $AS"
    case "$AS" in *':4400"'*) echo "OK: browsers are told h3 on UDP 4400 (first visit still arrives through Caddy; the next ones use the Desk's own QUIC)";; *) echo "FAIL: header not as expected, restoring the backup"; cp -a "$B" "$CF"; systemctl reload caddy;; esac
  else echo "FAIL: caddy validate or reload failed, restoring the backup"; cp -a "$B" "$CF"; systemctl reload caddy; fi
fi
