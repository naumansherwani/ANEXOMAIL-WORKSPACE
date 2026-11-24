#!/usr/bin/env bash
# ANEXOMAIL CONTROL PLANE installer CP-INSTALL (D5a-3b, 22 Nov 2026). Called by desk-install.sh as its last step (his rule: ONE install command, nothing typed, no secret printed).
# Own user anexomail-cp, own dir /opt/anexomail-controlplane, own unit, own key, own certificate, own read-only database role cp_lookup (EXECUTE on cp.lookup only). Loopback UDP 4410 (HTTP/3 only).
# Does NOT touch: founder, awam, Caddy, ufw. PORT RED LINE: it reads the live listeners first and refuses (changing nothing) if UDP 4410 is held by anything else.
set -u
REPO="${REPO:-/opt/anexomail-web}"; ROOT=/opt/anexomail-controlplane; SVC=anexomail-controlplane; ETC=/etc/anexomail-controlplane; DESKSVC=anexomail-desk; DESKROOT=/opt/anexomail-desk
LISTEN=127.0.0.1:4410; HOST=controlplane.internal; export CARGO_TARGET_DIR="$ROOT/target"
command -v cargo >/dev/null 2>&1 || export PATH="$HOME/.cargo/bin:$PATH"
for t in cargo psql openssl python3 curl; do command -v $t >/dev/null 2>&1 || { echo "FAIL: $t not found"; exit 2; }; done
git -C "$REPO" fetch -q origin main || { echo "FAIL: fetch"; exit 2; }
show() { git -C "$REPO" show "origin/main:$1"; }
echo "== CP 1/7 port red line (read-only)"
HOLD="$(ss -ulnp 2>/dev/null | awk '$4 ~ /:4410$/')"
OWN="$(systemctl show -p MainPID --value anexomail-controlplane 2>/dev/null)"   # ss shows the process name cut to 15 letters (anexomail-contr), so the owner is proven by the unit's own PID
own_ok(){ [ -n "$OWN" ] && [ "$OWN" != 0 ] && echo "$1" | grep -q "pid=$OWN,"; }
if [ -n "$HOLD" ] && ! own_ok "$HOLD"; then echo "FAIL: UDP 4410 is held by something else, nothing changed:"; echo "$HOLD" | sed 's/^/     /'; exit 2; fi
if [ -n "$HOLD" ]; then echo "   UDP 4410: held by the Control Plane itself (rerun)"; else echo "   UDP 4410: free"; fi
[ -r /etc/anexomail/sync.env ] || { echo "FAIL: /etc/anexomail/sync.env not readable"; exit 2; }
ADMIN="$( . /etc/anexomail/sync.env 2>/dev/null; printf %s "${WORKING_URL:-}" )"; [ -n "$ADMIN" ] || { echo "FAIL: no WORKING_URL in sync.env"; exit 2; }
psqla() { env -u PGHOST -u PGPORT -u PGUSER -u PGDATABASE -u PGSERVICE psql "$ADMIN" -X -q -At -v ON_ERROR_STOP=1 "$@"; }
echo "== CP 2/7 source (control-plane/ from origin/main) + build"
mkdir -p "$ROOT/src/src" "$ROOT/src/contract"; show control-plane/Cargo.toml >"$ROOT/src/Cargo.toml"; show control-plane/Cargo.lock >"$ROOT/src/Cargo.lock" 2>/dev/null
rm -f "$ROOT"/src/src/*.rs "$ROOT"/src/contract/*.json
for f in $(git -C "$REPO" ls-tree --name-only origin/main control-plane/src/ | grep '\.rs$'); do show "$f" >"$ROOT/src/src/$(basename "$f")"; done
for f in $(git -C "$REPO" ls-tree --name-only origin/main control-plane/contract/ | grep '\.json$'); do show "$f" >"$ROOT/src/contract/$(basename "$f")"; done
echo "   rust files: $(ls "$ROOT"/src/src/*.rs | wc -l)"
NEW="$ROOT/target/release/anexomail-controlplane"; rm -f "$NEW"; (cd "$ROOT/src" && nice cargo build --release >"$ROOT/build.log" 2>&1)
if [ ! -x "$NEW" ]; then echo "FAIL: build (nothing installed)"; grep -E "^error" -A6 "$ROOT/build.log" | head -20; exit 3; fi
echo "== CP 3/7 database: AD21.sql + CHECK + read-only login cp_lookup"
S="$(mktemp)"; show admin-desk/sql/AD21.sql >"$S"; psqla -f "$S" 2>&1 | tail -3; [ "${PIPESTATUS[0]}" = 0 ] || { echo "FAIL: AD21.sql (a table it reads is missing?)"; rm -f "$S"; exit 4; }
show admin-desk/sql/checks/AD21-check.sql >"$S"; CH="$(psqla -f "$S" 2>&1)"; rm -f "$S"; echo "$CH" | sed 's/^/   /'
echo "$CH" | grep -q '|f$' && { echo "FAIL: AD21 CHECK has a false row"; exit 4; }; echo "$CH" | grep -qi error && { echo "FAIL: AD21 CHECK error"; exit 4; }
echo "== CP 3b/7 database: AD22.sql (census for Customers and Plans) + selftest + CHECK"
S="$(mktemp)"; show admin-desk/sql/AD22.sql >"$S"; C2="$(psqla -f "$S" 2>&1 | tail -4)"; C2R=$?; rm -f "$S"; echo "$C2" | sed 's/^/   /'
S="$(mktemp)"; show admin-desk/sql/checks/AD22-check.sql >"$S"; CH2="$(psqla -f "$S" 2>&1)"; rm -f "$S"; echo "$CH2" | sed 's/^/   /'
if echo "$CH2" | grep -q '|f$' || echo "$CH2" | grep -qi error || echo "$C2" | grep -qi "error"; then echo "WARN: AD22 did not install cleanly: the Customers and Plans card will say Data unavailable (fail-closed) until it is fixed; the rest of the install continues"; else echo "OK: AD22 census installed and CHECKed"; fi
echo "== CP 3c/7 database: AD23.sql (deliverability for the Deliverability card) + selftest + CHECK"
S="$(mktemp)"; show admin-desk/sql/AD23.sql >"$S"; C3="$(psqla -f "$S" 2>&1 | tail -4)"; rm -f "$S"; echo "$C3" | sed 's/^/   /'
S="$(mktemp)"; show admin-desk/sql/checks/AD23-check.sql >"$S"; CH3="$(psqla -f "$S" 2>&1)"; rm -f "$S"; echo "$CH3" | sed 's/^/   /'
if echo "$CH3" | grep -q '|f$' || echo "$CH3" | grep -qi error || echo "$C3" | grep -qi "error"; then echo "WARN: AD23 did not install cleanly: the Deliverability card will say Data unavailable (fail-closed) until it is fixed; the rest of the install continues"; else echo "OK: AD23 deliverability installed and CHECKed"; fi
echo "== CP 3d/7 database: AD24.sql (six packages, No plan yet, plan detail for the Customers card) + selftest + CHECK"
S="$(mktemp)"; show admin-desk/sql/AD24.sql >"$S"; C4="$(psqla -f "$S" 2>&1 | tail -4)"; rm -f "$S"; echo "$C4" | sed 's/^/   /'
S="$(mktemp)"; show admin-desk/sql/checks/AD24-check.sql >"$S"; CH4="$(psqla -f "$S" 2>&1)"; rm -f "$S"; echo "$CH4" | sed 's/^/   /'
if echo "$CH4" | grep -q '|f$' || echo "$CH4" | grep -qi error || echo "$C4" | grep -qi "error"; then echo "WARN: AD24 did not install cleanly: the Customers card will say Data unavailable (fail-closed) until it is fixed; the rest of the install continues"; else echo "OK: AD24 customers census installed and CHECKed"; fi
echo "== CP 3e/7 database: AD25.sql (B13 Z4a: customer consent inbox + hash-chained ledger, the Control Plane can push/cancel/poll but never decide) + selftest + CHECK"
S="$(mktemp)"; show admin-desk/sql/AD25.sql >"$S"; C5="$(psqla -f "$S" 2>&1 | tail -4)"; rm -f "$S"; echo "$C5" | sed 's/^/   /'
S="$(mktemp)"; show admin-desk/sql/checks/AD25-check.sql >"$S"; CH5="$(psqla -f "$S" 2>&1)"; rm -f "$S"; echo "$CH5" | sed 's/^/   /'
if echo "$CH5" | grep -q '|f$' || echo "$CH5" | grep -qi error || echo "$C5" | grep -qi "error"; then echo "WARN: AD25 did not install cleanly: customer consent stays closed (requests cannot be approved) until it is fixed; the rest of the install continues"; else echo "OK: AD25 consent inbox installed and CHECKed"; fi
echo "== CP 3f/7 database: AD26.sql (B13 T1: tenant registry check + versioned domain ownership + first history fill) + selftest + CHECK"
S="$(mktemp)"; show admin-desk/sql/AD26.sql >"$S"; C6="$(psqla -f "$S" 2>&1 | tail -4)"; rm -f "$S"; echo "$C6" | sed 's/^/   /'
S="$(mktemp)"; show admin-desk/sql/checks/AD26-check.sql >"$S"; CH6="$(psqla -f "$S" 2>&1)"; rm -f "$S"; echo "$CH6" | sed 's/^/   /'
if echo "$CH6" | grep -q '|f$' || echo "$CH6" | grep -qi error || echo "$C6" | grep -qi "error"; then echo "WARN: AD26 did not install cleanly: tenant binding stays closed (no consent request can be bound to a tenant) until it is fixed; the rest of the install continues"; else echo "OK: AD26 tenant registry + domain ownership installed and CHECKed"; fi
PW="$(openssl rand -hex 24)"
URL="$(ADMIN_URL="$ADMIN" CPW="$PW" python3 - <<'P'
import os,urllib.parse as u
a=u.urlsplit(os.environ["ADMIN_URL"]); user=u.unquote(a.username or "postgres")
nu="cp_lookup"+("."+user.split(".",1)[1] if "." in user else "")
host=a.hostname+(":"+str(a.port) if a.port else ""); q=dict(u.parse_qsl(a.query)); q.setdefault("sslmode","require")
print(u.urlunsplit((a.scheme,nu+":"+os.environ["CPW"]+"@"+host,a.path,u.urlencode(q),"")))
P
)" || { echo "FAIL: cp_lookup url"; exit 4; }
printf "alter role cp_lookup login password :'pw';\n" | psqla -v pw="$PW" 2>&1 | tail -2; [ "${PIPESTATUS[1]}" = 0 ] || { echo "FAIL: ALTER ROLE cp_lookup"; exit 4; }; unset PW
echo "== CP 4/7 user, key, certificate"
id anexomail-cp >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin anexomail-cp
mkdir -p -m 700 "$ETC"; chown root:root "$ETC"
[ -s "$ETC/seed" ] && echo "   own signing key: kept" || { ( umask 077; head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n' >"$ETC/seed" ); echo "   own signing key: created (root-only, never printed)"; }
if [ -s "$ETC/cert.pem" ] && [ -s "$ETC/key.pem" ] && openssl x509 -in "$ETC/cert.pem" -noout -checkend 2592000 >/dev/null 2>&1; then echo "   certificate: kept (more than 30 days left)"
else ( umask 077; openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -days 825 -subj "/CN=$HOST" -addext "subjectAltName=DNS:$HOST,IP:127.0.0.1" -addext "basicConstraints=critical,CA:FALSE" -keyout "$ETC/key.pem" -out "$ETC/cert.pem" 2>/dev/null ) && echo "   certificate: created (ECDSA P-256, 825 days, name $HOST, loopback only)" || { echo "FAIL: certificate"; exit 5; }; fi
chmod 600 "$ETC"/seed "$ETC"/key.pem "$ETC"/cert.pem
DESKPUB="$(curl -s -H 'Host: admindesk.anexomail.com' http://127.0.0.1:4400/desk/v1/key | python3 -c 'import sys,json;print(json.load(sys.stdin)["pub"])' 2>/dev/null)"
case "$DESKPUB" in [0-9a-f][0-9a-f]*) [ ${#DESKPUB} = 64 ] || DESKPUB="";; *) DESKPUB="";; esac
[ -n "$DESKPUB" ] || { echo "FAIL: could not read the Desk public key from 127.0.0.1:4400 (is the Desk up?)"; exit 5; }
( umask 077; printf 'CP_DB_URL=%s\nCP_DESK_PUBKEY=%s\nCP_LISTEN=%s\n' "$URL" "$DESKPUB" "$LISTEN" >"$ETC/cp.env" ); unset URL; chmod 600 "$ETC/cp.env"
CA=""; [ -s /etc/anexomail-desk/db-ca.pem ] && CA="LoadCredential=db-ca.pem:/etc/anexomail-desk/db-ca.pem
Environment=CP_DB_CA=%d/db-ca.pem"
echo "== CP 5/7 binary + unit"
[ -f "$ROOT/anexomail-controlplane" ] && cp "$ROOT/anexomail-controlplane" "$ROOT/anexomail-controlplane.bak.$(date +%s)"
install -m 755 "$NEW" "$ROOT/anexomail-controlplane.new" && mv -f "$ROOT/anexomail-controlplane.new" "$ROOT/anexomail-controlplane"
cat >/etc/systemd/system/$SVC.service <<U
[Unit]
Description=Anexomail Control Plane (own process, loopback UDP 4410, HTTP/3 only)
After=network.target
[Service]
User=anexomail-cp
ExecStart=$ROOT/anexomail-controlplane
EnvironmentFile=$ETC/cp.env
LoadCredential=seed:$ETC/seed
LoadCredential=cert.pem:$ETC/cert.pem
LoadCredential=key.pem:$ETC/key.pem
Environment=CP_SEED_FILE=%d/seed
Environment=CP_CERT=%d/cert.pem
Environment=CP_KEY=%d/key.pem
$CA
Restart=on-failure
RestartSec=2
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
PrivateDevices=true
RestrictAddressFamilies=AF_INET AF_INET6
MemoryDenyWriteExecute=true
[Install]
WantedBy=multi-user.target
U
CPPUB="$(CP_SEED_FILE=$ETC/seed "$ROOT/anexomail-controlplane" --print-pubkey)"; [ ${#CPPUB} = 64 ] || { echo "FAIL: public key"; exit 5; }
echo "== CP 6/7 start + wire the Desk to it"
systemctl daemon-reload && systemctl enable $SVC >/dev/null 2>&1; systemctl restart $SVC; sleep 2
if ! systemctl is-active --quiet $SVC; then echo "FAIL: the Control Plane did not start; the Desk stays fail-closed (Data unavailable). Journal:"; journalctl -u $SVC --since '-30s' --no-pager | tail -6 | sed 's/^/     /'; exit 6; fi
echo "   $(journalctl -u $SVC --since '-20s' --no-pager | grep 'control plane ready' | tail -1 | sed 's/.*control plane ready/control plane ready/')"
echo "   listener:"; ss -ulnp | grep ':4410' | sed 's/^/     /'
mkdir -p /etc/systemd/system/$DESKSVC.service.d
printf '[Service]\nLoadCredential=cp-ca.pem:%s/cert.pem\nEnvironment=DESK_CONTROL_PLANE_ADDR=%s\nEnvironment=DESK_CONTROL_PLANE_HOST=%s\nEnvironment=DESK_CONTROL_PLANE_CA=%%d/cp-ca.pem\nEnvironment=DESK_CONTROL_PLANE_PUBKEY=%s\n' "$ETC" "$LISTEN" "$HOST" "$CPPUB" >/etc/systemd/system/$DESKSVC.service.d/cp.conf
systemctl daemon-reload; systemctl restart $DESKSVC; sleep 3
echo "== CP 7/7 end-to-end proof (Desk -> HTTP/3 -> Control Plane -> read-only database -> signed answer -> Desk verifies)"
ORG="$(psqla -c "select id from public.orgs order by created_at limit 1" 2>/dev/null)"
if [ -z "$ORG" ]; then echo "   note: no company row to look up; end-to-end proof skipped (the Control Plane is up)"; exit 0; fi
R="$(env DESK_SIGN_SEED_FILE=/etc/anexomail-desk/sign.seed DESK_CONTROL_PLANE_ADDR=$LISTEN DESK_CONTROL_PLANE_HOST=$HOST DESK_CONTROL_PLANE_CA=$ETC/cert.pem DESK_CONTROL_PLANE_PUBKEY=$CPPUB "$DESKROOT/anexomail-desk" lookup-selftest "$ORG" 2>&1 | tail -1)"
echo "   $R"
case "$R" in "LOOKUP SELFTEST OK"*) echo "OK: Control Plane live on UDP 4410; the Desk can now ask it (D5a-3b)";; *) echo "FAIL: end-to-end proof did not pass (paste these lines); the Desk stays fail-closed"; exit 7;; esac
