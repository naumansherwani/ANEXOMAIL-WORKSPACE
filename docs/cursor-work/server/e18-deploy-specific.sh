#!/usr/bin/env bash
# E18 — specific-file deploy, NOT a full `git pull` (Rule 14: "Server par poora
# git pull nahi: sirf specific files, sha-gated installer, backup + restore.sh").
#
# Touches exactly one file on the server: server/routes/auth.ts.
# Everything else in the working tree is left alone — no routeTree.gen.ts
# conflict, no unrelated commits pulled in.
#
# Run on the server, from anywhere:
#   bash docs/cursor-work/server/e18-deploy-specific.sh
set -euo pipefail

APP_DIR="/opt/anexomail-web"
TARGET_FILE="server/routes/auth.ts"
EXPECTED_SHA="661cb3c"   # E18 commit on main — sha-gate, do not change by hand
BACKUP_DIR="docs/cursor-work/server/backups"
TS="$(date +%Y%m%d%H%M%S)"

cd "$APP_DIR"

echo "[1/5] fetch (objects only — working tree untouched)"
git fetch origin main

echo "[2/5] sha-gate: confirm $EXPECTED_SHA is really on origin/main"
if ! git merge-base --is-ancestor "$EXPECTED_SHA" origin/main; then
  echo "ABORT: $EXPECTED_SHA not found on origin/main yet. Nothing changed." >&2
  exit 1
fi

echo "[3/5] backup current $TARGET_FILE"
mkdir -p "$BACKUP_DIR"
cp "$TARGET_FILE" "$BACKUP_DIR/auth.ts.$TS.bak"
echo "      -> $BACKUP_DIR/auth.ts.$TS.bak"

echo "[4/5] apply ONLY $TARGET_FILE from $EXPECTED_SHA (rest of the tree unchanged)"
git show "$EXPECTED_SHA:$TARGET_FILE" > "$TARGET_FILE"

echo "[5/5] rebuild (unavoidable for a compiled Bun/SSR app) + restart + health check"
bun install
bun run build:bun
pm2 restart anexomail-web --update-env
pm2 save
curl -s -o /dev/null -w "web /health %{http_code}\n" --max-time 5 http://127.0.0.1:3000/health

echo
echo "Done. If web /health was not 200, run:"
echo "  bash docs/cursor-work/server/e18-restore.sh"
echo
echo "Reminder — this script does NOT touch Supabase. Separately paste"
echo "  docs/cursor-work/sql/E18_signup_device_gate_nonblocking.sql"
echo "into Supabase #4 SQL Editor and Run — the server fix alone does nothing"
echo "until that function is replaced in the database too."
