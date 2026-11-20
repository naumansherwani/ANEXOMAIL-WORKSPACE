#!/usr/bin/env bash
# qconnect-switch-prep.sh (21 Nov 2026, QCONNECT step 8a). Changes NOTHING in the running service or the managed database (managed = read only).
# Local only: (1) login role "anexomail-founder" (peer auth on the socket, no superuser, only member of service_role), (2) the identity key file, (3) smoke test AS the service user, (4) drift list (managed vs anexo_copy, count + md5 per table).
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/qconnect-switch-prep.sh) 2>&1 | tail -30
unset PGHOST PGPORT PGSERVICE PGDATABASE PGUSER
set -uo pipefail
. /etc/anexomail/sync.env 2>/dev/null; [ -n "${WORKING_URL:-}" ] || { echo "FAIL: WORKING_URL missing"; exit 2; }
S=/var/run/postgresql; SU=anexomail-founder; KEY=/etc/anexomail/local-id.p8; D=/root/anexomail-backups; umask 077; mkdir -p "$D"
pg_isready -h $S >/dev/null || { echo "FAIL: local cluster not ready"; exit 2; }
id "$SU" >/dev/null 2>&1 || { echo "FAIL: OS user $SU missing (founder-install creates it)"; exit 2; }
echo "== 1/4 login role $SU (local database only)"
psql -X -h $S -d postgres -q -v ON_ERROR_STOP=1 <<SQL || { echo "FAIL: role"; exit 3; }
do \$\$ begin
  if not exists (select 1 from pg_roles where rolname = '$SU') then create role "$SU" login nosuperuser nocreatedb nocreaterole noinherit; end if;
end \$\$;
grant service_role to "$SU";
grant connect on database anexo_copy to "$SU";
SQL
psql -X -h $S -d anexo_copy -q -c "grant usage on schema public, auth, extensions to service_role" >/dev/null 2>&1
echo "   role ok: $(psql -X -h $S -d postgres -At -c "select rolsuper::text||' super, member of '||(select string_agg(b.rolname,',') from pg_auth_members m join pg_roles b on b.oid=m.roleid where m.member=r.oid) from pg_roles r where rolname='$SU'")"
echo "== 2/4 identity key file $KEY"
if [ -s "$KEY" ]; then echo "   exists (kept, never replaced)"; else
  openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out "$KEY" 2>/dev/null && echo "   created (P-256 PKCS8)" || { echo "FAIL: openssl"; exit 3; }; fi
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
