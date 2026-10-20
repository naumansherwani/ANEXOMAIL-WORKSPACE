#!/usr/bin/env bash
# ANEXOMAIL — Rust :3200 B1: LOCAL JWT VERIFY (ES256) + shared HTTP client + asli revocation. Rule 35: surgical + restore-on-fail.
#   PEHLE SQL:  git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E53_auth_session_alive CHECK_E53
#   PHIR:       bash <(git -C /opt/anexomail-web fetch -q origin main; git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-jwt-install.sh)
# Kya badalta hai (sirf yeh): (1) naya server/rust/jwt_core.rs (ES256 verify, `ring`), (2) live main.rs ka `auth_user` hissa
#   (markers `/// Identity Supabase Auth se` .. `/// Gate DB ka` — naya http() shared client, JWKS cache, session_alive, local verify, GoTrue fallback),
#   (3) baqi `reqwest::Client::new()` -> `http()` (pehle har call par naya TLS handshake), (4) Cargo.toml mein `ring = "0.17"` (pehle se tree mein — rustls ke saath).
# Safety: src + Cargo.toml + Cargo.lock + binary backup -> jwt_core ke 9 unit tests (cargo test) -> build -> FAIL = sab wapas, purani binary chalti rehti hai
#   -> OK = restart + health + nakli token 401 + ASLI SABOOT: test account ka token -> Rust 'auth chali' (403/200, 401 nahi) -> logout -> 6 s baad wohi token 401.
# polar :3400, Caddy, Bun, mail, .env ko haath nahi.
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"; TARGET="${TARGET:-/opt/anexomail-rust}"; RPC="${RPC:-http://127.0.0.1:3200}"
EMAIL="${EMAIL:-basic.test@anexomail.com}"
STAMP="$(date +%s)"; BIN="$TARGET/target/release/anexomail-rust"; LOG="/tmp/anexomail-rust-jwt-$STAMP.log"
S="$TARGET/src/main.rs"; C="$TARGET/Cargo.toml"; L="$TARGET/Cargo.lock"; J="$TARGET/src/jwt_core.rs"
A='/// Identity Supabase Auth se'; Z='/// Gate DB ka `chat_access()`'
command -v cargo >/dev/null 2>&1 || export PATH="$HOME/.cargo/bin:$PATH"
command -v cargo >/dev/null 2>&1 || { echo "FAIL: cargo nahi mila"; exit 2; }
[ -f "$S" ] && [ -f "$C" ] || { echo "FAIL: $TARGET/src/main.rs ya Cargo.toml nahi mili"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
git -C "$REPO" fetch -q origin main 2>/dev/null
show() { git -C "$REPO" show "origin/main:$1" 2>/dev/null; }
show server/rust/main.rs > "$T/repo_main.rs"; show server/rust/jwt_core.rs > "$T/jwt_core.rs"
[ -s "$T/repo_main.rs" ] && [ -s "$T/jwt_core.rs" ] || { echo "FAIL: repo (origin/main) se main.rs / jwt_core.rs nahi mili"; exit 2; }
grep -q '/// Ek hi shared HTTP client' "$T/repo_main.rs" && grep -q 'mod jwt_core;' "$T/repo_main.rs" || { echo "FAIL: repo main.rs mein jwt patch nahi — git fetch hua?"; exit 2; }
if grep -q 'mod jwt_core;' "$S" && [ -f "$J" ]; then echo "Pehle se lagi hai (jwt_core live main.rs mein maujood)."; exit 0; fi
grep -qF "$A" "$S" && grep -qF "$Z" "$S" || { echo "STOP: live main.rs mein auth_user ke markers nahi mile — kisi ne badla hai. Kuch nahi badla."; exit 3; }

# ---- keys (sirf server ke andar; screen par kabhi nahi)
for f in /opt/anexomail/.env /etc/anexomail/sync.env /opt/anexomail-rust/.env; do :; done
envv(){ for f in /opt/anexomail-rust/.env /opt/anexomail/.env /etc/anexomail/sync.env; do [ -r "$f" ] && grep -m1 -E "^$1=" "$f" | cut -d= -f2- | sed -e "s/^[\"']//" -e "s/[\"']$//"; done | head -1; }
SBU="$(envv SUPABASE4_URL)"; SBK="$(envv SUPABASE4_SERVICE_ROLE_KEY)"; SBU="${SBU%/}"
[ -n "$SBU" ] && [ -n "$SBK" ] || { echo "FAIL: SUPABASE4_URL / SERVICE_ROLE_KEY nahi mili"; exit 2; }

echo "== 0) E53 SQL laga hai? (auth_session_alive)"
R="$(curl -s -m 10 -H "apikey: $SBK" -H "authorization: Bearer $SBK" -H 'content-type: application/json' -d '{"_sid":"00000000-0000-0000-0000-000000000000"}' "$SBU/rest/v1/rpc/auth_session_alive")"
[ "$R" = "false" ] || { echo "STOP: E53 abhi nahi laga (jawab: ${R:0:80}). Pehle: sql-run.sh E53_auth_session_alive CHECK_E53 — phir yeh script."; exit 4; }
echo "   E53 theek (nakli session = false)"

echo "== 1) jwt_core ke unit tests (9) — kuch nahi badla abhi"
mkdir -p "$T/jt/src"; cp "$T/jwt_core.rs" "$T/jt/src/lib.rs"
printf '[package]\nname="jt"\nversion="0.1.0"\nedition="2024"\n[dependencies]\nserde_json="1"\nbase64="0.22"\nring="0.17"\n' > "$T/jt/Cargo.toml"
( cd "$T/jt" && nice -n 10 cargo test >"$LOG.test" 2>&1 ) || { echo "!! unit tests FAIL — kuch nahi badla:"; tail -25 "$LOG.test" | cut -c1-200; exit 1; }
grep -E "test result" "$LOG.test" | head -1

python3 - "$S" "$T/repo_main.rs" "$T/new_main.rs" <<'PY' || { echo "FAIL: patch nahi ban saka"; exit 3; }
import sys
live,repo,out=sys.argv[1:4]
A='/// Identity Supabase Auth se'; RA='/// Ek hi shared HTTP client'; Z='/// Gate DB ka `chat_access()`'
l=open(live).read(); r=open(repo).read()
blk=r[r.index(RA):r.index(Z)]  # repo mein blok http() se shuru hota hai; live mein purane auth_user marker se
la=l.index(A); lz=l.index(Z); assert la<lz
pre,post=l[:la],l[lz:]
# naya http() shared client: baqi purane per-call clients bhi usi par
pre=pre.replace('reqwest::Client::new()','http()'); post=post.replace('reqwest::Client::new()','http()')
open(out,'w').write(pre+blk+post)
PY
echo "== 2) backup (src + Cargo + binary)"
cp -p "$S" "$S.bak.$STAMP"; cp -p "$C" "$C.bak.$STAMP"; [ -f "$L" ] && cp -p "$L" "$L.bak.$STAMP"; [ -f "$BIN" ] && cp -p "$BIN" "$BIN.bak.$STAMP"
restore_all() { cp -p "$S.bak.$STAMP" "$S"; cp -p "$C.bak.$STAMP" "$C"; [ -f "$L.bak.$STAMP" ] && cp -p "$L.bak.$STAMP" "$L"; rm -f "$J"; }
cp "$T/new_main.rs" "$S"; cp "$T/jwt_core.rs" "$J"
grep -qE '^ring *=' "$C" || sed -i 's/^base64 = "0.22"/base64 = "0.22"\nring = "0.17"/' "$C"
grep -qE '^ring *=' "$C" || { restore_all; echo "FAIL: Cargo.toml mein ring nahi jud saka (base64 line nahi mili) — sab wapas"; exit 3; }
echo "== 3) cargo build --release (kuch minute; log: $LOG)"
( cd "$TARGET" && nice -n 10 cargo build --release >"$LOG" 2>&1 ); brc=$?
if [ "$brc" -ne 0 ]; then restore_all; echo "!! BUILD FAIL — sab wapas, purani binary chal rahi hai. Errors:"; grep -E '^error' -A9 "$LOG" | head -50 | cut -c1-200; exit 1; fi
echo "   build OK"
echo "== 4) pm2 restart + health"
pm2 restart anexomail-rust --update-env >/dev/null 2>&1; pm2 save >/dev/null 2>&1; sleep 4
H="$(curl -s -m 8 -o /dev/null -w '%{http_code}' "$RPC/rpc/health" 2>/dev/null)"
P="$(curl -s -m 8 -o /dev/null -w '%{http_code}' -X POST -H 'authorization: Bearer not-a-real-token' -H 'content-type: application/json' -d '{"input":{}}' "$RPC/rpc/chat.conversations.list" 2>/dev/null)"
echo "   /rpc/health $H · nakli token par rpc $P (401 chahiye)"
rollback() { echo "!! $1 — PURANI binary + src + Cargo wapas"; [ -f "$BIN.bak.$STAMP" ] && cp -p "$BIN.bak.$STAMP" "$BIN.new.$STAMP" && mv -f "$BIN.new.$STAMP" "$BIN"; restore_all; pm2 restart anexomail-rust --update-env >/dev/null 2>&1; pm2 save >/dev/null 2>&1; sleep 3; echo "   ab health: $(curl -s -m 8 -o /dev/null -w '%{http_code}' "$RPC/rpc/health" 2>/dev/null)"; exit 1; }
[ "$H" = "200" ] || rollback "health $H"
case "$P" in 401|403|404) ;; *) rollback "nakli token par $P";; esac

