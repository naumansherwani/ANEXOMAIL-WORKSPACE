#!/usr/bin/env bash
# ANEXOMAIL Brain :3100 — repo se managed source sync. Protected .env untouched.
set -euo pipefail

SOURCE=/opt/anexomail-web/server
TARGET=/opt/anexomail
ENV_FILE="${ENV_FILE:-/opt/anexomail/.env}"
BUN="${BUN:-$(command -v bun || echo /root/.bun/bin/bun)}"

[ -d "$TARGET/src/routes" ] || { echo "RED $TARGET/src/routes missing"; exit 2; }
[ -f "$TARGET/package.json" ] || { echo "RED $TARGET/package.json missing"; exit 2; }
[ -r "$ENV_FILE" ] || { echo "RED $ENV_FILE missing/unreadable"; exit 2; }

STAMP="$(date +%s)"
mkdir -p "$TARGET/backups/$STAMP/routes"
cp -a "$TARGET/src/index.ts" "$TARGET/backups/$STAMP/index.ts" 2>/dev/null || true

# Sirf repo-owned files sync; server ke doosre valid route files preserve rehte hain.
install -m 0644 "$SOURCE/index.ts" "$TARGET/src/index.ts"
for file in "$SOURCE"/routes/*.ts; do
  name="$(basename "$file")"
  [ -f "$TARGET/src/routes/$name" ] && cp -a "$TARGET/src/routes/$name" "$TARGET/backups/$STAMP/routes/$name"
  install -m 0644 "$file" "$TARGET/src/routes/$name"
done

# F3 A — auth imports ../mail/sendmail + ../lib/webauthn (Brain crash band)
mkdir -p "$TARGET/src/mail" "$TARGET/src/lib" "$TARGET/backups/$STAMP/mail" "$TARGET/backups/$STAMP/lib"
if [ -f "$SOURCE/mail/sendmail.ts" ]; then
  [ -f "$TARGET/src/mail/sendmail.ts" ] && cp -a "$TARGET/src/mail/sendmail.ts" "$TARGET/backups/$STAMP/mail/sendmail.ts"
  install -m 0644 "$SOURCE/mail/sendmail.ts" "$TARGET/src/mail/sendmail.ts"
fi
if [ -f "$SOURCE/lib/webauthn.ts" ]; then
  [ -f "$TARGET/src/lib/webauthn.ts" ] && cp -a "$TARGET/src/lib/webauthn.ts" "$TARGET/backups/$STAMP/lib/webauthn.ts"
  install -m 0644 "$SOURCE/lib/webauthn.ts" "$TARGET/src/lib/webauthn.ts"
fi
# auth-passkey imports ../lib/webauthn — path from routes is ../lib ✓
# Naya index tabhi restart ho jab uske tamam route modules target par maujood hon.
missing=0
while IFS= read -r module; do
  relative="${module#./}"
  base="${relative%.js}"
  [ -f "$TARGET/src/${base}.ts" ] || [ -f "$TARGET/src/${base}.js" ] || {
    echo "RED Brain import missing: $TARGET/src/${base}.ts"
    missing=1
  }
done < <(grep -oE 'from "\./routes/[^"]+' "$TARGET/src/index.ts" | sed 's/^from "//')
[ "$missing" -eq 0 ] || exit 2

cd "$TARGET"
bun install
# PM2 ki purani cached environment use nahi hoti. Har deploy par protected
# env-file Bun khud parse karta hai, bilkul account provisioning ki tarah.
pm2 delete anexomail-leo >/dev/null 2>&1 || true
pm2 start "$BUN" --name anexomail-leo --cwd "$TARGET" --interpreter none -- \
  --env-file="$ENV_FILE" run src/index.ts
for _ in $(seq 1 30); do
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://127.0.0.1:3100/api/health || true)"
  [ "$code" = "200" ] && break
  sleep 1
done
[ "${code:-000}" = "200" ] || {
  echo "RED Brain :3100 health ${code:-000}"
  pm2 logs anexomail-leo --lines 50 --nostream
  exit 3
}

for endpoint in login signup forgot-password; do
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 -X POST -H 'content-type: application/json' -d '{}' "http://127.0.0.1:3100/api/auth/$endpoint" || true)"
  [ "$code" = "400" ] || { echo "RED /api/auth/$endpoint -> $code"; exit 4; }
done
code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://127.0.0.1:3100/api/auth/session || true)"
[ "$code" = "401" ] || { echo "RED /api/auth/session guard -> $code"; exit 4; }
echo "GREEN anexomail-leo :3100 — SSH health only, not the website"