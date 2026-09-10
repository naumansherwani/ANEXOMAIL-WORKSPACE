#!/usr/bin/env bash
# ANEXOMAIL — family accounts (Humza, Raana, Masood) + founder row check.
# FOUNDER LOCK:
#   - Terminal pe password ASK banned (Lovable pattern).
#   - Founder password kabhi reset/touch nahi — FOUNDER_MAIL_PASSWORD is script use nahi karti.
#   - Family passwords sirf /opt/anexomail/.env se (HUMZA_PASSWORD · RAANA_PASSWORD · MASOOD_PASSWORD).
set -euo pipefail
cd "$(dirname "$0")/../.."

ENV_FILE="${ENV_FILE:-/opt/anexomail/.env}"
[ -f "$ENV_FILE" ] || { echo "RED  $ENV_FILE nahi mila"; exit 1; }

# Guard: agar koi purani copy ask() wapas laaye
if grep -qE '^ask FOUNDER|^ask HUMZA|read -r -s -p' "$0" 2>/dev/null; then
  echo "RED  purani create-accounts.sh (password ask). git pull karo."
  exit 2
fi

echo "GREEN create-accounts — no terminal password; family keys from $ENV_FILE; founder password untouched"

BUN="${BUN:-$(command -v bun || echo /root/.bun/bin/bun)}"
exec "$BUN" --env-file="$ENV_FILE" run server/accounts/create-accounts.ts
