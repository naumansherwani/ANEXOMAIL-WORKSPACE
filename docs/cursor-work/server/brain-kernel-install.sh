#!/usr/bin/env bash
# ANEXOMAIL — Brain (Bun :3100, pm2 anexomail-leo) FALLBACK: 26 Oct 2026 ke server-side Bun badlav live karo. Koi SQL nahi. Rust/Web ko haath nahi.
#   bash <(git -C /opt/anexomail-web fetch -q origin main; git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/brain-kernel-install.sh)
# Kyun: Bun code pull.sh se live nahi jata (brain-*-install.sh se jata hai). MFA (/api/auth/mfa*, magic-link verify) sirf Bun mein hai => Brain mein na ho to 404.
# Guroh (har guroh ya poora lagta hai ya bilkul nahi — aadha lagna mana):
#   A analytics : routes/analytics.ts (naya) + lib/analytics-gate.ts (naya) + index.ts (sirf 3 line: import + 2 mount, anchor se)  -> /api/analytics/*, /api/founder/analytics|billing/revenue fallback
#   B mfa       : routes/auth.ts + lib/mfa-challenge.ts (naya)                                       -> TOTP 2-step + magic-link verify
#   C pricing   : routes/calendar.ts (meeting cost Pro+) + routes/revenue.ts + routes/release.ts      -> flat price (Rule 51)
# Safety: live file ka sha256 repo ke BASE (8be9a82^) se mile tabhi badalti hai (warna DRIFT: us guroh ko chhod do, batao), `bun build` pre-flight,
#         backup, health + smoke, fail par purani files wapas.
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"; SRC="${BRAIN_SRC:-/opt/anexomail/src}"
BUN="$(command -v bun || echo /root/.bun/bin/bun)"; STAMP="$(date +%Y%m%d-%H%M%S)"; B="/root/anexomail-backups/brain-kernel-$STAMP"
BASE="${BASE:-8be9a82^}"
[ -d "$SRC/routes" ] || { echo "FAIL: $SRC/routes nahi mila"; exit 2; }
git -C "$REPO" fetch -q origin main 2>/dev/null
sh12() { sha256sum | cut -c1-12; }
declare -A GROUPS_EXIST=( [A]="" [B]="routes/auth.ts" [C]="routes/calendar.ts routes/revenue.ts routes/release.ts" )
declare -A GROUPS_NEW=( [A]="routes/analytics.ts lib/analytics-gate.ts" [B]="lib/mfa-challenge.ts" [C]="" )
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT; APPLY=""
for g in A B C; do
  ok=1; why=""
  for f in ${GROUPS_EXIST[$g]}; do
    live="$SRC/$f"; [ -f "$live" ] || { ok=0; why="$why $f(live nahi)"; continue; }
    new="$(git -C "$REPO" show "origin/main:server/$f" 2>/dev/null | sh12)"
    base="$(git -C "$REPO" show "$BASE:server/$f" 2>/dev/null | sh12)"
    cur="$(sh12 < "$live")"
    if [ "$cur" = "$new" ]; then :; elif [ "$cur" = "$base" ]; then :; else ok=0; why="$why $f(DRIFT live=$cur base=$base)"; fi
  done
  if [ "$ok" = 1 ]; then APPLY="$APPLY $g"; echo "guroh $g: lagega"; else echo "guroh $g: CHHOD DIYA —$why  (Output Claude ko bhejein; hunks banenge)"; fi
