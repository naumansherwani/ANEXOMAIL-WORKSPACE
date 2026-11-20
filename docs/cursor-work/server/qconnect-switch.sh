#!/usr/bin/env bash
# qconnect-switch.sh (21 Nov 2026, QCONNECT step 8b). THE SWITCH: founder service -> local PostgreSQL (unix socket). REST stays the fallback for ever.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/qconnect-switch.sh) 2>&1 | tail -30
#   rollback alone:  OFF=1 bash <(...same script...)
unset PGHOST PGPORT PGSERVICE PGDATABASE PGUSER
set -uo pipefail
S=/var/run/postgresql; SVC=anexomail-founder; ENVF=/etc/anexomail/founder.env; D=/root/anexomail-backups; KEY=/etc/anexomail/local-id.p8; DRIFT=$D/switch-drift.txt
URL="postgresql://$SVC@/anexo_copy?host=$S"
off() { sed -i '/^FOUNDER_DB=/d;/^FOUNDER_PG_URL=/d;/^FOUNDER_PG_POOL=/d;/^FOUNDER_ID_KEY_FILE=/d' "$ENVF"; systemctl restart $SVC; }
health() { for W in $(seq 1 40); do [ "$(curl -s -o /dev/null -w %{http_code} http://127.0.0.1:3210/healthz)" = 200 ] && return 0; sleep 1; done; return 1; }
if [ "${OFF:-}" = 1 ]; then off; health && echo "ROLLBACK done: founder service back on REST (managed). journal: $(journalctl -u $SVC -n 40 --no-pager | grep -o 'database engine = [A-Za-z ]*' | tail -1)"; exit 0; fi
. /etc/anexomail/sync.env 2>/dev/null; [ -n "${WORKING_URL:-}" ] || { echo "FAIL: WORKING_URL missing"; exit 2; }
[ -s "$KEY" ] && [ -f "$DRIFT" ] || { echo "FAIL: run qconnect-switch-prep.sh first (key / drift list missing)"; exit 2; }
[ $(( $(date +%s) - $(stat -c %Y "$DRIFT") )) -lt 7200 ] || { echo "FAIL: drift list older than 2 hours, run qconnect-switch-prep.sh again"; exit 2; }
health || { echo "FAIL: founder service is not healthy now; nothing changed"; exit 2; }
echo "== 1/5 freeze: founder service stopped (site of the founder is down during the copy, awam untouched)"
systemctl stop $SVC
fail() { echo "FAIL: $1 -> rollback to REST"; off; health && echo "   service back on REST"; exit 5; }
echo "== 2/5 copy the drifted tables (one local transaction each; managed side read only)"
N=0; while read -r T; do [ -n "$T" ] || continue
  { echo "set session_replication_role = replica; delete from only $T; copy $T from stdin;"; psql "$WORKING_URL" -X -q -c "copy $T to stdout"; echo '\.'; } | psql -X -h $S -d anexo_copy -q -1 -v ON_ERROR_STOP=1 -f - >/dev/null 2>"$D/sw-copy.err" || { head -3 "$D/sw-copy.err"; fail "copy of $T"; }
  N=$((N+1)); done < <(sort -u "$DRIFT")
echo "   tables copied: $N"
echo "== 3/5 sequences reset to max(column)"
psql -X -h $S -d anexo_copy -q -v ON_ERROR_STOP=1 <<'SQL' || fail "sequence reset"
do $$ declare r record; begin
  for r in select format('select setval(%L, greatest(coalesce((select max(%I) from %I.%I),0),1))', s.seq, a.attname, n.nspname, c.relname) q
    from (select d.objid::regclass::text seq, d.refobjid, d.refobjsubid from pg_depend d join pg_class sc on sc.oid=d.objid and sc.relkind='S' where d.deptype in ('a','i') and d.refclassid='pg_class'::regclass) s
    join pg_class c on c.oid=s.refobjid join pg_namespace n on n.oid=c.relnamespace join pg_attribute a on a.attrelid=c.oid and a.attnum=s.refobjsubid
    where n.nspname in ('public','auth') loop execute r.q; end loop; end $$;
SQL
echo "== 4/5 re-hash the copied tables on both sides (founder-owned prefixes must match; others are only warned)"
BAD=0; WARN=0
while read -r T; do [ -n "$T" ] || continue
  Q="select count(*), coalesce(md5(string_agg(md5(t::text), '' order by md5(t::text))), 'empty') from $T t"
  L=$(psql -X -h $S -d anexo_copy -At -F ' ' -c "$Q" 2>&1 | tail -1); M=$(psql "$WORKING_URL" -X -At -F ' ' -c "$Q" 2>&1 | tail -1)
  if [ "$L" != "$M" ]; then case "${T#*.}" in founder_*|fmail_*|qt_*|revenue_*|mail_*) echo "   MISMATCH (founder-owned) $T local=$L managed=$M"; BAD=$((BAD+1));; *) echo "   warn (written by others after the copy) $T local=${L%% *} managed=${M%% *}"; WARN=$((WARN+1));; esac; fi; done < <(sort -u "$DRIFT")
echo "   founder-owned mismatches: $BAD, warnings: $WARN"; [ $BAD -eq 0 ] || fail "founder-owned table differs after the copy"
echo "== 5/5 flag on, start, proof"
off >/dev/null 2>&1; systemctl stop $SVC
{ echo "FOUNDER_DB=local"; echo "FOUNDER_PG_URL=$URL"; echo "FOUNDER_PG_POOL=16"; echo "FOUNDER_ID_KEY_FILE=$KEY"; } >>"$ENVF"
systemctl restart $SVC; health || fail "service did not answer"
H=$(curl -s -o /dev/null -w %{http_code} http://127.0.0.1:3210/healthz); M2=$(curl -s -o /dev/null -w %{http_code} http://127.0.0.1:3210/founder/v1/me); B=$(curl -s -o /dev/null -w %{http_code} http://127.0.0.1:3210/founder/v1/bridge)
ENG=$(journalctl -u $SVC -n 60 --no-pager | grep -o 'database engine = [A-Za-z ]*' | tail -1)
echo "   healthz=$H (200) me=$M2 (401) bridge=$B (401) | journal: $ENG"
{ [ "$H" = 200 ] && [ "$M2" = 401 ] && [ "$B" = 401 ] && echo "$ENG" | grep -q LOCAL; } || fail "proof failed (engine line or door status)"
echo "OK: the founder service now reads and writes LOCAL PostgreSQL. REST stays the fallback. Rollback: OFF=1 with this same script. Next: sign in once, then step 9 db-latency-check."
