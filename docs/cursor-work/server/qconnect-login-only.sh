#!/usr/bin/env bash
# qconnect-login-only.sh (21 Nov 2026, QCONNECT-LO). HIS FINAL WORD 02:00/02:11: ONLY the login (and what belongs to it) lives on his server; EVERYTHING ELSE is back on Supabase exactly as before QCONNECT; every advance technology stays.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/qconnect-login-only.sh) 2>&1 | tail -30
#   full rollback to Supabase for everything (old gotrue login):  OFF=1 bash <(...same script...)
# What it does, in order (any failure = the service is put back EXACTLY as it is now, local mode, nothing lost):
#   0 read-only checks (service healthy, managed database reachable, managed role may write the founder tables)
#   1 freeze: the founder service stops (awam is not touched)
#   2 back-copy: every founder-owned table where his server holds rows that Supabase does not have (written since the switch) is copied local -> Supabase,
#     one transaction per table, from a finished dump file (a broken read can never half-write Supabase), refused if Supabase has MORE rows than the server
#   3 sequences on Supabase lifted to max(column) for those tables (only up, never down)
#   4 re-hash both sides: every founder-owned table must be identical (founder_localid_events is login-only and stays on the server, never copied)
#   5 flag FOUNDER_DB=login, start, proof (healthz 200, me 401, bridge 401, journal line "database engine = REST (managed, data); identity engine = LOCAL")
# Login stays local: auth.users, auth.sessions, auth.refresh_tokens and founder_localid_events. His open session stays valid (same key lid1), no new sign-in is needed.
unset PGHOST PGPORT PGSERVICE PGDATABASE PGUSER
set -uo pipefail
S=${QSOCK:-/var/run/postgresql}; PORT=${QPORT:-5432}; LDB=${QLDB:-anexo_copy}; SVC=anexomail-founder; ENVF=${QENV:-/etc/anexomail/founder.env}; D=${QDIR:-/root/anexomail-backups}; KEY=/etc/anexomail/local-id.p8
URL="postgresql://$SVC@/$LDB?host=$S"; TEST=${TESTMODE:-}
LP() { psql -X -h "$S" -p "$PORT" -d "$LDB" ${QUSER:+-U $QUSER} "$@"; }
MP() { psql "$WORKING_URL" -X "$@"; }
svc() { [ -n "$TEST" ] || systemctl "$@"; }
health() { [ -n "$TEST" ] && return 0; for W in $(seq 1 40); do [ "$(curl -s -o /dev/null -w %{http_code} http://127.0.0.1:3210/healthz)" = 200 ] && return 0; sleep 1; done; return 1; }
if [ "${OFF:-}" = 1 ]; then sed -i '/^FOUNDER_DB=/d;/^FOUNDER_PG_URL=/d;/^FOUNDER_PG_POOL=/d;/^FOUNDER_ID_KEY_FILE=/d' "$ENVF"; svc restart $SVC; health && echo "ROLLBACK done: login AND data are back on Supabase (managed). Sign in once again. journal: $(journalctl -u $SVC -n 40 --no-pager | grep -o 'database engine = [A-Za-z ]*' | tail -1)"; exit 0; fi
. /etc/anexomail/sync.env 2>/dev/null; [ -n "${WORKING_URL:-}" ] || { echo "FAIL: WORKING_URL missing"; exit 2; }
umask 077; mkdir -p "$D"
echo "== 0/5 read-only checks"
health || { echo "FAIL: founder service is not healthy now; nothing changed"; exit 2; }
[ "$(MP -At -c 'select 1' 2>&1 | tail -1)" = 1 ] || { echo "FAIL: Supabase database not reachable from this server; nothing changed"; exit 2; }
# can the managed role skip triggers for the copy? (tested inside a transaction that is rolled back: changes nothing)
[ "$(MP -At -c 'begin; set local session_replication_role = replica; select current_setting($$session_replication_role$$); rollback' 2>&1 | grep -x replica | head -1)" = replica ] || { echo "FAIL: the Supabase role may not run set session_replication_role = replica, so the append-only ledgers cannot be copied back; nothing changed. Tell Claude."; exit 2; }
TABLES="$(LP -At -c "select c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r' and c.relname ~ '^(founder_|fmail_|qt_|revenue_|mail_)' and c.relname <> 'founder_localid_events' order by 1")"
[ -n "$TABLES" ] && [ "$(echo "$TABLES" | wc -l)" -ge "${QMIN:-50}" ] || { echo "FAIL: the founder table list on the server is empty or too short (the server database did not answer); nothing changed"; exit 2; }
cp -p "$ENVF" "$D/founder.env.before-login" 2>/dev/null
# if this script is killed while the service is stopped, the EXIT trap starts it again exactly as it was (local mode)
trap 'svc is-active --quiet $SVC || { [ -f "$D/founder.env.before-login" ] && cp -p "$D/founder.env.before-login" "$ENVF"; svc start $SVC; }' EXIT
fail() { echo "FAIL: $1 -> service put back exactly as before (local mode); Supabase tables already copied stay (they only gained rows)"; [ -z "$TEST" ] && cp -p "$D/founder.env.before-login" "$ENVF"; svc restart $SVC; health && echo "   service back as before"; exit 5; }
echo "== 1/5 freeze: founder service stopped (founder site is down for a short moment, awam untouched)"
svc stop $SVC
HQ() { echo "select count(*)||' '||coalesce(md5(string_agg(md5(t::text), '' order by md5(t::text))),'empty') from public.$1 t"; }
echo "== 2/5 back-copy of the tables Supabase does not have yet"
COPIED=""; N=0
for T in $TABLES; do
  A="$(LP -At -c "$(HQ $T)" 2>&1 | tail -1)"; B="$(MP -At -c "$(HQ $T)" 2>&1 | tail -1)"
  case "$A" in [0-9]*" "*) ;; *) fail "the server database did not answer for $T ($A)";; esac
  [ "$A" = "$B" ] && continue
  case "$B" in ERROR*|psql*|"") echo "   skip $T: not readable on Supabase ($B)"; continue;; esac
  if ! [ "${B%% *}" -le "${A%% *}" ] 2>/dev/null; then
    # 21 Nov 03:20 (his paste: founder_dbsc_jti Supabase 147 vs server 144): the server PRUNES expiring tables, so Supabase can hold more old rows. Only a table with an append-only DELETE guard (a ledger) must never lose a row: that one is refused.
    PROT="$(LP -At -c "select count(*) from pg_trigger where tgrelid='public.$T'::regclass and not tgisinternal and tgenabled<>'D' and (tgtype & 8)=8" 2>&1 | tail -1)"
    [ "${PROT:-1}" = 0 ] || fail "Supabase has MORE rows than the server in the append-only table $T (${B%% *} vs ${A%% *}); refused to overwrite (integrity alarm)"
    echo "   note $T: Supabase had ${B%% *} rows, server ${A%% *}: the server prunes this table (no append-only guard), the server copy wins"
  fi
  LP -q -c "copy public.$T to stdout" > "$D/lo-$T.copy" 2>"$D/lo.err" || { head -3 "$D/lo.err"; fail "read of $T on the server"; }
  { echo "set session_replication_role = replica; delete from only public.$T; copy public.$T from stdin;"; cat "$D/lo-$T.copy"; echo '\.'; } | MP -q -1 -v ON_ERROR_STOP=1 -f - >/dev/null 2>"$D/lo.err" || { head -3 "$D/lo.err"; fail "write of $T to Supabase"; }
  rm -f "$D/lo-$T.copy"; COPIED="$COPIED,$T"; N=$((N+1)); echo "   copied $T (server ${A%% *} rows, Supabase had ${B%% *})"
