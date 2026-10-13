# #7 / #3 asli test — browser ke baghair: login token -> Rust RPC + Brain curl -> logs/DB.
# Server par chalta hai (Rule 15), ek block copy-paste. Password prompt hota hai (repo mein nahi).
# Test account: pro.buyer (E28 se bana). Doosre plan ke liye sirf H=... badlo.
H=pro.buyer; EM=$H@anexomail.com; TS=$(date +%s)
U=$(grep -m1 '^SUPABASE4_URL=' /opt/anexomail/.env | cut -d= -f2- | tr -d '"'"'"' ')
K=$(grep -m1 '^SUPABASE4_ANON_KEY=' /opt/anexomail/.env | cut -d= -f2- | tr -d '"'"'"' ')
read -rsp "$H password: " PW; echo
TOK=$(curl -s "$U/auth/v1/token?grant_type=password" -H "apikey: $K" -H "content-type: application/json" -d "{\"email\":\"$EM\",\"password\":\"$PW\"}" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))"); unset PW
[ -n "$TOK" ] && echo TOKEN_OK || { echo TOKEN_FAIL; return 2>/dev/null; }
R(){ curl -s -X POST http://127.0.0.1:3200/rpc/$1 -H "authorization: Bearer $TOK" -H "content-type: application/json" -d "${2:-{\}}"; echo; }
B(){ curl -s -w " [http %{http_code}]\n" -X POST http://127.0.0.1:3100/api/mail/schedule -H "authorization: Bearer $TOK" -H "content-type: application/json" -d "$1"; }
T(){ python3 -c "import sys,json;d=json.load(sys.stdin).get('result',{}).get('data',{});print([(t.get('subject'),t.get('from_address')) for t in d.get('threads',[])] or 'KHALI')"; }
echo "--- 1 Send-from list (Rust mail.identities)"
R mail.identities | python3 -c "import sys,json;d=json.load(sys.stdin)['result']['data'];print(d['identities'],'default=',d['default'])"
echo "--- 2 Postfix mein mailbox hai? (khali = cron ka intezar, 3 min baad dobara)"
postmap -q $EM hash:/etc/postfix/vmailbox
echo "--- 3 apne address se bhejo, apne ko (id aani chahiye)"
B "{\"identity\":\"$EM\",\"to\":\"$EM\",\"subject\":\"idtest$TS\",\"body\":\"hello\",\"hold_seconds\":0}"
echo "--- 4 doosre ka address (403 identity_not_allowed aana chahiye)"
B "{\"identity\":\"hello@anexomail.com\",\"to\":\"$EM\",\"subject\":\"x\",\"hold_seconds\":0}"
echo "--- 5 20 second ruko (worker 5s poll)"; sleep 20
grep "from=<$EM>" /var/log/mail.log | tail -2 | cut -c1-200
echo "--- 6 sent folder (Rust)"; R mail.threads "{\"folder\":\"sent\",\"q\":\"idtest$TS\"}" | T
echo "--- 7 inbox (aana = receive pipe theek)"; R mail.threads "{\"folder\":\"inbox\",\"q\":\"idtest$TS\"}" | T
unset TOK
