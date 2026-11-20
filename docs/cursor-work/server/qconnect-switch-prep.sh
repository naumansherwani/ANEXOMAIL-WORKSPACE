#!/usr/bin/env bash
# qconnect-switch-prep.sh (21 Nov 2026, QCONNECT step 8a). Changes NOTHING in the running service or the managed database (managed = read only).
# Local only: (1) login role "anexomail-founder" (peer auth on the socket, no superuser, only member of service_role), (2) the identity key file, (3) smoke test AS the service user, (4) drift list (managed vs anexo_copy, count + md5 per table).
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/qconnect-switch-prep.sh) 2>&1 | tail -30
unset PGHOST PGPORT PGSERVICE PGDATABASE PGUSER
set -uo pipefail
. /etc/anexomail/sync.env 2>/dev/null; [ -n "${WORKING_URL:-}" ] || { echo "FAIL: WORKING_URL missing"; exit 2; }
S=/var/run/postgresql; SU=anexomail-founder; KEY=/etc/anexomail/local-id.p8; D=/root/anexomail-backups; umask 077; mkdir -p "$D"
id "$SU" >/dev/null 2>&1 || { echo "FAIL: OS user $SU missing (founder-install creates it)"; exit 2; }
echo "== 0/4 socket door: the socket is 0770 (his hardening, step 3), so the service user needs the socket GROUP (dedicated group anexopg, nobody else gets in; the data directory stays 0700)"
VER="$(ls /usr/lib/postgresql | sort -n | tail -1)"
AUTO="$(ls /var/lib/postgresql/$VER/main/postgresql.auto.conf 2>/dev/null | head -1)"
restart_pg() { systemctl restart "postgresql@$VER-main" 2>/dev/null || pg_ctlcluster "$VER" main restart; for W in $(seq 1 15); do pg_isready -h $S >/dev/null && return 0; sleep 1; done; return 1; }
undo_group() { [ -n "$AUTO" ] && sed -i "/^unix_socket_group/d" "$AUTO"; restart_pg; }
getent group anexopg >/dev/null || groupadd --system anexopg
# PostgreSQL may only chown its socket to a group the postgres OS user belongs to (his 00:25 paste: restart failed without it)
for U in postgres "$SU"; do id -nG "$U" | tr ' ' '\n' | grep -qx anexopg || usermod -aG anexopg "$U"; done
if ! pg_isready -h $S >/dev/null; then echo "   cluster was DOWN from the last failed restart: removing the group line and starting it"; undo_group || { echo "FAIL: cluster still down; log:"; tail -15 /var/log/postgresql/postgresql-$VER-main.log; exit 2; }; fi
CUR="$(psql -X -h $S -d postgres -At -c "show unix_socket_group")"
if [ "$CUR" != anexopg ]; then
  psql -X -h $S -d postgres -At -c "alter system set unix_socket_group = 'anexopg'" >/dev/null
  if ! restart_pg; then echo "   restart with the group FAILED, log tail:"; tail -8 /var/log/postgresql/postgresql-$VER-main.log; undo_group; echo "FAIL: group door not possible, cluster restored without it (socket unchanged)"; exit 2; fi
fi
pg_isready -h $S >/dev/null || { echo "FAIL: cluster not ready after the group change"; exit 2; }
echo "   socket: $(ls -l $S/.s.PGSQL.5432 | awk '{print $1, $3, $4}'), unix_socket_group=$(psql -X -h $S -d postgres -At -c "show unix_socket_group"), $SU groups: $(id -nG $SU)"
echo "   listeners (must be none): $(ss -tlnp 2>/dev/null | grep -c postgres)"
echo "== 1/4 login role $SU (local database only)"
psql -X -h $S -d postgres -q -v ON_ERROR_STOP=1 <<SQL || { echo "FAIL: role"; exit 3; }
do \$\$ begin
  if not exists (select 1 from pg_roles where rolname = '$SU') then create role "$SU" login nosuperuser nocreatedb nocreaterole noinherit; end if;
