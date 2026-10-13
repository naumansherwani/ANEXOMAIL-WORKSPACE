#!/usr/bin/env bash
# E18 rollback — puts server/routes/auth.ts back to whatever it was right
# before e18-deploy-specific.sh ran, using the newest backup it made.
#
# Run on the server:
#   bash docs/cursor-work/server/e18-restore.sh
set -euo pipefail

APP_DIR="/opt/anexomail-web"
TARGET_FILE="server/routes/auth.ts"
BACKUP_DIR="docs/cursor-work/server/backups"

cd "$APP_DIR"

LATEST_BACKUP="$(ls -t "$BACKUP_DIR"/auth.ts.*.bak 2>/dev/null | head -1 || true)"
if [ -z "$LATEST_BACKUP" ]; then
  echo "ABORT: no backup found in $BACKUP_DIR — nothing to restore." >&2
  exit 1
fi

echo "Restoring $TARGET_FILE from $LATEST_BACKUP"
cp "$LATEST_BACKUP" "$TARGET_FILE"

bun run build:bun
pm2 restart anexomail-web --update-env
pm2 save
curl -s -o /dev/null -w "web /health %{http_code}\n" --max-time 5 http://127.0.0.1:3000/health

echo "Restored."
