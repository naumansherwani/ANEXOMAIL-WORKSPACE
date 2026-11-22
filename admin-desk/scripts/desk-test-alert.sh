#!/usr/bin/env bash
# ANEXOMAIL ADMIN DESK D2 LIVE PROOF (his 22 Nov 2026 08:56: "codes aye hain server pe toh green mark kero"). Raises ONE clearly labelled TEST alert (severity notice, so no red P1 pulse)
# through the Desk's own SQL function desk.fadm_alert_raise, so Claude can press Acknowledge and Resolve on it in live Chrome. Reversible: the test alert is closed again from the Alerts page.
# Uses the Desk's own env file /etc/anexomail-desk/db.env (root-only). Writes exactly one alert row, nothing else.
set -uo pipefail
ENVF=/etc/anexomail-desk/db.env
[ -r "$ENVF" ] || { echo "FAIL: $ENVF is missing"; exit 2; }
. "$ENVF"; [ -n "${DESK_DB_URL:-}" ] || { echo "FAIL: DESK_DB_URL is empty"; exit 2; }
command -v psql >/dev/null || { echo "FAIL: psql not found"; exit 2; }
ID="$(env -u PGHOST -u PGPORT -u PGUSER -u PGDATABASE -u PGSERVICE psql "$DESK_DB_URL" -X -q -t -A -P pager=off -c "select desk.fadm_alert_raise('selftest', 'notice', 'live.proof.d2', NULL, '{\"note\":\"D2 live proof, TEST alert, safe to close\"}'::jsonb, 'd2-live-proof-$(date +%s)')" 2>&1)"
case "$ID" in ''|*[!0-9]*) echo "FAIL: could not raise the test alert: $ID"; exit 1;; esac
echo "OK: test alert #$ID raised (severity notice). Open Alerts in the Desk; Claude will press Acknowledge and Resolve."
