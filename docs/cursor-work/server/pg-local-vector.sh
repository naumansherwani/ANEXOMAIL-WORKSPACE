#!/usr/bin/env bash
# pg-local-vector.sh (20 Nov 2026, QCONNECT step 4b). His pg-local-copy run: 675 of 677 tables restored; the 2 missing (public.leo_memory_vectors, public.ai_memory_vectors) need the pgvector extension (type extensions.vector).
# Installs pgvector from the OS packages, then restores ONLY those tables and their data from the dump of that run into anexo_copy. Managed database NOT touched, running service NOT touched, no port.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pg-local-vector.sh) 2>&1 | tail -25
unset PGHOST PGPORT PGSERVICE PGDATABASE PGUSER
set -uo pipefail
S=/var/run/postgresql; VER=$(ls /usr/lib/postgresql | sort -n | tail -1)
D=$(ls -dt /root/anexomail-backups/pgcopy-* 2>/dev/null | head -1); [ -s "$D/managed.dump" ] || { echo "FAIL: no dump found"; exit 2; }
echo "== 1/3 pgvector package for postgresql $VER"
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "postgresql-$VER-pgvector" >/dev/null 2>&1 || { echo "FAIL: apt install postgresql-$VER-pgvector"; apt-cache policy "postgresql-$VER-pgvector" | head -3; exit 3; }
psql -X -h $S -d anexo_copy -q -c "create extension if not exists vector with schema extensions" || { echo "FAIL: create extension"; exit 3; }
echo "   extension: $(psql -X -h $S -d anexo_copy -At -c "select extversion from pg_extension where extname='vector'")"
echo "== 2/3 restore only the 2 vector tables from $D/managed.dump"
pg_restore -h $S -d anexo_copy --no-owner --no-privileges -t leo_memory_vectors -t ai_memory_vectors "$D/managed.dump" 2>"$D/vector.err"; echo "   pg_restore exit $?, error lines: $(grep -c 'error:' "$D/vector.err")"; grep 'error:' "$D/vector.err" | cut -c1-200 | sort | uniq -c | head -5
echo "== 3/3 proof"
echo "   tables local: $(psql -X -h $S -d anexo_copy -At -c "select count(*) from information_schema.tables where table_schema in ('public','auth','storage')") (managed was 677)"
for TB in public.leo_memory_vectors public.ai_memory_vectors; do echo "   $TB rows: $(psql -X -h $S -d anexo_copy -At -c "select count(*) from $TB" 2>&1 | tail -1)"; done
echo "   functions local: $(psql -X -h $S -d anexo_copy -At -c "select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'")"
echo "DONE. Next: hash-chain compare (ledger verify functions) on anexo_copy."