echo "== 5) ASLI SABOOT: test account ($EMAIL) ka token -> Rust"
LINK="$(curl -s -m 20 -H "apikey: $SBK" -H "authorization: Bearer $SBK" -H 'content-type: application/json' -d "{\"type\":\"magiclink\",\"email\":\"$EMAIL\"}" "$SBU/auth/v1/admin/generate_link")"
HASH="$(printf '%s' "$LINK" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("hashed_token",""))
except Exception: print("")')"
SESS="$(curl -s -m 20 -H "apikey: $SBK" -H 'content-type: application/json' -d "{\"type\":\"magiclink\",\"token_hash\":\"$HASH\"}" "$SBU/auth/v1/verify")"
TOK="$(printf '%s' "$SESS" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("access_token",""))
except Exception: print("")')"; unset SESS LINK HASH
if [ -z "$TOK" ]; then echo "   (test token nahi bana — saboot chhoda; health + nakli token theek the, binary rakhi)"; pm2 status anexomail-rust | head -6; echo "DONE (saboot adhoora). backup: $S.bak.$STAMP"; exit 0; fi
call() { curl -s -m 10 -o /dev/null -w '%{http_code}' -X POST -H "authorization: Bearer $TOK" -H 'content-type: application/json' -d '{"input":{}}' "$RPC/rpc/chat.conversations.list"; }
OK1="$(call)"; echo "   asli token par rpc: $OK1 (403/200 = auth chali; 401 = ghalat)"
case "$OK1" in 401|5*) unset TOK; rollback "asli token par $OK1";; esac
# latency: 24 parallel
t0=$(date +%s%N); for i in $(seq 1 24); do call >/dev/null & done; wait; t1=$(date +%s%N); echo "   24 parallel calls: $(( (t1-t0)/1000000 )) ms (local verify + cache)"
# revocation: logout -> 6 s baad wohi token 401
curl -s -m 10 -o /dev/null -X POST -H "apikey: $SBK" -H "authorization: Bearer $TOK" "$SBU/auth/v1/logout?scope=local"
sleep 26
OK2="$(call)"; echo "   logout ke baad (26 s: 20 s auth cache + 5 s session cache) wohi token: $OK2 (401 chahiye)"
unset TOK
[ "$OK2" = "401" ] || rollback "revocation kaam nahi kar rahi ($OK2) — logout ke baad bhi token chala"
pm2 status anexomail-rust | head -6
echo "DONE: Rust local JWT verify + shared client + revocation. backup: $S.bak.$STAMP"
