#!/usr/bin/env bash
# Founder Polar READ-ONLY token — chat mein token KABHI paste nahi karna. Yeh script server par chhupa kar poochti hai, env file mein 0600 rakhti hai,
# service restart karti hai aur 'polar reader ON' ka saboot dikhati hai.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-polar.sh)
# Pehle Polar dashboard > Settings > Developers > New Organization Access Token: SIRF scope `metrics:read` (aur kuch nahi). Yeh payment/webhook token NAHI.
# Naya token nahi banana? Engine ka maujooda secret reuse:  ...founder-polar.sh) engine   (/opt/polar-rust-payment/.env se POLAR_ACCESS_TOKEN seedha founder.env mein; screen par kabhi nahi).
#   Dhyan: woh payment-engine ka token hai (zyada ikhtiyar); founder code sirf GET karta hai. Scope metrics:read na ho to card wajah likhega — tab chhota naya token lena behtar.
# Hatane ke liye:  bash <(...founder-polar.sh) off
set -euo pipefail
ENVF="${FOUNDER_ENV:-/etc/anexomail/founder.env}"; SVC=anexomail-founder
[ "$(id -u)" -eq 0 ] || { echo "FAIL: root chahiye"; exit 2; }
[ -f "$ENVF" ] || { echo "FAIL: $ENVF nahi — pehle founder-install.sh"; exit 2; }
sedi() { sed -i "$@" "$ENVF"; }
if [ "${1:-}" = "off" ]; then sedi '/^FOUNDER_POLAR_READ_TOKEN=/d'; systemctl restart $SVC; sleep 2; journalctl -u $SVC -n 20 --no-pager | grep -E "polar reader" | tail -1; exit 0; fi
if [ "${1:-}" = "engine" ]; then
  EE="${POLAR_ENGINE_ENV:-/opt/polar-rust-payment/.env}"; [ -r "$EE" ] || { echo "FAIL: $EE nahi padh sakta"; exit 2; }
  TOK="$(grep -E '^POLAR_ACCESS_TOKEN=' "$EE" | tail -1 | cut -d= -f2- | tr -d '"'"'"' \r')"
  [ -n "$TOK" ] || { echo "FAIL: $EE mein POLAR_ACCESS_TOKEN khali/nahi"; exit 2; }
  echo "engine ka maujooda POLAR_ACCESS_TOKEN use ho raha hai (screen par nahi dikhaya)"
else
  printf 'Polar read-only token (scope metrics:read) — typing hidden: '; read -rs TOK; echo
fi
[ "${#TOK}" -ge 20 ] && [[ "$TOK" =~ ^[A-Za-z0-9_.-]+$ ]] || { echo "FAIL: token ghalat lagta hai (20+ akshar, sirf A-Za-z0-9_.-)"; exit 2; }
sedi '/^FOUNDER_POLAR_READ_TOKEN=/d'; printf 'FOUNDER_POLAR_READ_TOKEN=%s\n' "$TOK" >>"$ENVF"; chmod 600 "$ENVF"; unset TOK
systemctl restart $SVC; sleep 3
journalctl -u $SVC -n 30 --no-pager | grep -E "polar reader" | tail -1
echo "Ab Chrome mein Bridge kholein: 'BILLING · POLAR' card asli reading dikhaye ga (60 second tak lag sakte hain). Token reject ho to card wajah likhta hai."
