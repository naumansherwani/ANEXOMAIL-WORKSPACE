#!/usr/bin/env bash
# ANEXOMAIL — wsx LIVE TEST: naye-user workspace banane ka asli raasta (workspace.personal + workspace.organisations) Rust :3200 par.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/wsx-live-test.sh)
# Kya: 2 THROWAWAY zz.wsx.* account banata hai (GoTrue admin, password random — screen par kabhi nahi), har ek se workspace banwata hai,
#      DB mein har table ki row jaanchta hai, dobara call par existing:true dekhta hai, phir APNE banaye zz rows saaf karta hai.
# Kisi asli user/data ko haath nahi lagata. Sirf zz.wsx.<ts>.* naam ki cheezein.
set -uo pipefail
envv(){ for f in /opt/anexomail/.env /etc/anexomail/sync.env; do [ -r "$f" ] && grep -m1 -E "^$1=" "$f" | cut -d= -f2- | sed -e "s/^[\"']//" -e "s/[\"']$//"; done | head -1; }
URL="${SUPABASE4_URL:-$(envv SUPABASE4_URL)}"; [ -n "$URL" ] || URL="$(envv SUPABASE_URL)"; URL="${URL%/}"
KEY="$(envv SUPABASE4_SERVICE_ROLE_KEY)"; [ -n "$KEY" ] || KEY="$(envv SUPABASE_SERVICE_ROLE_KEY)"
[ -n "$URL" ] && [ -n "$KEY" ] || { echo "FAIL: .env mein SUPABASE4_URL / SERVICE_ROLE_KEY nahi"; exit 2; }
RUST="${RUST:-http://127.0.0.1:3200}"; TS="$(date +%s)"; FAILS=0
jq_(){ python3 -c 'import json,sys
d=json.load(sys.stdin)
for k in sys.argv[1].split("."):
    d=(d[int(k)] if isinstance(d,list) else d.get(k)) if d is not None and (not isinstance(d,list) or k.isdigit()) else None
print("" if d is None else (json.dumps(d) if isinstance(d,(dict,list,bool)) else d))' "$1" 2>/dev/null; }
chk(){ if [ "$2" = "$3" ]; then printf "PASS  %-52s %s\n" "$1" "$2"; else printf "FAIL  %-52s got [%s] want [%s]\n" "$1" "$2" "$3"; FAILS=$((FAILS+1)); fi; }
rest(){ curl -s -m 20 -H "apikey: $KEY" -H "authorization: Bearer $KEY" "$URL/rest/v1/$1"; }
delrest(){ curl -s -m 20 -o /dev/null -X DELETE -H "apikey: $KEY" -H "authorization: Bearer $KEY" "$URL/rest/v1/$1"; }

run_one(){ # kind(personal|business)
  local kind="$1" EM PW UID_ TOK HASH SESS R ORG
  EM="zz.wsx.$TS.$kind@anexomail.com"
  PW="$(python3 -c 'import secrets;print(secrets.token_urlsafe(24))')"
  echo "== $kind : $EM"
  UID_="$(curl -s -m 20 -H "apikey: $KEY" -H "authorization: Bearer $KEY" -H 'content-type: application/json' -d "{\"email\":\"$EM\",\"password\":\"$PW\",\"email_confirm\":true}" "$URL/auth/v1/admin/users" | jq_ id)"; unset PW
  [ -n "$UID_" ] || { echo "FAIL: test user nahi bana"; FAILS=$((FAILS+1)); return; }
  HASH="$(curl -s -m 20 -H "apikey: $KEY" -H "authorization: Bearer $KEY" -H 'content-type: application/json' -d "{\"type\":\"magiclink\",\"email\":\"$EM\"}" "$URL/auth/v1/admin/generate_link" | jq_ hashed_token)"
  SESS="$(curl -s -m 20 -H "apikey: $KEY" -H 'content-type: application/json' -d "{\"type\":\"magiclink\",\"token_hash\":\"$HASH\"}" "$URL/auth/v1/verify")"; TOK="$(printf '%s' "$SESS" | jq_ access_token)"; unset SESS HASH
  [ -n "$TOK" ] || { echo "FAIL: test token nahi mila"; FAILS=$((FAILS+1)); return; }
  # profile row (asli signup bhi banata hai)
  curl -s -m 20 -o /dev/null -H "apikey: $KEY" -H "authorization: Bearer $KEY" -H 'content-type: application/json' -H 'prefer: resolution=merge-duplicates' \
    -d "{\"user_id\":\"$UID_\",\"email\":\"$EM\",\"legal_name\":\"zz wsx\",\"display_name\":\"zz wsx\"}" "$URL/rest/v1/account_profiles?on_conflict=user_id"
  if [ "$kind" = personal ]; then
    R="$(curl -s -m 30 -H "authorization: Bearer $TOK" -H 'content-type: application/json' -d '{"input":{}}' "$RUST/rpc/workspace.personal")"
  else
    R="$(curl -s -m 30 -H "authorization: Bearer $TOK" -H 'content-type: application/json' -d "{\"input\":{\"name\":\"ZZ WSX Co $TS\",\"domain\":\"zzwsx$TS.com\"}}" "$RUST/rpc/workspace.organisations")"
  fi
  ORG="$(printf '%s' "$R" | jq_ result.data.id)"
  chk "$kind: workspace bana (id mila)" "$([ -n "$ORG" ] && echo yes || echo no)" yes
  chk "$kind: kind jawab mein" "$(printf '%s' "$R" | jq_ result.data.kind)" "$kind"
  [ -n "$ORG" ] || { echo "   jawab: $R"; return; }
  chk "$kind: organisations row" "$(rest "organisations?select=id,owner_id&id=eq.$ORG" | jq_ 0.owner_id)" "$UID_"
  chk "$kind: org_members owner" "$(rest "org_members?select=role&org_id=eq.$ORG&user_id=eq.$UID_" | jq_ 0.role)" owner
  chk "$kind: account_organisations row" "$(rest "account_organisations?select=created_by&id=eq.$ORG" | jq_ 0.created_by)" "$UID_"
  chk "$kind: account_org_members owner" "$(rest "account_org_members?select=role&org_id=eq.$ORG&user_id=eq.$UID_" | jq_ 0.role)" owner
  chk "$kind: orgs row (legacy)" "$(rest "orgs?select=id&id=eq.$ORG" | jq_ 0.id)" "$ORG"
  chk "$kind: mail_accounts jodi" "$(rest "mail_accounts?select=org_id&address=eq.$EM" | jq_ 0.org_id)" "$ORG"
  chk "$kind: profile workspace_kind" "$(rest "account_profiles?select=preferences&user_id=eq.$UID_" | jq_ 0.preferences.workspace_kind)" "$kind"
  chk "$kind: profile onboarded" "$(rest "account_profiles?select=onboarded&user_id=eq.$UID_" | jq_ 0.onboarded)" True
  if [ "$kind" = personal ]; then
    R2="$(curl -s -m 30 -H "authorization: Bearer $TOK" -H 'content-type: application/json' -d '{"input":{}}' "$RUST/rpc/workspace.personal")"
    chk "personal: dobara call => existing:true" "$(printf '%s' "$R2" | jq_ result.data.existing)" True
    chk "personal: dobara => wahi org" "$(printf '%s' "$R2" | jq_ result.data.id)" "$ORG"
  fi
  # SAAF: sirf apne zz rows
  delrest "mail_accounts?org_id=eq.$ORG"; delrest "org_members?org_id=eq.$ORG"; delrest "account_org_members?org_id=eq.$ORG"
  delrest "account_organisations?id=eq.$ORG"; delrest "orgs?id=eq.$ORG"; delrest "organisations?id=eq.$ORG"; delrest "account_profiles?user_id=eq.$UID_"
  curl -s -m 20 -o /dev/null -X DELETE -H "apikey: $KEY" -H "authorization: Bearer $KEY" "$URL/auth/v1/admin/users/$UID_"
  chk "$kind: safai (organisations row gayab)" "$(rest "organisations?select=id&id=eq.$ORG" | jq_ 0.id)" ""
}
run_one personal
run_one business
unset TOK KEY
[ "$FAILS" -eq 0 ] && echo "ALL PASS (wsx live)" || echo "$FAILS FAIL — output Claude ko bhejein"
