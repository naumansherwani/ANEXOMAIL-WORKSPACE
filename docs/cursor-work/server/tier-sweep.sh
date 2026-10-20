#!/usr/bin/env bash
# ANEXOMAIL — TIER SWEEP: ek hi command, CHAARON package ke test accounts par wohi calls; farq sirf gate ka hona chahiye, UI/server ka nahi.
#   bash <(git -C /opt/anexomail-web fetch -q origin main; git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/tier-sweep.sh)
# Accounts badalne ho: EMAILS="a@x b@y" bash <(...). Har account ke liye login-probe.sh chalta hai (koi typing/password nahi, sirf GET).
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"
EMAILS="${EMAILS:-basic.test@anexomail.com pro.buyer@anexomail.com business.buyer@anexomail.com bpro.buyer@anexomail.com}"
git -C "$REPO" fetch -q origin main 2>/dev/null
P="$(mktemp)"; trap 'rm -f "$P"' EXIT
git -C "$REPO" show origin/main:docs/cursor-work/server/login-probe.sh > "$P" || { echo "FAIL: login-probe.sh nahi mila"; exit 2; }
for e in $EMAILS; do
  echo "=================== $e"
  EMAIL="$e" bash "$P" 2>&1 | grep -E "FAIL|round 3|BRAIN|RUST" | tail -8
done
echo "DONE. Chaaron mein BRAIN 200 aur RUST 200/403 ek jaise hon. Koi 5xx ya sirf ek package par anokha 401 => us package ka gate/data masla — output Claude ko bhejein."
