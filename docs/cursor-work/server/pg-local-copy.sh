#!/usr/bin/env bash
# pg-local-copy.sh (20 Nov 2026, QCONNECT step 4). WHY: the E-line (E37..E196) is only the top layer; it needs the base schema (phase58 and earlier) that lives in the managed database, so a fresh database cannot be built from the E-line alone (rehearsed in my sandbox: E37 stops at "mail_ingest not found").
# SO: one read-only pg_dump of public + auth + storage from the managed database (WORKING_URL in /etc/anexomail/sync.env) is restored into a NEW local database anexo_copy on the socket. The managed database is only READ; the running service is NOT changed.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pg-local-copy.sh) 2>&1 | tail -30
unset PGHOST PGPORT PGSERVICE PGDATABASE PGUSER
set -uo pipefail
. /etc/anexomail/sync.env 2>/dev/null; [ -n "${WORKING_URL:-}" ] || { echo "FAIL: WORKING_URL missing"; exit 2; }
S=/var/run/postgresql; D=/root/anexomail-backups/pgcopy-$(date +%Y%m%d-%H%M%S); umask 077; mkdir -p "$D"
pg_isready -h $S >/dev/null || { echo "FAIL: local cluster not ready"; exit 2; }
echo "== 1/4 dump from the managed database (read only)"
T0=$(date +%s)
pg_dump "$WORKING_URL" --no-owner --no-privileges --no-comments -n public -n auth -n storage -Fc -f "$D/managed.dump" 2>"$D/dump.err"; R=$?
echo "   pg_dump exit $R, $(du -h "$D/managed.dump" 2>/dev/null | cut -f1), $(( $(date +%s)-T0 )) s; stderr lines: $(wc -l <"$D/dump.err")"
[ $R -eq 0 ] || { head -5 "$D/dump.err"; echo "FAIL: dump (nothing local changed)"; exit 3; }
echo "== 2/4 new local database anexo_copy (the existing anexo_founder stays untouched)"
psql -X -h $S -d postgres -At -c "drop database if exists anexo_copy" -c "create database anexo_copy" >/dev/null || { echo "FAIL: createdb"; exit 3; }
psql -X -h $S -d anexo_copy -q -c "create schema if not exists extensions; create extension if not exists pgcrypto with schema extensions; create extension if not exists pg_trgm with schema extensions; create extension if not exists btree_gist with schema extensions" 2>&1 | tail -2
echo "== 3/4 restore (errors are counted, the list goes to $D/restore.err)"
pg_restore -h $S -d anexo_copy --no-owner --no-privileges -j 4 "$D/managed.dump" 2>"$D/restore.err"; echo "   pg_restore exit $?, error lines: $(grep -c 'error:' "$D/restore.err")"
grep 'error:' "$D/restore.err" | cut -c1-200 | sort | uniq -c | sort -rn | head -8
echo "== 4/4 proof: row counts local vs managed"
for TB in public.fmail_messages public.fmail_outbox public.profiles auth.users; do
  L=$(psql -X -h $S -d anexo_copy -At -c "select count(*) from $TB" 2>&1 | tail -1); M=$(psql "$WORKING_URL" -X -At -c "select count(*) from $TB" 2>&1 | tail -1); echo "   $TB local=$L managed=$M"
done
echo "   tables local: $(psql -X -h $S -d anexo_copy -At -c "select count(*) from information_schema.tables where table_schema in ('public','auth','storage')")  managed: $(psql "$WORKING_URL" -X -At -c "select count(*) from information_schema.tables where table_schema in ('public','auth','storage')" | tail -1)"
echo "DONE. Dump kept in $D. Next: hash-chain compare and the E-line top layer (written after his paste)."
