#!/usr/bin/env bash
# ANEXOMAIL — ANEXO tag (E90/E91): observe <-> enforce, SAFE (27 Oct 2026). Polar/Brain/Bun ko haath nahi. Reversible.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/tag-enforce.sh) [status|enforce|observe]
# status (default): abhi ka mode + Rust ki tag ginti.  enforce: PEHLE ginti dekhta hai (missing>0 ya invalid>0 => RUK jata hai), phir Rust restart,
# kernel-check chalata hai, FAIL ho to khud observe par wapas.  observe: wapas sirf-ginti.
set -uo pipefail
G=/opt/anexomail-web; MODE="${1:-status}"
cur(){ pm2 jlist 2>/dev/null | python3 -c 'import json,sys
try:
    for p in json.load(sys.stdin):
        if p.get("name")=="anexomail-rust": print(p["pm2_env"].get("ANEXO_TAG_MODE") or "observe")
except Exception: print("?")'; }
cnt(){ (pm2 logs anexomail-rust --nostream --lines 800 2>/dev/null) | grep 'kernel request-tag' | tail -1; }
restart(){ ANEXO_TAG_MODE="$1" pm2 restart anexomail-rust --update-env >/dev/null 2>&1 && pm2 save >/dev/null 2>&1; sleep 4
  echo "rust /rpc/health $(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://127.0.0.1:3200/rpc/health)  mode=$(cur)"; }
echo "mode abhi: $(cur)"; L="$(cnt)"; echo "tag ginti: ${L##*INFO }"
case "$MODE" in
  status) echo "(badalne ke liye: ... tag-enforce.sh enforce | observe)";;
  observe) restart observe;;
  enforce)
    [ -n "$L" ] || { echo "RUK: tag ginti abhi nahi — browser mein app kholein (kuch click karein), phir dobara chalayein"; exit 1; }
    echo "$L" | grep -Eq 'missing=0' && echo "$L" | grep -Eq 'invalid=0' || { echo "RUK: missing ya invalid 0 nahi — abhi enforce karne se kuch log 401 khayenge. Pehle observe mein ginti saaf hone dein."; exit 1; }
    restart enforce
    sleep 16
    if bash <(git -C "$G" show origin/main:docs/cursor-work/server/kernel-check.sh) 2>&1 | grep -q "KERNEL CHECK: ALL PASS"; then
      echo "ENFORCE LIVE: kernel-check ALL PASS. Browser (Ctrl+Shift+R) mein app chala kar dekhein; masla ho to: ... tag-enforce.sh observe"
    else
      echo "kernel-check FAIL — khud observe par wapas"; restart observe; exit 2
    fi;;
  *) echo "use: status | enforce | observe"; exit 1;;
esac
