#!/usr/bin/env bash
# ANEXOMAIL — family accounts (Humza, Raana, Masood) + founder row check.
# FOUNDER LOCK:
#   - Terminal pe password ASK banned.
#   - Founder password kabhi reset/touch nahi.
#   - Family passwords sirf /opt/anexomail/.env se.
set -euo pipefail
cd "$(dirname "$0")/../.."

ENV_FILE="${ENV_FILE:-/opt/anexomail/.env}"
[ -f "$ENV_FILE" ] || { echo "RED  $ENV_FILE nahi mila"; exit 1; }

echo "GREEN create-accounts — no terminal password; family keys from $ENV_FILE; founder password untouched"

BUN="${BUN:-$(command -v bun || echo /root/.bun/bin/bun)}"
exec "$BUN" --env-file="$ENV_FILE" run server/accounts/create-accounts.ts
