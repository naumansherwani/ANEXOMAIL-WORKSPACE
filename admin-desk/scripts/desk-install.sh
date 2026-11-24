#!/usr/bin/env bash
# ANEXOMAIL ADMIN DESK installer R3a0 (21 Nov 2026), R3d signing key + Rule 52 check (22 Nov 2026). DESK ISOLATION: its own user, own dir /opt/anexomail-desk, own unit anexomail-desk, loopback 127.0.0.1:4400.
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
mkdir -p "$ROOT/src/contract"; rm -f "$ROOT"/src/contract/*.json; for f in $(git -C "$REPO" ls-tree --name-only origin/main admin-desk/server/contract/ | grep "\.json$"); do show "$f" >"$ROOT/src/contract/$(basename "$f")"; done; echo "   contract files: $(ls "$ROOT"/src/contract/*.json 2>/dev/null | xargs -n1 basename 2>/dev/null | tr "\n" " ")"
echo "== 2/4 build"; T0=$(date +%s); NEW="$ROOT/target/release/anexomail-desk"; rm -f "$NEW"; (cd "$ROOT/src" && DESK_BUILD_COMMIT="$(git -C "$REPO" rev-parse --short origin/main)" nice cargo build --release >"$ROOT/build.log" 2>&1); RC=$?; if [ $RC != 0 ] || [ ! -x "$NEW" ]; then echo "FAIL: build (nothing installed, the running Desk is untouched)"; grep -E "^error" -A6 "$ROOT/build.log" | head -20; exit 3; fi; tail -1 "$ROOT/build.log"; echo "   build took $(( $(date +%s) - T0 )) s, crates compiled: $(grep -c Compiling "$ROOT/build.log")"
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
# R3d (22 Nov 2026, Rule 52): the Desk's OWN Ed25519 signing key. Made ONCE here (32 random bytes, root-only 0600), never printed, never replaced on rerun;
# it reaches the service as a systemd credential (same pattern as the database CA), so /etc/anexomail-desk stays root-only 0700.
SEED=/etc/anexomail-desk/sign.seed; mkdir -p -m 700 /etc/anexomail-desk
if [ -s "$SEED" ]; then echo "   Rule 52 signing key: kept (existing)"; else ( umask 077; head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n' >"$SEED" ); echo "   Rule 52 signing key: created (32 random bytes, root-only)"; fi
chown root:root "$SEED"; chmod 600 "$SEED"
mkdir -p /etc/systemd/system/$SVC.service.d; printf '[Service]\nLoadCredential=sign.seed:%s\nEnvironment=DESK_SIGN_SEED_FILE=%%d/sign.seed\n' "$SEED" >/etc/systemd/system/$SVC.service.d/sign.conf
# R3a2-dbsc (23 Nov 2026): device-bound sessions in OBSERVE mode (register, refresh, ledger; never blocks). Written ONCE: if the file exists (e.g. he later set enforce) it is never overwritten. Rollback = DESK_DBSC=off in that file.
[ -f /etc/systemd/system/$SVC.service.d/dbsc.conf ] && echo "   DBSC mode: kept ($(grep -o 'DESK_DBSC=[a-z]*' /etc/systemd/system/$SVC.service.d/dbsc.conf))" || { printf '[Service]\nEnvironment=DESK_DBSC=observe\n' >/etc/systemd/system/$SVC.service.d/dbsc.conf; echo "   DBSC mode: observe (set now)"; }
# the awam AES-256 edge serves only names whose certificate it has copied; run the existing sync so a new Desk host is not refused for up to a day
[ -x /usr/local/sbin/anexomail-awam-certs-sync ] && /usr/local/sbin/anexomail-awam-certs-sync >/dev/null 2>&1
echo "== 4/4 start + check"
systemctl daemon-reload && systemctl enable $SVC >/dev/null 2>&1; systemctl restart $SVC; sleep 2
H="$(curl -s -o /dev/null -w %{http_code} -H 'Host: admindesk.anexomail.com' http://127.0.0.1:4400/desk/v1/health)"
W="$(curl -s -o /dev/null -w %{http_code} -H 'Host: founderworkspace.anexomail.com' http://127.0.0.1:4400/desk/v1/health)"
K="$(curl -s -H 'Host: admindesk.anexomail.com' http://127.0.0.1:4400/desk/v1/key)"; KC="$(curl -s -o /dev/null -w %{http_code} -H 'Host: admindesk.anexomail.com' http://127.0.0.1:4400/desk/v1/key)"
S="$(curl -s -H 'Host: admindesk.anexomail.com' -H 'x-desk-nonce: 00112233445566778899aabbccddeeff' http://127.0.0.1:4400/desk/v1/sig/ping)"
case "$S" in *'"sig":"'*'unsigned_request'*|*'unsigned_request'*'"sig":"'*) SG=signed;; *) SG=NOT-signed;; esac
echo "   health with the Desk host: $H (want 200); wrong host: $W (want 404)"
echo "   Rule 52: key $KC (want 200) kid=$(printf %s "$K" | grep -o '"kid":"[0-9a-f]*"' | cut -d'"' -f4); call without a session = refused and $SG (want signed)"
echo "   listener:"; ss -ltnp | grep ':4400' | sed 's/^/     /'
if [ "$H" != 200 ] || [ "$W" != 404 ] || [ "$KC" != 200 ] || [ "$SG" != signed ]; then echo "FAIL: rollback"; systemctl stop $SVC; B="$(ls -t $ROOT/anexomail-desk.bak.* 2>/dev/null | head -1)"; [ -n "$B" ] && cp "$B" "$ROOT/anexomail-desk"; [ -d "$ROOT/dist-desk.old" ] && rm -rf "$ROOT/dist-desk" && mv "$ROOT/dist-desk.old" "$ROOT/dist-desk"; systemctl start $SVC; journalctl -u $SVC -n 15 --no-pager; exit 4; fi
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
# 7/7 (his 22 Nov 2026 23:57: ONE install does everything): the Control Plane responder (own binary, UDP 4410, read-only database role), wired to the Desk, with an end-to-end proof line
echo "== 7/7 Control Plane (D5a-3b)"
bash <(show admin-desk/scripts/cp-install.sh) || exit $?
# 8/8 (his 23 Nov 2026 01:18: the Storage Box copy of the lookup-audit checkpoints, signed with the Desk key, timer every 10 minutes)
echo "== 8/8 audit outside copy (D5a-4)"
bash <(show admin-desk/scripts/audit-export-install.sh) || exit $?
# 9/9 (his 23 Nov 2026 02:38: "the last 15 lines must PROVE the new code is the one running"): printed LAST so `tail -15` always shows it. Read-only.
echo "== 9/9 PROOF: the running binary and the live page are the NEW build"
PID="$(systemctl show -p MainPID --value $SVC)"; RUN="$(sha256sum /proc/$PID/exe 2>/dev/null | cut -c1-12)"; BIN="$(sha256sum "$ROOT/anexomail-desk" | cut -c1-12)"; BLD="$(sha256sum "$NEW" | cut -c1-12)"
HEADC="$(git -C "$REPO" rev-parse --short origin/main)"
echo "   $(timeout 5 "$ROOT/anexomail-desk" version 2>&1 | head -1)"
if [ -n "$RUN" ] && [ "$RUN" = "$BIN" ] && [ "$BIN" = "$BLD" ]; then echo "   PROOF binary: running process = installed file = this build ($RUN), repo commit $HEADC: SAME"; else echo "   PROOF binary: DIFFERENT (running $RUN, installed $BIN, built $BLD): do not trust this install"; fi
LIVE="$(curl -s -H 'Host: admindesk.anexomail.com' http://127.0.0.1:4400/adminlogin | grep -o 'desk-[A-Za-z0-9_-]*\.js' | head -1)"; REPOJS="$(show founder-web/dist-desk/desk.html | grep -o 'desk-[A-Za-z0-9_-]*\.js' | head -1)"
if [ -n "$LIVE" ] && [ "$LIVE" = "$REPOJS" ]; then echo "   PROOF page: served bundle $LIVE = repo build: SAME"; else echo "   PROOF page: DIFFERENT (served ${LIVE:-none}, repo ${REPOJS:-none})"; fi
WASM="$(show founder-web/dist-desk/desk.html | grep -o 'anexomail_desk_kernel_bg-[A-Za-z0-9_-]*\.wasm' | head -1)"; [ -z "$WASM" ] && WASM="$(git -C "$REPO" ls-tree --name-only origin/main founder-web/dist-desk/assets/ | grep -o 'anexomail_desk_kernel_bg-[A-Za-z0-9_-]*\.wasm' | head -1)"
SW="$(curl -s -H 'Host: admindesk.anexomail.com' "http://127.0.0.1:4400/assets/$WASM" | sha256sum | cut -c1-12)"; RW="$(git -C "$REPO" show "origin/main:founder-web/dist-desk/assets/$WASM" | sha256sum | cut -c1-12)"
if [ -n "$WASM" ] && [ "$SW" = "$RW" ]; then echo "   PROOF kernel: served $WASM sha $SW = repo: SAME"; else echo "   PROOF kernel: DIFFERENT (served $SW, repo $RW, file ${WASM:-none})"; fi
# 9b (his 23 Nov 2026 07:12: a step that is installed must be PROVEN in the last lines, never hidden above them): the census function of the Control Plane (CP2, Customers and Plans) is checked LAST, read-only.
ADMINU="$( . /etc/anexomail/sync.env 2>/dev/null; printf %s "${WORKING_URL:-}" )"
CP2="$(show admin-desk/sql/checks/CP2-check.sql | env -u PGHOST -u PGPORT -u PGUSER -u PGDATABASE -u PGSERVICE psql "${ADMINU:-postgres://none}" -X -q -At -f - 2>&1)"
CPT="$(printf '%s\n' "$CP2" | grep -c '|t$')"; CPF="$(printf '%s\n' "$CP2" | grep -c '|f$')"
if [ -n "$ADMINU" ] && [ "$CPT" -ge 8 ] && [ "$CPF" = 0 ]; then echo "   PROOF census (CP2): cp.census is in the awam database, CHECK $CPT of $CPT true"; else echo "   PROOF census (CP2): NOT PROVEN (true $CPT, false $CPF): the Customers and Plans card will say Data unavailable until this is fixed"; fi
CP4="$(show admin-desk/sql/checks/CP4-check.sql | env -u PGHOST -u PGPORT -u PGUSER -u PGDATABASE -u PGSERVICE psql "${ADMINU:-postgres://none}" -X -q -At -f - 2>&1)"
CP4T="$(printf '%s\n' "$CP4" | grep -c '|t$')"; CP4F="$(printf '%s\n' "$CP4" | grep -c '|f$')"
if [ -n "$ADMINU" ] && [ "$CP4T" -ge 6 ] && [ "$CP4F" = 0 ]; then echo "   PROOF customers plans (CP4): six packages + No plan yet + per-plan detail are in the awam database, CHECK $CP4T of $CP4T true"; else echo "   PROOF customers plans (CP4): NOT PROVEN (true $CP4T, false $CP4F): the Customers card will say Data unavailable until this is fixed"; fi
CP3="$(show admin-desk/sql/checks/CP3-check.sql | env -u PGHOST -u PGPORT -u PGUSER -u PGDATABASE -u PGSERVICE psql "${ADMINU:-postgres://none}" -X -q -At -f - 2>&1)"
CP3T="$(printf '%s\n' "$CP3" | grep -c '|t$')"; CP3F="$(printf '%s\n' "$CP3" | grep -c '|f$')"
if [ -n "$ADMINU" ] && [ "$CP3T" -ge 9 ] && [ "$CP3F" = 0 ]; then echo "   PROOF deliverability (CP3): cp.deliverability is in the awam database, CHECK $CP3T of $CP3T true"; else echo "   PROOF deliverability (CP3): NOT PROVEN (true $CP3T, false $CP3F): the Deliverability card will say Data unavailable until this is fixed"; fi
