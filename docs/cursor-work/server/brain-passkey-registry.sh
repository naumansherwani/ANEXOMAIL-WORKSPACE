#!/usr/bin/env bash
# ANEXOMAIL — Brain: SIRF ek chhota patch (E76) — passkey chhoot ab naam-pattern AUR test_accounts registry dono par. Asli user "x.test" ab bach nahi sakta.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/brain-passkey-registry.sh)
# PEHLE SQL E76 chal chuki ho (rpc na mile to fail-closed: chhoot nahi, sab ko gate). Backup + bun build pre-flight + health + restore-on-fail.
set -uo pipefail
SRC="${BRAIN_SRC:-/opt/anexomail/src}"; F="$SRC/routes/auth-passkey.ts"
BUN="$(command -v bun || echo /root/.bun/bin/bun)"; B="/root/anexomail-backups/brain-pk-registry-$(date +%Y%m%d-%H%M%S)"
[ -f "$F" ] || { echo "FAIL: $F nahi"; exit 2; }
grep -q "is_registered_test_account" "$F" && { echo "Pehle se lagi hai."; exit 0; }
mkdir -p "$B"; cp -p "$F" "$B/auth-passkey.ts"
python3 - "$F" <<'PY' || { echo "FAIL: patch point nahi mila — kuch nahi badla"; exit 3; }
import sys
p=sys.argv[1]; s=open(p).read()
old='if (/(^|[._-])test@/i.test(String((identity.user as any).email || ""))) {'
new='if (/(^|[._-])test@/i.test(String((identity.user as any).email || "")) && (await getAdmin().rpc("is_registered_test_account", { _email: String((identity.user as any).email || "") })).data === true) {'
if s.count(old)!=1: sys.exit(1)
open(p,'w').write(s.replace(old,new,1))
PY
T="$(mktemp -d)"; "$BUN" build "$F" --target=bun --external '*' --outfile "$T/o.js" >"$T/l" 2>&1 || { cat "$T/l"; cp -p "$B/auth-passkey.ts" "$F"; echo "!! build FAIL — purani wapas"; exit 1; }
pm2 restart anexomail-leo --update-env >/dev/null 2>&1 && pm2 save >/dev/null 2>&1; sleep 5
H="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/health)"; C="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/api/auth/passkey/status)"
echo "health $H · passkey/status (bina login) $C"
if [ "$H" != "200" ] || { [ "$C" != "401" ] && [ "$C" != "403" ]; }; then cp -p "$B/auth-passkey.ts" "$F"; pm2 restart anexomail-leo --update-env >/dev/null 2>&1; echo "!! FAIL — purani wapas"; exit 1; fi
echo "DONE: registry patch lagi. backup $B"
