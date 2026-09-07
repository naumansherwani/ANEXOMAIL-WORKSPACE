#!/usr/bin/env bash
# ANEXOMAIL — SQL apply runner (founder: Muhammad Nauman Sherwani)
# Use: bash sql/run.sh sql/phaseNN_name.sql
# Koi edit nahi. DB URL khud dhoondta hai; na mile to saaf batata hai.
set -uo pipefail

FILE="${1:-}"
if [ -z "$FILE" ]; then echo "FAIL: file nahi di"; exit 2; fi
cd "$(dirname "$0")/.." || exit 2
if [ ! -f "$FILE" ]; then echo "FAIL: $FILE mojood nahi"; exit 2; fi

URL="${DATABASE_URL:-}"
if [ -z "$URL" ]; then
  for f in /etc/anexomail/mail.env /opt/anexomail-web/.env /opt/anexomail/.env /root/.anexomail.env; do
    [ -f "$f" ] || continue
    v="$(grep -aoE '(DATABASE_URL|SUPABASE_DB_URL|PG_URL|POSTGRES_URL)=.*' "$f" | head -n1 | cut -d= -f2- | tr -d '"'"'"' ')"
    if [ -n "${v:-}" ]; then URL="$v"; break; fi
  done
fi

if [ -n "$URL" ]; then
  OUT="$(psql "$URL" -v ON_ERROR_STOP=1 -q -f "$FILE" 2>&1)"; RC=$?
elif [ -n "${PGHOST:-}" ]; then
  OUT="$(psql -v ON_ERROR_STOP=1 -q -f "$FILE" 2>&1)"; RC=$?
else
  echo "FAIL: DB URL nahi mila. Sirf ek dafa yeh line paste karo (apna Supabase connection string ke saath), phir command dobara chalao:"
  echo '  echo DATABASE_URL=postgresql://postgres:PASSWORD@HOST:5432/postgres > /root/.anexomail.env'
  exit 3
fi

echo "$OUT" | grep -aiE '^(ERROR|FATAL|psql:)' && RC=1
if [ "$RC" -eq 0 ]; then echo "GREEN  $FILE"; else echo "RED    $FILE"; fi
exit "$RC"
