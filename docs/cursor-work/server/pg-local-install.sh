#!/usr/bin/env bash
# pg-local-install.sh (20 Nov 2026, QCONNECT step 3). Installs PostgreSQL from the OS packages on HIS server and makes ONE cluster that listens on a UNIX SOCKET ONLY (listen_addresses empty):
# it opens NO TCP port, so the PORT RED LINE (his ss paste 21:06) is untouched. It touches nothing that exists: no Caddy, no founder service, no env of the running service.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pg-local-install.sh) 2>&1 | tail -25
# Safe to run again (every step checks first). Output ends with proof lines: version, socket, no TCP listener, role list, the compat bootstrap result.
set -euo pipefail
REPO="${REPO:-/opt/anexomail-web}"; DB=anexo_founder; ENVL=/etc/anexomail/local-pg.env
[ "$(id -u)" = 0 ] || { echo "FAIL: run as root"; exit 2; }
echo "== 1/6 packages (the cluster is NOT auto-created, so no TCP listener ever appears)"
mkdir -p /etc/postgresql-common
if [ -f /etc/postgresql-common/createcluster.conf ]; then sed -i 's/^#\?create_main_cluster.*/create_main_cluster = false/' /etc/postgresql-common/createcluster.conf; else echo "create_main_cluster = false" > /etc/postgresql-common/createcluster.conf; fi
export DEBIAN_FRONTEND=noninteractive
dpkg -s postgresql >/dev/null 2>&1 || apt-get install -y -qq postgresql postgresql-client >/dev/null
VER="$(ls /usr/lib/postgresql | sort -n | tail -1)"; echo "   postgresql major: $VER"
echo "== 2/6 cluster on a unix socket only"
if ! pg_lsclusters -h | awk '{print $1" "$2}' | grep -q "^$VER main$"; then
  pg_createcluster "$VER" main -o listen_addresses='' -o unix_socket_directories=/var/run/postgresql -o unix_socket_permissions=0770 >/dev/null
fi
CONF="/etc/postgresql/$VER/main/conf.d"; mkdir -p "$CONF"
cat > "$CONF/anexo.conf" <<CFG
# QCONNECT (20 Nov 2026): socket only, sized for his 15 GB server (service and cache share the RAM), slow-query log at 100 ms
listen_addresses = ''
unix_socket_directories = '/var/run/postgresql'
unix_socket_permissions = 0770
CFG
systemctl enable "postgresql@$VER-main" >/dev/null 2>&1 || true
pg_ctlcluster "$VER" main start >/dev/null 2>&1 || true
for W in $(seq 1 30); do pg_isready -q -h /var/run/postgresql && break; sleep 1; done
pg_isready -h /var/run/postgresql || { echo "FAIL: cluster not ready"; exit 1; }
# 21:15 FIX (his first run: Ubuntu 26.04 had auto-created the cluster on localhost:5432 and the conf.d file was not the winning setting): ALTER SYSTEM writes postgresql.auto.conf, which beats every other file.
for KV in "listen_addresses=''" "unix_socket_directories='/var/run/postgresql'" "unix_socket_permissions='0770'" "max_connections=80" "shared_buffers='2GB'" "effective_cache_size='8GB'" "work_mem='16MB'" "maintenance_work_mem='256MB'" "random_page_cost=1.1" "jit=off" "synchronous_commit=on" "log_min_duration_statement=100" "log_lock_waits=on" "password_encryption='scram-sha-256'"; do
  K="${KV%%=*}"; V="${KV#*=}"; su postgres -c "psql -X -q -At -c \"alter system set $K = $V\"" >/dev/null
done
systemctl restart "postgresql@$VER-main" 2>/dev/null || pg_ctlcluster "$VER" main restart
for W in $(seq 1 30); do pg_isready -q -h /var/run/postgresql && break; sleep 1; done
pg_isready -h /var/run/postgresql || { echo "FAIL: cluster not ready after restart"; exit 1; }
if ss -tlnp 2>/dev/null | grep -q postgres; then echo "FAIL: still a TCP listener after the fix; diagnosis:"; su postgres -c "psql -X -At -c \"select name||' = ['||setting||'] from '||coalesce(sourcefile,'default')||' ('||source||')' from pg_settings where name in ('listen_addresses','port','unix_socket_directories')\""; ss -tlnp | grep postgres; exit 1; fi
echo "== 3/6 owner role (root, superuser, peer auth over the socket) and the database"
su postgres -c "psql -X -At -c \"select 1 from pg_roles where rolname='root'\"" | grep -q 1 || su postgres -c "createuser -s root"
su postgres -c "psql -X -At -c \"select 1 from pg_database where datname='$DB'\"" | grep -q 1 || su postgres -c "createdb -O root -E UTF8 $DB"
echo "== 4/6 compat layer (roles anon/authenticated/service_role, schemas extensions/auth/storage, stubs)"
if [ -d "$REPO/.git" ]; then git -C "$REPO" fetch -q origin main 2>/dev/null || true; git -C "$REPO" show origin/main:docs/cursor-work/sql/QCONNECT_bootstrap.sql > /tmp/qconnect_bootstrap.sql; else echo "FAIL: no repo at $REPO"; exit 2; fi
psql -X -q -v ON_ERROR_STOP=1 -h /var/run/postgresql -d "$DB" -At -f /tmp/qconnect_bootstrap.sql | tail -1; rm -f /tmp/qconnect_bootstrap.sql
echo "== 5/6 env file for sql-run (a LOCAL file, the running service is NOT changed)"
mkdir -p /etc/anexomail; umask 077
printf 'WORKING_URL=postgresql://root@/%s?host=/var/run/postgresql\n' "$DB" > "$ENVL"; chmod 600 "$ENVL"
echo "== 6/6 proof"
psql -X -At -h /var/run/postgresql -d "$DB" -c "select 'server '||current_setting('server_version')||' | socket '||current_setting('unix_socket_directories')||' | listen ['||current_setting('listen_addresses')||']'"
psql -X -At -h /var/run/postgresql -d "$DB" -c "select 'roles '||string_agg(rolname, ',' order by rolname) from pg_roles where rolname in ('anon','authenticated','service_role')"
psql -X -At -h /var/run/postgresql -d "$DB" -c "select 'schemas '||string_agg(nspname, ',' order by nspname) from pg_namespace where nspname in ('auth','extensions','storage','public')"
if ss -tlnp 2>/dev/null | grep -q postgres; then echo "FAIL: a postgres TCP listener exists (must be none)"; ss -tlnp | grep postgres; exit 1; else echo "no postgres TCP listener: OK (socket only)"; fi
echo "DONE: PostgreSQL ready on the socket, empty. Next: the E-line through sql-run with ENV_FILE=$ENVL (his one line, given after this proof)."
