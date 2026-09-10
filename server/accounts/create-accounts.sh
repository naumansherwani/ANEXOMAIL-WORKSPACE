#!/usr/bin/env bash
# ANEXOMAIL — founder + family accounts (Humza, Raana, Masood).
# FOUNDER LOCK: password kabhi terminal pe mat poochho (Lovable pattern banned).
# Sirf /opt/anexomail/.env → Bun --env-file. Missing key = RED, no prompt.
set -euo pipefail
cd "$(dirname "$0")/../.."

ENV_FILE="${ENV_FILE:-/opt/anexomail/.env}"
[ -f "$ENV_FILE" ] || { echo "RED  $ENV_FILE nahi mila"; exit 1; }

BUN="${BUN:-$(command -v bun || echo /root/.bun/bin/bun)}"
# `.env` shell se source/eval nahi — special chars toot'te hain.
# Bun dotenv safely load karta hai. Ask/read password = banned.
exec "$BUN" --env-file="$ENV_FILE" run server/accounts/create-accounts.ts