done
[ -n "$APPLY" ] || { echo "Kuch nahi lagaya."; exit 3; }
# tayyar tree: live src ki copy + naye files
mkdir -p "$T/pf/app/src"; (cd "$SRC" && tar cf - --exclude=node_modules .) | (cd "$T/pf/app/src" && tar xf -)
NM=""; d="$SRC"; for _ in 1 2 3; do [ -d "$d/node_modules" ] && { NM="$d/node_modules"; break; }; d="$(dirname "$d")"; done
[ -n "$NM" ] || { echo "FAIL: Brain ka node_modules nahi mila"; exit 2; }
ln -s "$NM" "$T/pf/app/node_modules"
FILES=""; case " $APPLY " in *" A "*) FILES=" index.ts";; esac
for g in $APPLY; do for f in ${GROUPS_EXIST[$g]} ${GROUPS_NEW[$g]}; do
  [ -n "$f" ] || continue; mkdir -p "$(dirname "$T/pf/app/src/$f")"
  git -C "$REPO" show "origin/main:server/$f" > "$T/pf/app/src/$f" || { echo "FAIL: repo mein server/$f nahi"; exit 2; }
  FILES="$FILES $f"
done; done
case " $APPLY " in *" A "*)
  python3 -I - "$T/pf/app/src/index.ts" <<'PY' || { echo "guroh A: index.ts ke anchor nahi mile — guroh A chhod diya"; for f in routes/analytics.ts lib/analytics-gate.ts; do rm -f "$T/pf/app/src/$f"; FILES="${FILES/ $f/}"; done; APPLY="${APPLY/A/}"; }
import sys,re
p=sys.argv[1]; s=open(p).read()
if "routes/analytics" in s: sys.exit(0)
imp='import { analyticsRouter, founderAnalyticsRouter } from "./routes/analytics";\n'
mnt='// Analytics Center (Rust PRIMARY) — Bun fallback\napp.use("/api", analyticsRouter);\napp.use("/api/founder", founderAnalyticsRouter);\n'
m=list(re.finditer(r'^import .*;\s*$', s, re.M))
a=s.find('app.use("/api/auth", authRouter);')
if not m or a<0: sys.exit(1)
a_end=s.index("\n",a)+1
s=s[:a_end]+mnt+s[a_end:]
e=m[-1].end(); s=s[:e]+"\n"+imp.rstrip("\n")+s[e:]
open(p,"w").write(s)
PY
;; esac
"$BUN" build "$T/pf/app/src/index.ts" --target=bun --outfile "$T/pf/out.js" >"$T/b.log" 2>&1 || { tail -20 "$T/b.log"; echo "!! build FAIL — kuch install nahi hua."; exit 1; }
mkdir -p "$B"
for f in $FILES; do if [ -f "$SRC/$f" ]; then mkdir -p "$B/$(dirname "$f")"; cp -p "$SRC/$f" "$B/$f"; else echo "$f" >> "$B/NEW-FILES.txt"; fi; mkdir -p "$(dirname "$SRC/$f")"; cp "$T/pf/app/src/$f" "$SRC/$f"; done
echo "lagaya (guroh:$APPLY ). backup: $B"
restore() { for f in $FILES; do if [ -f "$B/$f" ]; then cp -p "$B/$f" "$SRC/$f"; else rm -f "$SRC/$f"; fi; done; pm2 restart anexomail-leo --update-env >/dev/null 2>&1; }
pm2 restart anexomail-leo --update-env >/dev/null 2>&1 && pm2 save >/dev/null 2>&1; sleep 7
H="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/health)"
M="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/api/auth/mfa)"          # B: 401 (404 nahi)
A="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/api/analytics/response-debt)"   # A: 401 (404 nahi)
echo "Brain health $H (200) · /api/auth/mfa $M (401) · /api/analytics/response-debt $A (401)"
BAD=0; [ "$H" = 200 ] || BAD=1
case " $APPLY " in *" B "*) [ "$M" = 401 ] || BAD=1;; esac
case " $APPLY " in *" A "*) [ "$A" = 401 ] || BAD=1;; esac
if [ "$BAD" = 1 ]; then restore; echo "!! check FAIL — purani files wapas, health $(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/health)"; exit 1; fi
pm2 status anexomail-leo | head -6
echo "DONE: Brain kernel/MFA/analytics fallback."
