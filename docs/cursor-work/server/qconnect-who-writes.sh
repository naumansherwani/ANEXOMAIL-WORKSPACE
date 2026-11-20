#!/usr/bin/env bash
# qconnect-who-writes.sh (21 Nov 2026, QCONNECT step 8 survey). READ-ONLY. WHY: before the founder service switches to the local database, every OTHER program that writes the managed database must be known, else mail delivered by them lands in the managed copy while the founder reads the local one (split brain). Prints only unit names, env file paths and the DATABASE HOST of SUPABASE_URL (never a key, never a password).
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/qconnect-who-writes.sh) 2>&1 | tail -40
unset PGHOST PGPORT PGSERVICE PGDATABASE PGUSER
echo "== 1/3 systemd units (running or timers) that name an env file"
for U in $(systemctl list-units --type=service --type=timer --all --no-legend 2>/dev/null | awk '{print $1}' | grep -i -E 'anexo|founder|awam|deliver|mail|brain|sync|chat' ); do
  E=$(systemctl show "$U" -p EnvironmentFile --value 2>/dev/null | sed 's/ (ignore_errors=[a-z]*)//' | tr '\n' ' ')
  A=$(systemctl is-active "$U" 2>/dev/null)
  X=$(systemctl show "$U" -p ExecStart --value 2>/dev/null | sed -n 's/.*path=\([^ ;]*\).*/\1/p' | head -1)
  H=""
  for F in $E; do [ -r "$F" ] && H="$H $(basename $F):$(grep -h -E '^(SUPABASE_URL|FOUNDER_DB|WORKING_URL)=' "$F" 2>/dev/null | sed -E 's/^([A-Z_]+)=["'"'"']?(https?:\/\/)?([^\/"'"'"'@]*@)?([^\/"'"'"':?]*).*/\1=\4/' | tr '\n' ',')"; done
  echo "   $U [$A] bin=$X env:${H:- none}"
done
echo "== 2/3 cron entries naming the database"
grep -l -E 'supabase|SUPABASE' /etc/cron.d/* /etc/cron.daily/* 2>/dev/null | sed 's/^/   /'
echo "== 3/3 listening processes that hold a connection to a database port (5432/6543/443 outbound to the managed host are normal; this lists the program names only)"
ss -tnp 2>/dev/null | awk '$5 ~ /:(5432|6543)$/ {print $6}' | sed -E 's/.*users:\(\("([^"]+)".*/\1/' | sort | uniq -c | sed 's/^/   /'
echo "DONE (read only, nothing changed)."
