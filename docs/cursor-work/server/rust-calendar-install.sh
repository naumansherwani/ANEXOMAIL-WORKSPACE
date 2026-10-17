#!/usr/bin/env bash
# TIP: Calendar + People (aur aage ke modules) EK build mein: docs/cursor-work/server/rust-engine-install.sh — do alag build ki zaroorat nahi.
# ANEXOMAIL — Rust engine: Calendar v2 SAFE install (invitations + RSVP + find-a-time), restore-on-fail.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-calendar-install.sh)
#
# Kya karta hai (sirf anexomail-rust; polar-rust-payment :3400, Brain, web ko haath nahi lagata; Cargo.toml / .env ko haath nahi):
#   0. cal_core.rs ke 21 unit tests SERVER PAR chalata hai (std-only, kuch second) — fail => kuch nahi badalta.
#   1. LIVE src/main.rs ko repo se REPLACE nahi karta — sirf 3 chhoti jagah PATCH karta hai (anchor-based, idempotent):
#        `mod cal_core; mod cal_glue;`  +  public RSVP proc (bearer se pehle)  +  authenticated calendar procs.
#      Anchor na mile => kuch nahi badalta.
#   2. cal_core.rs + cal_glue.rs ko src/ mein rakhta hai, src ka aur chalti binary ka backup (.bak.<ts>) pehle.
#   3. `nice cargo build --release` (kuch minute). Build FAIL => src wapas, purani binary chalti rehti hai, errors dikhata hai.
#   4. Build OK => pm2 restart anexomail-rust + /rpc/health; 200 na aaye => purani binary + src wapas.
#   5. Naye procs ka live saboot (nakli token se): Rust ne proc pakda ya nahi.
# SQL: pehle docs/cursor-work/sql/E31_calendar_v2.sql chalayen (warna procs 501 dete hain aur frontend purane route par girta hai — kuch toot'ta nahi).
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"
TARGET="${TARGET:-/opt/anexomail-rust}"
RPC="${RPC:-http://127.0.0.1:3200}"
STAMP="$(date +%s)"
BIN="$TARGET/target/release/anexomail-rust"
LOG="/tmp/anexomail-rust-calendar-build-$STAMP.log"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
show() { git -C "$REPO" show "origin/main:$1" 2>/dev/null; }

for f in cal_core.rs cal_glue.rs; do
  show "server/rust/$f" >"$T/$f"; [ -s "$T/$f" ] || { echo "FAIL: repo (origin/main) se server/rust/$f nahi mili — git fetch hua?"; exit 2; }
done
[ -f "$TARGET/src/main.rs" ] || { echo "FAIL: $TARGET/src/main.rs nahi mili — Rust engine yahan install nahi hai"; exit 2; }
command -v cargo >/dev/null 2>&1 || export PATH="$HOME/.cargo/bin:$PATH"
command -v cargo >/dev/null 2>&1 || { echo "FAIL: cargo nahi mila"; exit 2; }

echo "== 0) pre-flight: cal_core ke unit tests (server par)"
( cd "$T" && rustc --edition 2021 --test cal_core.rs -o cal_core_test >"$T/rustc.log" 2>&1 && ./cal_core_test >"$T/test.log" 2>&1 ); trc=$?
tail -3 "$T/test.log" 2>/dev/null
[ "$trc" -eq 0 ] || { echo "!! unit tests FAIL — kuch install nahi hua. Output Claude ko paste karein:"; head -20 "$T/rustc.log" | cut -c1-180; exit 1; }

# live main.rs par patch (idempotent) — pre-flight aur asli dono mein yehi
patch_main() { python3 - "$1" <<'PY'
import sys,re
p=sys.argv[1]; s=open(p).read()
if "mod cal_glue;" in s and "cal_glue::owns(" in s and "cal_glue::public_owns(" in s:
    print("main.rs: calendar pehle se judi hai"); sys.exit(0)
if "mod cal_glue;" in s or "cal_glue::" in s:
    print("PATCH FAIL: main.rs mein calendar adhoori judi hai — haath se dekhna padega"); sys.exit(4)
a=re.search(r'^const PORT: u16 = 3200;', s, re.M)
if not a: print("PATCH FAIL: `const PORT: u16 = 3200;` anchor nahi mila"); sys.exit(4)
s=s[:a.start()]+"mod cal_core;\nmod cal_glue;\n\n"+s[a.start():]
d=re.search(r'^(?:pub )?async fn dispatch\(\s*Path\(proc\)', s, re.M)
if not d: print("PATCH FAIL: `async fn dispatch(Path(proc)...` nahi mila"); sys.exit(4)
bm=re.compile(r'^    let token = match bearer\(&headers\) \{', re.M).search(s, d.start())
if not bm: print("PATCH FAIL: dispatch mein `let token = match bearer(&headers)` nahi mila"); sys.exit(4)
b=bm.start()
pub='''    // Calendar v2 — invitation RSVP (public, token se; bearer nahi chahiye). Token = DB ka random uuid.
    if cal_glue::public_owns(&proc) {
        return cal_glue::public(&proc, &input).await;
    }

'''
s=s[:b]+pub+s[b:]
w=s.find('    if proc == "whoami" {', d.start())
if w<0:
    w=s.find('    // 8o — founder-only expiry watch', d.start())
if w<0: print("PATCH FAIL: whoami / 8o anchor nahi mila"); sys.exit(4)
auth='''    // Calendar v2 (invitations, RSVP, find-a-time) — Rust PRIMARY. E31 SQL na ho to 501 => frontend legacy route.
    if cal_glue::owns(&proc) {
        return cal_glue::dispatch(&proc, &token, &input).await;
    }

'''
s=s[:w]+auth+s[w:]
open(p,"w").write(s); print("main.rs: calendar judi (mod + public proc + authenticated procs)")
PY
}

