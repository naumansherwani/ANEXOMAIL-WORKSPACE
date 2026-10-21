#!/usr/bin/env bash
# ANEXOMAIL — Brain: founder revenue board PRICE FIX (stale 20/40/85/700/500/40 -> locked 23/46/97/790). 21 Oct 2026.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/brain-pricefix-install.sh)
# Kya: routes/revenue.ts + routes/release.ts mein sirf 4 chhoti jagah (surgical, idempotent). Baaki live file ko haath nahi.
# Anchor na mile to STOP (kuch nahi badalta). Backup + bun build pre-flight + health + restore-on-fail. Rust/web/polar no touch.
set -uo pipefail
SRC="${BRAIN_SRC:-/opt/anexomail/src}"; BUN="$(command -v bun || echo /root/.bun/bin/bun)"
B="/root/anexomail-backups/brain-pricefix-$(date +%Y%m%d-%H%M%S)"
[ -f "$SRC/routes/revenue.ts" ] && [ -f "$SRC/routes/release.ts" ] || { echo "FAIL: live revenue.ts/release.ts nahi: $SRC/routes"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
python3 - "$SRC/routes" "$T" <<'PY'
import sys,os
src,out=sys.argv[1:3]
E=[("revenue.ts","const PLAN_PRICE: Record<string, number> = { basic: 20, pro: 40, business: 85 };",
    "const PLAN_PRICE: Record<string, number> = { basic: 23, pro: 46, business: 97 }; // locked list prices"),
   ("revenue.ts","const SLA_PRICE = 700;","const SLA_PRICE = 790; // Priority Support GBP 790/mo (locked)"),
   ("release.ts",".filter((a) => a.sla_addon).length * 500;",".filter((a) => a.sla_addon).length * 790; // Priority Support GBP 790/mo (locked)"),
   ("release.ts",": seats * 40;",": seats * 46; // Pro list price per seat (locked)")]
news={}; bad=0; state=[]
for f,old,new in E:
    s=news.get(f) or open(os.path.join(src,f)).read()
    if new in s: state.append((f,'same')); news[f]=s; continue
    if s.count(old)!=1: print('STOP: %s anchor nahi mila/ek se zyada (%d): %s'%(f,s.count(old),old)); bad=1; continue
    news[f]=s.replace(old,new); state.append((f,'update'))
if bad: sys.exit(3)
for f,s in news.items(): open(os.path.join(out,f),'w').write(s)
print('status:',', '.join('%s=%s'%x for x in state))
sys.exit(0 if any(v=='update' for _,v in state) else 4)
PY
RC=$?; [ "$RC" = 4 ] && { echo "Sab pehle se lagi hain."; exit 0; }; [ "$RC" = 0 ] || { echo "(kuch nahi badla)"; exit 3; }
NM=""; d="$SRC"; for _ in 1 2 3; do [ -d "$d/node_modules" ] && { NM="$d/node_modules"; break; }; d="$(dirname "$d")"; done
[ -n "$NM" ] || { echo "FAIL: Brain ka node_modules nahi mila"; exit 2; }
mkdir -p "$T/pf/app/src"; (cd "$SRC" && tar cf - --exclude=node_modules .) | (cd "$T/pf/app/src" && tar xf -); ln -s "$NM" "$T/pf/app/node_modules"
cp "$T/revenue.ts" "$T/pf/app/src/routes/revenue.ts"; cp "$T/release.ts" "$T/pf/app/src/routes/release.ts"
"$BUN" build "$T/pf/app/src/index.ts" --target=bun --outfile "$T/pf/out.js" >"$T/b.log" 2>&1 || { tail -20 "$T/b.log"; echo "!! build FAIL — kuch install nahi hua."; exit 1; }
mkdir -p "$B"; cp -p "$SRC/routes/revenue.ts" "$SRC/routes/release.ts" "$B/"
cp "$T/revenue.ts" "$SRC/routes/revenue.ts"; cp "$T/release.ts" "$SRC/routes/release.ts"; echo "lagaya. backup: $B"
restore(){ cp -p "$B/revenue.ts" "$B/release.ts" "$SRC/routes/"; pm2 restart anexomail-leo --update-env >/dev/null 2>&1; }
pm2 restart anexomail-leo --update-env >/dev/null 2>&1 && pm2 save >/dev/null 2>&1; sleep 6
H="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/health)"
F="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/api/founder/revenue/pipeline)"
echo "Brain health $H (200) · founder pipeline bina token $F (401)"
if [ "$H" != "200" ] || [ "$F" != "401" ]; then restore; echo "!! check FAIL — purani files wapas, health $(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/health)"; exit 1; fi
grep -c "basic: 23, pro: 46, business: 97" "$SRC/routes/revenue.ts" | sed 's/^/revenue.ts naye daam: /'
pm2 status anexomail-leo | head -6
echo "DONE: revenue board price fix (Brain)."