end \$\$;
grant service_role to "$SU";
grant connect on database anexo_copy to "$SU";
SQL
# his 00:27 paste: "permission denied for table founder_accounts". pg_copy used pg_dump --no-privileges, so the copy has NO grants. service_role (the only role the service uses; anon/authenticated are never given anything here, fail-closed) gets what the managed project gave it.
psql -X -h $S -d anexo_copy -q -v ON_ERROR_STOP=1 <<'SQL' || { echo "FAIL: grants"; exit 3; }
grant usage on schema public, auth, storage, extensions to service_role;
grant all on all tables in schema public, auth, storage to service_role;
grant all on all sequences in schema public, auth, storage to service_role;
grant execute on all functions in schema public, auth, storage, extensions to service_role;
SQL
echo "   service_role grants on anexo_copy: tables $(psql -X -h $S -d anexo_copy -At -c "select count(*) from information_schema.role_table_grants where grantee='service_role' and table_schema='public'")"
echo "   role ok: $(psql -X -h $S -d postgres -At -c "select rolsuper::text||' super, member of '||(select string_agg(b.rolname,',') from pg_auth_members m join pg_roles b on b.oid=m.roleid where m.member=r.oid) from pg_roles r where rolname='$SU'")"
echo "== 2/4 identity key file $KEY"
# 21 Nov 2026 01:30 PKT ROOT CAUSE of the failed proof (found in the sandbox, not guessed): the key file must be DER PKCS#8 WITH the public key (138 bytes). `openssl genpkey -out` wrote PEM text (and without the public key it is 121 bytes) and ring refuses both, so the service said "identity key not usable" and stayed on REST. This key was made tonight and never used, so replacing it is safe.
mkkey() { openssl ecparam -name prime256v1 -genkey -noout 2>/dev/null | openssl pkcs8 -topk8 -nocrypt -outform DER -out "$KEY.new" 2>/dev/null && [ "$(stat -c %s "$KEY.new")" = 138 ] && mv "$KEY.new" "$KEY" && chown root:$SU "$KEY" && chmod 640 "$KEY"; }
if [ "$(stat -c %s "$KEY" 2>/dev/null)" = 138 ]; then echo "   exists, DER PKCS#8 138 bytes (kept)"; else mkkey && echo "   created: DER PKCS#8 with public key, 138 bytes (the old file was the wrong format)" || { echo "FAIL: key"; exit 3; }; fi
chown root:$SU "$KEY"; chmod 640 "$KEY"; ls -l "$KEY" | awk '{print "   " $1, $3, $4}'
echo "== 3/4 smoke test AS the service user over the socket (the same way the service connects)"
OUT=$(runuser -u $SU -- psql -X -h $S -d anexo_copy -At -c "set role service_role" -c "select 'founder_accounts rows: '||count(*) from public.founder_accounts" -c "select 'localid_verify: '||public.localid_verify()::text" 2>&1 | head -6)
echo "$OUT" | sed 's/^/   /'
echo "$OUT" | grep -q "founder_accounts rows" || { echo "FAIL: service user cannot read over the socket (peer auth?). hba:"; grep -vE '^\s*(#|$)' $(psql -X -h $S -d postgres -At -c "show hba_file") | head -8; exit 4; }
echo "== 4/4 drift list (read only, managed side slow, a few minutes)"
GEN="select format('select %L, count(*), coalesce(md5(string_agg(md5(t::text), %L order by md5(t::text))), %L) from %I.%I t', table_schema||'.'||table_name, '', 'empty', table_schema, table_name) from information_schema.tables where table_schema in ('public','auth','storage') and table_type='BASE TABLE' order by 1"
psql -X -h $S -d anexo_copy -At -F ' ' <<SQL >"$D/sw-local.txt" 2>"$D/sw-local.err"
$GEN \gexec
SQL
psql "$WORKING_URL" -X -At -F ' ' <<SQL >"$D/sw-managed.txt" 2>"$D/sw-managed.err"
$GEN \gexec
SQL
join -j1 <(sort "$D/sw-local.txt") <(sort "$D/sw-managed.txt") | awk '$2!=$4 || $3!=$5 {print $1}' >"$D/switch-drift.txt"
echo "   tables hashed: local $(wc -l <"$D/sw-local.txt"), managed $(wc -l <"$D/sw-managed.txt"); DRIFT tables: $(wc -l <"$D/switch-drift.txt")"
sed 's/^/   drift: /' "$D/switch-drift.txt" | head -40
echo "DONE. Nothing switched. Drift list: $D/switch-drift.txt (the switch accepts it for 2 hours). Next: qconnect-switch.sh"
