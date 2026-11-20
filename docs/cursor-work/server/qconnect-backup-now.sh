#!/usr/bin/env bash
# qconnect-backup-now.sh (21 Nov 2026 02:16 PKT, his order: backup BEFORE the login-only switch so nothing can be lost). READ-ONLY on both databases; it only WRITES new files in /var/backups/anexomail-pg (root, 0700, his server only; NOT the Storage Box, NOT git).
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/qconnect-backup-now.sh) 2>&1 | tail -20
# 1 his server database (anexo_copy, the newest data) as a full pg_dump + SHA-256 + a restore-list check
# 2 Supabase founder tables as COPY files + SHA-256 (the old copy, in case the back-copy ever has to be undone)
unset PGHOST PGPORT PGSERVICE PGDATABASE PGUSER
set -uo pipefail
S=${QSOCK:-/var/run/postgresql}; PORT=${QPORT:-5432}; LDB=${QLDB:-anexo_copy}; B=${QBACK:-/var/backups/anexomail-pg}; TS=$(date +%Y%m%d-%H%M%S)
. /etc/anexomail/sync.env 2>/dev/null; [ -n "${WORKING_URL:-}" ] || { echo "FAIL: WORKING_URL missing"; exit 2; }
umask 077; mkdir -p "$B"; chmod 700 "$B"; DIR="$B/pre-login-$TS"; mkdir -p "$DIR/supabase"
LP() { psql -X -h "$S" -p "$PORT" -d "$LDB" ${QUSER:+-U $QUSER} "$@"; }
echo "== 1/2 his server database (full dump)"
${QDUMP:-runuser -u postgres --} pg_dump -h "$S" -p "$PORT" ${QUSER:+-U $QUSER} -Fc "$LDB" -f "$DIR/server-$LDB.dump" 2>"$DIR/dump.err" || { cat "$DIR/dump.err" | head -3; echo "FAIL: server dump"; exit 3; }
N=$(${QDUMP:-runuser -u postgres --} pg_restore -l "$DIR/server-$LDB.dump" | wc -l); [ "$N" -gt "${QMINE:-100}" ] || { echo "FAIL: dump has only $N entries"; exit 3; }
echo "   $(ls -lh "$DIR/server-$LDB.dump" | awk '{print $5}') $DIR/server-$LDB.dump (restore list: $N entries)"
echo "== 2/2 Supabase founder tables (COPY files)"
T=0; BAD=0
for X in $(LP -At -c "select c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r' and c.relname ~ '^(founder_|fmail_|qt_|revenue_|mail_)' order by 1"); do
  if psql "$WORKING_URL" -X -q -c "copy public.$X to stdout" 2>/dev/null | gzip -c > "$DIR/supabase/$X.copy.gz" && [ "${PIPESTATUS[0]}" = 0 ]; then T=$((T+1)); else BAD=$((BAD+1)); rm -f "$DIR/supabase/$X.copy.gz"; fi
done
echo "   $T Supabase tables saved, $BAD not readable"
( cd "$DIR" && sha256sum server-$LDB.dump supabase/*.gz > SHA256SUMS && sha256sum -c SHA256SUMS --quiet && echo "   SHA-256 of all files: OK" )
echo "   folder: $DIR ($(du -sh "$DIR" | cut -f1)); disk free: $(df -h / | awk 'NR==2{print $4}')"
[ "$T" -gt "${QMIN:-50}" ] && [ "$BAD" -eq 0 ] && echo "OK: backup complete on his server only. Nothing was changed in either database." || { echo "WARN: not every table saved; do NOT switch until Claude has read this"; exit 4; }
