#!/usr/bin/env bash
# READ-ONLY (16 Nov 05:20): why did sql-run AUTO say "no new SQL"? Prints what his server sees. Changes nothing.
R=/opt/anexomail-web; L=/var/lib/anexomail/sql-applied.tsv
git -C $R fetch origin main 2>&1 | tail -2
echo "origin/main on this server: $(git -C $R log origin/main --oneline -1)"
echo "E177 file in origin/main: $(git -C $R ls-tree --name-only origin/main docs/cursor-work/sql/ | grep -c '^docs/cursor-work/sql/E177_')"
echo "E177 lines in ledger: $(grep -c '^E177_' $L 2>/dev/null)"
echo "last 3 ledger rows:"; tail -3 $L | cut -c1-90
