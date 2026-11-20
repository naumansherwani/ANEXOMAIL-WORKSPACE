#!/usr/bin/env bash
# db-direct-probe.sh (20 Nov 2026): READ-ONLY. QSPEED step 4 fact: how far is the database ITSELF (not the REST front)? Prints dns + TCP connect time to db.<project>.supabase.co on 5432 and 6543.
# Writes nothing, prints no key, no full URL (project name masked). Needs only /etc/anexomail/founder.env for the host name.
set -u
ENVF=/etc/anexomail/founder.env
[ -r "$ENVF" ] || { echo "no $ENVF"; exit 1; }
set -a; . "$ENVF"; set +a
REF=$(echo "${SUPABASE4_URL:-}" | sed -E 's#https?://##; s#\..*##')
[ -n "$REF" ] || { echo "database url missing in env"; exit 1; }
for H in "db.$REF.supabase.co"; do
  echo "== host (masked): $(echo "$H" | sed -E 's/^db\.[a-z0-9]+\./db.X./')"
  echo "== A records: $(getent ahostsv4 "$H" | awk '{print $1}' | sort -u | tr '\n' ' ')"
  echo "== AAAA records: $(getent ahostsv6 "$H" | awk '{print $1}' | sort -u | head -1)"
  for P in 5432 6543; do
    for I in 1 2 3; do
      S=$(date +%s%N); if timeout 4 bash -c "exec 3<>/dev/tcp/$H/$P" 2>/dev/null; then E=$(date +%s%N); echo "tcp $P connect $(( (E-S)/1000000 )) ms"; else echo "tcp $P no connection (blocked or no IPv4 route)"; break; fi
    done
  done
done
echo "DONE: read-only, nothing changed."
