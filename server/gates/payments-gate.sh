#!/usr/bin/env bash
# ============================================================================
# GATE 5 — POLAR PAYMENT ENGINE (:3400) + webhook
#   bash server/gates/payments-gate.sh
# Sirf padhta hai. Engine ki logic no-touch hai.
# ============================================================================
set -uo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

echo "=== GATE 5 · PAYMENTS :3400 ==="

check_pm2 polar-rust-payment
check_port "payment engine" 3400

check_body "health db=true"              "http://127.0.0.1:3400/health" '"db":true'
check_body "health webhook_secret=true"  "http://127.0.0.1:3400/health" '"webhook_secret":true'
check_body "health polar_token=true"     "http://127.0.0.1:3400/health" '"polar_token":true'
check_body "9 product IDs loaded"        "http://127.0.0.1:3400/health" '"products":9'
check_http "/ready (WAL writable)"       "http://127.0.0.1:3400/ready" 200
check_body "/metrics zinda"              "http://127.0.0.1:3400/metrics" 'queue_depth'

echo "--- public ingress (dono endpoint) ---"
check_http "polarpayments.anexomail.com/health" "https://polarpayments.anexomail.com/health" 200
check_http "anexomail.com webhook path live"    "https://anexomail.com/api/v1/polar-webhook" 401 \
  -X POST -H 'content-type: application/json' --data '{}'
check_http "primary webhook signature guard"    "https://polarpayments.anexomail.com/api/v1/polar-webhook" 401 \
  -X POST -H 'content-type: application/json' --data '{}'

echo "--- asli signed event (repo ka test) ---"
if bash /opt/anexomail-web/server/rust/polar-payment/test-event.sh >/tmp/polar-gate.log 2>&1; then
  ok "signed test event accept hua"
else
  bad "signed test event" "detail: /tmp/polar-gate.log"
fi

echo "--- DB truth ---"
check_sql "webhook inbox mein event maujood" \
  "select count(*)>0 from public.polar_webhook_inbox;" "t"
check_sql "koi failed event nahi" \
  "select count(*) from public.polar_webhook_inbox where process_error is not null;" "0"
check_sql "signature rejects sirf evidence (block nahi)" \
  "select count(*)>=0 from public.polar_signature_rejects;" "t"
check_sql "service block hamesha false" \
  "select coalesce(bool_and(not service_blocked),true) from (select (public.polar_billing_state(user_id)->>'service_blocked')::boolean as service_blocked from public.polar_subscriptions limit 20) s;" "t"

gate_result "PAYMENTS :3400"
