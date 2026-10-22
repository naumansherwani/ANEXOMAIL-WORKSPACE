#!/usr/bin/env bash
# ANEXOMAIL — Rust engine: EK build mein naye modules (Calendar v2 + People import) SAFE install, restore-on-fail.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh)
#
# Kyun: har module ke liye alag script = alag cargo build = alag restart. Yeh script jo modules repo (origin/main) mein hain
# woh SAB ek hi build mein lagata hai: ek backup, ek build, ek restart, ek health check, ek rollback.
#   cal    -> server/rust/cal_core.rs    + cal_glue.rs     (invitations, RSVP, find-a-time)       [pehle E31 SQL chalayen]
#   book   -> server/rust/book_core.rs   + book_glue.rs    (Booking page /book/<handle>: slots, book, cancel/reschedule, mails)  [pehle E59 SQL; cal ke saath]
#   overlap-> server/rust/overlap_core.rs + overlap_glue.rs (Overlap Matrix `calendar.overlap`: team ka green/amber/red waqt)  [pehle E62 SQL; cal ke saath]
#   people -> server/rust/people_core.rs + people_glue.rs  (People / Leads import, move-to-people) [koi nayi SQL nahi]
#   team   -> server/rust/team_core.rs   + team_glue.rs    (team invitations + join link, members, Teams)  [pehle E33 SQL chalayen]
#   security -> server/rust/security_core.rs + security_glue.rs (Security page: asli sessions/devices/logins + live TLS)  [pehle E39 SQL]
#   evidence -> server/rust/evidence_core.rs + evidence_glue.rs (attach_core.rs saath) (appeal ke saboot: screenshots/PDF/docs — tokio stream upload, clamd, allowlist; appeal 20,000 characters; `appeal.device.open`)  [pehle E72 SQL; attach ke saath]
#   b6     -> server/rust/b6_core.rs     + b6_glue.rs     (billing.portal: Polar customer portal — cancel/card/VAT; chaabi /etc/anexomail/pcp.key)  [koi SQL nahi]
#   b5     -> server/rust/b5_core.rs     + b5_glue.rs     (founder pages: move-in, release gate/lock/roadmap/QA run, revenue pipeline+lead, public status, outbox)  [koi nayi SQL nahi]
#   mig    -> server/rust/mig_core.rs    + mig_glue.rs (+ mig_imap.rs mig_mime.rs mig_run.rs)  (purana mailbox copy karna — IMAP App Password)
#             [pehle E35 SQL chalayen] [OPT-IN: default mein NAHI — Cargo.toml mein 2 crate judte hain (rustls, webpki-roots), isliye
#              sirf tab jab aap khud likhen:  MODULES=mig bash <(...)  ]
# Sirf kuch modules chahiye: MODULES="people" bash <(...)   (default: cal people team — jo repo mein hon)
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
# Saath mein (alag "membership guard" step, GUARD=0 se band): Rust ki "user kis organisation ka hai" wali reads mein nikale hue
#   (revoked) member ko bahar rakhna — production mail path ka chhota, anchor-based, idempotent patch (founder "haan" 19 Oct 2026).
# Bun (Brain) fallback hamesha rehta hai: Rust 404/501/502/503 de to frontend purane route par girta hai — kuch toot'ta nahi.
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"
TARGET="${TARGET:-/opt/anexomail-rust}"
RPC="${RPC:-http://127.0.0.1:3200}"
STAMP="$(date +%s)"
BIN="$TARGET/target/release/anexomail-rust"
LOG="/tmp/anexomail-rust-engine-build-$STAMP.log"
ALL_MODULES="cal book overlap people team locale device dnsauth security export attach evidence b5 b6"   # default. "mig" opt-in hai (MODULES=mig) kyunki woh Cargo.toml mein crate jodta hai.
# extra files jo kisi module ke core ke saath jaati hain (core unki #[path] se leta hai)
extras_of() { case "$1" in mig) echo "mig_imap.rs mig_mime.rs mig_run.rs";; book) echo "cal_core.rs";; overlap) echo "cal_core.rs";; evidence) echo "attach_core.rs";; esac; }
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
  have_extra=1
  for x in $(extras_of "$m"); do show "server/rust/$x" >"$T/$x"; [ -s "$T/$x" ] || have_extra=0; done
  if [ -s "$T/${m}_core.rs" ] && [ -s "$T/${m}_glue.rs" ] && [ "$have_extra" -eq 1 ]; then MODS="$MODS $m"
  elif [ -n "$EXPLICIT" ]; then echo "FAIL: repo (origin/main) mein server/rust/${m}_core.rs / ${m}_glue.rs nahi — git fetch hua?"; exit 2
  else echo "   (module '$m' abhi repo mein nahi — chhod diya)"; fi
done
MODS="${MODS# }"
[ -n "$MODS" ] || { echo "FAIL: koi module nahi mila"; exit 2; }
echo "modules: $MODS"

