#!/usr/bin/env bash
# ANEXOMAIL — Rust engine: EK build mein naye modules (Calendar v2 + People import) SAFE install, restore-on-fail.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh)
#
# Kyun: har module ke liye alag script = alag cargo build = alag restart. Yeh script jo modules repo (origin/main) mein hain
# woh SAB ek hi build mein lagata hai: ek backup, ek build, ek restart, ek health check, ek rollback.
#   cal    -> server/rust/cal_core.rs    + cal_glue.rs     (invitations, RSVP, find-a-time)       [pehle E31 SQL chalayen]
#   people -> server/rust/people_core.rs + people_glue.rs  (People / Leads import, move-to-people) [koi nayi SQL nahi]
#   team   -> server/rust/team_core.rs   + team_glue.rs    (team invitations + join link, members, Teams)  [pehle E33 SQL chalayen]
# Sirf kuch modules chahiye: MODULES="people" bash <(...)   (default: jo repo mein hon sab)
#
# Kya karta hai (sirf anexomail-rust; polar-rust-payment :3400, Brain, web, Cargo.toml, .env ko haath nahi):
#   0. har module ke *_core.rs ke unit tests SERVER PAR chalata hai (std-only, kuch second) — fail => kuch nahi badalta.
#   1. LIVE src/main.rs ko repo se REPLACE nahi karta — har module ke liye chhoti jagah PATCH karta hai (anchor-based, idempotent):
#        `mod X_core; mod X_glue;` + (cal ke liye) public RSVP proc + authenticated procs. Anchor na mile => kuch nahi badalta.
#      Agar live main.rs mein yehi proc-naam pehle se kisi aur code ke paas hon => ruk jata hai (double-handling nahi).
#   2. src aur chalti binary ka backup (.bak.<ts>) pehle.
#   3. `nice cargo build --release` (kuch minute). Build FAIL => src wapas, purani binary chalti rehti hai, errors dikhata hai.
#   4. Build OK => pm2 restart anexomail-rust + /rpc/health; 200 na aaye => purani binary + src wapas.
#   5. Naye procs ka live saboot (nakli token se): Rust ne proc pakda ya nahi.
# Bun (Brain) fallback hamesha rehta hai: Rust 404/501/502/503 de to frontend purane route par girta hai — kuch toot'ta nahi.
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"
TARGET="${TARGET:-/opt/anexomail-rust}"
RPC="${RPC:-http://127.0.0.1:3200}"
STAMP="$(date +%s)"
BIN="$TARGET/target/release/anexomail-rust"
LOG="/tmp/anexomail-rust-engine-build-$STAMP.log"
ALL_MODULES="cal people team"
EXPLICIT="${MODULES:-}"
WANT="${MODULES:-$ALL_MODULES}"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
show() { git -C "$REPO" show "origin/main:$1" 2>/dev/null; }

[ -f "$TARGET/src/main.rs" ] || { echo "FAIL: $TARGET/src/main.rs nahi mili — Rust engine yahan install nahi hai"; exit 2; }
command -v cargo >/dev/null 2>&1 || export PATH="$HOME/.cargo/bin:$PATH"
command -v cargo >/dev/null 2>&1 || { echo "FAIL: cargo nahi mila"; exit 2; }

MODS=""
for m in $WANT; do
  show "server/rust/${m}_core.rs" >"$T/${m}_core.rs"; show "server/rust/${m}_glue.rs" >"$T/${m}_glue.rs"
  if [ -s "$T/${m}_core.rs" ] && [ -s "$T/${m}_glue.rs" ]; then MODS="$MODS $m"
  elif [ -n "$EXPLICIT" ]; then echo "FAIL: repo (origin/main) mein server/rust/${m}_core.rs / ${m}_glue.rs nahi — git fetch hua?"; exit 2
  else echo "   (module '$m' abhi repo mein nahi — chhod diya)"; fi
done
MODS="${MODS# }"
[ -n "$MODS" ] || { echo "FAIL: koi module nahi mila"; exit 2; }
echo "modules: $MODS"

echo "== 0) pre-flight: unit tests (server par)"
for m in $MODS; do
  ( cd "$T" && rustc --edition 2021 --test "${m}_core.rs" -o "${m}_core_test" >"$T/rustc-$m.log" 2>&1 && "./${m}_core_test" >"$T/test-$m.log" 2>&1 ); trc=$?
  echo "   $m: $(grep -E '^test result' "$T/test-$m.log" 2>/dev/null | head -1)"
  [ "$trc" -eq 0 ] || { echo "!! $m unit tests FAIL — kuch install nahi hua. Output Claude ko paste karein:"; head -20 "$T/rustc-$m.log" | cut -c1-180; tail -15 "$T/test-$m.log" 2>/dev/null | cut -c1-180; exit 1; }
