#!/usr/bin/env bash
# pg-local-run198.sh (20 Nov 2026, QCONNECT step 7). Puts the identity SQL doors (LOCAL_E198) on the LOCAL COPY anexo_copy, never on the managed database. Reads the real schema there (his copy), changes nothing else.
# 1) the parameter-log guard (a slow statement must never be logged WITH its bound parameters), 2) LOCAL_E198 through the normal sql-run with its own env + ledger, 3) its CHECK.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pg-local-run198.sh) 2>&1 | tail -25
unset PGHOST PGPORT PGSERVICE PGDATABASE PGUSER
set -uo pipefail
S=/var/run/postgresql; REPO="${REPO:-/opt/anexomail-web}"
pg_isready -q -h $S || { echo "FAIL: local cluster not ready"; exit 2; }
psql -X -h $S -d anexo_copy -At -c "select 1" >/dev/null 2>&1 || { echo "FAIL: anexo_copy missing (run pg-local-copy.sh first)"; exit 2; }
printf 'WORKING_URL=postgresql://root@/anexo_copy?host=/var/run/postgresql\n' > /etc/anexomail/local-copy.env; chmod 600 /etc/anexomail/local-copy.env
echo "== 1/3 parameter-log guard"
psql -X -h $S -d postgres -q -c "alter system set log_parameter_max_length = 0" -c "alter system set log_parameter_max_length_on_error = 0" -c "select pg_reload_conf()" >/dev/null && echo "   log_parameter_max_length = $(psql -X -h $S -d postgres -At -c 'show log_parameter_max_length')"
echo "== 2/3 LOCAL_E198 + 3/3 its CHECK (sql-run, local env, local ledger)"
ENV_FILE=/etc/anexomail/local-copy.env LEDGER=/var/lib/anexomail/sql-applied-local-copy.tsv bash <(git -C "$REPO" show origin/main:docs/cursor-work/server/sql-run.sh) LOCAL_E198_founder_localid_doors CHECK_LOCAL_E198 2>&1 | grep -v "^NOTICE\|NOTICE:" | tail -14
echo "DONE. (managed database untouched; the running service untouched)"
