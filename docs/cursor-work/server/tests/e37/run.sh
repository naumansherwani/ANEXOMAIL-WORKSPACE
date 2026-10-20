#!/usr/bin/env bash
# E37 self-test: 4 haalat. Kharab (stray) haal mein file FAIL honi chahiye, baqi mein pass.
set -u
P="psql -h /var/run/postgresql -U postgres -q"; F="$(cd "$(dirname "$0")/../../../sql" && pwd)/E37_mail_ingest_no_stray_org.sql"; H="$(cd "$(dirname "$0")" && pwd)"
run() { # $1=label $2=mode $3=seed-sql $4=expect(pass|fail)
  $P -c "drop database if exists e37" -c "create database e37" 2>/dev/null; $P -d e37 -v ON_ERROR_STOP=1 -f "$H/stubs.sql" >/dev/null 2>&1
  $P -d e37 -c "update public.stub_cfg set mode='$2'" -c "$3" >/dev/null 2>&1
  out="$($P -d e37 -v ON_ERROR_STOP=1 -f "$F" 2>&1)"; rc=$?
  if [ "$4" = pass ] && [ $rc -eq 0 ]; then echo "OK   $1"; elif [ "$4" = fail ] && [ $rc -ne 0 ]; then echo "OK   $1 (file ne sahi fail kiya: $(echo "$out" | grep -o 'E37 SELFTEST FAIL[^(]*' | head -1))"; else echo "BAD  $1 rc=$rc"; echo "$out" | tail -5; ST=1; fi
}
ST=0
O1=11111111-1111-1111-1111-111111111111; O2=22222222-2222-2222-2222-222222222222
run "ek org, normal"                 normal      "insert into public.mailboxes(address,org_id) values ('a@anexomail.com','$O1')" pass
run "pata do orgs mein, pehle owner" normal      "insert into public.mailboxes(address,org_id) values ('f@anexomail.com','$O1'),('f@anexomail.com','$O2')" pass
run "pata do orgs mein, doosra owner (purana test yahan fail hota tha)" other_owner "insert into public.mailboxes(address,org_id) values ('f@anexomail.com','$O1'),('f@anexomail.com','$O2')" pass
run "BUG: mail kisi aur org mein"    stray       "insert into public.mailboxes(address,org_id) values ('a@anexomail.com','$O1')" fail
exit $ST