# live Cargo.toml ki edition (2024 upgrade ke baad bhi wahi; na mile to 2021). Live compiler: rust-toolchain.toml (agar hai) — `cd "$TARGET"` se rustc wahi leta hai.
EDITION="$(grep -E '^edition[[:space:]]*=' "$TARGET/Cargo.toml" 2>/dev/null | head -1 | tr -d ' "' | cut -d= -f2)"; EDITION="${EDITION:-2021}"
echo "== 0) pre-flight: unit tests (server par)"
echo "   (rustc $(cd "$TARGET" && rustc --version | cut -d' ' -f2), edition $EDITION)"
for m in $MODS; do
  ( cd "$TARGET" && R="$(rustup which rustc 2>/dev/null || command -v rustc)"; cd "$T" && "$R" --edition "$EDITION" --test "${m}_core.rs" -o "${m}_core_test" >"$T/rustc-$m.log" 2>&1 && "./${m}_core_test" >"$T/test-$m.log" 2>&1 ); trc=$?
  echo "   $m: $(grep -E '^test result' "$T/test-$m.log" 2>/dev/null | head -1)"
  [ "$trc" -eq 0 ] || { echo "!! $m unit tests FAIL — kuch install nahi hua. Output Claude ko paste karein:"; head -20 "$T/rustc-$m.log" | cut -c1-180; tail -15 "$T/test-$m.log" 2>/dev/null | cut -c1-180; exit 1; }
done

