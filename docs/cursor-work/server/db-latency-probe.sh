#!/usr/bin/env bash
# KP3 API latency audit, step D (15 Nov 2026). READ-ONLY. Changes nothing, writes only to /tmp, prints no key and no URL.
# Question it answers: is one database call slow by itself (~0.25 s), or do many calls AT THE SAME TIME queue up (the dashboard sends ~25 at once and the journal showed 0.6 s growing to 2.5 s)?
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/db-latency-probe.sh)
# It reads the table revenue_targets with limit=1 (the same kind of read the bridge does), 5 times one after another, then 8 at once, then 25 at once, and prints the times in ms.
set -u
ENVF="${ENVF:-/etc/anexomail/founder.env}"
[ -r "$ENVF" ] || { echo "FAIL: $ENVF not readable (run as root)"; exit 2; }
. "$ENVF"
[ -n "${SUPABASE4_URL:-}" ] && [ -n "${SUPABASE4_SERVICE_ROLE_KEY:-}" ] || { echo "FAIL: database settings missing in $ENVF"; exit 2; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
one() { curl -s -o /dev/null -w '%{time_total}' -H "apikey: $SUPABASE4_SERVICE_ROLE_KEY" -H "authorization: Bearer $SUPABASE4_SERVICE_ROLE_KEY" "$SUPABASE4_URL/rest/v1/revenue_targets?select=target_gbp&limit=1"; }
ms() { awk '{printf "%d\n", $1*1000}'; }
echo "== A one after another (5 calls), ms:"
for i in 1 2 3 4 5; do one | ms | tr -d "\n"; printf " "; done; echo
burst() { N=$1; rm -f "$T"/b.*; for i in $(seq 1 "$N"); do ( one | ms > "$T/b.$i" ) & done; wait; echo "== $N at the same time, ms (sorted):"; cat "$T"/b.* 2>/dev/null | sort -n | tr '\n' ' '; echo; }
burst 8
burst 25
echo "== same 25 again right after (connections now warm), ms (sorted):"
burst 25 | tail -1
echo "OK read-only probe done. Paste this whole output to Claude."
