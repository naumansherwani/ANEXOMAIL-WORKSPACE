#!/usr/bin/env bash
# ANEXOMAIL — teen accounts (founder · Humza · Raana) Supabase Auth mein ready.
# Passwords terminal par chhup ke type hote hain; kahin likhe/print nahi hote. .env touch nahi hota.
set -euo pipefail
cd "$(dirname "$0")/../.."

ENV_FILE="${ENV_FILE:-/opt/anexomail/.env}"
[ -f "$ENV_FILE" ] || { echo "RED  $ENV_FILE nahi mila"; exit 1; }
set -a; # shellcheck disable=SC1090
source "$ENV_FILE"; set +a

ask() { local var="$1" label="$2"; if [ -z "${!var:-}" ]; then read -r -s -p "$label password (min 8): " val; echo; export "$var=$val"; fi; }
ask FOUNDER_MAIL_PASSWORD "Founder (naumansherwani.founder@)"
ask HUMZA_PASSWORD        "Humza (humzasherwani@)"
ask RAANA_PASSWORD        "Raana (raanasherwani@)"

BUN="${BUN:-$(command -v bun || echo /root/.bun/bin/bun)}"
exec "$BUN" run server/accounts/create-accounts.ts