# live main.rs par patch (idempotent) — pre-flight aur asli dono mein yehi
patch_main() { python3 - "$1" "$MODS" <<'PY'
import sys,re
p=sys.argv[1]; mods=sys.argv[2].split(); s=open(p).read()
CFG={
 "cal":    {"public": True,  "label": "calendar",  "procs": ['"calendar.create"']},
 # book (B7c): Booking page anexomail.com/book/<handle> — slots, booking, cancel/reschedule, mails. SQL E59 PEHLE. cal module ke saath (cal_core.rs share).
 "book":   {"public": True,  "label": "booking",   "procs": ['"booking.page.get"','"booking.page.set"','"booking.public.book"'],
            "public_call": "public(&proc, &input, &headers)"},
 # overlap (W1 / calendar #4b): `calendar.overlap` — team ke working hours + OOO + free/busy se green/amber/red matrix aur best times. SQL E62 PEHLE. cal module ke saath (cal_core.rs share).
 "overlap": {"public": False, "label": "overlap",   "procs": ['"calendar.overlap"']},
 "people": {"public": False, "label": "people",    "procs": ['"people.import"','"crm.leadsImport"','"crm.leadsMoveToPeople"']},
 "team":   {"public": True,  "label": "team",      "procs": ['"team.members.list"','"team.invites.create"','"team.invite.accept"']},
 "mig":    {"public": False, "label": "migration", "procs": ['"migration.start"','"migration.providers"','"migration.verify"']},
 "locale": {"public": True,  "label": "locale",    "procs": ['"locale.pref"','"locale.bundle"','"locale.pref.set"']},
 # device: procs khaali JAAN-BOOJH kar — chat arm mein wohi naam hain (dead fallback rehta hai); yeh module unhein chat gate se PEHLE har plan ke liye pakadta hai.
 "device": {"public": False, "label": "device",    "procs": []},
 # dnsauth (D2): `mail.domains.verify` ko mail dispatch se PEHLE pakadta hai (authoritative NS); main.rs wala DoH arm dead fallback.
 "dnsauth": {"public": False, "label": "dnsauth",   "procs": []},
 # security (E39): Security page sach — auth.sessions / device_vault / audit log / live TLS. Pehle E39 SQL chalayen.
 "security": {"public": False, "label": "security",  "procs": ['"security.dashboard"','"security.sessions"']},
 # export (G36): asli data export (ZIP stream) + apni integrity halat. Extra HTTP route: GET /file/account-export?t=<ticket> (/file/download ke baad). SQL E44 PEHLE.
 "export": {"public": False, "label": "export",    "procs": ['"account.export.ticket"','"account.integrity.me"','"account.integrity.appeal"'],
            "route_marker": "export_glue::download",
            "route_after": '.route("/file/download", get(file_download))',
            "route_add": '.route("/file/account-export", get(export_glue::download))',
            # G37: blocked account guard — token ke foran baad, SAB module hooks se pehle
            "guard_marker": "export_glue::blocked(",
            "guard_code": '    // G37 — blocked/purged account: sirf export / halat / apna delete (export_glue::blocked)\n    if let Some(r) = export_glue::blocked(&proc, &token).await {\n        return r;\n    }\n\n'},
 # evidence (E72): appeal ke saboot. POST /file/appeal-evidence (tokio stream, per-user ek upload, server par 8 tak), GET /file/appeal-evidence/get?id= (malik ya reviewer).
 # `appeal.device.open` = device appeal (20..20,000 characters) + files EK transaction mein. Blocked user ko yeh procs allowed (export_core). SQL E72 PEHLE. attach_core.rs saath chahiye (need_mods).
 "evidence": {"public": False, "label": "appeal-evidence", "procs": ['"appeal.evidence.limits"','"appeal.evidence.remove"','"appeal.evidence.list"','"appeal.device.open"'],
            "need_mods": ["attach_core"],
            "route_marker": "evidence_glue::upload",
            "route_after": '.route("/file/download", get(file_download))',
            "route_add": '.route("/file/appeal-evidence", post(evidence_glue::upload))\n        .route("/file/appeal-evidence/get", get(evidence_glue::download))'},
 # b5 (G40): founder pages ki Bun-only calls Rust par — move-in, release gate/lock/roadmap, revenue pipeline/lead, public status, offline outbox. Koi nayi SQL nahi.
 # Public procs ko request headers chahiye (revenue.lead ki IP rate-limit) — isliye public_call alag.
 "b5":     {"public": True,  "label": "founder-pages", "procs": ['"movein.capacity"','"revenue.lead"','"status.public"','"founder.release.run"'],
            "public_call": "public(&proc, &input, &headers)"},
 # b6 (G16): `billing.portal` — Polar customer portal (cancel/card/VAT). Polar engine :3400 ko MUHAR-band call; chaabi /etc/anexomail/pcp.key (polar-control-plane-install.sh banata hai). Koi SQL nahi.
 "b6":     {"public": False, "label": "billing-portal", "procs": ['"billing.portal"']},
 # attach (G38): bheji jane wali mail ke attachments (stream upload, org-ke-andar SHA-256 dedup, clamd, quota). SQL E48 PEHLE.
 # Routes: POST /file/attach (upload), GET /file/attach/get?id= (download). Thread read ka `url` (jo server ka disk_path de deta tha) band + `stored` flag.
 "attach": {"public": False, "label": "attach",    "procs": ['"mail.attach.limits"','"mail.attach.remove"'],
            "route_marker": "attach_glue::upload",
            "route_after": '.route("/file/download", get(file_download))',
            "route_add": '.route("/file/attach", post(attach_glue::upload))\n        .route("/file/attach/get", get(attach_glue::download))',
            "replace": [
              ('                                                    .or_else(|| a.get("disk_path"))\n', '', 'server ka disk_path client ko nahi jata'),
              ('                                                    "size_bytes": a.get("size_bytes").and_then(|v| v.as_i64()).unwrap_or(0),\n',
               '                                                    "size_bytes": a.get("size_bytes").and_then(|v| v.as_i64()).unwrap_or(0),\n                                                    "stored": a.get("sha256").map(|v| !v.is_null()).unwrap_or(false),\n                                                    "blocked": a.get("scan").and_then(|v| v.get("clamd")).and_then(|v| v.as_str()) == Some("found"),\n', 'stored + blocked flag', '"stored": a.get("sha256")'),
              ('                                                    "stored": a.get("sha256").map(|v| !v.is_null()).unwrap_or(false),\n',
               '                                                    "stored": a.get("sha256").map(|v| !v.is_null()).unwrap_or(false),\n                                                    "blocked": a.get("scan").and_then(|v| v.get("clamd")).and_then(|v| v.as_str()) == Some("found"),\n', 'blocked flag (virus mila: bytes nahi rakhe)', '"blocked": a.get("scan")'),
            ]},
}
changed=[]
for m in mods:
    c=CFG[m]; g=m+"_glue"
    for ent in c.get("replace", []):
        fnd, rep, why = ent[0], ent[1], ent[2]
        unless = ent[3] if len(ent) > 3 else (rep or None)   # pehle se lagi ho to dobara nahi (har dafa chalane par duplicate nahi)
        if unless and unless in s:
            continue
        if fnd in s:
            s=s.replace(fnd, rep, 1); changed.append(c["label"]+" ("+why+")")
        elif rep and rep not in s:
            print("   (dhyan: main.rs mein '%s' wala hissa seedha nahi mila — yeh chhota sudhar chhoot gaya, baqi install chalta hai)"%why)
    have_mod=("mod %s;"%g) in s
    have_auth=(g+"::owns(") in s
    have_pub=(not c["public"]) or ((g+"::public_owns(") in s)
    have_route=(not c.get("route_marker")) or (c["route_marker"] in s)
    have_guard=(not c.get("guard_marker")) or (c["guard_marker"] in s)
    if have_mod and have_auth and have_pub and have_route and have_guard:
        print("main.rs: %s pehle se judi hai"%c["label"]); continue
    only_extras = have_mod and have_auth and have_pub and (not have_route or not have_guard)
    if only_extras:
        d=re.search(r'^(?:pub )?async fn dispatch\(\s*Path\(proc\)', s, re.M)
        if not d: print("PATCH FAIL: `async fn dispatch(Path(proc)...` nahi mila"); sys.exit(4)
        if not have_guard:
            bm=re.compile(r'^    let token = match bearer\(&headers\) \{', re.M).search(s, d.start())
            if not bm: print("PATCH FAIL: dispatch mein `let token = match bearer(&headers)` nahi mila"); sys.exit(4)
            e=s.find("\n    };\n", bm.start())
            if e<0: print("PATCH FAIL: token match ka end nahi mila"); sys.exit(4)
            e+=len("\n    };\n")
            s=s[:e]+"\n"+c["guard_code"].rstrip("\n")+"\n"+s[e:]
        if not have_route:
            ra=s.find(c["route_after"])
            if ra<0: print("PATCH FAIL: route anchor nahi mila: "+c["route_after"]); sys.exit(4)
            ra+=len(c["route_after"])
            s=s[:ra]+"\n        "+c["route_add"]+s[ra:]
        changed.append(c["label"]+" (guard/route)")
        continue
    if have_mod or (g+"::") in s:
        print("PATCH FAIL: main.rs mein %s adhoori judi hai — haath se dekhna padega"%c["label"]); sys.exit(4)
    for pr in c["procs"]:
        if pr in s:
            print("PATCH FAIL: live main.rs mein %s pehle se maujood hai — double-handling se bachne ke liye ruk gaya. Claude ko batayen."%pr); sys.exit(4)
    a=re.search(r'^const PORT: u16 = 3200;', s, re.M)
    if not a: print("PATCH FAIL: `const PORT: u16 = 3200;` anchor nahi mila"); sys.exit(4)
    need="".join("mod %s;\n"%n for n in c.get("need_mods", []) if ("mod %s;"%n) not in s)
    s=s[:a.start()]+need+"mod %s_core;\nmod %s;\n\n"%(m,g)+s[a.start():]
    d=re.search(r'^(?:pub )?async fn dispatch\(\s*Path\(proc\)', s, re.M)
    if not d: print("PATCH FAIL: `async fn dispatch(Path(proc)...` nahi mila"); sys.exit(4)
    if c["public"]:
        bm=re.compile(r'^    let token = match bearer\(&headers\) \{', re.M).search(s, d.start())
        if not bm: print("PATCH FAIL: dispatch mein `let token = match bearer(&headers)` nahi mila"); sys.exit(4)
        b=bm.start()
        pub=('    // %s — public proc (token se; bearer nahi chahiye). Token = DB ka random uuid.\n'
             '    if %s::public_owns(&proc) {\n        return %s::%s.await;\n    }\n\n')%(c["label"],g,g,c.get("public_call","public(&proc, &input)"))
        s=s[:b]+pub+s[b:]
    w=s.find('    if proc == "whoami" {', d.start())
    if w<0:
        w=s.find('    // 8o — founder-only expiry watch', d.start())
    if w<0: print("PATCH FAIL: whoami / 8o anchor nahi mila"); sys.exit(4)
    auth=('    // %s — Rust PRIMARY (exact-match procs). Bun route sirf fallback (Rust 404/501/502/503 par).\n'
          '    if %s::owns(&proc) {\n        return %s::dispatch(&proc, &token, &input).await;\n    }\n\n')%(c["label"],g,g)
    s=s[:w]+auth+s[w:]
    if c.get("route_marker"):
        ra=s.find(c["route_after"])
        if ra<0: print("PATCH FAIL: route anchor nahi mila: "+c["route_after"]); sys.exit(4)
        ra+=len(c["route_after"])
        s=s[:ra]+"\n        "+c["route_add"]+s[ra:]
    if c.get("guard_marker"):
        d2=re.search(r'^(?:pub )?async fn dispatch\(\s*Path\(proc\)', s, re.M)
        bm=re.compile(r'^    let token = match bearer\(&headers\) \{', re.M).search(s, d2.start())
        if not bm: print("PATCH FAIL: guard ke liye token match nahi mila"); sys.exit(4)
        e=s.find("\n    };\n", bm.start())
        if e<0: print("PATCH FAIL: token match ka end nahi mila"); sys.exit(4)
        e+=len("\n    };\n")
        s=s[:e]+"\n"+c["guard_code"].rstrip("\n")+"\n"+s[e:]
    changed.append(c["label"])
open(p,"w").write(s)
print("main.rs: judi -> "+(", ".join(changed) if changed else "(kuch nahi badla)"))
PY
}

