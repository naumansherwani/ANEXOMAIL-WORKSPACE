#!/usr/bin/env bash
# QCONNECT footprint: READ-ONLY. How much RAM, disk and CPU the local PostgreSQL takes on his server.
# Changes nothing. No restart, no write, no network.
set -u
unset PGHOST PGPORT PGSERVICE PGDATABASE PGUSER
echo "== 1/5 server RAM now (MB) =="
free -m | sed -n '1,2p'
echo "== 2/5 postgres processes: count and RAM used (RSS, MB) =="
ps -eo rss,comm | awk '$2 ~ /postgres/ {n++; s+=$1} END {printf "processes=%d  rss_total_mb=%.0f (shared memory is counted several times, real use is lower)\n", n, s/1024}'
echo "== 3/5 founder service RAM (MB) =="
ps -eo rss,args | awk '/anexomail-founder/ && !/awk/ {printf "founder rss_mb=%.0f\n", $1/1024}'
echo "== 4/5 database size on disk =="
runuser -u postgres -- psql -At -c "select datname||' = '||pg_size_pretty(pg_database_size(datname)) from pg_database where datname like 'anexo%' order by 1" 2>&1 | head -5
du -sh /var/lib/postgresql 2>/dev/null
echo "== 5/5 disk free =="
df -h / | sed -n '1,2p'
echo "(read-only: nothing was changed)"
