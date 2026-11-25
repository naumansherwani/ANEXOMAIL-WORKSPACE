cd /home/claude/anexomail-workspace/docs/claude/admin-desk/sql
Q(){ su postgres -c "psql -X -q -d ad35t $*" 2>&1; }
okc(){ ! echo "$1" | grep -qE '\| f( |$)|ERROR' && echo "$1" | grep -qE '\| t( |$)'; }
for f in $(ls AD*.sql | sed 's/\.sql//' | sort -V); do
  head -5 $f.sql | grep -q 'TARGET-DB: AWAM' && continue
  if [ -f checks/$f-check.sql ]; then R=$(Q "-f $PWD/checks/$f-check.sql"); okc "$R" && { echo "$f: already run, skipped"; continue; }; fi
  O=$(Q "-v ON_ERROR_STOP=1 -f $PWD/$f.sql" | grep -v NOTICE)
  if echo "$O" | grep -q ERROR; then echo "$f: FAILED: $(echo "$O" | grep ERROR | head -1 | cut -c1-160)"; continue; fi
  if [ -f checks/$f-check.sql ]; then R=$(Q "-f $PWD/checks/$f-check.sql"); okc "$R" && echo "$f: run and CHECK OK" || { echo "$f: CHECK FALSE"; echo "$R" | grep -E "\| f( |$)" | cut -c1-150; }; else echo "$f: run (no check)"; fi
done