echo "== 1) live main.rs par patch laga sakte hain? (copy par try, kuch badla nahi)"
cp "$TARGET/src/main.rs" "$T/main.rs.try"
patch_main "$T/main.rs.try"; prc=$?
[ "$prc" -eq 0 ] || { echo "!! patch nahi lag sakta — kuch install nahi hua. Output Claude ko paste karein."; exit 4; }

# Membership guard (founder "haan" 19 Oct 2026): Brain "revoke" sirf org_members.status='revoked' likhta hai, par Rust ki "ye user kis
# organisation ka hai" wali reads us ko nahi dekhti thin — nikala hua member mail khol sakta tha. Guard sirf un string-literals mein
# `&or=(status.is.null,status.neq.revoked)` jodta hai (code ko nahi). Kuch bhi safe tareeqe se patch na ho to ruk jata hai, kuch nahi badalta.
# Band karna ho: GUARD=0 bash <(...)
if [ "${GUARD:-1}" = "1" ]; then
  show docs/cursor-work/server/membership_guard.py >"$T/membership_guard.py"
  [ -s "$T/membership_guard.py" ] || { echo "FAIL: repo (origin/main) mein docs/cursor-work/server/membership_guard.py nahi — git fetch hua?"; exit 2; }
  python3 -I "$T/membership_guard.py" "$T/main.rs.try"; grc=$?
  [ "$grc" -eq 0 ] || { echo "!! membership guard safe tareeqe se nahi lag sakta — kuch install nahi hua. Upar wali lines Claude ko paste karein."; exit 4; }
fi
for h in 'fn sb()' 'fn sb_select(' 'fn sb_insert(' 'fn sb_patch(' 'fn sb_rpc(' 'fn auth_user(' 'fn ok(' 'fn err('; do
  grep -qF "$h" "$TARGET/src/main.rs" || echo "   (dhyan: live main.rs mein '$h' seedha nahi dikha — build isko pakad lega; fail hua to restore ho jayega)"
