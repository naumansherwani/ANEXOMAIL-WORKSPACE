#!/usr/bin/env bash
# ANEXOMAIL — Brain: SIRF ek chhota patch — test accounts par passkey banner/gate band (G35 deadline real users ke liye).
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/brain-passkey-exempt.sh)
# Kyun alag script: live routes/auth-passkey.ts repo se alag hai (STOP aaya) — poori file nahi badalte, sirf /passkey/status mein
# ek block daalte hain. Baqi live badlav bachte hain. Backup + bun build pre-flight + health + restore-on-fail.
set -uo pipefail
SRC="${BRAIN_SRC:-/opt/anexomail/src}"; F="$SRC/routes/auth-passkey.ts"
BUN="$(command -v bun || echo /root/.bun/bin/bun)"; B="/root/anexomail-backups/brain-pk-exempt-$(date +%Y%m%d-%H%M%S)"
[ -f "$F" ] || { echo "FAIL: $F nahi"; exit 2; }
grep -q "exempt: true" "$F" && { echo "Pehle se lagi hai."; exit 0; }
mkdir -p "$B"; cp -p "$F" "$B/auth-passkey.ts"
python3 - "$F" <<'PY' || { echo "FAIL: patch point nahi mila — kuch nahi badla"; exit 3; }
import re,sys
p=sys.argv[1]; s=open(p).read()
m=re.search(r'(authRouter\.get\("/passkey/status",\s*async\s*\(req,\s*res\)\s*=>\s*\{\s*const identity = await userFrom\(req, res\);\s*if \(!identity\) return;\n)',s)
if not m: sys.exit(1)
blk='''    // Founder 21 Oct 2026: 27 Oct deadline sirf REAL users ke liye; test accounts (basic.test@ ...) par banner/gate nahi.
    if (/(^|[._-])test@/i.test(String((identity.user as any).email || ""))) {
      return res.json({ exempt: true, required: false, hard: false, count: 0, target: 0, codes_remaining: 1 });
    }
'''
open(p,'w').write(s[:m.end()]+blk+s[m.end():])
PY
T="$(mktemp -d)"; "$BUN" build "$F" --target=bun --external '*' --outfile "$T/o.js" >"$T/l" 2>&1 || { cat "$T/l"; cp -p "$B/auth-passkey.ts" "$F"; echo "!! build FAIL — purani wapas"; exit 1; }
pm2 restart anexomail-leo --update-env >/dev/null 2>&1 && pm2 save >/dev/null 2>&1; sleep 5
H="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/health)"; C="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/api/auth/passkey/status)"
echo "health $H · passkey/status (bina login) $C"
if [ "$H" != "200" ] || { [ "$C" != "401" ] && [ "$C" != "403" ]; }; then cp -p "$B/auth-passkey.ts" "$F"; pm2 restart anexomail-leo --update-env >/dev/null 2>&1; echo "!! FAIL — purani wapas"; exit 1; fi
echo "DONE: test accounts exempt. backup $B"
