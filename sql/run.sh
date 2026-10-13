#!/usr/bin/env bash
# ANEXOMAIL — SQL apply runner (founder: Muhammad Nauman Sherwani)
# Use: bash sql/run.sh sql/phaseNN_name.sql
# Koi edit nahi. DB URL khud dhoondta hai. Purane function signature ka
# `cannot change return type` error khud heal karta hai (DROP + retry).
set -uo pipefail

FILE="${1:-}"
if [ -z "$FILE" ]; then echo "FAIL: file nahi di"; exit 2; fi
cd "$(dirname "$0")/.." || exit 2
if [ "$FILE" != "--check" ] && [ "$FILE" != "--query" ] && [ ! -f "$FILE" ]; then echo "FAIL: $FILE mojood nahi"; exit 2; fi


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

if [ -z "$URL" ] && [ -z "${PGHOST:-}" ]; then
  echo "FAIL: DATABASE_URL/PGHOST server ki protected env files mein nahi mila."
  exit 3
fi

psql_run() { # $@ = psql args
  if [ -n "$URL" ]; then psql "$URL" -X -v ON_ERROR_STOP=1 -v VERBOSITY=verbose "$@" 2>&1
  else psql -X -v ON_ERROR_STOP=1 -v VERBOSITY=verbose "$@" 2>&1; fi
}

if [ "$FILE" = "--check" ]; then
  OUT="$(PGOPTIONS='-c client_min_messages=warning' psql_run -qAtc 'select 1')"; RC=$?
  printf '%s\n' "$OUT"
  if printf '%s\n' "$OUT" | grep -aiEq '(^|: )(ERROR|FATAL):|^psql: error:'; then RC=1; fi
  [ "$RC" -eq 0 ] && echo "GREEN  DATABASE CONNECTION" || echo "RED    DATABASE CONNECTION"
  exit "$RC"
fi

# Gate helper: ek query ka sirf value print karo (koi shor nahi)
if [ "$FILE" = "--query" ]; then
  Q="${2:-}"
  [ -z "$Q" ] && { echo "FAIL: query nahi di"; exit 2; }
  PGOPTIONS='-c client_min_messages=warning' psql_run -qAtc "$Q"
  exit $?
fi



HEALED=""
for attempt in 1 2 3 4 5 6; do
  OUT="$(psql_run -q -f "$FILE")"; RC=$?
  if printf '%s\n' "$OUT" | grep -aiEq '(^|: )(ERROR|FATAL):|^psql: error:'; then RC=1; fi
  [ "$RC" -eq 0 ] && break

  # Auto-heal: purana function signature — server ka HINT khud follow karo.
  SIGS="$(printf '%s\n' "$OUT" | grep -aoE 'DROP (FUNCTION|VIEW|TRIGGER)[^.]*' | sed -E 's/^DROP (FUNCTION|VIEW|TRIGGER) //' | sort -u)"
  KIND="$(printf '%s\n' "$OUT" | grep -aoE 'DROP (FUNCTION|VIEW|TRIGGER)' | head -n1 | awk '{print $2}')"
  [ -z "$SIGS" ] && break

  DID=0
  while IFS= read -r sig; do
    [ -z "$sig" ] && continue
    case "$sig" in *"("*) obj="$sig";; *) obj="$sig";; esac
    d="$(psql_run -qAtc "drop ${KIND:-function} if exists ${obj} cascade")"
    printf 'HEAL   drop %s %s\n' "${KIND:-function}" "$obj"
    HEALED="$HEALED $obj"
    DID=1
  done <<< "$SIGS"
  [ "$DID" -eq 0 ] && break
done

if [ -n "$OUT" ]; then printf '%s\n' "$OUT"; fi
if [ "$RC" -eq 0 ]; then
  echo "GREEN  $FILE"
else
  echo "RED    $FILE"
fi
exit "$RC"
