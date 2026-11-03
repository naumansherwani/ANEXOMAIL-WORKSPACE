#!/usr/bin/env bash
# ============================================================================
# ANEXOMAIL — GATE LIBRARY (sirf padhta hai, kuch badalta nahi)
# Har gate isay source karti hai. PASS/FAIL ginti + aakhir mein saaf faisla.
# ============================================================================
PASS=0
FAIL=0
FAILED_LIST=""

ok()   { PASS=$((PASS+1)); printf 'PASS  %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); FAILED_LIST="$FAILED_LIST
  - $1"; printf 'FAIL  %s   (%s)\n' "$1" "${2:-no detail}"; }

# check_http <label> <url> <expected-code> [extra curl args...]
# want=200 par redirect follow hota hai (browser bhi yahi karta hai — canonical
# search-params wala 307 asli 200 par khatam hota hai).
check_http() {
  local label="$1" url="$2" want="$3"; shift 3
  local code follow=""
  [ "$want" = "200" ] && follow="-L"
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 $follow "$@" "$url" || echo 000)
  if [ "$code" = "$want" ]; then ok "$label ($code)"; else bad "$label" "got $code want $want · $url"; fi
}

# check_body <label> <url> <substring> [extra curl args...]
check_body() {
  local label="$1" url="$2" want="$3"; shift 3
  local body
  body=$(curl -s --max-time 20 "$@" "$url" || true)
  if printf '%s' "$body" | grep -q -- "$want"; then ok "$label"
  else bad "$label" "response mein '$want' nahi mila · $url"; fi
}

# check_cmd <label> <command...>
check_cmd() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "$label"; else bad "$label" "command fail: $*"; fi
}

# check_port <label> <port>
check_port() {
  local label="$1" port="$2"
  if ss -lntu 2>/dev/null | grep -q ":$port "; then ok "$label (port $port listening)"
  else bad "$label" "port $port par kuch listen nahi kar raha"; fi
}

# check_pm2 <name>
check_pm2() {
  local name="$1"
  if pm2 describe "$name" 2>/dev/null | grep -q 'status.*online'; then ok "pm2 $name online"
  else bad "pm2 $name" "process online nahi"; fi
}

# check_sql <label> <sql returning single value> <expected>
check_sql() {
  local label="$1" sql="$2" want="$3" out
  out=$(bash /opt/anexomail-web/sql/run.sh --query "$sql" 2>/dev/null | tr -d '[:space:]')
  if [ "$out" = "$want" ]; then ok "$label ($out)"; else bad "$label" "got '$out' want '$want'"; fi
}

gate_result() {
  echo
  echo "================================================"
  printf 'GATE: %s\n' "$1"
  printf 'PASS=%s  FAIL=%s\n' "$PASS" "$FAIL"
  if [ "$FAIL" -gt 0 ]; then
    printf 'FAILED DOTS:%s\n' "$FAILED_LIST"
    echo "GATE RED — is block ko DONE nahi likha jayega."
    echo "================================================"
    exit 1
  fi
  echo "GATE GREEN — poora block asli response de raha hai."
  echo "================================================"
}
