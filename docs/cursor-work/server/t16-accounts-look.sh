# t16 — chaar test accounts (basic/pro/business/bpro.buyer): E28 se seed + har plan ko website kya dikhata hai.
# Founder ke server par chalta hai (chat block). Pehle pm2 restart (rust, leo, web — polar-rust-payment ko haath nahi), public pages, phir har account ka rail/dashboard/send-from/domains/addresses/gate, phir #10 survey.
# Passwords sirf /root/test-accounts/<handle>.pw (server par). Repo mein koi secret nahi.
(
set -o pipefail
G=/opt/anexomail-web; mkdir -p /root/t16 && cd /root/t16
echo "=== 1 env load + pm2 restart (rust, leo, web; polar-rust-payment ko haath nahi)"
pm2 restart anexomail-rust anexomail-leo anexomail-web --update-env >/dev/null 2>&1; pm2 save >/dev/null 2>&1; sleep 8
pm2 jlist 2>/dev/null | python3 -c "
import sys,json,time
for p in json.load(sys.stdin):
    e=p['pm2_env']; print('  %-20s %-8s restarts=%s up=%ss'%(p['name'],e['status'],e['restart_time'],int((time.time()*1000-e['pm_uptime'])/1000)))"
for a in anexomail-rust anexomail-leo; do echo "  env $a: SUPABASE vars=$(tr '\0' '\n' < /proc/$(pm2 pid $a)/environ 2>/dev/null | grep -c '^SUPABASE')"; done
. /etc/anexomail/sync.env
git -C $G fetch -q origin main
echo "=== 2 public website (Caddy ke raaste)"
API=$(grep -h '^VITE_API_URL=' $G/.env* 2>/dev/null | head -1 | cut -d= -f2- | tr -d "\"' "); [ -n "$API" ] || API=https://anexomail.com
echo "  api base: $API"
for p in / /plans /auth /app/domains; do curl -s -o /dev/null -w "  https://anexomail.com$p -> %{http_code}\n" --max-time 10 https://anexomail.com$p; done
A=$(basename "$(ls $G/.output/public/assets/app.domains-*.js | head -1)")
echo "  public bundle $A: 'Connect a domain' matches=$(curl -s --max-time 10 https://anexomail.com/assets/$A | grep -c 'Connect a domain')"
U=$(grep -m1 '^SUPABASE4_URL=' /opt/anexomail/.env | cut -d= -f2- | tr -d '"'"'"' ')
K=$(grep -m1 '^SUPABASE4_ANON_KEY=' /opt/anexomail/.env | cut -d= -f2- | tr -d '"'"'"' ')
echo "=== 3 test accounts (E28 SQL, Business workspace)"
mkdir -p /root/test-accounts; chmod 700 /root/test-accounts
git -C $G show origin/main:docs/cursor-work/sql/E28_seed_buyer_test_account.sql > E28.sql
seed(){
  local H=$1 PLAN=$2 NM=$3 ORG=$4 DOM=$5 EM=$1@anexomail.com PWF=/root/test-accounts/$1.pw PW
  PW=$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 12)
  if [ "$(psql "$WORKING_URL" -Atc "select count(*) from auth.users where email='$EM'")" = 1 ]; then
    if [ -s "$PWF" ]; then echo "  $H: pehle se hai"
    else psql "$WORKING_URL" -qAtc "set search_path=public,extensions; update auth.users set encrypted_password=crypt('$PW',gen_salt('bf')),updated_at=now() where email='$EM'" >/dev/null && (umask 077; echo "$PW" > "$PWF") && echo "  $H: pehle se tha, naya password"; fi
  else
    psql "$WORKING_URL" -v ON_ERROR_STOP=1 -q -v handle=$H -v nm="$NM" -v org="$ORG" -v domain=$DOM -v plan=$PLAN -v pw="$PW" -f E28.sql >/dev/null 2>&1 \
      && { (umask 077; echo "$PW" > "$PWF"); echo "  $H: ban gaya ($PLAN)"; } || echo "  $H: SEED_FAIL ($PLAN)"
  fi
}
seed basic.buyer basic "Basic Buyer" "Basic Buyer Test" basicbuyer.axonetis.com
seed pro.buyer pro "Pro Buyer" "Pro Buyer Test" probuyer.axonetis.com
seed business.buyer business "Business Buyer" "Business Buyer Test" businessbuyer.axonetis.com
seed bpro.buyer business_pro "Business Pro Buyer" "Business Pro Buyer Test" bprobuyer.axonetis.com
cat > rail.mjs <<'JS'
import fs from "fs";
const ps = await import((process.env.WEB || "/opt/anexomail-web") + "/src/lib/plan-surface.ts");
const s = JSON.parse(fs.readFileSync(0, "utf8"));
const u = s.user || {};
const org = (s.organisations || []).find((o) => o.id === s.active_organisation_id) || (s.organisations || [])[0];
const sf = ps.surfaceFromSession(u, org?.slug);
const items = [["/app","Dashboard"],["/app/mail/inbox","Mail"],["/app/people","People"],["/app/calendar","Calendar"],["/app/work","Work"],["/app/crm","CRM"],["/app/org","Org"],["/app/domains","Domains"],["/app/safety","Safety"],["/app/chat","ANEXOChat"],["/app/ai-center","AI"],["/app/perf","Speed"],["/app/founder","Founder"],["/app/admin","Admin"]];
const opts = { plan: sf.billed, kind: sf.kind, founder: Boolean(u.is_founder), founderHost: false, publicMailHost: true, aiHost: false };
console.log("  session : plan=" + sf.billed + " kind=" + sf.kind + " label='" + sf.copyName + "' org=" + (org?.slug || "?"));
console.log("  rail    : " + items.filter(([to]) => ps.railItemVisible(to, opts)).map(([, l]) => l).join(" | "));
const den = ["/app/domains", "/app/work", "/app/chat", "/app/org"].map((p) => [p, ps.surfaceDenial(p, opts)]).filter(([, d]) => d).map(([p, d]) => p + " (" + d.title + ")");
console.log("  denied  : " + (den.join(" ; ") || "none"));
JS
cat > j.py <<'PY'
import sys,json
raw=sys.stdin.read()
try:
    d=json.loads(raw); d=d.get('result',{}).get('data',d); exec(sys.argv[1])
