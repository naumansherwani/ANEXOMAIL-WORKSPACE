#!/usr/bin/env bash
# QCONNECT login-only, step A: READ-ONLY on BOTH databases. Which founder tables hold rows on his server that Supabase does not have (written since the switch)?
# Changes nothing. Output: table | rows local | rows managed | same? . Founder-owned prefixes only (founder_ fmail_ qt_ revenue_ mail_).
unset PGHOST PGPORT PGSERVICE PGDATABASE PGUSER
set -uo pipefail
. /etc/anexomail/sync.env 2>/dev/null; [ -n "${WORKING_URL:-}" ] || { echo "FAIL: WORKING_URL missing"; exit 2; }
S=/var/run/postgresql
L() { psql -X -h $S -d anexo_copy -At -F ' ' -c "$1" 2>&1 | tail -1; }
M() { psql "$WORKING_URL" -X -At -F ' ' -c "$1" 2>&1 | tail -1; }
TABLES="$(psql -X -h $S -d anexo_copy -At -c "select c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r' and c.relname ~ '^(founder_|fmail_|qt_|revenue_|mail_)' order by 1")"
D=0; N=0
for T in $TABLES; do
  Q="select count(*)||' '||coalesce(md5(string_agg(t::text, '|' order by t::text)),'-') from public.$T t"
  A="$(L "$Q")"; B="$(M "$Q")"; N=$((N+1))
  if [ "$A" = "$B" ]; then continue; fi
  D=$((D+1)); echo "DIFF $T | local rows ${A%% *} | managed rows ${B%% *}"
done
echo "checked $N founder tables, $D differ (those hold writes made on his server since the switch)"
echo "(read-only: nothing was changed on either side)"
