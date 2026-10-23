#!/usr/bin/env bash
# ANEXOMAIL — CalDAV (#6 C1) ke liye Caddy mein DO chhote handle: /.well-known/caldav -> 301 /dav/  aur  /dav* -> Rust :3200.
#   plan (default): sirf dikhata hai, kuch nahi badalta
#     git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/caddy-caldav.sh)
#   MODE=apply: backup -> insert -> caddy validate -> reload -> test -> fail par rollback
#     MODE=apply bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/caddy-caldav.sh)
# PEHLE E80 SQL + Rust (dav module) chalayen; warna /dav/ Rust ke bajaye purane fallback par jayega.
# HTTP/3 aur baqi handles ko haath nahi: sirf `handle /rpc/*` se PEHLE ek surgical insert (anexomail.com block ke andar).
set -uo pipefail
MODE="${MODE:-plan}"; CF="${CADDYFILE:-/etc/caddy/Caddyfile}"
[ -f "$CF" ] || { echo "FAIL: $CF nahi mili"; exit 2; }
STAMP="$(date +%Y%m%d-%H%M%S)"; BAK="$CF.bak.caldav-$STAMP"
T="$(mktemp)"; trap 'rm -f "$T" /tmp/caddy-validate.$$' EXIT
python3 -I - "$CF" "$T" <<'PY'
import re, sys
s = open(sys.argv[1]).read()
if re.search(r'^[ \t]*handle[ \t]+(@\w+|/dav)', s, re.M) and ("/dav" in s and "reverse_proxy 127.0.0.1:3200" in s and re.search(r'/dav[ \t*]', s)):
    print("SAME"); open(sys.argv[2], "w").write(s); sys.exit(0)
m = re.search(r'^([ \t]*)handle[ \t]+/rpc/\*[ \t]*\{', s, re.M)
if not m:
    print("STOP: `handle /rpc/*` anchor nahi mila — haath se dekhna padega"); sys.exit(4)
# anchor sahi site block (anexomail.com) mein hona chahiye: pichla site header dhoondo
head = s[:m.start()]
hs = list(re.finditer(r'^([^\s#{][^\n{]*)\{[ \t]*$', head, re.M))
if not hs or "anexomail.com" not in hs[-1].group(1):
    print("STOP: `handle /rpc/*` anexomail.com block mein nahi lagta"); sys.exit(4)
ind = m.group(1)
ins = (f"{ind}# CalDAV (C1) — repo-managed: docs/cursor-work/server/caddy-caldav.sh\n"
       f"{ind}handle /.well-known/caldav {{\n{ind}\tredir * /dav/ 301\n{ind}}}\n"
       f"{ind}@caldav path /dav /dav/*\n"
       f"{ind}handle @caldav {{\n{ind}\treverse_proxy 127.0.0.1:3200\n{ind}}}\n\n")
open(sys.argv[2], "w").write(s[:m.start()] + ins + s[m.start():])
print("INSERT")
PY
rc=$?; [ $rc -eq 0 ] || exit 3
if cmp -s "$CF" "$T"; then echo "Pehle se laga hai (CalDAV handles Caddyfile mein maujood). Kuch nahi badla."; exit 0; fi
echo "==> PLAN: yeh lines judengi (handle /rpc/* se pehle):"; diff <(cat "$CF") "$T" | grep '^>' | sed 's/^> /    + /'
# pehle ASLI Caddyfile ka validate (baseline): wo khud fail ho to qasoor meri insert ka nahi
if caddy validate --config "$CF" >/tmp/caddy-validate-base.$$ 2>&1; then BASE=ok; else BASE=fail; fi
echo "==> asli Caddyfile validate: $BASE"
# naya config ASLI folder mein (relative import/path same rahein), phir turant hata dete hain
TT="$(dirname "$CF")/.Caddyfile.caldav-try.$$"; cp "$T" "$TT"
if caddy validate --config "$TT" --adapter caddyfile >/tmp/caddy-validate.$$ 2>&1; then rm -f "$TT"; echo "==> naya config validate OK (copy par)"
else rm -f "$TT"; echo "!! naya config validate FAIL — kuch nahi badla. Caddy ki asli error:"; grep -v '^$' /tmp/caddy-validate.$$ | tail -8 | cut -c1-220
  [ "$BASE" = "fail" ] && { echo "-- asli Caddyfile ki apni error:"; tail -4 /tmp/caddy-validate-base.$$ | cut -c1-220; }
  rm -f /tmp/caddy-validate-base.$$; exit 1; fi
rm -f /tmp/caddy-validate-base.$$
[ "$MODE" = "apply" ] || { echo; echo "Yeh sirf PLAN tha. Kuch nahi badla. Lagane ke liye: MODE=apply ..."; exit 0; }
cp -p "$CF" "$BAK"; cp "$T" "$CF"
rollback() { echo "!!! ROLLBACK: $1"; cp -p "$BAK" "$CF"; caddy validate --config "$CF" >/dev/null 2>&1 && systemctl reload caddy; echo "    purani Caddyfile wapas. Backup: $BAK"; exit 1; }
caddy validate --config "$CF" >/tmp/caddy-validate.$$ 2>&1 || { tail -3 /tmp/caddy-validate.$$; rollback "caddy validate fail"; }
systemctl reload caddy || rollback "caddy reload fail"
sleep 3
FAIL=0
M="$(curl -s -m 10 -o /dev/null -w '%{http_code}' https://anexomail.com/)"; [ "$M" = "200" ] && echo "    OK   anexomail.com => 200" || { echo "    FAIL anexomail.com => $M"; FAIL=1; }
R="$(curl -s -m 10 -o /dev/null -w '%{http_code} %{redirect_url}' https://anexomail.com/.well-known/caldav)"; echo "    well-known => $R (301 https://anexomail.com/dav/ chahiye)"
case "$R" in 301*) ;; *) FAIL=1;; esac
O="$(curl -s -m 10 -i -X OPTIONS https://anexomail.com/dav/ | tr -d '\r' | grep -i '^dav:' | head -1)"; echo "    OPTIONS /dav/ => ${O:-<DAV header nahi>}"
[ -n "$O" ] || echo "    NOTE: DAV header nahi — Rust dav module install hua? (rust-engine-install.sh pehle chalayen)"
P="$(curl -s -m 10 -o /dev/null -w '%{http_code}' -X PROPFIND -H 'Depth: 0' https://anexomail.com/dav/)"; echo "    PROPFIND bina login => $P (401 chahiye)"
H3="$(curl -s -m 10 -o /dev/null --http3 -w '%{http_code}' https://anexomail.com/ 2>/dev/null || echo n/a)"; echo "    HTTP/3 => $H3 (n/a = curl mein h3 nahi, theek)"
[ "$FAIL" = "0" ] || rollback "post-check fail"
echo; echo "==> CALDAV CADDY TAYYAR. Backup: $BAK"
echo "    Rollback haath se: cp -p $BAK $CF && systemctl reload caddy"
