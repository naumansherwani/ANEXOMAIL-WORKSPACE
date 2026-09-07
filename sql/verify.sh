#!/usr/bin/env bash
# ANEXOMAIL — DB verify: tables, GRANTs, RLS, functions. Sirf padhta hai, kuch badalta nahi.
# Use: bash sql/verify.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

Q=$(cat <<'SQL'
\pset pager off
select 'TABLES' as check, count(*) as value from pg_tables where schemaname='public';
select 'FUNCTIONS' as check, count(*) as value from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public';
select 'RLS OFF (must be 0)' as check, count(*) as value
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where n.nspname='public' and c.relkind='r' and c.relrowsecurity=false;
select 'NO GRANT (must be 0)' as check, count(*) as value from (
  select c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace
   where n.nspname='public' and c.relkind='r'
     and not exists (
       select 1 from information_schema.role_table_grants g
        where g.table_schema='public' and g.table_name=c.relname
          and g.grantee in ('authenticated','anon','service_role'))) x;
select c.relname as rls_off_table
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where n.nspname='public' and c.relkind='r' and c.relrowsecurity=false order by 1;
select c.relname as no_grant_table
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where n.nspname='public' and c.relkind='r'
   and not exists (select 1 from information_schema.role_table_grants g
     where g.table_schema='public' and g.table_name=c.relname
       and g.grantee in ('authenticated','anon','service_role')) order by 1;
SQL
)

TMP=$(mktemp /tmp/anexomail-verify-XXXX.sql)
printf '%s\n' "$Q" > "$TMP"
bash sql/run.sh "$TMP" >/dev/null 2>&1 || true

URL="${DATABASE_URL:-}"
if [ -z "$URL" ]; then
  for f in /etc/anexomail/mail.env /opt/anexomail-web/.env /opt/anexomail/.env /root/.anexomail.env; do
    [ -f "$f" ] || continue
    v="$(grep -aoE '(DATABASE_URL|SUPABASE_DB_URL|PG_URL|POSTGRES_URL)=.*' "$f" | head -n1 | cut -d= -f2- | tr -d '"'"'"' ')"
    if [ -n "${v:-}" ]; then URL="$v"; break; fi
  done
fi
if [ -n "$URL" ]; then psql "$URL" -f "$TMP"; else psql -f "$TMP"; fi
rm -f "$TMP"
