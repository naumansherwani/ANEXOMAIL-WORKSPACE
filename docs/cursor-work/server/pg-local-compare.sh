#!/usr/bin/env bash
# pg-local-compare.sh (20 Nov 2026, QCONNECT step 5). READ-ONLY on both sides. For every table of public + auth + storage it computes: row count and one md5 over the sorted row hashes, on the managed database and on the local copy anexo_copy, and lists ONLY the tables that differ.
# 22:2x FIX: empty tables (0 rows) have an empty hash, which made join+awk show a false DIFF; the hash of an empty table is now the word empty. Rows written by the live site after the dump (13 min ago and later) will show as differences: that is expected and is closed by the delta copy at switch time. Then it runs the zero-argument ledger verify functions on the local copy (hash chains).
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pg-local-compare.sh) 2>&1 | tail -40
unset PGHOST PGPORT PGSERVICE PGDATABASE PGUSER
set -uo pipefail
. /etc/anexomail/sync.env 2>/dev/null; [ -n "${WORKING_URL:-}" ] || { echo "FAIL: WORKING_URL missing"; exit 2; }
S=/var/run/postgresql; D=/root/anexomail-backups/pgcompare-$(date +%Y%m%d-%H%M%S); umask 077; mkdir -p "$D"
GEN="select format('select %L, count(*), coalesce(md5(string_agg(md5(t::text), %L order by md5(t::text))), %L) from %I.%I t', table_schema||'.'||table_name, '', 'empty', table_schema, table_name) from information_schema.tables where table_schema in ('public','auth','storage') and table_type='BASE TABLE' order by table_schema, table_name"
echo "== 1/3 local copy (fast)"
psql -X -h $S -d anexo_copy -At -F ' ' <<SQL >"$D/local.txt" 2>"$D/local.err"
$GEN \gexec
SQL
echo "   tables hashed: $(wc -l <"$D/local.txt")"
echo "== 2/3 managed database (read only, slow: distance 215 ms, a few minutes)"
psql "$WORKING_URL" -X -At -F ' ' <<SQL >"$D/managed.txt" 2>"$D/managed.err"
$GEN \gexec
SQL
echo "   tables hashed: $(wc -l <"$D/managed.txt")"
echo "== 3/3 differences (table, local count/hash vs managed count/hash)"
join -j1 <(sort "$D/local.txt") <(sort "$D/managed.txt") | awk '$2!=$4 || $3!=$5 {printf "   DIFF %s local=%s managed=%s\n",$1,$2,$4; n++} END {print "   differing tables: " n+0}'
echo "   only on one side: $(join -v1 -j1 <(sort "$D/local.txt") <(sort "$D/managed.txt") | wc -l) local-only, $(join -v2 -j1 <(sort "$D/local.txt") <(sort "$D/managed.txt") | wc -l) managed-only"
echo "== hash-chain verify functions (zero arguments) on the local copy"
psql -X -h $S -d anexo_copy -At -F ' | ' <<'SQL' 2>&1 | cut -c1-200 | head -30
select format('select %L, left(%s::text, 120)', proname, 'public.'||quote_ident(proname)||'()') from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and pronargs=0 and proname ~ 'verify' and prokind='f' and proretset=false order by 1 \gexec
SQL
echo "DONE. Files: $D (local.txt, managed.txt)"