done

# live main.rs par patch (idempotent) — pre-flight aur asli dono mein yehi
patch_main() { python3 - "$1" "$MODS" <<'PY'
import sys,re
p=sys.argv[1]; mods=sys.argv[2].split(); s=open(p).read()
CFG={
 "cal":    {"public": True,  "label": "calendar",  "procs": ['"calendar.create"']},
 "people": {"public": False, "label": "people",    "procs": ['"people.import"','"crm.leadsImport"','"crm.leadsMoveToPeople"']},
 "team":   {"public": True,  "label": "team",      "procs": ['"team.members.list"','"team.invites.create"','"team.invite.accept"']},
}
changed=[]
for m in mods:
    c=CFG[m]; g=m+"_glue"
    have_mod=("mod %s;"%g) in s
    have_auth=(g+"::owns(") in s
    have_pub=(not c["public"]) or ((g+"::public_owns(") in s)
    if have_mod and have_auth and have_pub:
        print("main.rs: %s pehle se judi hai"%c["label"]); continue
    if have_mod or (g+"::") in s:
        print("PATCH FAIL: main.rs mein %s adhoori judi hai — haath se dekhna padega"%c["label"]); sys.exit(4)
    for pr in c["procs"]:
        if pr in s:
            print("PATCH FAIL: live main.rs mein %s pehle se maujood hai — double-handling se bachne ke liye ruk gaya. Claude ko batayen."%pr); sys.exit(4)
    a=re.search(r'^const PORT: u16 = 3200;', s, re.M)
    if not a: print("PATCH FAIL: `const PORT: u16 = 3200;` anchor nahi mila"); sys.exit(4)
    s=s[:a.start()]+"mod %s_core;\nmod %s;\n\n"%(m,g)+s[a.start():]
    d=re.search(r'^(?:pub )?async fn dispatch\(\s*Path\(proc\)', s, re.M)
    if not d: print("PATCH FAIL: `async fn dispatch(Path(proc)...` nahi mila"); sys.exit(4)
    if c["public"]:
        bm=re.compile(r'^    let token = match bearer\(&headers\) \{', re.M).search(s, d.start())
        if not bm: print("PATCH FAIL: dispatch mein `let token = match bearer(&headers)` nahi mila"); sys.exit(4)
        b=bm.start()
        pub=('    // %s — public proc (token se; bearer nahi chahiye). Token = DB ka random uuid.\n'
             '    if %s::public_owns(&proc) {\n        return %s::public(&proc, &input).await;\n    }\n\n')%(c["label"],g,g)
        s=s[:b]+pub+s[b:]
    w=s.find('    if proc == "whoami" {', d.start())
    if w<0:
        w=s.find('    // 8o — founder-only expiry watch', d.start())
    if w<0: print("PATCH FAIL: whoami / 8o anchor nahi mila"); sys.exit(4)
    auth=('    // %s — Rust PRIMARY (exact-match procs). Bun route sirf fallback (Rust 404/501/502/503 par).\n'
          '    if %s::owns(&proc) {\n        return %s::dispatch(&proc, &token, &input).await;\n    }\n\n')%(c["label"],g,g)
    s=s[:w]+auth+s[w:]
    changed.append(c["label"])
open(p,"w").write(s)
print("main.rs: judi -> "+(", ".join(changed) if changed else "(kuch nahi badla)"))
PY
}

echo "== 1) live main.rs par patch laga sakte hain? (copy par try, kuch badla nahi)"
cp "$TARGET/src/main.rs" "$T/main.rs.try"
patch_main "$T/main.rs.try"; prc=$?
[ "$prc" -eq 0 ] || { echo "!! patch nahi lag sakta — kuch install nahi hua. Output Claude ko paste karein."; exit 4; }
for h in 'fn sb()' 'fn sb_select(' 'fn sb_insert(' 'fn sb_patch(' 'fn sb_rpc(' 'fn auth_user(' 'fn ok(' 'fn err('; do
  grep -qF "$h" "$TARGET/src/main.rs" || echo "   (dhyan: live main.rs mein '$h' seedha nahi dikha — build isko pakad lega; fail hua to restore ho jayega)"
done

same=1
for m in $MODS; do
  for k in core glue; do cmp -s "$T/${m}_$k.rs" "$TARGET/src/${m}_$k.rs" 2>/dev/null || same=0; done
done
cmp -s "$T/main.rs.try" "$TARGET/src/main.rs" || same=0

