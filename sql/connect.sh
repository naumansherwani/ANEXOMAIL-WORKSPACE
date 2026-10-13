#!/usr/bin/env bash
# ANEXOMAIL — protected database connection setup; secret terminal par nazar nahi aata.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

printf 'Database connection URI paste karein (typing nazar nahi aayegi), phir Enter: '
IFS= read -r -s URL
printf '\n'

if [ -z "$URL" ]; then
  echo 'RED    DATABASE CONNECTION — URI khaali hai'
  exit 2
fi

case "$URL" in
  postgresql://*|postgres://*) ;;
  *) echo 'RED    DATABASE CONNECTION — URI postgresql:// ya postgres:// se shuru honi chahiye'; exit 2 ;;
esac

OUT="$(psql "$URL" -X -v ON_ERROR_STOP=1 -qAtc "select current_database(), current_user" 2>&1)"; RC=$?
if [ "$RC" -ne 0 ]; then
  unset URL
  printf '%s\n' "$OUT"
  echo 'RED    DATABASE CONNECTION — kuch save nahi hua'
  exit "$RC"
fi

umask 077
TMP="$(mktemp /root/.anexomail.env.XXXXXX)"
printf 'DATABASE_URL=%s\n' "$URL" > "$TMP"
chmod 600 "$TMP"
mv "$TMP" /root/.anexomail.env
unset URL

echo 'GREEN  DATABASE CONNECTION SAVED'
echo 'NEXT   bash sql/apply-all.sh'