echo "== 1) live main.rs par patch laga sakte hain? (copy par try, kuch badla nahi)"
cp "$TARGET/src/main.rs" "$T/main.rs.try"
patch_main "$T/main.rs.try"; prc=$?
[ "$prc" -eq 0 ] || { echo "!! patch nahi lag sakta — kuch install nahi hua. Output Claude ko paste karein."; exit 4; }

if cmp -s "$T/cal_core.rs" "$TARGET/src/cal_core.rs" 2>/dev/null && cmp -s "$T/cal_glue.rs" "$TARGET/src/cal_glue.rs" 2>/dev/null && cmp -s "$T/main.rs.try" "$TARGET/src/main.rs"; then
  echo "   pehle se install hai (files same) — build ki zaroorat nahi."
else
  echo "== 2) backup + install"
  mkdir -p "$TARGET/src"
  cp -p "$TARGET/src/main.rs" "$TARGET/src/main.rs.bak.$STAMP"
  for f in cal_core.rs cal_glue.rs; do [ -f "$TARGET/src/$f" ] && cp -p "$TARGET/src/$f" "$TARGET/src/$f.bak.$STAMP"; done
  [ -f "$BIN" ] && cp -p "$BIN" "$BIN.bak.$STAMP"
  restore_src() {
    cp -p "$TARGET/src/main.rs.bak.$STAMP" "$TARGET/src/main.rs"
    for f in cal_core.rs cal_glue.rs; do
      if [ -f "$TARGET/src/$f.bak.$STAMP" ]; then cp -p "$TARGET/src/$f.bak.$STAMP" "$TARGET/src/$f"; else rm -f "$TARGET/src/$f"; fi
    done
  }
  cp "$T/cal_core.rs" "$TARGET/src/cal_core.rs"; cp "$T/cal_glue.rs" "$TARGET/src/cal_glue.rs"
  cp "$T/main.rs.try" "$TARGET/src/main.rs"

  echo "== 3) cargo build --release (kuch minute lagte hain; server par load kam rakhne ke liye nice; log: $LOG)"
  ( cd "$TARGET" && nice -n 10 cargo build --release >"$LOG" 2>&1 ); brc=$?
  if [ "$brc" -ne 0 ]; then
    restore_src
    echo "!! BUILD FAIL — src wapas kar diya, purani binary chal rahi hai (kuch restart nahi hua). Pehle errors:"
    grep -E '^error' -A9 "$LOG" | head -70 | cut -c1-200
    echo "   (poora log: $LOG) — upar wale lines chat mein Claude ko paste karein."
    exit 1
  fi
  echo "   build OK ($(tail -1 "$LOG" | cut -c1-100))"

  echo "== 4) pm2 restart + health"
  pm2 restart anexomail-rust --update-env >/dev/null 2>&1 || echo "!! pm2 restart fail"
  pm2 save >/dev/null 2>&1
  sleep 3
  code="$(curl -s -m 8 -o /dev/null -w '%{http_code}' "$RPC/rpc/health" 2>/dev/null)"
  if [ "$code" != "200" ]; then
    echo "!! naye build par /rpc/health = $code — PURANI binary + src wapas laga raha hoon"
    [ -f "$BIN.bak.$STAMP" ] && cp -p "$BIN.bak.$STAMP" "$BIN"
    restore_src
    pm2 restart anexomail-rust --update-env >/dev/null 2>&1; pm2 save >/dev/null 2>&1
    sleep 3
    echo "   ab health: $(curl -s -m 8 -o /dev/null -w '%{http_code}' "$RPC/rpc/health" 2>/dev/null)"
    exit 1
  fi
fi

echo "== 5) live saboot (nakli token se — kuch nahi badalta)"
r1="$(curl -s -m 8 -w ' [HTTP %{http_code}]' -X POST -H 'content-type: application/json' -d '{"input":{"token":"00000000-0000-0000-0000-000000000000"}}' "$RPC/rpc/calendar.rsvp.lookup" 2>/dev/null)"
echo "   calendar.rsvp.lookup (nakli uuid): $r1"
r2="$(curl -s -m 8 -w ' [HTTP %{http_code}]' -X POST -H 'authorization: Bearer not-a-real-token' -H 'content-type: application/json' -d '{"input":{}}' "$RPC/rpc/calendar.create" 2>/dev/null)"
echo "   calendar.create (nakli token): $r2"
case "$r1" in
  *calendar_v2_sql_missing*) echo "   -> Rust ne proc pakda, par E31 SQL abhi nahi lagi (ya PostgREST ne naye columns nahi dekhe) — E31 chalayen";;
  *"not valid"*) echo "   -> Rust ne proc pakda aur E31 SQL lagi hui hai (nakli link par 'not valid' = theek)";;
  *) echo "   -> jawab upar dekhein (Rust ne pakda ho to JSON mein 'error' ka code hoga)";;
esac
pm2 describe anexomail-rust 2>/dev/null | grep -E "status|restarts|uptime" | sed 's/^/   /' | head -4
echo "OK — Rust par Calendar v2. (polar-rust-payment :3400 aur Brain ko haath nahi lagaya)"
echo "   wapas lene ke liye: cp $TARGET/src/main.rs.bak.$STAMP $TARGET/src/main.rs && rm -f $TARGET/src/cal_core.rs $TARGET/src/cal_glue.rs && (cd $TARGET && cargo build --release) && pm2 restart anexomail-rust --update-env"