done

# Cargo.toml — SIRF mig ke liye (2 crate: rustls, webpki-roots; founder ki ijazat G30, 19 Oct 2026). Copy par try; asli file backup ke baad badalti hai.
NEED_CARGO=0
case " $MODS " in *" mig "*|*" security "*) NEED_CARGO=1;; esac   # security bhi rustls/webpki-roots (wohi 2 crate) istemal karta hai
cp "$TARGET/Cargo.toml" "$T/Cargo.toml.try"
if [ "$NEED_CARGO" -eq 1 ]; then
  echo "== 1b) Cargo.toml (sirf mig): 2 crate judte hain — copy par try"
  show docs/cursor-work/server/cargo_migration_deps.py >"$T/cargo_migration_deps.py"
  [ -s "$T/cargo_migration_deps.py" ] || { echo "FAIL: repo (origin/main) mein docs/cursor-work/server/cargo_migration_deps.py nahi — git fetch hua?"; exit 2; }
  python3 -I "$T/cargo_migration_deps.py" "$T/Cargo.toml.try"; crc=$?
  [ "$crc" -eq 0 ] || { echo "!! Cargo.toml safe tareeqe se nahi badal sakta — kuch install nahi hua. Upar wali lines Claude ko paste karein."; exit 4; }
fi

same=1
for m in $MODS; do
  for k in core glue; do cmp -s "$T/${m}_$k.rs" "$TARGET/src/${m}_$k.rs" 2>/dev/null || same=0; done
  for x in $(extras_of "$m"); do cmp -s "$T/$x" "$TARGET/src/$x" 2>/dev/null || same=0; done
done
cmp -s "$T/main.rs.try" "$TARGET/src/main.rs" || same=0
cmp -s "$T/Cargo.toml.try" "$TARGET/Cargo.toml" || same=0

if [ "$same" -eq 1 ]; then
  echo "   pehle se install hai (files same) — build ki zaroorat nahi."
