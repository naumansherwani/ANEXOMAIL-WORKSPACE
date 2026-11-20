#!/usr/bin/env bash
# QCONNECT reverse copy (local -> Supabase) PROBE: READ-ONLY on the local database only. Changes nothing, touches no network.
# Lists every founder-owned table with: row count, primary key columns, whether it has updated_at / created_at, and the table kind.
# The mirror design (outbox + Rust drain to Supabase) is written from THIS fact, not from a guess.
set -u
DB=anexo_copy
runuser -u postgres -- psql -d "$DB" -At -F ' | ' -c "
select c.relname,
       coalesce((select string_agg(a.attname, ',' order by a.attnum) from pg_index i join pg_attribute a on a.attrelid=i.indrelid and a.attnum=any(i.indkey) where i.indrelid=c.oid and i.indisprimary),'NO-PK') as pk,
       exists(select 1 from pg_attribute a where a.attrelid=c.oid and a.attname='updated_at' and not a.attisdropped) as has_updated_at,
       exists(select 1 from pg_attribute a where a.attrelid=c.oid and a.attname in ('created_at','at','ts') and not a.attisdropped) as has_time,
       c.reltuples::bigint as approx_rows
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relkind='r' and (c.relname ~ '^(founder_|fmail_|qt_|revenue_|mail_)')
order by c.relname" 2>&1 | head -150
echo "(read-only: nothing was changed)"