if [ "$same" -eq 1 ]; then
  echo "   pehle se install hai (files same) — build ki zaroorat nahi."
else
  echo "== 2) backup + install"
  cp -p "$TARGET/src/main.rs" "$TARGET/src/main.rs.bak.$STAMP"
  for m in $MODS; do for k in core glue; do f="${m}_$k.rs"; [ -f "$TARGET/src/$f" ] && cp -p "$TARGET/src/$f" "$TARGET/src/$f.bak.$STAMP"; done; done
  [ -f "$BIN" ] && cp -p "$BIN" "$BIN.bak.$STAMP"
  restore_src() {
    cp -p "$TARGET/src/main.rs.bak.$STAMP" "$TARGET/src/main.rs"
    for m in $MODS; do for k in core glue; do
      f="${m}_$k.rs"
      if [ -f "$TARGET/src/$f.bak.$STAMP" ]; then cp -p "$TARGET/src/$f.bak.$STAMP" "$TARGET/src/$f"; else rm -f "$TARGET/src/$f"; fi
    done; done
  }
  for m in $MODS; do cp "$T/${m}_core.rs" "$TARGET/src/${m}_core.rs"; cp "$T/${m}_glue.rs" "$TARGET/src/${m}_glue.rs"; done
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
probe() { curl -s -m 8 -w ' [HTTP %{http_code}]' -X POST -H "authorization: Bearer not-a-real-token" -H 'content-type: application/json' -d "$2" "$RPC/rpc/$1" 2>/dev/null; }
for m in $MODS; do
  case "$m" in
    cal)
      r1="$(curl -s -m 8 -w ' [HTTP %{http_code}]' -X POST -H 'content-type: application/json' -d '{"input":{"token":"00000000-0000-0000-0000-000000000000"}}' "$RPC/rpc/calendar.rsvp.lookup" 2>/dev/null)"
      echo "   calendar.rsvp.lookup (nakli uuid): $r1"
      echo "   calendar.create (nakli token): $(probe calendar.create '{"input":{}}')"
      case "$r1" in
        *calendar_v2_sql_missing*) echo "   -> Rust ne calendar proc pakda, par E31 SQL abhi nahi lagi — docs/cursor-work/sql/E31_calendar_v2.sql chalayen";;
        *"not valid"*) echo "   -> calendar: Rust ne proc pakda aur E31 SQL lagi hui hai (nakli link par 'not valid' = theek)";;
        *) echo "   -> calendar: jawab upar dekhein";;
      esac;;
    team)
      r1="$(curl -s -m 8 -w ' [HTTP %{http_code}]' -X POST -H 'content-type: application/json' -d '{"input":{"token":"00000000-0000-0000-0000-000000000000"}}' "$RPC/rpc/team.invite.lookup" 2>/dev/null)"
      echo "   team.invite.lookup (nakli uuid): $r1"
      echo "   team.members.list (nakli token): $(probe team.members.list '{"input":{}}')"
      case "$r1" in
        *team_v1_sql_missing*) echo "   -> team: Rust ne proc pakda, par E33 SQL abhi nahi lagi — docs/cursor-work/sql/E33_team_invites.sql chalayen";;
        *invite_not_found*) echo "   -> team: Rust ne proc pakda aur E33 SQL lagi hui hai (nakli link par 'not valid' = theek)";;
        *procedure_not_in_rust*|*unknown_proc*) echo "   -> team: Rust ne proc NAHI pakda — patch/build dobara dekhein";;
        *) echo "   -> team: jawab upar dekhein";;
      esac;;
    people)
      r="$(probe people.import '{"input":{"rows":[]}}')"
      echo "   people.import (nakli token): $r"
      case "$r" in
        *'"unauthorized"'*) echo "   -> people: Rust ne proc pakda (bina asli login ke 401 = theek)";;
        *procedure_not_in_rust*) echo "   -> people: Rust ne proc NAHI pakda — patch/build dobara dekhein";;
        *) echo "   -> people: jawab upar dekhein";;
      esac;;
  esac
done
pm2 describe anexomail-rust 2>/dev/null | grep -E "status|restarts|uptime" | sed 's/^/   /' | head -4
echo "OK — Rust par: $MODS. (polar-rust-payment :3400 aur Brain ko haath nahi lagaya; Bun routes fallback ke taur par jaisi thin waisi hain)"
echo "   wapas lene ke liye: cp $TARGET/src/main.rs.bak.$STAMP $TARGET/src/main.rs && (cd $TARGET/src && rm -f $(for m in $MODS; do printf '%s_core.rs %s_glue.rs ' $m $m; done)) && (cd $TARGET && cargo build --release) && pm2 restart anexomail-rust --update-env"