else
  echo "== 2) backup + install"
  cp -p "$TARGET/src/main.rs" "$TARGET/src/main.rs.bak.$STAMP"
  for m in $MODS; do for k in core glue; do f="${m}_$k.rs"; [ -f "$TARGET/src/$f" ] && cp -p "$TARGET/src/$f" "$TARGET/src/$f.bak.$STAMP"; done
    for x in $(extras_of "$m"); do [ -f "$TARGET/src/$x" ] && cp -p "$TARGET/src/$x" "$TARGET/src/$x.bak.$STAMP"; done; done
  if [ "$NEED_CARGO" -eq 1 ]; then
    cp -p "$TARGET/Cargo.toml" "$TARGET/Cargo.toml.bak.$STAMP"
    [ -f "$TARGET/Cargo.lock" ] && cp -p "$TARGET/Cargo.lock" "$TARGET/Cargo.lock.bak.$STAMP"
  fi
  [ -f "$BIN" ] && cp -p "$BIN" "$BIN.bak.$STAMP"
  restore_src() {
    cp -p "$TARGET/src/main.rs.bak.$STAMP" "$TARGET/src/main.rs"
    for m in $MODS; do for k in core glue; do
      f="${m}_$k.rs"
      if [ -f "$TARGET/src/$f.bak.$STAMP" ]; then cp -p "$TARGET/src/$f.bak.$STAMP" "$TARGET/src/$f"; else rm -f "$TARGET/src/$f"; fi
    done
      for x in $(extras_of "$m"); do
        if [ -f "$TARGET/src/$x.bak.$STAMP" ]; then cp -p "$TARGET/src/$x.bak.$STAMP" "$TARGET/src/$x"; else rm -f "$TARGET/src/$x"; fi
      done
    done
    if [ "$NEED_CARGO" -eq 1 ]; then
      [ -f "$TARGET/Cargo.toml.bak.$STAMP" ] && cp -p "$TARGET/Cargo.toml.bak.$STAMP" "$TARGET/Cargo.toml"
      [ -f "$TARGET/Cargo.lock.bak.$STAMP" ] && cp -p "$TARGET/Cargo.lock.bak.$STAMP" "$TARGET/Cargo.lock"
    fi
  }
  for m in $MODS; do cp "$T/${m}_core.rs" "$TARGET/src/${m}_core.rs"; cp "$T/${m}_glue.rs" "$TARGET/src/${m}_glue.rs"
    for x in $(extras_of "$m"); do cp "$T/$x" "$TARGET/src/$x"; done; done
  cp "$T/main.rs.try" "$TARGET/src/main.rs"
  [ "$NEED_CARGO" -eq 1 ] && cp "$T/Cargo.toml.try" "$TARGET/Cargo.toml"

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
    [ -f "$BIN.bak.$STAMP" ] && cp -p "$BIN.bak.$STAMP" "$BIN.new.$STAMP" && mv -f "$BIN.new.$STAMP" "$BIN"   # chalti binary par seedha cp = "Text file busy"
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
      echo "   calendar.meta.set (nakli token): $(probe calendar.meta.set '{"input":{}}')"
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
    export)
      r="$(probe account.export.ticket '{"input":{}}')"
      echo "   account.export.ticket (nakli token): $r"
      r2="$(curl -s -m 8 -w ' [HTTP %{http_code}]' "$RPC/file/account-export?t=00000000000000000000000000000000000000000000dead" 2>/dev/null)"
      echo "   /file/account-export (nakli ticket): $r2"
      case "$r$r2" in
        *'"unauthorized"'*invalid_ticket*|*invalid_ticket*'"unauthorized"'*) echo "   -> export: Rust ne proc bhi pakda aur download route bhi (bina asli login/ticket ke 401 = theek). SQL E44 chala hona lazmi.";;
        *procedure_not_in_rust*|*unknown_proc*) echo "   -> export: Rust ne proc NAHI pakda — patch/build dobara dekhein";;
        *) echo "   -> export: jawab upar dekhein";;
      esac;;
    attach)
      r="$(probe mail.attach.limits '{"input":{}}')"
      echo "   mail.attach.limits (nakli token): $r"
      r2="$(curl -s -m 8 -w ' [HTTP %{http_code}]' -X POST -H 'authorization: Bearer not-a-real-token' --data-binary 'x' "$RPC/file/attach" 2>/dev/null)"
      echo "   POST /file/attach (nakli token): $r2"
      r3="$(curl -s -m 8 -w ' [HTTP %{http_code}]' "$RPC/file/attach/get?id=00000000-0000-0000-0000-000000000000" 2>/dev/null)"
      echo "   GET /file/attach/get (bina token): $r3"
      case "$r$r2$r3" in
        *'"unauthorized"'*'"unauthorized"'*'"unauthorized"'*) echo "   -> attach: Rust ne proc, upload route aur download route teeno pakde (bina asli login ke 401 = theek). SQL E48 chala hona lazmi. Storage/scan ka haal: bash docs/cursor-work/server/attach-check.sh";;
        *procedure_not_in_rust*|*unknown_proc*) echo "   -> attach: Rust ne proc NAHI pakda — patch/build dobara dekhein";;
        *) echo "   -> attach: jawab upar dekhein";;
      esac;;
    evidence)
      r="$(probe appeal.evidence.limits '{"input":{}}')"
      echo "   appeal.evidence.limits (nakli token): $r"
      r2="$(curl -s -m 8 -w ' [HTTP %{http_code}]' -X POST -H 'authorization: Bearer not-a-real-token' --data-binary 'x' "$RPC/file/appeal-evidence" 2>/dev/null)"
      echo "   POST /file/appeal-evidence (nakli token): $r2"
      r3="$(curl -s -m 8 -w ' [HTTP %{http_code}]' "$RPC/file/appeal-evidence/get?id=00000000-0000-0000-0000-000000000000" 2>/dev/null)"
      echo "   GET /file/appeal-evidence/get (bina token): $r3"
      case "$r$r2$r3" in
        *'"unauthorized"'*'"unauthorized"'*'"unauthorized"'*) echo "   -> evidence: Rust ne proc, upload route aur download route teeno pakde (bina asli login ke 401 = theek). SQL E72 chala hona lazmi.";;
        *procedure_not_in_rust*|*unknown_proc*) echo "   -> evidence: Rust ne proc NAHI pakda — patch/build dobara dekhein";;
        *) echo "   -> evidence: jawab upar dekhein";;
      esac;;
    mig)
      r="$(probe migration.providers '{"input":{}}')"
      echo "   migration.providers (nakli token): $r"
      case "$r" in
        *'"unauthorized"'*) echo "   -> mig: Rust ne proc pakda (bina asli login ke 401 = theek)";;
        *procedure_not_in_rust*|*unknown_proc*) echo "   -> mig: Rust ne proc NAHI pakda — patch/build dobara dekhein";;
        *) echo "   -> mig: jawab upar dekhein";;
      esac
      if [ -r /etc/anexomail/sync.env ]; then
        has="$( ( . /etc/anexomail/sync.env 2>/dev/null; psql "$WORKING_URL" -tAc "select to_regprocedure('public.migration_ingest(text,jsonb)') is not null" 2>/dev/null ) | tr -d ' \r\n' )"
        case "$has" in
          t) echo "   -> mig: E35 SQL lagi hui hai";;
          f) echo "   -> mig: E35 SQL abhi NAHI lagi — docs/cursor-work/sql/E35_migration_walled_garden.sql chalayen (jab tak nahi, migration shuru nahi hogi)";;
          *) echo "   -> mig: E35 SQL ka check nahi ho saka (psql / sync.env) — E35 chala hua ho to theek";;
        esac
      fi
      if timeout 6 bash -c 'exec 3<>/dev/tcp/imap.gmail.com/993' 2>/dev/null; then echo "   -> mig: server se bahar ka IMAP raasta khula hai (imap.gmail.com:993)"
      else echo "   -> mig: server imap.gmail.com:993 tak nahi pahunch raha — firewall / outbound 993 dekhein (nahi to copy shuru hi nahi hogi)"; fi;;
    dnsauth)
      r="$(probe mail.domains.verify '{"input":{"domain_id":"x"}}')"
      echo "   mail.domains.verify (nakli token): $r"
      case "$r" in
        *'"unauthorized"'*) echo "   -> dnsauth: Rust ne proc pakda (nakli login 401 = theek)";;
        *) echo "   -> dnsauth: jawab upar dekhein";;
      esac
      for h in 1.1.1.1 8.8.8.8; do
        if timeout 4 bash -c "exec 3<>/dev/udp/$h/53" 2>/dev/null; then echo "   -> server se $h:53 (UDP) ka raasta khula"; else echo "   -> $h:53 tak raasta nahi — authoritative check public DoH par wapas chalega"; fi
      done;;
    security)
      r="$(probe security.dashboard '{"input":{}}')"
      echo "   security.dashboard (nakli token): $r"
      case "$r" in
        *'"unauthorized"'*) echo "   -> security: Rust ne proc pakda (nakli login 401 = theek)";;
        *) echo "   -> security: jawab upar dekhein";;
      esac
      has="$( ( . /etc/anexomail/sync.env 2>/dev/null; psql "$WORKING_URL" -tAc "select to_regprocedure('public.sec_dashboard(uuid,uuid)') is not null" 2>/dev/null ) | tr -d ' \r\n' )"
      case "$has" in
        t) echo "   -> security: E39 SQL lagi hui hai";;
        f) echo "   -> security: E39 SQL abhi NAHI lagi — tab tak page purane Bun route par chalta hai (toot-ta nahi). docs/cursor-work/sql/E39_security_truth.sql chalayen";;
        *) echo "   -> security: E39 ka check nahi ho saka (psql / sync.env)";;
      esac
      for hp in "anexomail.com 443" "mail.anexomail.com 993"; do
        set -- $hp
        v="$(echo | timeout 6 openssl s_client -connect 127.0.0.1:$2 -servername "$1" -verify_return_error 2>/dev/null | grep -E '^ *(Protocol|Verify return code)' | tr -s ' ' | tr '\n' ' ')"
        echo "   -> TLS $1:$2 => ${v:-jawab nahi}"
      done;;
    device)
      r="$(probe chat.device.trust.list '{"input":{}}')"
      echo "   chat.device.trust.list (nakli token): $r"
      case "$r" in
        *'"unauthorized"'*) echo "   -> device: Rust ne proc chat gate se PEHLE pakda (nakli login 401 = theek; asli Basic login ab 403 nahi)";;
        *chat_not_entitled*) echo "   -> device: abhi bhi chat gate — patch/build dobara dekhein";;
        *) echo "   -> device: jawab upar dekhein";;
      esac;;
    locale)
      r1="$(curl -s -m 8 -w ' [HTTP %{http_code}]' -X POST -H 'content-type: application/json' -d '{"input":{"tag":"ur-PK"}}' "$RPC/rpc/locale.bundle" 2>/dev/null)"
      r2="$(probe locale.pref '{"input":{}}')"
      echo "   locale.bundle ur-PK (public): $(printf '%s' "$r1" | cut -c1-110)"
      echo "   locale.pref (nakli token): $r2"
      r3="$(probe locale.uipref '{"input":{}}')"
      echo "   locale.uipref (nakli token): $r3"
      case "$r3" in
        *'"unauthorized"'*) echo "   -> locale.uipref: Rust ne proc pakda (nakli login 401 = theek). SQL E57 chala hona lazmi.";;
        *procedure_not_in_rust*) echo "   -> locale.uipref: Rust ne proc NAHI pakda — patch/build dobara dekhein";;
        *) echo "   -> locale.uipref: jawab upar dekhein";;
      esac
      case "$r1$r2" in
        *'"tag":"ur-PK"'*'"unauthorized"'*) echo "   -> locale: Rust ne dono proc pakde (bundle 200, nakli login 401 = theek) — browser ke 404 band";;
        *procedure_not_in_rust*) echo "   -> locale: Rust ne proc NAHI pakda — patch/build dobara dekhein";;
        *) echo "   -> locale: jawab upar dekhein";;
      esac;;
    b5)
      r1="$(curl -s -m 10 -w ' [HTTP %{http_code}]' -X POST -H 'content-type: application/json' -d '{"input":{}}' "$RPC/rpc/status.public" 2>/dev/null)"
      r2="$(curl -s -m 10 -w ' [HTTP %{http_code}]' -X POST -H 'content-type: application/json' -d '{"input":{}}' "$RPC/rpc/movein.capacity" 2>/dev/null)"
      r3="$(probe founder.release.run '{"input":{}}')"
      r4="$(probe founder.revenue.pipeline '{"input":{}}')"
      r5="$(probe founder.brain.command '{"input":{}}')"
      echo "   status.public (public): $(printf '%s' "$r1" | cut -c1-150)"
      echo "   movein.capacity (public): $(printf '%s' "$r2" | cut -c1-110)"
      echo "   founder.release.run (nakli token): $r3"
      echo "   founder.revenue.pipeline (nakli token): $r4"
      echo "   founder.brain.command (nakli token): $r5"
      case "$r1$r3$r4$r5" in
        *'"state"'*'"unauthorized"'*'"unauthorized"'*'"unauthorized"'*) echo "   -> b5: Rust ne public status bhi diya aur founder procs (command center samet) bhi pakde (nakli login 401 = theek).";;
        *procedure_not_in_rust*|*unknown_proc*) echo "   -> b5: Rust ne proc NAHI pakda — patch/build dobara dekhein";;
        *) echo "   -> b5: jawab upar dekhein";;
      esac;;
    b6)
      r="$(probe billing.portal '{"input":{}}')"
      echo "   billing.portal (nakli token): $r"
      case "$r" in
        *'"unauthorized"'*) echo "   -> b6: Rust ne billing.portal pakda (bina asli login ke 401 = theek). Asli test: billing page par Manage billing button.";;
        *procedure_not_in_rust*|*unknown_proc*) echo "   -> b6: Rust ne proc NAHI pakda — patch/build dobara dekhein";;
        *) echo "   -> b6: jawab upar dekhein";;
      esac;;
    book)
      r1="$(curl -s -m 8 -w ' [HTTP %{http_code}]' -X POST -H 'content-type: application/json' -d '{"input":{"handle":"zz-no-such-page"}}' "$RPC/rpc/booking.public.page" 2>/dev/null)"
      r2="$(probe booking.page.get '{"input":{}}')"
      r3="$(curl -s -m 8 -w ' [HTTP %{http_code}]' -X POST -H 'content-type: application/json' -d '{"input":{"token":"00000000-0000-4000-8000-000000000000"}}' "$RPC/rpc/booking.manage.lookup" 2>/dev/null)"
      echo "   booking.public.page (nakli handle): $(printf '%s' "$r1" | cut -c1-140)"
      echo "   booking.page.get (nakli token): $r2"
      echo "   booking.manage.lookup (nakli token): $(printf '%s' "$r3" | cut -c1-140)"
      case "$r1$r2$r3" in
        *procedure_not_in_rust*|*unknown_proc*) echo "   -> book: Rust ne proc NAHI pakda — patch/build dobara dekhein";;
        *booking_sql_missing*) echo "   -> book: Rust ne proc pakda par SQL E59 nahi lagi — pehle: E59_booking_page CHECK_E59";;
        *'"not_found"'*'"unauthorized"'*'"not_found"'*) echo "   -> book: Rust ne public + login-wale dono procs pakde aur E59 SQL lagi hui hai (nakli handle/link par not_found, nakli login 401 = theek).";;
        *) echo "   -> book: jawab upar dekhein";;
      esac;;
    overlap)
      r="$(probe calendar.overlap '{"input":{"addresses":[]}}')"
      echo "   calendar.overlap (nakli token): $r"
      case "$r" in
        *'"unauthorized"'*) echo "   -> overlap: Rust ne calendar.overlap pakda (nakli login 401 = theek). SQL E62 chala hona lazmi (asli test: calendar mein Find a time / team overlay).";;
        *procedure_not_in_rust*|*unknown_proc*) echo "   -> overlap: Rust ne proc NAHI pakda — patch/build dobara dekhein";;
        *) echo "   -> overlap: jawab upar dekhein";;
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
if [ "$same" -eq 1 ]; then
  echo "   (kuch badla nahi — wapas lene ki zaroorat nahi)"