done
echo "   tables copied: $N"
echo "== 3/5 sequences on Supabase lifted for the copied tables (only up)"
if [ -n "$COPIED" ]; then
  { echo "set app.t = '${COPIED#,}';"; cat <<'SQL'
do $$ declare r record; m bigint; cur bigint; begin
  for r in select s.seq, a.attname, n.nspname, c.relname from (select d.objid::regclass::text seq, d.refobjid, d.refobjsubid from pg_depend d join pg_class sc on sc.oid=d.objid and sc.relkind='S' where d.deptype in ('a','i') and d.refclassid='pg_class'::regclass) s
    join pg_class c on c.oid=s.refobjid join pg_namespace n on n.oid=c.relnamespace join pg_attribute a on a.attrelid=c.oid and a.attnum=s.refobjsubid
    where n.nspname='public' and c.relname = any(string_to_array(current_setting('app.t'), ',')) loop
    execute format('select coalesce(max(%I),0) from %I.%I', r.attname, r.nspname, r.relname) into m;
    execute format('select last_value from %s', r.seq) into cur;
    if m > cur then perform setval(r.seq, m); end if;
  end loop; end $$;
SQL
  } | MP -q -v ON_ERROR_STOP=1 -f - >/dev/null 2>"$D/lo.err" || { head -3 "$D/lo.err"; fail "sequence lift on Supabase"; }
