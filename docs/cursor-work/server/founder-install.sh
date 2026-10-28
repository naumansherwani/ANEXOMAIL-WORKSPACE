#!/usr/bin/env bash
# ANEXOMAIL FOUNDER — anexomail-founder (Rust, Rule 61/62/63) SAFE install: alag Linux user + alag systemd service, localhost-only :3210.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh)
# Kya karta hai (anexomail-rust :3200, Brain, web, Caddy, .env ko HAATH NAHI):
#   1. origin/main se server/founder (+ server/rust/jwt_core.rs) ko /opt/anexomail-founder/src mein; cargo test (fail => ruk jao).
#   2. cargo build --release; purani binary ka backup; naya binary; 
#   3. user `anexomail-founder` (no shell); /etc/anexomail/founder.env (mode 600): SUPABASE4_* anexomail-rust ki .env se, FOUNDER_HMAC_KEY pehli baar random (dobara nahi badalta).
#   4. systemd unit (ProtectSystem=strict, NoNewPrivileges, PrivateTmp, seccomp-lite) -> start -> /healthz + /founder/v1/me bina token = 401 saboot.
#   Fail => purani binary wapas. Caddy/host ABHI nahi (F1a mein alag, pehle saboot).
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"; ROOT=/opt/anexomail-founder; RUST_ENV="${RUST_ENV:-/opt/anexomail-rust/.env}"
SVC=anexomail-founder; ENVF=/etc/anexomail/founder.env; STAMP="$(date +%s)"
command -v cargo >/dev/null 2>&1 || export PATH="$HOME/.cargo/bin:$PATH"
command -v cargo >/dev/null 2>&1 || { echo "FAIL: cargo nahi mila"; exit 2; }
[ "$(id -u)" -eq 0 ] || { echo "FAIL: root chahiye"; exit 2; }
show() { git -C "$REPO" show "origin/main:$1"; }
mkdir -p "$ROOT/src/src" "$ROOT/web" /etc/anexomail
for f in Cargo.toml Cargo.lock src/main.rs src/audit.rs src/gate.rs src/sign.rs src/bridge.rs src/data.rs src/login.rs; do show "server/founder/$f" >"$ROOT/src/$f" || { echo "FAIL: repo mein server/founder/$f nahi"; exit 2; }; done
# jwt_core ko main.rs `../../rust/jwt_core.rs` se leta hai
mkdir -p "$ROOT/rust" && show server/rust/jwt_core.rs >"$ROOT/rust/jwt_core.rs" || { echo "FAIL: jwt_core.rs nahi"; exit 2; }
# main.rs ka path src/ se ../../rust/jwt_core.rs = $ROOT/rust/jwt_core.rs (src/src -> ../../ = src/..)
echo "== 1/4 tests"; (cd "$ROOT/src" && cargo test --release 2>&1 | grep -E "test result|FAILED|^error" ) ; (cd "$ROOT/src" && cargo test --release >/dev/null 2>&1) || { echo "FAIL: tests — kuch nahi badla"; exit 3; }
echo "== 2/4 build"; (cd "$ROOT/src" && nice cargo build --release 2>&1 | tail -3) ; NEW="$ROOT/src/target/release/anexomail-founder"; [ -x "$NEW" ] || { echo "FAIL: build"; exit 3; }
[ -x "$ROOT/anexomail-founder" ] && cp "$ROOT/anexomail-founder" "$ROOT/anexomail-founder.bak.$STAMP"
echo "== 2b/4 SPA (founder-web/dist, sandbox mein bana; server par npm/Node NAHI)"
NEWWEB="$ROOT/web.new.$STAMP"; mkdir -p "$NEWWEB"
for f in $(git -C "$REPO" ls-tree -r --name-only origin/main founder-web/dist); do rel="${f#founder-web/dist/}"; mkdir -p "$NEWWEB/$(dirname "$rel")"; show "$f" >"$NEWWEB/$rel"; done
[ -f "$NEWWEB/index.html" ] || { echo "FAIL: founder-web/dist/index.html repo mein nahi"; exit 3; }
rm -rf "$ROOT/web.old"; [ -d "$ROOT/web" ] && mv "$ROOT/web" "$ROOT/web.old"; mv "$NEWWEB" "$ROOT/web"
echo "== 3/4 user + env"
# Supabase kunjiyan: pehle jo export hon, phir .env files (Rust/Brain/sync), phir chalte anexomail-rust ka pm2 env. Kahin nahi mile => ruk jao (kuch half nahi).
envv() { for n in "$@"; do
  [ -n "${!n:-}" ] && { printf '%s' "${!n}"; return; }
  for f in "$RUST_ENV" /opt/anexomail/.env /etc/anexomail/sync.env /etc/anexomail/*.env; do [ -r "$f" ] && { v="$(grep -m1 -E "^(export )?$n=" "$f" | cut -d= -f2- | sed -e "s/^[\"']//" -e "s/[\"']\$//")"; [ -n "$v" ] && { printf '%s' "$v"; return; }; }; done
  if command -v pm2 >/dev/null 2>&1; then v="$(pm2 env "$(pm2 id anexomail-rust 2>/dev/null | tr -dc '0-9' | head -c 4)" 2>/dev/null | grep -m1 -E "^$n:" | sed -e "s/^$n: *//")"; [ -n "$v" ] && { printf '%s' "$v"; return; }; fi
done; }
if [ ! -f "$ENVF" ]; then
  SBU="$(envv SUPABASE4_URL SUPABASE_URL)"; SBK="$(envv SUPABASE4_SERVICE_ROLE_KEY SUPABASE_SERVICE_ROLE_KEY)"
  if [ -z "$SBU" ] || [ -z "$SBK" ]; then
    echo "FAIL: Supabase URL/service key kahin nahi mili (.env files + pm2 env dekhe). Haath se do aur dobara chalao:"
    echo "   SUPABASE4_URL=https://<ref>.supabase.co SUPABASE4_SERVICE_ROLE_KEY=<service role> bash <(git -C $REPO show origin/main:docs/cursor-work/server/founder-install.sh)"
    exit 3
  fi
  umask 077; { echo "SUPABASE4_URL=$SBU"; echo "SUPABASE4_SERVICE_ROLE_KEY=$SBK"; echo "FOUNDER_HMAC_KEY=$(head -c 48 /dev/urandom | base64 | tr -d '\n=+/' | head -c 48)"; echo "FOUNDER_BIND=127.0.0.1:3210"; echo "FOUNDER_STATIC=$ROOT/web"; } >"$ENVF"
