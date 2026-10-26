#!/usr/bin/env bash
# polar-product-ids-update.sh — Polar product ID(s) payment engine ki .env mein badalna (26 Oct 2026).
# Usage:  bash polar-product-ids-update.sh POLAR_PRODUCT_PLAN_BASIC_MONTHLY=<uuid> POLAR_PRODUCT_PLAN_BASIC_YEARLY=<uuid> ...
# Sirf diye gaye KEY=UUID badalte hain (baqi .env ko haath nahi lagta). Backup + health check + auto-rollback.
# Test hook: ENVF=/tmp/x.env SKIP_PM2=1 (live service ko chhue baghair logic test).
set -u
ENVF="${ENVF:-/opt/polar-rust-payment/.env}"
[ "$#" -ge 1 ] || { echo "FAIL: kam az kam ek KEY=UUID do (misaal: POLAR_PRODUCT_PLAN_BASIC_MONTHLY=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)"; exit 2; }
[ -f "$ENVF" ] || { echo "FAIL: $ENVF nahi mili"; exit 2; }
for kv in "$@"; do
  k="${kv%%=*}"; v="${kv#*=}"
  [[ "$k" =~ ^POLAR_PRODUCT_[A-Z0-9_]+$ ]] || { echo "FAIL: key ghalat: $k"; exit 2; }
  [[ "$v" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]] || { echo "FAIL: $k ki value UUID nahi lagti: $v"; exit 2; }
done
BK="$(dirname "$ENVF")/.env.bak.$(date +%s)"
cp -a "$ENVF" "$BK" && chmod 600 "$BK"
restore(){ echo "!!! ROLLBACK: $1"; cp -a "$BK" "$ENVF"; chmod 600 "$ENVF"; [ "${SKIP_PM2:-0}" = 1 ] || pm2 restart polar-rust-payment --update-env >/dev/null 2>&1; echo "    .env wapas ($BK)"; exit 1; }
for kv in "$@"; do
  k="${kv%%=*}"; v="${kv#*=}"
  if grep -q "^${k}=" "$ENVF"; then
    old="$(grep -m1 "^${k}=" "$ENVF" | cut -d= -f2-)"
    sed -i "s|^${k}=.*|${k}=${v}|" "$ENVF" || restore "sed fail $k"
    echo "    UPDATED $k  (purani: ${old:0:8}…  nayi: ${v:0:8}…)"
  else
    printf '%s=%s\n' "$k" "$v" >> "$ENVF" || restore "append fail $k"
    echo "    ADDED   $k  (nayi: ${v:0:8}…)"
  fi
done
chmod 600 "$ENVF"
if [ "${SKIP_PM2:-0}" = 1 ]; then echo "==> SKIP_PM2: restart/health chhoda (test mode)"; exit 0; fi
pm2 restart polar-rust-payment --update-env >/dev/null 2>&1 || restore "pm2 restart fail"
sleep 3
H="$(curl -fsS -m 10 http://127.0.0.1:3400/health 2>/dev/null || true)"
[ -n "$H" ] || restore "3400/health jawab nahi de raha"
echo "==> OK  health: $H"
echo "    Backup: $BK   (rollback: cp $BK $ENVF && pm2 restart polar-rust-payment --update-env)"
