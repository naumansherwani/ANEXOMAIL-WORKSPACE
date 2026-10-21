#!/usr/bin/env bash
# ANEXOMAIL — Brain (Bun :3100) FALLBACK passkey hardening (B2, founder 21 Oct 2026): challenge SINGLE-USE (pehle mitao, phir verify),
# challenge shape check, challenge-user == credential-owner. Rust wale rasta jaisa; Bun sirf fallback hai par ab wahan bhi replay ka darwaza band.
#   bash <(git -C /opt/anexomail-web fetch -q origin main; git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/brain-passkey-harden-install.sh)
# Sirf routes/auth-passkey.ts, 3 surgical jagah (brain_passkey_harden.py). Backup + bun build pre-flight + health + hostile-input check + restore-on-fail.
# Rust, web, polar, .env ko haath nahi.
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"; SRC="${BRAIN_SRC:-/opt/anexomail/src}"
BUN="$(command -v bun || echo /root/.bun/bin/bun)"; STAMP="$(date +%Y%m%d-%H%M%S)"; B="/root/anexomail-backups/brain-passkey-harden-$STAMP"
PK="$SRC/routes/auth-passkey.ts"
[ -f "$PK" ] && [ -f "$SRC/index.ts" ] || { echo "FAIL: Brain src/auth-passkey.ts nahi: $SRC"; exit 2; }
git -C "$REPO" fetch -q origin main 2>/dev/null
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
git -C "$REPO" show origin/main:docs/cursor-work/server/brain_passkey_harden.py > "$T/patch.py"; [ -s "$T/patch.py" ] || { echo "FAIL: repo se brain_passkey_harden.py nahi mila"; exit 2; }
ST="$(python3 -I "$T/patch.py" "$PK" "$T/auth-passkey.ts")"; RC=$?
[ "$RC" = 0 ] || { echo "$ST"; echo "(live auth-passkey.ts ke markers alag hain — kuch nahi badla. Output Claude ko bhejein.)"; exit 3; }
echo "status: $ST"
[ "$ST" = same ] && { echo "Pehle se lagi hai."; exit 0; }
NM=""; d="$SRC"; for _ in 1 2 3; do [ -d "$d/node_modules" ] && { NM="$d/node_modules"; break; }; d="$(dirname "$d")"; done
[ -n "$NM" ] || { echo "FAIL: Brain ka node_modules nahi mila"; exit 2; }
mkdir -p "$T/pf/app/src"; (cd "$SRC" && tar cf - --exclude=node_modules .) | (cd "$T/pf/app/src" && tar xf -); ln -s "$NM" "$T/pf/app/node_modules"
cp "$T/auth-passkey.ts" "$T/pf/app/src/routes/auth-passkey.ts"
"$BUN" build "$T/pf/app/src/index.ts" --target=bun --outfile "$T/pf/out.js" >"$T/b.log" 2>&1 || { tail -20 "$T/b.log"; echo "!! nayi file ka build FAIL — kuch install nahi hua."; exit 1; }
mkdir -p "$B"; cp -p "$PK" "$B/auth-passkey.ts"; cp "$T/auth-passkey.ts" "$PK"
echo "lagaya. backup: $B"
restore() { cp -p "$B/auth-passkey.ts" "$PK"; pm2 restart anexomail-leo --update-env >/dev/null 2>&1; }
pm2 restart anexomail-leo --update-env >/dev/null 2>&1 && pm2 save >/dev/null 2>&1; sleep 6
H="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/health)"
# hostile input: filter-injection challenge + kachra credential => saaf 400 (500 / 200 nahi)
J='{"id":"x","response":{"clientDataJSON":"'"$(printf '{"type":"webauthn.get","challenge":"a)&or=(id.gt.0","origin":"https://anexomail.com"}' | base64 -w0 | tr '+/' '-_' | tr -d '=')"'","authenticatorData":"AA","signature":"AA"}}'
V="$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'content-type: application/json' -H 'origin: https://anexomail.com' -d "$J" http://127.0.0.1:3100/api/auth/passkey/verify)"
G="$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'content-type: application/json' -d '{}' http://127.0.0.1:3100/api/auth/passkey/verify)"
O="$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'content-type: application/json' -H 'origin: https://anexomail.com' -d '{"email":"no-such-user-b2"}' http://127.0.0.1:3100/api/auth/passkey/options)"
S="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/api/auth/session)"
echo "Brain health $H (200) · injection-challenge verify $V (400) · khali verify $G (400) · anjaan account options $O (400) · session bina token $S (401)"
if [ "$H" != "200" ] || [ "$V" != "400" ] || [ "$G" != "400" ] || [ "$O" != "400" ] || [ "$S" != "401" ]; then restore; echo "!! check FAIL — purani file wapas, health $(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/health)"; exit 1; fi
pm2 status anexomail-leo | head -6
echo "DONE: Brain fallback passkey hardening."
