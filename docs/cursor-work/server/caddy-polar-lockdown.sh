#!/usr/bin/env bash
# ============================================================================
# caddy-polar-lockdown.sh — Caddy ke 2 bekaar public darwaaze band (Caddy KHUD rehta hai).
#   plan  (default): sirf dikhata hai, kuch nahi badalta
#   apply          : backup -> badlav -> caddy validate -> reload -> test -> koi test fail to rollback
#
#   bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/caddy-polar-lockdown.sh)          # plan
#   MODE=apply bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/caddy-polar-lockdown.sh)
#
# Badlav (sirf yeh):
#   /etc/caddy/Caddyfile            anexomail.com: 'handle /api/v1/checkout*' aur 'handle /api/v1/billing/*' hata
#   /etc/caddy/sites/polarpayments.caddy   'handle /api/v1/*' -> 'handle /api/v1/polar-webhook*'
# Webhook ke dono raaste (polarpayments + anexomail.com) bilkul NAHI chhede jaate.
# Saboot ke Caddy logs: billing 1 hit (founder ka apna curl), checkout 0, webhook 264.
# ============================================================================
set -uo pipefail
MODE="${MODE:-plan}"
MAIN=/etc/caddy/Caddyfile
SITE=/etc/caddy/sites/polarpayments.caddy
STAMP="$(date +%Y%m%d-%H%M%S)"
BK="/root/anexomail-backups/caddy-lockdown-$STAMP"
WORK="$(mktemp -d)"

say() { printf '\n==> %s\n' "$*"; }
[ -f "$MAIN" ] || { echo "!!! $MAIN nahi mila"; exit 1; }

# --- badlav python se (exact match; na mile to kuch nahi badalta) ---
python3 - "$MAIN" "$SITE" "$WORK" <<'PY'
import re, sys, pathlib
main, site, work = sys.argv[1:4]
t = open(main).read()
pat = re.compile(r'[ \t]*handle\s+/api/v1/(?:checkout\*|billing/\*)\s*\{\s*reverse_proxy\s+127\.0\.0\.1:3400\s*\}[ \t]*\n', re.M)
hits = pat.findall(t)
new = pat.sub('', t)
open(f'{work}/Caddyfile.new', 'w').write(new)
print(f'MAIN: {len(hits)} darwaaze milay (2 chahiye ya 0 agar pehle hi band)')
s = pathlib.Path(site)
if s.exists():
    st = s.read_text()
    n = st.count('handle /api/v1/* {')
    open(f'{work}/site.new', 'w').write(st.replace('handle /api/v1/* {', 'handle /api/v1/polar-webhook* {'))
    print(f'SITE: {n} jagah "handle /api/v1/*" mili (1 chahiye ya 0 agar pehle hi band)')
else:
    open(f'{work}/site.new', 'w').write('')
    print('SITE: file nahi mili')
PY

say "PLAN — Caddyfile ka farq"
diff -u "$MAIN" "$WORK/Caddyfile.new" | sed 's/^/   /' || true
if [ -f "$SITE" ]; then say "PLAN — polarpayments.caddy ka farq"; diff -u "$SITE" "$WORK/site.new" | sed 's/^/   /' || true; fi

if [ "$MODE" != "apply" ]; then
  echo; echo "Yeh sirf PLAN tha. Kuch nahi badla. Chalane ke liye: MODE=apply ..."; exit 0
fi

say "APPLY — backup $BK"
mkdir -p "$BK"; cp -a "$MAIN" "$BK/Caddyfile"; [ -f "$SITE" ] && cp -a "$SITE" "$BK/polarpayments.caddy"

rollback() {
  echo "!!! ROLLBACK: $1"
  cp -a "$BK/Caddyfile" "$MAIN"; [ -f "$BK/polarpayments.caddy" ] && cp -a "$BK/polarpayments.caddy" "$SITE"
  caddy validate --config "$MAIN" >/dev/null 2>&1 && systemctl reload caddy
  echo "    purani Caddy config wapas. Backup: $BK"; exit 1
}

cp "$WORK/Caddyfile.new" "$MAIN"
[ -s "$WORK/site.new" ] && cp "$WORK/site.new" "$SITE"
caddy validate --config "$MAIN" 2>&1 | tail -3 || true
caddy validate --config "$MAIN" >/dev/null 2>&1 || rollback "caddy validate fail"
systemctl reload caddy || rollback "caddy reload fail"
sleep 2

FAIL=0
code() { curl -s -m 10 -o /dev/null -w '%{http_code}' "$@"; }
UID0=00000000-0000-4000-8000-000000000000
for h in anexomail.com polarpayments.anexomail.com; do
  W="$(code -X POST -H 'content-type: application/json' -d '{}' "https://$h/api/v1/polar-webhook")"
  [ "$W" = "401" ] && echo "    OK   $h webhook khula (401 = engine tak pahuncha, bina signature rad)" || { echo "    FAIL $h webhook => $W (401 chahiye)"; FAIL=1; }
  B="$(code "https://$h/api/v1/billing/$UID0")"
  case "$B" in 200|500|502|503) echo "    FAIL $h billing/ abhi bhi engine tak => $B"; FAIL=1;; *) echo "    OK   $h billing/ band ($B)";; esac
  C="$(code -X POST -H 'content-type: application/json' -d '{"product_key":"X"}' "https://$h/api/v1/checkout")"
  case "$C" in 400|502|503) echo "    FAIL $h checkout abhi bhi engine tak => $C"; FAIL=1;; *) echo "    OK   $h checkout band ($C)";; esac
done
HC="$(code https://polarpayments.anexomail.com/health)"; [ "$HC" = "200" ] && echo "    OK   polarpayments /health 200" || { echo "    FAIL /health => $HC"; FAIL=1; }
SITEUP="$(code https://anexomail.com/)"; [ "$SITEUP" = "200" ] && echo "    OK   anexomail.com 200" || { echo "    FAIL anexomail.com => $SITEUP"; FAIL=1; }

[ "$FAIL" = "0" ] || rollback "post-check fail"
echo; echo "==> CADDY LOCKDOWN HO GAYA. Backup: $BK"
echo "    Rollback haath se: cp $BK/Caddyfile $MAIN; cp $BK/polarpayments.caddy $SITE; systemctl reload caddy"
