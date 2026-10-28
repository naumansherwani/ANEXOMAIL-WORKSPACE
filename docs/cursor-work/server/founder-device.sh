#!/usr/bin/env bash
# Founder device approval (F1a) — server par founder khud. Naya device founderworkspace par "device_pending" ke saath 8 akshar ka CODE dikhata hai.
#   list            : sab devices (label, code, state, last seen)
#   approve <CODE>  : pending device ko manzoor karo (audit mein, wajah ke saath)
#   revoke  <CODE>  : device band (uska chala hua token bhi foran band; aakhri approved device revoke nahi hota)
# REASON="..." (>= 8 akshar) env se wajah; warna default. Kuch install/restart nahi hota; sirf founder_device_* RPC (E104).
# Usage: git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-device.sh) list
set -u
ENVF="${FOUNDER_ENV:-/etc/anexomail/founder.env}"
[ -r "$ENVF" ] || { echo "FAIL: $ENVF padh nahi sakta (root se chalao)"; exit 2; }
URL="$(grep -m1 '^SUPABASE4_URL=' "$ENVF" | cut -d= -f2-)"; KEY="$(grep -m1 '^SUPABASE4_SERVICE_ROLE_KEY=' "$ENVF" | cut -d= -f2-)"
[ -n "$URL" ] && [ -n "$KEY" ] || { echo "FAIL: Supabase URL/key env file mein nahi"; exit 2; }
rest() { curl -s -m 15 "$@" -H "apikey: $KEY" -H "authorization: Bearer $KEY"; }
UID_="${FOUNDER_UID:-$(rest "$URL/rest/v1/founder_accounts?select=user_id&limit=2" | python3 -c 'import sys,json; r=json.load(sys.stdin); print(r[0]["user_id"] if len(r)==1 else "")' 2>/dev/null)}"
[ -n "$UID_" ] || { echo "FAIL: founder uid ek nahi mila (FOUNDER_UID=<uuid> do)"; exit 2; }
rpc() { rest -X POST "$URL/rest/v1/rpc/$1" -H 'content-type: application/json' -d "$2"; }
cmd="${1:-list}"; code="${2:-}"; reason="${REASON:-approved from server by founder ($cmd $code)}"
case "$cmd" in
  list) rpc founder_device_list "{\"p_uid\":\"$UID_\"}" | python3 -c '
import sys,json
d=json.load(sys.stdin)
if not isinstance(d,list): print("FAIL:",d); sys.exit(1)
print("%-9s %-9s %-34s %s"%("CODE","STATE","LABEL","LAST SEEN"))
for x in d: print("%-9s %-9s %-34s %s"%(x["code"],x["state"],x["label"][:34],x["last_seen_at"] or "-"))
if not d: print("(no devices yet)")';;
  approve|revoke)
    echo "$code" | grep -Eq '^[0-9A-F]{8}$' || { echo "FAIL: CODE 8 hex akshar (bade) chahiye, jaise A1B2C3D4"; exit 2; }
    r="$(rpc founder_device_$cmd "{\"p_uid\":\"$UID_\",\"p_code\":\"$code\",\"p_reason\":\"$reason\"}")"
    echo "$r" | python3 -c 'import sys,json; d=json.load(sys.stdin); print("OK" if d.get("state") in ("approved","revoked") else "FAIL"); print(d)'; [ "$(echo "$r" | grep -c '"state"')" -ge 1 ] || exit 1;;
  *) echo "usage: founder-device.sh list | approve <CODE> | revoke <CODE>"; exit 2;;
esac
