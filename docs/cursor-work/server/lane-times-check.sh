#!/usr/bin/env bash
# LA-7b proof helper (15 Nov 2026). READ-ONLY. Calls the same database function the Bridge uses (founder_bridge_lane_times) and prints only lane names and times, no key, no URL.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/lane-times-check.sh)
set -u
ENVF="${ENVF:-/etc/anexomail/founder.env}"
[ -r "$ENVF" ] || { echo "FAIL: $ENVF not readable (run as root)"; exit 2; }
. "$ENVF"
[ -n "${SUPABASE4_URL:-}" ] && [ -n "${SUPABASE4_SERVICE_ROLE_KEY:-}" ] || { echo "FAIL: database settings missing"; exit 2; }
echo "== now (UTC): $(date -u +%FT%TZ)"
echo "== founder_bridge_lane_times:"
curl -s -X POST -H "apikey: $SUPABASE4_SERVICE_ROLE_KEY" -H "authorization: Bearer $SUPABASE4_SERVICE_ROLE_KEY" -H "content-type: application/json" -d '{}' "$SUPABASE4_URL/rest/v1/rpc/founder_bridge_lane_times" | head -c 1500; echo
echo "OK read-only. Paste this whole output to Claude."
