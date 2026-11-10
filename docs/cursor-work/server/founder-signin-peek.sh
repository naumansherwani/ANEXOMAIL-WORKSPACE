#!/usr/bin/env bash
# S2 (10 Nov 2026): READ-ONLY look at the founder sign-in ledger (E151/E152). Changes nothing. No secret is printed (the ledger holds none).
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-signin-peek.sh)
set -uo pipefail
ENV_FILE="${ENV_FILE:-/etc/anexomail/sync.env}"
[ -r "$ENV_FILE" ] || { echo "FAIL: $ENV_FILE nahi mila"; exit 2; }
. "$ENV_FILE" 2>/dev/null
[ -n "${WORKING_URL:-}" ] || { echo "FAIL: WORKING_URL khali hai"; exit 2; }
command -v psql >/dev/null || { echo "FAIL: psql nahi mila"; exit 2; }
echo "== last sign-in events (PKT, newest first)"
psql "$WORKING_URL" -X -At -F ' | ' -c "select to_char(to_timestamp(ts_ms / 1000.0) at time zone 'Asia/Karachi', 'DD Mon HH24:MI:SS'), kind, coalesce(facts ->> 'method', facts ->> 'why', facts ->> 'factor', '') from public.founder_signin_events order by ts_ms desc limit 8" 2>&1
echo "== last hand-offs (method | new network | risk | reasons)"
psql "$WORKING_URL" -X -At -F ' | ' -c "select to_char(released_at at time zone 'Asia/Karachi', 'DD Mon HH24:MI:SS'), method, new_net, risk, risk_reasons from public.founder_signin_handoffs order by released_at desc limit 3" 2>&1
echo "== ledger chain verifies"
psql "$WORKING_URL" -X -At -c "select public.founder_signin_verify(100000) ->> 'ok'" 2>&1