fi
id anexomail-founder >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin anexomail-founder
install -m 755 "$NEW" "$ROOT/anexomail-founder"
chown root:anexomail-founder "$ENVF"; chmod 640 "$ENVF"; chown -R root:anexomail-founder "$ROOT/web"; chmod -R g+rX "$ROOT/web"
cat >/etc/systemd/system/$SVC.service <<UNIT
[Unit]
Description=ANEXOMAIL Founder (Rust)
After=network-online.target
[Service]
User=anexomail-founder
EnvironmentFile=$ENVF
ExecStart=$ROOT/anexomail-founder
Restart=on-failure
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectKernelTunables=yes
ProtectControlGroups=yes
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
CapabilityBoundingSet=
ReadOnlyPaths=/var/lib/anexomail
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload && systemctl enable $SVC >/dev/null 2>&1; systemctl restart $SVC; sleep 2
echo "== 4/4 saboot"
H="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3210/healthz)"; M="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3210/founder/v1/me)"; B="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3210/founder/v1/bridge)"
S="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3210/)"; echo "SPA index=$S (200)"; echo "healthz=$H (200 chahiye)  me bina token=$M (401)  bridge bina token=$B (401)"
if [ "$S" = 200 ] && [ "$H" = 200 ] && [ "$M" = 401 ] && [ "$B" = 401 ]; then echo "OK - founder service zinda, darwaza band. Caddy/host abhi nahi (F1a)."; else
  echo "FAIL: rollback"; systemctl stop $SVC; B2="$(ls -t $ROOT/anexomail-founder.bak.* 2>/dev/null | head -1)"; [ -n "$B2" ] && cp "$B2" "$ROOT/anexomail-founder" && systemctl start $SVC; journalctl -u $SVC -n 15 --no-pager; exit 4; fi
