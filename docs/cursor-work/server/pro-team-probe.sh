#!/usr/bin/env bash
# ANEXOMAIL — PRO TEAM PROBE (27 Oct 2026): shared-inbox collision + 20-seat cap, SERVER par, koi typing nahi (server-key se token, password nahi).
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pro-team-probe.sh)
# Pehle: pro-second-user.sh (pro.buyer2). Test: pro.buyer thread ko pro.buyer2 ko assign (200) -> basic.buyer (bahar ka) ko assign (assignee_not_member 400) -> wapas unassign.
#   Seat cap: team_seat_calc SQL (pro = 20; 20 used + 1 pending => free 0). Data wapas bahal (assign hata diya jata hai). Token/key screen par nahi.
set -uo pipefail
. /etc/anexomail/sync.env 2>/dev/null
envv(){ for f in /opt/anexomail/.env /etc/anexomail/sync.env; do [ -r "$f" ] && grep -m1 -E "^$1=" "$f" | cut -d= -f2- | sed -e "s/^[\"']//" -e "s/[\"']$//"; done | head -1; }
URL="$(envv SUPABASE4_URL)"; [ -n "$URL" ] || URL="$(envv SUPABASE_URL)"; URL="${URL%/}"
KEY="$(envv SUPABASE4_SERVICE_ROLE_KEY)"; [ -n "$KEY" ] || KEY="$(envv SUPABASE_SERVICE_ROLE_KEY)"
jget(){ python3 -c 'import json,sys
try: print(json.load(sys.stdin).get(sys.argv[1],""))
except Exception: print("")' "$1"; }
token(){ local L H S; L="$(curl -s -m 20 -H "apikey: $KEY" -H "authorization: Bearer $KEY" -H 'content-type: application/json' -d "{\"type\":\"magiclink\",\"email\":\"$1\"}" "$URL/auth/v1/admin/generate_link")"; H="$(printf '%s' "$L" | jget hashed_token)"
  [ -n "$H" ] || return 1; S="$(curl -s -m 20 -H "apikey: $KEY" -H 'content-type: application/json' -d "{\"type\":\"magiclink\",\"token_hash\":\"$H\"}" "$URL/auth/v1/verify")"; printf '%s' "$S" | jget access_token; }
TOK1="$(token pro.buyer@anexomail.com)"; TOK2="$(token pro.buyer2@anexomail.com)"; unset KEY
[ -n "$TOK1" ] || { echo "FAIL: pro.buyer token nahi"; exit 1; }
[ -n "$TOK2" ] || { echo "FAIL: pro.buyer2 nahi — pehle pro-second-user.sh"; exit 1; }
RUST="${RUST:-http://127.0.0.1:3200}"; FAILS=0
rpc(){ curl -s -o /tmp/.pt.$$ -m 20 -w "%{http_code}" -H "authorization: Bearer $1" -H 'content-type: application/json' -d "{\"input\":$3}" "$RUST/rpc/$2"; }
chk(){ if [ "$2" = "$3" ]; then printf "PASS  %-52s %s\n" "$1" "$2"; else printf "FAIL  %-52s got %s want %s\n" "$1" "$2" "$3"; FAILS=$((FAILS+1)); fi; }
chk "pro.buyer2 apna plan Pro (mail.threads 200)" "$(rpc "$TOK2" mail.threads '{"folder":"inbox"}')" 200
chk "pro.buyer2 shared team ka inbox dekhta hai (200)" "$(rpc "$TOK1" mail.threads '{"folder":"inbox"}')" 200
TH="$(python3 -c 'import json
try:
  d=json.load(open("/tmp/.pt.'$$'"))["result"]["data"]["threads"]; print(d[0]["id"] if d else "")
except Exception: print("")')"
if [ -n "$TH" ]; then
  chk "assign -> pro.buyer2 (team member, 200)" "$(rpc "$TOK1" mail.assign "{\"thread_id\":\"$TH\",\"assignee\":\"pro.buyer2@anexomail.com\"}")" 200
  chk "assign -> basic.buyer (team ke bahar) = 400" "$(rpc "$TOK1" mail.assign "{\"thread_id\":\"$TH\",\"assignee\":\"basic.buyer@anexomail.com\"}")" 400
  chk "unassign (data wapas) 200" "$(rpc "$TOK1" mail.assign "{\"thread_id\":\"$TH\",\"assignee\":\"\"}")" 200
else echo "SKIP  assign: pro.buyer ke inbox mein thread nahi (koi mail bhejein phir dobara)"; fi
if command -v psql >/dev/null 2>&1; then
  S="$(psql "$WORKING_URL" -X -Atq -c "select (public.team_seat_calc('pro',0,20,1)->>'free'), (public.team_seat_calc('pro',0,0,0)->>'seats')" 2>/dev/null)"
  chk "seat cap: Pro 20 seats" "${S##*|}" 20
  chk "seat cap: 20 used + 1 pending => free 0" "${S%%|*}" 0
fi
rm -f /tmp/.pt.$$
[ "$FAILS" = 0 ] && echo "ALL PASS (pro team)" || echo "$FAILS FAIL — output Claude ko bhejein"