except Exception as ex:
    print('  ERR',type(ex).__name__,raw[:160].replace('\n',' '))
PY
echo "=== 4 har account ko website kya dikhata hai (public API + asli deployed plan-surface code)"
for H in basic.buyer pro.buyer business.buyer bpro.buyer; do
  EM=$H@anexomail.com; PW=$(cat /root/test-accounts/$H.pw 2>/dev/null) || { echo "--- $EM: password file nahi"; continue; }
  TOK=$(curl -s "$U/auth/v1/token?grant_type=password" -H "apikey: $K" -H "content-type: application/json" -d "{\"email\":\"$EM\",\"password\":\"$PW\"}" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))")
  echo "--- $EM"; [ -n "$TOK" ] || { echo "  TOKEN_FAIL"; continue; }
  R(){ curl -s -X POST $API/rpc/$1 -H "authorization: Bearer $TOK" -H "content-type: application/json" -d "${2:-{\}}"; }
  curl -s $API/api/auth/session -H "authorization: Bearer $TOK" | WEB=$G bun rail.mjs 2>&1 | head -5
  R dashboard.summary | python3 j.py "print('  dashboard: plan=%s storage=%.0fGB(%s) domain=%s/%s unread=%s waiting=%s sent_today=%s'%(d['plan'],d['storage_limit_bytes']/2**30,d['storage_model'],d['domain'],d['domain_status'],d['unread'],d['waiting'],d['sent_today']))"
  R dashboard.analytics | python3 j.py "print('  analytics: received=%s sent=%s'%(sum(x['received'] for x in d['series']),sum(x['sent'] for x in d['series'])))"
  R mail.identities | python3 j.py "print('  send-from:',[i['address'] if isinstance(i,dict) else i for i in d['identities']],'default=',d['default'])"
  R mail.domains.list | python3 j.py "print('  domains: used=%s cap=%s'%(len(d['domains']),d['domain_cap']))"
  R mail.addresses.list | python3 j.py "print('  addresses: mailbox used=%s cap=%s'%(d['mailbox_used'],d['mailbox_cap']))"
  echo "  gate work.tasks.list -> $(curl -s -o /dev/null -w '%{http_code}' -X POST $API/rpc/work.tasks.list -H "authorization: Bearer $TOK" -H 'content-type: application/json' -d '{}')   (Basic par 403 chahiye)"
done
echo "=== 5 #10: Brain ke live-only files (kaun asli mein import hota hai)"
cd /opt/anexomail/src
git -C $G grep -hoE "(\./|\.\./)lib/[A-Za-z0-9_.-]+" origin/main -- 'server/*.ts' 'server/routes/*.ts' 'server/lib/*.ts' 2>/dev/null | sed -E 's#.*lib/##; s#\.ts$##' | sort -u > /root/t16/used.txt
echo "  repo ka Brain code in lib modules ko import karta hai: $(tr '\n' ' ' < /root/t16/used.txt)"
same=0; diffc=0; none=0
for f in lib/*.ts; do b=$(basename $f)
  git -C $G cat-file -e origin/main:server/$f 2>/dev/null && continue
  if git -C $G cat-file -e origin/main:src/lib/$b 2>/dev/null; then
    if [ "$(sha256sum $f | cut -c1-16)" = "$(git -C $G show origin/main:src/lib/$b | sha256sum | cut -c1-16)" ]; then same=$((same+1)); else diffc=$((diffc+1)); echo "  lib/$b web src/lib se alag"; fi
  else none=$((none+1)); echo "  lib/$b repo mein kahin nahi"; fi
done
echo "  live-only lib files: web src/lib ke barabar=$same, web se alag=$diffc, kahin nahi=$none"
for m in $(cat /root/t16/used.txt); do [ -f lib/$m.ts ] && ! git -C $G cat-file -e origin/main:server/lib/$m.ts 2>/dev/null && echo "  IMPORTED aur repo mein nahi: lib/$m.ts"; done
echo "  anexochat.ts live vs repo (pehli 20 lines):"; diff <(git -C $G show origin/main:server/anexochat.ts) anexochat.ts | head -20 | cut -c1-170
echo "=== done"
)
