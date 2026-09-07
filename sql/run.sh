#!/usr/bin/env bash
# ANEXOMAIL — SQL apply runner (founder: Muhammad Nauman Sherwani)
# Use: bash sql/run.sh sql/phaseNN_name.sql
# Koi edit nahi. DB URL khud dhoondta hai; na mile to saaf batata hai.
set -uo pipefail

FILE="${1:-}"
if [ -z "$FILE" ]; then echo "FAIL: file nahi di"; exit 2; fi
cd "$(dirname "$0")/.." || exit 2
if [ "$FILE" != "--check" ] && [ ! -f "$FILE" ]; then echo "FAIL: $FILE mojood nahi"; exit 2; fi

URL="${DATABASE_URL:-}"
if [ -z "$URL" ]; then
  # connect.sh ka login-verified URI authoritative hai. Purani app/mail env files
  # fallback hain; warna unka stale DATABASE_URL verified URI ko override karta hai.
  for f in /root/.anexomail.env /etc/anexomail/mail.env /opt/anexomail-web/.env /opt/anexomail/.env; do
    [ -f "$f" ] || continue
    v="$(grep -am1 -E '^[[:space:]]*(export[[:space:]]+)?(DATABASE_URL|SUPABASE_DB_URL|SUPABASE_DATABASE_URL|DIRECT_URL|PG_URL|POSTGRES_URL)=' "$f" | cut -d= -f2-)"
    v="${v#\"}"; v="${v%\"}"; v="${v#\'}"; v="${v%\'}"
    if [ -n "${v:-}" ]; then URL="$v"; break; fi
  done
fi

if [ -n "$URL" ]; then
  if [ "$FILE" = "--check" ]; then
    OUT="$(psql "$URL" -X -v ON_ERROR_STOP=1 -qAtc 'select 1' 2>&1)"; RC=$?
  else
    OUT="$(psql "$URL" -X -v ON_ERROR_STOP=1 -q -f "$FILE" 2>&1)"; RC=$?
  fi
elif [ -n "${PGHOST:-}" ]; then
  if [ "$FILE" = "--check" ]; then
    OUT="$(psql -X -v ON_ERROR_STOP=1 -qAtc 'select 1' 2>&1)"; RC=$?
  else
    OUT="$(psql -X -v ON_ERROR_STOP=1 -q -f "$FILE" 2>&1)"; RC=$?
  fi
else
  echo "FAIL: DATABASE_URL/PGHOST server ki protected env files mein nahi mila."
  exit 3
fi

if [ -n "$OUT" ]; then printf '%s\n' "$OUT"; fi
if printf '%s\n' "$OUT" | grep -aiEq '(^|: )(ERROR|FATAL):|^psql:'; then RC=1; fi
if [ "$RC" -eq 0 ]; then
  if [ "$FILE" = "--check" ]; then echo "GREEN  DATABASE CONNECTION"; else echo "GREEN  $FILE"; fi
else
  if [ "$FILE" = "--check" ]; then echo "RED    DATABASE CONNECTION"; else echo "RED    $FILE"; fi
fi
exit "$RC"
