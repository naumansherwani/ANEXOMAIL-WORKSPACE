#!/usr/bin/env bash
# ANEXOMAIL — 2 chhote server kaam EK command mein (founder 21 Oct 07:04 "abhi ke abhi"):
#   (1) ufw: 3443/udp (QUIC/WebTransport) allow — agar ufw active hai aur rule nahi to lagata hai; active nahi to kuch NAHI chhedta (batata hai).
#   (2) passkey: test accounts exempt — live Brain auth-passkey.ts mein marker dekhta hai; na ho to brain-passkey-exempt.sh (backup + build + health + restore) chalata hai.
# Dono idempotent: dobara chalane par kuch nahi badalta. Koi secret print nahi.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/ops-ufw-passkey.sh)
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"; F="${BRAIN_SRC:-/opt/anexomail/src}/routes/auth-passkey.ts"
echo "== 1) ufw 3443/udp"
if ! command -v ufw >/dev/null 2>&1; then echo "   ufw install nahi — firewall koi aur (iptables/Hetzner panel?). UDP 3443 listening: $(awk 'NR>1 && toupper($2) ~ /:0D73$/ {f=1} END{print f?"haan":"nahi"}' /proc/net/udp /proc/net/udp6 2>/dev/null)"
else
  ST="$(ufw status 2>/dev/null | head -1)"; echo "   $ST"
  if echo "$ST" | grep -qi inactive; then echo "   ufw band (inactive) — kuch nahi chheda (port ufw se nahi rukta). Hetzner Cloud Firewall panel mein 3443/udp dekhna ho to wahan."
  elif ufw status | grep -qE '(^|[[:space:]])3443/udp'; then echo "   rule pehle se hai."
  else ufw allow 3443/udp >/dev/null 2>&1; ufw status | grep -E '3443/udp' | head -2 | sed 's/^/   /'; ufw status | grep -qE '3443/udp' && echo "   rule laga di." || echo "   !! rule nahi lagi — haath se: ufw allow 3443/udp"; fi
fi
echo "== 2) passkey test-account exempt"
if [ ! -f "$F" ]; then echo "   FAIL: $F nahi mila"; exit 2; fi
if grep -q "exempt: true" "$F"; then echo "   pehle se lagi hai (marker mila)."
else
  echo "   marker nahi — brain-passkey-exempt.sh chala raha hoon (backup + build + health + restore)"
  bash <(git -C "$REPO" show origin/main:docs/cursor-work/server/brain-passkey-exempt.sh) || { echo "   !! exempt install FAIL (upar dekhein)"; exit 1; }
fi
echo "   grep: $(grep -c 'exempt: true' "$F") jagah marker"
echo "DONE"
