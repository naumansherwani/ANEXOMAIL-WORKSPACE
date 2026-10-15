# #7 / #3 asli test — browser ke baghair, ek block (server par, Rule 15 / Rule 17).
# Pehle test account (agar nahi hai to E28 SQL se banta hai, hai to sirf naya auto-generated password),
# phir login token -> Rust RPC + Brain curl -> logs/DB. Password khud banta hai, /root/test-accounts/<handle>.pw
# (chmod 600, server par) mein rehta hai; repo/chat mein fixed password nahi. Dobara chalane par wohi password dobara
# kaam aata hai (file se); file na ho tab hi naya set hota hai. Postfix cron (har minute) ka intezar script khud karti hai.
# Doosre plan ke liye sirf pehli line badlo (H, PLAN, ORG, DOM, NM).
# __E28_B64__ = docs/cursor-work/sql/E28_seed_buyer_test_account.sql ka gzip+base64:
#   grep -v '^--' E28_seed_buyer_test_account.sql | grep -v '^$' | gzip -9n | base64 -w0
(
H=pro.buyer; PLAN=pro; ORG='Pro Buyer Test'; DOM=probuyer.axonetis.com; NM='Pro Buyer'
EM=$H@anexomail.com; TS=$(date +%s); PWF=/root/test-accounts/$H.pw
. /etc/anexomail/sync.env
U=$(grep -m1 '^SUPABASE4_URL=' /opt/anexomail/.env | cut -d= -f2- | tr -d '"'"'"' ')
K=$(grep -m1 '^SUPABASE4_ANON_KEY=' /opt/anexomail/.env | cut -d= -f2- | tr -d '"'"'"' ')
PW=$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 12)
echo "--- 0 account"
if [ "$(psql "$WORKING_URL" -Atc "select count(*) from auth.users where email='$EM'")" = 1 ]; then
  if [ -s "$PWF" ]; then PW=$(cat "$PWF"); echo "account pehle se hai: saved password"
  else psql "$WORKING_URL" -qAtc "set search_path=public,extensions; update auth.users set encrypted_password=crypt('$PW',gen_salt('bf')),updated_at=now() where email='$EM'" >/dev/null && echo "account pehle se tha: naya password set"; fi
else
  echo '__E28_B64__' | base64 -d | gunzip | psql "$WORKING_URL" -v ON_ERROR_STOP=1 -v handle=$H -v nm="$NM" -v org="$ORG" -v domain=$DOM -v plan=$PLAN -v pw="$PW" -f - || { echo SEED_FAIL; exit 2; }
fi
mkdir -p /root/test-accounts; chmod 700 /root/test-accounts; (umask 077; echo "$PW" > "$PWF")
echo "login: $EM   password: $PW   (file: $PWF)"
LR=$(curl -s "$U/auth/v1/token?grant_type=password" -H "apikey: $K" -H "content-type: application/json" -d "{\"email\":\"$EM\",\"password\":\"$PW\"}")
TOK=$(echo "$LR" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))")
[ -n "$TOK" ] && echo TOKEN_OK || { echo TOKEN_FAIL; echo "$LR" | cut -c1-250; echo "url_len=${#U} key_len=${#K}"; exit 2; }
R(){ curl -s -X POST http://127.0.0.1:3200/rpc/$1 -H "authorization: Bearer $TOK" -H "content-type: application/json" -d "${2:-{\}}"; echo; }
B(){ curl -s -w " [http %{http_code}]\n" -X POST http://127.0.0.1:3100/api/mail/schedule -H "authorization: Bearer $TOK" -H "content-type: application/json" -d "$1"; }
T(){ python3 -c "import sys,json;d=json.load(sys.stdin).get('result',{}).get('data',{});print([(t.get('subject'),t.get('from_address')) for t in d.get('threads',[])] or 'KHALI')"; }
echo "--- 1 Send-from list (Rust mail.identities)"
R mail.identities | python3 -c "import sys,json;d=json.load(sys.stdin)['result']['data'];print(d['identities'],'default=',d['default'])"
echo "--- 2 Postfix mein mailbox (cron har minute; 2 min tak intezar)"
for i in $(seq 1 24); do [ -n "$(postmap -q $EM hash:/etc/postfix/vmailbox)" ] && break; sleep 5; done
postmap -q $EM hash:/etc/postfix/vmailbox || { echo "POSTFIX_MAP_NAHI: cron check karo (tail /var/log/anexomail-sync-maps.log)"; exit 3; }
echo "--- 3 apne address se bhejo, apne ko (id aani chahiye)"
B "{\"identity\":\"$EM\",\"to\":\"$EM\",\"subject\":\"idtest$TS\",\"body\":\"hello\",\"hold_seconds\":0}"
echo "--- 4 kisi aur ka address (403 identity_not_allowed aana chahiye)"
B "{\"identity\":\"not.mine.test@anexomail.com\",\"to\":\"$EM\",\"subject\":\"x\",\"hold_seconds\":0}"
echo "--- 5 20 second ruko (worker 5s poll)"; sleep 20
grep "from=<$EM>" /var/log/mail.log | tail -2 | cut -c1-200
echo "--- 6 sent folder (Rust)"; R mail.threads "{\"folder\":\"sent\",\"q\":\"idtest$TS\"}" | T
echo "--- 7 inbox (aana = receive pipe theek)"; R mail.threads "{\"folder\":\"inbox\",\"q\":\"idtest$TS\"}" | T
)