else
  # Sahi rollback: har file apne .bak se wapas (bak na ho to sirf wahi file hatao jo is install ne nayi rakhi thi). Shared extras (jaise cal_core.rs)
  # kabhi seedhe delete nahi hote. Backup binary ho to build ki zaroorat nahi (turant wapas); na ho to hi cargo build.
  RB="/root/rust-rollback-$STAMP.sh"
  {
    echo '#!/bin/bash'
    echo 'set -u'
    echo 'command -v cargo >/dev/null 2>&1 || export PATH="$HOME/.cargo/bin:$PATH"'
    echo "S=\"$TARGET/src\"; STAMP=\"$STAMP\""
    echo 'cp -p "$S/main.rs.bak.$STAMP" "$S/main.rs" || { echo "main.rs backup nahi mili — ruk gaya"; exit 1; }'
    for m in $MODS; do
      for f in ${m}_core.rs ${m}_glue.rs $(extras_of "$m"); do
        echo "if [ -f \"\$S/$f.bak.\$STAMP\" ]; then cp -p \"\$S/$f.bak.\$STAMP\" \"\$S/$f\"; else rm -f \"\$S/$f\"; fi"
      done
    done
    if [ "$NEED_CARGO" -eq 1 ]; then
      echo "cp -p \"$TARGET/Cargo.toml.bak.$STAMP\" \"$TARGET/Cargo.toml\"; [ -f \"$TARGET/Cargo.lock.bak.$STAMP\" ] && cp -p \"$TARGET/Cargo.lock.bak.$STAMP\" \"$TARGET/Cargo.lock\""
    fi
    echo "if [ -f \"$BIN.bak.$STAMP\" ]; then cp -p \"$BIN.bak.$STAMP\" \"$BIN.new.$STAMP\" && mv -f \"$BIN.new.$STAMP\" \"$BIN\"; else (cd \"$TARGET\" && cargo build --release) || { echo 'build fail'; exit 1; }; fi"
    echo 'pm2 restart anexomail-rust --update-env && pm2 save >/dev/null 2>&1'
    echo "sleep 3; echo \"health: \$(curl -s -m 8 -o /dev/null -w '%{http_code}' $RPC/rpc/health)\""
  } >"$RB" 2>/dev/null
  chmod +x "$RB" 2>/dev/null
  echo "   wapas lene ke liye (sirf yeh ek command): bash $RB"
fi
