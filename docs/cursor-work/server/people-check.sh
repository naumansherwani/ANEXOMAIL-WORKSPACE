#!/usr/bin/env bash
# ANEXOMAIL — PEOPLE CHECK (27 Oct 2026, READ-ONLY): pro.buyer2 ne anexomail27@gmail.com ko mail bheji, par /app/people khali.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/people-check.sh)
# Sawal: (1) bheji hui mail DB mein kis org/direction ke saath hai? (2) contacts table mein anexomail27 hai? (3) rebuild function kya jawab deta hai? (4) Rust contacts.list kitne deta hai?
# Kuch likhta/badalta nahi (rebuild wahi call hai jo har People-open par khud hota hai). Key/token screen par nahi.
set -uo pipefail
. /etc/anexomail/sync.env 2>/dev/null
envv(){ for f in /opt/anexomail/.env /etc/anexomail/sync.env; do [ -r "$f" ] && grep -m1 -E "^$1=" "$f" | cut -d= -f2- | sed -e "s/^[\"']//" -e "s/[\"']$//"; done | head -1; }
URL="$(envv SUPABASE4_URL)"; [ -n "$URL" ] || URL="$(envv SUPABASE_URL)"; URL="${URL%/}"
KEY="$(envv SUPABASE4_SERVICE_ROLE_KEY)"; [ -n "$KEY" ] || KEY="$(envv SUPABASE_SERVICE_ROLE_KEY)"
[ -n "$URL" ] && [ -n "$KEY" ] || { echo "FAIL: supabase env nahi mila"; exit 1; }
jget(){ python3 -c 'import json,sys
try: print(json.load(sys.stdin).get(sys.argv[1],""))
except Exception: print("")' "$1"; }
rest(){ curl -s -m 20 -H "apikey: $KEY" -H "authorization: Bearer $KEY" "$URL/rest/v1/$1"; }
EM=pro.buyer2@anexomail.com; EXT=anexomail27@gmail.com
echo "== 1. $EM ki bheji mail (mail_messages, taza 5) =="
rest "mail_messages?select=org_id,direction,from_address,to_addresses,sent_at&from_address=eq.$EM&order=sent_at.desc&limit=5" | python3 -m json.tool 2>/dev/null | head -40
ORG="$(rest "mail_messages?select=org_id&from_address=eq.$EM&order=sent_at.desc&limit=1" | python3 -c 'import json,sys
try: print(json.load(sys.stdin)[0]["org_id"])
except Exception: print("")')"
echo "org_id = ${ORG:-(nahi mila)}"
echo; echo "== 2. contacts table mein $EXT (kisi bhi org mein) =="
rest "contacts?select=org_id,primary_address,last_contact_at&primary_address=eq.$EXT&limit=5" | python3 -m json.tool 2>/dev/null | head -20
if [ -n "$ORG" ]; then
  echo; echo "== 3. anexo_rebuild_contacts(org) ka jawab =="
  curl -s -m 30 -H "apikey: $KEY" -H "authorization: Bearer $KEY" -H 'content-type: application/json' -d "{\"p_org\":\"$ORG\"}" "$URL/rest/v1/rpc/anexo_rebuild_contacts" | cut -c1-400; echo
  echo; echo "== 4. is org ke contacts (rebuild ke BAAD) =="
  rest "contacts?select=primary_address,last_contact_at&org_id=eq.$ORG&limit=10" | python3 -m json.tool 2>/dev/null | head -30
fi
echo; echo "== 5. Rust log mein contx.rebuild error (aakhri 5) =="
pm2 logs anexomail-rust --lines 400 --nostream 2>/dev/null | grep -E "contx\.rebuild" | tail -5 | cut -c1-300
echo "(khali = koi rebuild error nahi)"
unset KEY
