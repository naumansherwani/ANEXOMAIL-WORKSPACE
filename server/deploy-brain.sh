#!/usr/bin/env bash
# ANEXOMAIL Brain :3100 — repo se managed source sync. Protected .env untouched.
set -euo pipefail

SOURCE=/opt/anexomail-web/server
TARGET=/opt/anexomail

[ -d "$TARGET/src/routes" ] || { echo "RED $TARGET/src/routes missing"; exit 2; }
[ -f "$TARGET/package.json" ] || { echo "RED $TARGET/package.json missing"; exit 2; }

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

# Naya index tabhi restart ho jab uske tamam route modules target par maujood hon.
missing=0
while IFS= read -r module; do
  relative="${module#./}"
  [ -f "$TARGET/src/${relative}.ts" ] || [ -f "$TARGET/src/${relative}.js" ] || {
    echo "RED Brain import missing: $TARGET/src/${relative}.{ts,js}"
    missing=1
  }
done < <(grep -oE 'from "\./routes/[^"]+' "$TARGET/src/index.ts" | sed 's/^from "//')
[ "$missing" -eq 0 ] || exit 2

cd "$TARGET"
bun install
pm2 restart anexomail-leo --update-env
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
echo "GREEN Brain auth contract :3100"