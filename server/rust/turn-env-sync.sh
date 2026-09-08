#!/usr/bin/env bash
# ============================================================================
# ANEXOVideoCall — TURN SECRET SYNC (coturn  <->  Rust engine)
#
#   cd /opt/anexomail-web && bash server/rust/turn-env-sync.sh
#
# Kaam:
#   1. coturn conf mein `use-auth-secret` + `static-auth-secret` hona yaqeeni
#      (na ho to naya secret khud banata hai — kabhi print nahi karta)
#   2. wahi secret /opt/anexomail-rust/.env mein TURN_HOST/TURN_SECRET/
#      TURN_TTL_SECONDS ke tor par likhta hai (.env ka backup pehle)
#   3. coturn restart + pm2 restart anexomail-rust --update-env
#   4. readiness verify: /rpc/chat.turn.health -> "credential_ready":true
#
# Koi external API nahi — relay apna coturn, HMAC sirf server par.
# ============================================================================
set -uo pipefail

TURN_HOST_NAME="anexovideocall.anexomail.com"
RUST_ENV="/opt/anexomail-rust/.env"
TTL=3600
STAMP="$(date +%s)"

CONF=""
for c in /etc/turnserver.conf /etc/coturn/turnserver.conf; do
  [ -f "$c" ] && CONF="$c" && break
done
if [ -z "$CONF" ]; then
  echo "!! coturn conf nahi mili (/etc/turnserver.conf) — coturn install nahi hai."
  exit 1
fi
[ -f "$RUST_ENV" ] || { echo "!! $RUST_ENV nahi mila — Rust engine install nahi hai."; exit 1; }

cp "$CONF" "$CONF.bak.$STAMP"
cp "$RUST_ENV" "$RUST_ENV.bak.$STAMP"

SECRET="$(grep -E '^[[:space:]]*static-auth-secret[[:space:]]*=' "$CONF" | tail -1 | cut -d= -f2- | tr -d '[:space:]')"
if [ -z "$SECRET" ]; then
  SECRET="$(openssl rand -hex 32)"
  printf '\n# ANEXOVideoCall — REST auth (secret sirf server par)\nstatic-auth-secret=%s\n' "$SECRET" >> "$CONF"
  echo ">>> coturn: naya static-auth-secret likha (value print nahi hoti)"
else
  echo ">>> coturn: mojooda static-auth-secret use ho raha hai"
fi

grep -qE '^[[:space:]]*use-auth-secret' "$CONF" || {
  printf 'use-auth-secret\n' >> "$CONF"; echo ">>> coturn: use-auth-secret on"; }
grep -qE '^[[:space:]]*realm[[:space:]]*=' "$CONF" || {
  printf 'realm=%s\n' "$TURN_HOST_NAME" >> "$CONF"; echo ">>> coturn: realm=$TURN_HOST_NAME"; }

set_env() {
  local key="$1" val="$2"
  if grep -qE "^${key}=" "$RUST_ENV"; then
    python3 - "$RUST_ENV" "$key" "$val" <<'PY'
import sys
path, key, val = sys.argv[1], sys.argv[2], sys.argv[3]
lines = open(path).read().splitlines()
out = [f"{key}={val}" if l.startswith(key + "=") else l for l in lines]
open(path, "w").write("\n".join(out) + "\n")
PY
  else
    printf '%s=%s\n' "$key" "$val" >> "$RUST_ENV"
  fi
  echo ">>> .env $key set"
}
set_env TURN_HOST "$TURN_HOST_NAME"
set_env TURN_SECRET "$SECRET"
set_env TURN_TTL_SECONDS "$TTL"
chmod 600 "$RUST_ENV"

systemctl restart coturn >/dev/null 2>&1 && echo ">>> coturn restarted" || echo "!! coturn restart fail"
pm2 restart anexomail-rust --update-env >/dev/null 2>&1 && echo ">>> anexomail-rust restarted"
pm2 save >/dev/null 2>&1

sleep 2
echo "--- readiness (secret-free) ---"
curl -s -X POST -H 'content-type: application/json' --data '{}' \
  http://127.0.0.1:3200/rpc/chat.turn.health; echo
printf 'chat.turn.credentials bina token (401 expected): '
curl -s -o /dev/null -w '%{http_code}\n' -X POST -H 'content-type: application/json' \
  --data '{}' http://127.0.0.1:3200/rpc/chat.turn.credentials