fi
echo "== 4/5 re-hash both sides (every founder-owned table must now be identical)"
BAD=0
for T in $TABLES; do A="$(LP -At -c "$(HQ $T)" 2>&1 | tail -1)"; B="$(MP -At -c "$(HQ $T)" 2>&1 | tail -1)"; case "$A" in [0-9]*" "*) ;; *) A="UNREADABLE";; esac; [ "$A" = "$B" ] || { echo "   MISMATCH $T server=${A%% *} supabase=${B%% *}"; BAD=$((BAD+1)); }; done
echo "   founder-owned mismatches: $BAD"; [ $BAD -eq 0 ] || fail "a founder table still differs after the copy"
echo "== 5/5 flag login-only, start, proof"
if [ -z "$TEST" ]; then
  sed -i '/^FOUNDER_DB=/d;/^FOUNDER_PG_URL=/d;/^FOUNDER_PG_POOL=/d;/^FOUNDER_ID_KEY_FILE=/d' "$ENVF"
  [ -n "$(tail -c1 "$ENVF")" ] && echo >>"$ENVF"
  { echo "FOUNDER_DB=login"; echo "FOUNDER_PG_URL=$URL"; echo "FOUNDER_PG_POOL=4"; echo "FOUNDER_ID_KEY_FILE=$KEY"; } >>"$ENVF"
  systemctl restart $SVC; health || fail "service did not answer"
  H=$(curl -s -o /dev/null -w %{http_code} http://127.0.0.1:3210/healthz); M2=$(curl -s -o /dev/null -w %{http_code} http://127.0.0.1:3210/founder/v1/me); B=$(curl -s -o /dev/null -w %{http_code} http://127.0.0.1:3210/founder/v1/bridge)
  sleep 2; ENG=$(journalctl -u $SVC --since=-3min --no-pager | grep -o 'database engine = REST (managed, data); identity engine = LOCAL' | tail -1)
  [ -n "$ENG" ] || { echo "   service lines about the database (journal):"; journalctl -u $SVC --since=-3min --no-pager | grep -i -e FOUNDER_DB -e "staying on REST" -e identity -e engine | tail -5 | cut -c1-220 | sed 's/^/   /'; }
  echo "   healthz=$H (200) me=$M2 (401) bridge=$B (401) | journal: ${ENG:-MISSING}"
  { [ "$H" = 200 ] && [ "$M2" = 401 ] && [ "$B" = 401 ] && [ -n "$ENG" ]; } || fail "proof failed (engine line or door status)"
fi
trap - EXIT
echo "OK: LOGIN is on his server (PostgreSQL socket, bcrypt, ES256 kid lid1); ALL DATA is on Supabase again. His open session stays valid. Rollback of everything: OFF=1 with this same script. Next: my Chrome look."
