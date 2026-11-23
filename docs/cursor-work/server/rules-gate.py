#!/usr/bin/env python3
"""Rules gate (founder 28 Oct 2026): run before every commit. A FAIL means: do not commit. It checks only what a machine can check;
judgment rules (is the UI good?) stay with the founder's eyes. Usage: python3 docs/cursor-work/server/rules-gate.py [--staged]"""
import re, subprocess, sys, os

os.chdir(subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip())


def sh(*a):
    return subprocess.run(a, capture_output=True, text=True).stdout


staged = [f for f in sh("git", "diff", "--cached", "--name-only").splitlines() if f]
if "--staged" not in sys.argv and not staged:
    staged = [f for f in sh("git", "diff", "--name-only", "HEAD").splitlines() if f]
if "--all" in sys.argv:  # audit the whole founder tree, not just a commit
    staged = [f for f in sh("git", "ls-files", "founder-web/src", "server/founder/src").splitlines() if f]
fails, warns = [], []


# THE TECHNOLOGY RULE IN FRONT OF EVERY GATE (founder 11 Nov 2026 04:39, "her gate ke agay technology phase wala rule likho"):
# every FAIL and every warning carries it, and the whole run prints it first, so no gate is ever read without it.
TECH_RULE = "TECH RULE: the phase's LISTED technology (CLAUDE.md line 18 + TECH LAW cell in BLUEPRINT-ABC-01NOV.md) must be in code BEFORE green: HTTP/3 primary, Rust WASM kernel, WebTransport, ML-KEM, latest only; contract = docs/claude/tech-contracts/CURRENT.md"


def fail(rule, msg):
    fails.append(f"FAIL [{rule}] {msg}  || {TECH_RULE}")


def warn(rule, msg):
    warns.append(f"warn [{rule}] {msg}  || TECH RULE: listed technology first (docs/claude/tech-contracts/CURRENT.md)")


code = [f for f in staged if re.match(r"(founder-web/src|server/founder/src)/.*\.(jsx?|css|rs)$", f) and os.path.exists(f)]

# Rule 69 NO MOCK: no placeholder / fake-data markers in founder code
MOCK = re.compile(r"lorem ipsum|\bmock(ed)?\b|fake[ _-]?data|dummy|sample data|placeholder data|TODO|FIXME|john doe|jane doe", re.I)
for f in code:
    for n, l in enumerate(open(f, errors="ignore"), 1):
        s = l.strip()
        if MOCK.search(l) and "NO MOCK" not in l and "Rule 69" not in l and not s.startswith(("//", "/*", "*")):
            fail("69 NO MOCK", f"{f}:{n}: {s[:90]}")

# Rule 67: UI text is English. Roman-Urdu words inside string literals / JSX text of UI files
URDU = re.compile(r"\b(nahi|hai|hain|kero|karo|abhi|aap|mera|kyun|kab|bhai|bana|haan|jaldi|shuru)\b", re.I)
for f in [c for c in code if c.startswith("founder-web/src") and c.endswith(".jsx")]:
    for n, l in enumerate(open(f, errors="ignore"), 1):
        if l.strip().startswith(("//", "/*", "*")):
            continue
        for a, b in re.findall(r'"([^"]{6,})"|>([^<>{}]{6,})<', l):
            t = a or b
            if URDU.search(t) and " " in t:
                fail("67 UI English", f"{f}:{n}: {t[:80]}")

# CORE FREEZE (founder 13 Nov 2026): the awam mail/calendar/attachment code is preserved for the later awam migration; the founder wraps it, never edits it.
_cf = subprocess.run([sys.executable, "docs/cursor-work/server/core-freeze.py"], capture_output=True, text=True) if os.path.exists("docs/claude/CORE-FREEZE.json") else None
if _cf is not None and _cf.returncode != 0:
    fail("CORE FREEZE", "awam mail/calendar core changed without his word: " + " ".join(l.split(": ", 1)[1] for l in _cf.stdout.splitlines() if l.startswith("FROZEN"))[:300])
# Rule 24: the founder's order + status are recorded with the work; the pull command is updated with the work
ALL = "--all" in sys.argv
big = [] if ALL else [f for f in staged if re.match(r"(founder-web/src|server/founder/src|docs/cursor-work/sql)/", f)]
if big and "docs/cursor-work/founder/founder-commands.md" not in staged:
    fail("24 commands", "code changed but founder-commands.md (verbatim order + status) not updated in this commit")
if big and "docs/cursor-work/DONE-DO-NOT-REPEAT.md" not in staged:
    fail("ledger", "code changed but DONE-DO-NOT-REPEAT.md not updated")
# Founder 6 Nov 2026 20:45 ("rules follow kerwao"): the chat context is updated with every code change, and the two top rules can never be removed from the first lines.
if big and "docs/cursor-work/CLAUDE-CHAT-CONTEXT-WITH-FOUNDER-NAUMAN-SHERWANI.md" not in staged:
    fail("context", "code changed but CLAUDE-CHAT-CONTEXT-WITH-FOUNDER-NAUMAN-SHERWANI.md (new checkpoint) not updated in this commit")
for top in ("AGENTS.md", "CLAUDE.md"):
    try:
        head = open(top, encoding="utf-8").read(17000)
    except OSError:
        head = ""
    if "ONE WEBSITE, ONE BUILD" not in head or "RULE 34" not in head or "LIVE CHROME = REPO" not in head or "SHARED-CODE RULE" not in head or "NEXT PHASE + ITS TECHNOLOGY" not in head or "EVERY PHASE IS WRITTEN AND LIVE-TESTED" not in head or "NO UNFINISHED WORK" not in head:
        fail("34 ONE BUILD", top + ": the ONE WEBSITE, ONE BUILD and RULE 34 blocks must stay at the very top (founder 6 Nov 2026)")
# Founder 9 Nov 2026 19:47 ("websocket banned hai"): WebSocket is BANNED in every lane. Transport = WebTransport (QUIC) with SSE as the honest fallback, nothing else.
_ws = re.compile(r"new\s+WebSocket|tokio[-_]tungstenite|\btungstenite\b|axum::extract::ws|WebSocketUpgrade|\bwss?://|\bsocket\.io\b|\bsockjs\b", re.I)
for f in ([] if ALL else staged):
    if re.match(r"(founder-web/src|web-wasm/src|server/founder/src|server/awam-edge/src|src)/.*\.(rs|ts|tsx|toml)$", f) and os.path.exists(f):
        for i, l in enumerate(open(f, encoding="utf-8", errors="ignore"), 1):
            if _ws.search(l):
                fail("WEBSOCKET BANNED", f + ":" + str(i) + ": WebSocket is banned (founder 9 Nov 2026). Use WebTransport (QUIC) with SSE fallback.")
                break
# Founder rule 42/38 (22 Oct 2026): every NEW SQL (E100+ and its CHECK) starts with an EMPTY first line (the Supabase editor can eat the first character). Found 9 Nov: five of my files broke it.
for f in ([] if ALL else staged):
    m = re.match(r"docs/cursor-work/sql/(?:CHECK_)?E(\d+)\w*\.sql$", f)
    if m and int(m.group(1)) >= 100 and os.path.exists(f) and not open(f, encoding="utf-8", errors="ignore").read(1) == "\n":
        fail("42 SQL first line", f + ": the first line must be EMPTY (Rule 42.1); then run sql-editor-lint.py")
srv = [] if ALL else [f for f in staged if re.match(r"(founder-web/src|founder-web/dist|server/founder/src|docs/cursor-work/sql)/", f)]
if srv and "docs/claude/founder/PULL-COMMANDS.md" not in staged:
    fail("24 pull command", "server-affecting change but PULL-COMMANDS.md not updated")
# Rule 73 (founder 3 Nov 08:33): lanes. Every file in one lane, founder never reaches into awam code (and back), lovable-gold/ is a frozen copy of the Lovable code.
if os.path.exists("lanes/lane-sync.py"):
    r = subprocess.run([sys.executable, "lanes/lane-sync.py", "--check"], capture_output=True, text=True)
    for l in r.stdout.splitlines():
        if l.startswith("FAIL"):
            fails.append(l)
    if r.returncode != 0 and not any(x.startswith("FAIL") for x in r.stdout.splitlines()):
        fails.append("FAIL [73 lanes] lane-sync --check crashed: " + r.stderr[-200:])

pc = "docs/claude/founder/PULL-COMMANDS.md"
if os.path.exists(pc):
    t = open(pc).read()
    i = t.rfind("ABHI PENDING")
    if i >= 0:
        n = len(re.findall(r"^\s*\d+\.\s", t[i:], re.M))
        if n > 2:
            warn("24 one-two points", f"latest ABHI PENDING block has {n} numbered steps (Rule 24: 1-2 at a time)")

# Rule 61: UI stack gaps must stay written down; forbidden runtimes never appear
doc = "docs/claude/FOUNDER-UI-DESIGN-28OCT.md"
if os.path.exists(doc):
    d = open(doc).read()
    for need in ("TanStack Router", "Tailwind"):
        if need not in d:
            fail("61 stack", f"{doc} no longer lists the Rule 61 gap for {need}")
pk = "founder-web/package.json"
if os.path.exists(pk):
    pj = open(pk).read()
    for bad in ('"bun"', '"express"', '"next"', "jquery", "redux"):
        if bad in pj:
            fail("61 stack", f"{pk} contains {bad} (founder UI stack is fixed by Rule 61)")
for f in staged:
    if f.startswith("server/founder/") and f.endswith((".ts", ".js")) and "/tests/" not in f:
        fail("61 no Bun/Node", "founder server code must be Rust: " + f)

# FC18/FC20/FC22: a founder change never edits user-side files
for f in staged:
    if re.match(r"(src/(routes|components|lib)|server/routes)/", f):
        warn("FC18/FC22", f"user-side file touched: {f} (founder work must not edit user files)")

# CHAIRMAN FOOTER LOCK (founder 2 Nov 04:41): the awam footer text is the chairman's own wording. Claude never edits it.
# Only the founder's explicit order may unlock one commit: CHAIRMAN_FOOTER_OK=1 python3 ... (say so in founder-commands.md first).
if "src/components/site/SiteFooter.tsx" in staged and os.environ.get("CHAIRMAN_FOOTER_OK") != "1":
    fail("CHAIRMAN FOOTER", "SiteFooter.tsx is the chairman's wording: not editable without his explicit order (CHAIRMAN_FOOTER_OK=1)")

# Deploy manifest must be clean
v = subprocess.run([sys.executable, "docs/cursor-work/server/manifest-verify.py"], capture_output=True, text=True).stdout.strip().splitlines()
if not v or not v[-1].endswith(" 0 bad"):
    fail("manifest", "manifest-verify is not 0 bad: " + (v[-1] if v else "no output"))

# HOLE CLOSED (his 23 Nov 2026 08:06, awam pull.sh build failed: 3 new awam files were not in the deploy manifest, so the server got AppShell.tsx without the files it imports): every NEW file under src/ must be listed in DEPLOY-MANIFEST.txt in the same commit.
try:
    _man = open("docs/cursor-work/server/DEPLOY-MANIFEST.txt").read()
    _newsrc = [f for f in sh("git", "diff", "--cached", "--name-only", "--diff-filter=A").splitlines() if f.startswith("src/") and not f.endswith(("00-FOUNDER-TECH-RULE.md", "READ-FIRST-FOUNDER-LAW.md")) and not f.endswith(".md")]
    _miss = [f for f in _newsrc if (f + " ") not in _man]
    if _miss:
        fail("MANIFEST NEW FILE", "new src/ file(s) not in docs/cursor-work/server/DEPLOY-MANIFEST.txt (run: python3 docs/cursor-work/server/manifest-sync.py " + " ".join(_miss[:6]) + "): the server would get the files that import them without them")
except OSError:
    pass

# Loophole found 6 Nov 2026 (awam answered 404 for kernel 0.13.0): manifest-sync only auto-adds src/, so a deployed non-src file (the kernel wasm, public/) never reached the server.
# Every shipped kernel wasm (user site + founder SPA + founder dist) and the wasm the pin names MUST be in the deploy manifest.
try:
    man = {l.split()[0] for l in open("docs/cursor-work/server/DEPLOY-MANIFEST.txt", encoding="utf-8").read().splitlines() if l.strip() and not l.startswith("#")}
    tracked = sh("git", "ls-files", "public/kernel", "founder-web/public/kernel", "founder-web/dist/kernel").split()
    miss = [f for f in tracked if f.endswith(".wasm") and f not in man]
    pin = re.search(r'version:\s*"([0-9.]+)"', open("src/lib/kernel/pin.gen.ts", encoding="utf-8").read())
    if pin and f"public/kernel/anexo-kernel-{pin.group(1)}.wasm" not in man:
        miss.append(f"public/kernel/anexo-kernel-{pin.group(1)}.wasm (named by src/lib/kernel/pin.gen.ts)")
    if miss:
        fail("manifest kernel", "kernel wasm not in DEPLOY-MANIFEST (awam would answer 404): " + ", ".join(miss) + "  -> python3 docs/cursor-work/server/manifest-sync.py <those paths>")
except OSError:
    pass

# TECH LAW (founder 11 Nov 2026, last warning): the technology LISTED per phase must be in the code. Checks live in docs/claude/TECH-LAW-GATE.json.
# status ok = enforced on every commit; status open = known gap with a deadline (warning until closed); "fail_after" (ISO date) turns the warning into a FAIL from that day.
import json
try:
    for c in json.load(open("docs/claude/TECH-LAW-GATE.json"))["checks"]:
        txt = open(c["file"], errors="ignore").read().lower() if os.path.exists(c["file"]) else ""
        good = (c["must"].lower() in txt) if "must" in c else (c["mustnot"].lower() not in txt)
        if c["status"] == "ok" and not good:
            fail("TECH LAW", f'{c["id"]}: {c["why"]} ({c["file"]})')
        elif c["status"] == "open" and not good and c.get("fail_after") and __import__("datetime").date.today().isoformat() >= c["fail_after"]:
            fail("TECH LAW OVERDUE", f'{c["id"]}: the listed technology is still missing and its date {c["fail_after"]} has come: {c["why"]} (his 11 Nov 21:59 word: no advanced technology = the gate FAILS)')
        elif c["status"] == "open" and not good:
            warn("TECH LAW OPEN", f'{c["id"]} until {c.get("deadline", "?")}: {c["why"]}')
        elif c["status"] == "open" and good:
            warn("TECH LAW", f'{c["id"]} now holds: change its status to ok in docs/claude/TECH-LAW-GATE.json')
except FileNotFoundError:
    fail("TECH LAW", "docs/claude/TECH-LAW-GATE.json is missing")

# ADMIN DESK ADVANCED-TECHNOLOGY GATE (his 21 Nov 2026 08:19): admin-desk/gates/DESK-FEATURES.json; missing technology = FAIL (no commit), shouted.
try:
    sys.path.insert(0, "admin-desk/gates")
    import desk_tech_gate
    _df, _dw = desk_tech_gate.check(".")
    for _m in _df: fail("DESK TECH", _m)
    for _m in _dw: warn("DESK TECH", _m)
except ImportError:
    fail("DESK TECH", "admin-desk/gates/desk_tech_gate.py is missing")

# ADMIN DESK D4 WIRING GATE (his 22 Nov 2026 08:56: "D4 gate banao"): a Desk card may never be dead, and the real Desk never shows phase names or "P1" (his 08:26 word).
# Also: any admin-desk script that WRITES a row an employee can see (desk-test-alert.sh) may not carry a phase name (D2, R3b ...) or "P1" in that text (his 09:03 Chairman word, after "live.proof.d2" showed on the Alerts page).
# Runs when a commit touches founder-web/src/desk: (1) the card registry test (route, track, "what it waits for", unique key), (2) no user-facing "Waits for phase" / "phase K" text.
for _sf in ("docs/claude/admin-desk/scripts/desk-test-alert.sh",):
    try:
        for _ln in open(_sf, encoding="utf-8").read().splitlines():
            if "fadm_alert_raise" in _ln and __import__("re").search(r"\bD[0-9]+[a-z]?\b|\bR[0-9][a-z0-9-]*\b|[Pp]hase|\bP1\b|\.d[0-9]\b", _ln.split("fadm_alert_raise", 1)[1]):
                fail("DESK WIRING", f"{_sf}: the test alert text carries a phase name or P1; employees see it on the Alerts page")
    except OSError: pass
_dstaged = [f for f in subprocess.run(["git", "diff", "--cached", "--name-only"], capture_output=True, text=True).stdout.splitlines() if f.startswith("founder-web/src/desk/")]
if _dstaged:
    _r = subprocess.run(["bun", "test", "src/desk/desk_cards.test.ts"], cwd="founder-web", capture_output=True, text=True)
    if _r.returncode != 0:
        fail("DESK WIRING", "the Desk card registry test fails (a dead card or a broken route): " + (_r.stdout + _r.stderr).strip().splitlines()[-1][:160])
    import re as _re
    for _f in _dstaged:
        if _f.endswith(".test.ts") or not _f.endswith((".ts", ".tsx")): continue
        try: _t = open(_f, encoding="utf-8").read()
        except OSError: continue
        _t = _re.sub(r"/\*.*?\*/", "", _t, flags=_re.S); _t = _re.sub(r"(?m)^\s*//.*$", "", _t)
        if _re.search(r"Waits for phase|[\"`>]\s*Phase [A-Z]\b|\bP1\b|severity=p1|dcb-p1", _t):
            fail("DESK WIRING", f"{_f}: user-facing text names a phase or says P1; the real Desk uses plain words (Urgent alerts, Not connected yet)")


# DESK NO-MONEY GATE (D5a-1, his 22 Nov 2026 10:10 word: no amounts, invoices, cards, transactions, Polar or webhook names on the Admin Desk; finance stays founder side). Reads docs/claude/admin-desk/gates/DESK-LOOKUP-CONTRACT.json.
if "--staged" in sys.argv:
    import re as _rm, json as _jm
    try:
        _forb = _jm.load(open("docs/claude/admin-desk/gates/DESK-LOOKUP-CONTRACT.json", encoding="utf-8"))["forbidden_identifiers"]
    except Exception as _e:
        _forb = []; fail("DESK NO-MONEY", "contract file DESK-LOOKUP-CONTRACT.json is missing or broken: " + str(_e)[:80])
    _rx = _rm.compile(r"(?<![A-Za-z0-9])(" + "|".join(_rm.escape(x) for x in _forb) + r")(?![A-Za-z0-9])", _rm.I) if _forb else None
    for _f in staged:
        if not _rx or not _f.startswith(("founder-web/src/desk/", "docs/claude/admin-desk/server/", "docs/claude/admin-desk/sql/", "docs/claude/admin-desk/kernel/")): continue
        if not _f.endswith((".ts", ".tsx", ".rs", ".sql")) or ".test." in _f or "/sql/checks/" in _f: continue
        try: _t = open(_f, encoding="utf-8").read()
        except OSError: continue
        _t = "\n".join(_x for _x in _t.splitlines() if "no-money-gate-ok" not in _x)   # a negative rule or selftest line that must NAME the forbidden word carries this tag
        _t = _rm.sub(r"/\*.*?\*/", "", _t, flags=_rm.S); _t = _rm.sub(r"(?m)(^|\s)(//|--).*$", "", _t)
        _m = _rx.search(_t)
        if _m: fail("DESK NO-MONEY", f"{_f}: the Desk names a money field ({_m.group(1)}); finance, invoices, cards and Polar stay on the founder side (contract DESK-LOOKUP-CONTRACT.json)")

# DESK PHASE START (his 22 Nov 2026 06:41): a commit that changes Desk CODE needs a Desk phase receipt (desk-phase-start.py, also run by rules-read.py) younger than 2 hours: the strict rules, the phase technology and WORKING-NOW were printed to Claude.
if "--staged" in sys.argv:
    _desk_code = [f for f in staged if f.startswith(("docs/claude/admin-desk/server/", "docs/claude/admin-desk/kernel/", "founder-web/src/desk/")) and f.endswith((".rs", ".ts", ".tsx", ".sql", ".sh"))]
    if _desk_code:
        try:
            import json as _j4, time as _t4
            _rc = _j4.load(open(".git/desk-phase-receipt.json"))
            _need = ["docs/claude/admin-desk/DESK-PHASES-22NOV.md", "docs/claude/admin-desk/BLUEPRINT-ADMIN-DESK.md", "docs/claude/admin-desk/RULE-BOOK.md", "docs/claude/admin-desk/state/WORKING-NOW.md", "docs/claude/state/WORKING-NOW.md"]
            _miss = [x for x in _need if x not in _rc.get("read", [])]
            if _miss: fail("DESK PHASE START", "receipt does not show the repo was read (his 22 Nov 07:26: no rules + blueprint + working-now read = no commit): missing " + ", ".join(_miss) + "; run desk-phase-start.py <phase> and READ it")
            import hashlib as _h4, re as _r4
            _cur = _h4.sha256("\n".join(l for l in open("docs/claude/admin-desk/DESK-PHASES-22NOV.md", errors="ignore").read().split("\n") if _r4.match(r"^\d+\. ", l)).encode()).hexdigest()
            if _rc.get("rules_sha") != _cur: fail("DESK PHASE START", "the Desk strict rules changed since your last read: run desk-phase-start.py <phase> again and READ the new rules")
            if _t4.time() - _rc["time"] > 7200: fail("DESK PHASE START", "receipt older than 2 hours: run python3 docs/cursor-work/server/desk-phase-start.py <phase> and READ it (strict rules, phase technology, WORKING-NOW)")
        except Exception:
            fail("DESK PHASE START", "no Desk phase receipt: run python3 docs/cursor-work/server/desk-phase-start.py <phase> and READ it before changing Desk code (docs/claude/admin-desk/DESK-PHASES-22NOV.md)")

# CODE BACKUP LAW (his 22 Nov 2026 06:02): backups/<lane>/<stamp>-<commit>/ is APPEND-ONLY. A staged change that modifies or deletes anything under backups/ fails; every backup archive must match its SHA256SUMS. Nothing pulls from backups/ unless he asks. docs/claude/CODE-BACKUP-LAW-22NOV.md
try:
    _bs = sh("git", "diff", "--cached", "--name-status", "--", "backups/").splitlines()
    _bad = [l for l in _bs if l and not l.startswith("A")]
    if _bad: fail("CODE BACKUP", "backups/ is append-only (add a new backup, never change or delete an old one): " + " | ".join(_bad[:3]))
    if os.path.isdir("backups"):
        _v = subprocess.run([sys.executable, "docs/cursor-work/server/code-backup.py", "verify"], capture_output=True, text=True)
        if _v.returncode != 0: fail("CODE BACKUP", "a backup archive does not match its SHA256SUMS: " + _v.stdout.strip()[-200:])
except Exception as _x:
    fail("CODE BACKUP", "code-backup check cannot run: " + str(_x)[:100])

# ADMIN DESK TWO PLACES (his 21 Nov 2026 09:59): canonical docs/claude/admin-desk/ + ONE identical copy at admin-desk/ (server installers fetch it from origin/main). Drift = no commit.
try:
    import subprocess as _sp
    _r = _sp.run([sys.executable, "docs/cursor-work/server/desk-copy-sync.py", "check"], capture_output=True, text=True)
    if _r.returncode != 0: fail("DESK COPY", "docs/claude/admin-desk and admin-desk/ differ (edit only docs/claude/admin-desk, then run: python3 docs/cursor-work/server/desk-copy-sync.py sync): " + " | ".join(_r.stdout.strip().splitlines()[:3]))
except Exception as _x:
    fail("DESK COPY", "desk-copy-sync.py cannot run: " + str(_x)[:100])

# TECH-FIRST PROTOCOL (founder 11 Nov 2026 04:33, "forever solution"): docs/claude/TECH-FIRST-PROTOCOL.md. Three mechanical gates so the listed technology can never be skipped again.

# SERVER-SELF-CONTAINED (11 Nov 22:00, incident: founder-install failed on his server because a test pulled web-wasm/src/mldsa.rs via #[path]): his server builds ONLY the server/ folder.
# No #[path], include_str! or include_bytes! in server/founder may reach outside server/ (a test vector file goes INSIDE the crate).
import glob as _g2
for _f in [x for x in _g2.glob("server/founder/src/**/*", recursive=True) if os.path.isfile(x) and not x.endswith((".rs", ".md"))]:
    fail("SERVER SELF-CONTAINED", f"{_f}: founder-install.sh copies ONLY *.rs from server/founder/src (incident 11 Nov 23:10: a .txt vector file never reached his server); make it a .rs file")
for _f in _g2.glob("server/founder/src/**/*.rs", recursive=True):
    for _m in re.finditer(r'(#\[path\s*=\s*"([^"]+)"\]|include_(?:str|bytes)!\(\s*"([^"]+)")', open(_f, errors="ignore").read()):
        _t = _m.group(2) or _m.group(3)
        if ".." in _t.replace("../", "", 0) and os.path.normpath(os.path.join(os.path.dirname(_f), _t)).split(os.sep)[0] != "server":
            fail("SERVER SELF-CONTAINED", f"{_f}: {_t} reaches outside server/ (his server builds only the server/ folder), install would fail")

# RULES-READ RECEIPT (founder 11 Nov 22:05): after a compaction Claude must have READ the rules + the phase technology; the proof is a fresh receipt written by rules-read.py (it prints them).
# Missing / older than 2 h / protocol, contract, resume or gate file changed by someone else since = the COMMIT FAILS. (Files edited in THIS commit are fine: they are re-hashed by the next rules-read.py.)
if "--staged" in sys.argv:
    import json as _j3, time as _t3, hashlib as _h3
    try:
        _r = _j3.load(open(".git/rules-read-receipt.json"))
        _age = _t3.time() - _r["time"]
        if _age > 7200: fail("RULES NOT READ", "receipt is older than 2 hours: run python3 docs/cursor-work/server/rules-read.py and READ its output (RESUME-POINT, TECH-FIRST-PROTOCOL, CURRENT.md, open technologies)")
    except Exception:
        fail("RULES NOT READ", "no receipt: after a compaction or new chat run python3 docs/cursor-work/server/rules-read.py FIRST and READ its output; the phase technology in the blueprint is the founder's, not optional")
import glob as _glob, subprocess as _sp
def _raw_net():
    n = 0
    for f in _glob.glob("founder-web/src/**/*", recursive=True):
        if f.endswith((".ts", ".tsx")) and ".test." not in f:
            n += len(re.findall(r"(?<![\w.])fetch\(|XMLHttpRequest|new WebSocket", open(f, errors="ignore").read()))
    return n
try:
    base = json.load(open("docs/claude/TECH-RATCHET.json"))["raw_network_calls"]
    now = _raw_net()
    if now > base:
        fail("TECH RATCHET", f"raw fetch/XHR/WebSocket in founder-web/src rose {base} -> {now}: Rule 52 = browser -> kernel -> WebTransport/HTTP3, fetch only as fallback (docs/claude/TECH-FIRST-PROTOCOL.md)")
    elif now < base:
        warn("TECH RATCHET", f"raw network calls fell {base} -> {now}: lower raw_network_calls in docs/claude/TECH-RATCHET.json")
except FileNotFoundError:
    fail("TECH RATCHET", "docs/claude/TECH-RATCHET.json is missing")
cur = "docs/claude/tech-contracts/CURRENT.md"
code_staged = [f for f in staged if re.match(r"(founder-web/src|server/founder/src|docs/cursor-work/sql)/", f)]
if code_staged and cur not in staged:
    fail("TECH CONTRACT", "founder code changed but docs/claude/tech-contracts/CURRENT.md is not in this commit: write the phase's technology contract FIRST (docs/claude/TECH-FIRST-PROTOCOL.md)")
if os.path.exists(cur):
    ct = open(cur, errors="ignore").read()
    if "TECH CONTRACT FOR PHASE" not in ct:
        fail("TECH CONTRACT", "CURRENT.md must start with 'TECH CONTRACT FOR PHASE: <letter>'")
    if re.search(r"^STATE:\s*GREEN", ct, re.M):
        nos = [l for l in ct.splitlines() if l.startswith("|") and len(l.split("|")) > 4 and l.split("|")[3].strip() == "NO"]
        if nos:
            fail("TECH CONTRACT", f"STATE is GREEN but {len(nos)} listed technolog(y/ies) say NO in CURRENT.md")
# INCOMPLETE ADVANCE (his word 22 Nov 2026 20:36 PKT, in anger: "incomplete phase, incomplete codes, incomplete advance technology is BANNED; no commit"):
# a commit that carries Desk CODE is refused unless the NEWEST technology contract block (top of CURRENT.md) has every listed advance technology IN CODE = yes (or n/a) and is not "IN PROGRESS".
# Half-written phases stay in the working tree; only a finished phase is committed. Contract notes, docs and the ledger are not code and may be committed any time.
# HOLE CLOSED (his 23 Nov 2026 07:12, "gate ne mistake ki hai"): the Control Plane code and SQL and the Desk installers are Desk code too; a half-built sub-phase can no longer ride in through them.
_desk_code = [f for f in staged if re.match(r"docs/claude/admin-desk/server/src/.*\.rs$|founder-web/src/desk/|docs/claude/admin-desk/sql/AD[0-9]+[a-z]?\.sql$|control-plane/src/.*\.rs$|control-plane/sql/CP[0-9]+\.sql$|docs/claude/admin-desk/scripts/.*\.sh$", f)]
if _desk_code and os.path.exists(cur):
    _ct = open(cur, errors="ignore").read()
    _parts = _ct.split("# TECH CONTRACT FOR PHASE")
    if len(_parts) < 2:
        fail("INCOMPLETE ADVANCE", "Desk code is staged but CURRENT.md has no technology contract block")
    else:
        _blk = _parts[1]; _head = _blk.splitlines()[0] if _blk.strip() else ""
        if re.search(r"STATE:\s*IN PROGRESS", _head):
            fail("INCOMPLETE ADVANCE", f"Desk code staged while the newest phase contract says IN PROGRESS (incomplete phases are banned from commits): {_head[:100]}")
        _bad = [l for l in _blk.splitlines() if l.startswith("|") and len(l.split("|")) > 4 and l.split("|")[3].strip().lower().split(" ")[0] in ("no", "partly", "pending")]
        if _bad:
            fail("INCOMPLETE ADVANCE", f"Desk code staged but {len(_bad)} advance technolog(y/ies) of the newest phase are not IN CODE yet (incomplete advance technology is banned): {_bad[0].split('|')[1].strip()[:80]}")
# BILLIONAIRE LIST (his order 23 Nov 2026 09:11 PKT): the Desk copies the setup of the billionaire companies (Zendesk, Salesforce and the rest) and adds an advance level none of them have; the master list is
# docs/claude/admin-desk/BILLIONAIRE-SETUP-LIST-23NOV.md (rows BL-xx). Desk code may only be committed when the newest CURRENT.md contract block names the BL id(s) it builds, and each named id must exist in the list.
if _desk_code and os.path.exists(cur):
    _bl = "docs/claude/admin-desk/BILLIONAIRE-SETUP-LIST-23NOV.md"
    if not os.path.exists(_bl):
        fail("BILLIONAIRE LIST", f"{_bl} is missing: the list of what the billionaire companies have (plus our advance level) must exist before Desk code is committed")
    else:
        _blk2 = (open(cur, errors="ignore").read().split("# TECH CONTRACT FOR PHASE") + ["", ""])[1]
        _ids = set(re.findall(r"\bBL-\d{2}\b", _blk2.splitlines()[0] if _blk2.strip() else ""))
        _have = set(re.findall(r"^\| (BL-\d{2}) \|", open(_bl, errors="ignore").read(), re.M))
        if not _ids:
            fail("BILLIONAIRE LIST", "the newest CURRENT.md contract heading names no BL id: which row of BILLIONAIRE-SETUP-LIST-23NOV.md does this phase build? (his 09:11 order: copy the billionaire setup and add the advance level)")
        elif not _ids <= _have:
            fail("BILLIONAIRE LIST", f"the contract names {sorted(_ids - _have)} which are not rows of BILLIONAIRE-SETUP-LIST-23NOV.md")
        else:
            # ORDER-LOCK (his 23 Nov 09:28): rows are built in the order of the ORDER-LOCK line; a GREEN row is never rebuilt; the heading must name the NEXT row that is not GREEN yet.
            _txt = open(_bl, errors="ignore").read(); _ol = re.search(r"^ORDER-LOCK[^\n]*?:\s*((?:BL-\d{2},?)+)", _txt, re.M)
            if not _ol:
                fail("BILLIONAIRE LIST", "ORDER-LOCK line is missing in BILLIONAIRE-SETUP-LIST-23NOV.md (his 09:28 order)")
            else:
                _ord = _ol.group(1).strip(",").split(",")
                _st = {m.group(1): m.group(2) for m in re.finditer(r"^\| (BL-\d{2}) \|[^|]*\|\s*([^|]*)\|", _txt.split("## F. ADVANCE TECHNOLOGY PER PHASE")[0], re.M)}
                _next = [i for i in _ord if not _st.get(i, "").strip().startswith("GREEN") and not _st.get(i, "").strip().startswith("NOT YET")]
                # his 10:2x word ("FIX ka ristha de do"): a heading "FIX of BL-xx" for a row that is GREEN is a correction of finished work, not a rebuild, so it needs no ORDER-LOCK turn; every other check still applies.
                _fix = re.search(r"FIX of (BL-\d{2})", _blk2.splitlines()[0]); _is_fix = bool(_fix) and _st.get(_fix.group(1), "").strip().startswith("GREEN")
                _frows = set(re.findall(r"^\| (BL-\d{2}) \| [^|]+\| [^|]{40,}\|$", _txt.split("## F. ADVANCE TECHNOLOGY PER PHASE")[-1], re.M)) if "## F. ADVANCE TECHNOLOGY PER PHASE" in _txt else set()
                if _next and _next[0] in _ids and _next[0] not in _frows and not _is_fix:
                    fail("BILLIONAIRE LIST", f"{_next[0]} has no ADVANCE TECHNOLOGY row in section F of BILLIONAIRE-SETUP-LIST-23NOV.md (his 09:35: advance technology next to every phase, world-class)")
                _miss = [i for i in _ord if not re.search(r"^ADVANCE-TECH " + i + r" \([^)]*\): .{60,}", _txt, re.M)]
                if _miss:
                    fail("BILLIONAIRE LIST", f"ADVANCE-TECH line missing in BILLIONAIRE-SETUP-LIST-23NOV.md section F for {_miss[:4]} (his 09:36: advance technology next to every phase, world advance, before commit)")
                _tail = _ord[_ord.index("BL-07"):] if "BL-07" in _ord else []
                _nlt = open("docs/claude/admin-desk/NOW-LIST-23NOV.md", errors="ignore").read() if os.path.exists("docs/claude/admin-desk/NOW-LIST-23NOV.md") else ""
                if set(_tail) & _ids and not re.search(r"\b1o (?:GREEN|= GREEN)", _nlt):
                    fail("BILLIONAIRE LIST", "DASHBOARD-FIRST (his 09:33): BL-07 and later start only after the Dashboard order phases 1n and 1o are GREEN in NOW-LIST-23NOV.md")
                if _next and _next[0] not in _ids and not _is_fix:
                    fail("BILLIONAIRE LIST", f"ORDER-LOCK: the next row to build is {_next[0]}, but the contract heading names {sorted(_ids)}; follow his order and never rebuild a GREEN row")
# GATE FOREVER (his 09:55 / 10:20 law): the checks that make a Desk commit impossible without advance SQL, advance code and advance technology can never be deleted from this file.
_forever = ["PHASE FILES", "INCOMPLETE ADVANCE", "BILLIONAIRE LIST", "SQL WORLD-CLASS", "RESEARCH IN BLUEPRINT", "FUTURE-PROOF", "NO TEST NO COMMIT"]
_src = open(__file__, errors="ignore").read()
for _k in _forever:
    if _src.count('fail("' + _k + '"') < 1:
        fail("GATE FOREVER", f"the check {_k} is missing from rules-gate.py: his law says a commit is impossible without advance SQL, advance code and advance technology; put it back (docs/claude/admin-desk/GATE-FOREVER-LAW-23NOV.md)")
# PHASE FILES (his 23 Nov 09:55 order): the gate is told ALL the work of the phase. Every code path named in the "Where in code" column of the newest CURRENT.md contract block (a .rs, .sql, .ts or .tsx file name)
# must EXIST in the repo before a Desk commit; every NEW AD*.sql must carry its CHECK file, and the contract must hold at least one SQL row, one Rust row and one screen row. No advance SQL or no advance code = the commit is stopped.
if _desk_code and os.path.exists(cur):
    _pb = (open(cur, errors="ignore").read().split("# TECH CONTRACT FOR PHASE") + ["", ""])[1]
    _rows = [l for l in _pb.splitlines() if l.startswith("|") and len(l.split("|")) > 4 and not l.startswith("|---") and "Advance technology" not in l]
    _names = []
    for _l in _rows:
        _names += re.findall(r"[A-Za-z0-9_./-]+\.(?:rs|sql|tsx|ts)\b", _l.split("|")[2])
    _have_files = {os.path.basename(f) for root in ("docs/claude/admin-desk", "founder-web/src/desk", "control-plane") for dp, dn, fn in os.walk(root) if "node_modules" not in dp and "target" not in dp for f in fn}
    _gone = sorted({os.path.basename(n) for n in _names if os.path.basename(n) not in _have_files})
    if _names and _gone:
        fail("PHASE FILES", f"the newest contract names code files that do not exist yet: {_gone[:5]} (advance SQL and advance code of the phase must be written before commit)")
    _txt = " ".join(_names)
    if _rows and not (re.search(r"\.sql", _txt) and re.search(r"\.rs", _txt) and re.search(r"\.tsx?", _txt)):
        fail("PHASE FILES", "the newest contract must name at least one SQL file, one Rust file and one screen/TypeScript file (his 09:55 order: advance SQL + advance code + screen for every phase)")
    for _s in [f for f in (staged if "staged" in globals() else []) if re.search(r"sql/AD\d+[a-z]?\.sql$", f)]:
        if not os.path.exists(_s.replace("sql/", "sql/checks/").replace(".sql", "-check.sql")):
            fail("PHASE FILES", f"{_s} has no CHECK file in sql/checks/")
# RESEARCH IN BLUEPRINT (his word 23 Nov 2026 03:1x PKT, STRICT, for every phase and every SOP of the website): the advance technology that web research gives a phase must be written in
# FOUR places BEFORE code is committed: the phase LIST file (named in the CURRENT.md heading), the Desk blueprint (line "ADVANCE-RESEARCH [<phase>]"), NOW-LIST-23NOV.md, and CURRENT.md rows all IN CODE.
# One missing dot = the gate stops the commit and asks "is this phase's advance technology and advance code added?".
if _desk_code and os.path.exists(cur):
    _h2 = (open(cur, errors="ignore").read().split("# TECH CONTRACT FOR PHASE") + ["", ""])[1].splitlines()[0] if True else ""
    _m = re.search(r"\(phase (\d+[a-z])\)", _h2)
    if _m:
        _id = _m.group(1)
        _lm = re.search(r"LIST: (docs/claude/admin-desk/[A-Za-z0-9_.-]+)", _h2)
        _bp = "docs/claude/admin-desk/DESK-D-SERIES-BLUEPRINT-22NOV.md"; _nl = "docs/claude/admin-desk/NOW-LIST-23NOV.md"
        _tag = f"ADVANCE-RESEARCH [{_id}]"
        # LOOPHOLE CLOSED (his autofix order 23 Nov 03:13): the contract block must be for the phase that NOW-LIST says is NOW, so code of the next phase can never ride on an older phase's block.
        if os.path.exists(_nl):
            _nm = re.search(r">>> (\d+[a-z]) [^<]*= NOW <<<", open(_nl, errors="ignore").read())
            if _nm and _nm.group(1) != _id:
                fail("RESEARCH IN BLUEPRINT", f"NOW-LIST says phase {_nm.group(1)} is NOW but the newest CURRENT.md contract block is phase {_id}: do the web research, LIST file, ADVANCE-RESEARCH lines and contract block for {_nm.group(1)} FIRST")
        if not _lm or not os.path.exists(_lm.group(1)):
            fail("RESEARCH IN BLUEPRINT", f"phase {_id}: the CURRENT.md heading must name 'LIST: <file>' and that web-research list must exist. Is this phase's advance technology written?")
        for _f in (_bp, _nl):
            if not os.path.exists(_f) or _tag not in open(_f, errors="ignore").read():
                fail("RESEARCH IN BLUEPRINT", f"phase {_id}: '{_tag}' line (research points + advance technology + code files) is missing in {_f}. Is this phase's advance technology and advance code added?")
# SQL WORLD-CLASS LAW (his word 23 Nov 2026 06:01 PKT, STRICT, EVERY SQL of the whole website: founder, awam/user, Admin Desk, shared): every NEW .sql file must be world-class advanced and written ON TOP of the older schema.
# It sits beside RESEARCH IN BLUEPRINT (which stays intact) and extends the same order to founder and awam: web research -> list -> ADVANCE-RESEARCH line -> contract -> SQL. A new SQL file must carry in its first 60 lines:
#   -- SCHEMA-FIRST: <older SQL files read>   -- ADVANCE-RESEARCH: [<phase>] <what research gave>   -- CHECK-FILE: <path that exists>
# and the body must hold a selftest that rolls back; a CREATE TABLE needs FORCE ROW LEVEL SECURITY; SECURITY DEFINER needs a fixed search_path; every CREATE FUNCTION needs a REVOKE ... FROM PUBLIC.
_sqlnew = [f for f in sh("git", "diff", "--cached", "--name-only", "--diff-filter=A").splitlines() if f.endswith(".sql") and "/checks/" not in f and not os.path.basename(f).upper().startswith("CHECK") and not f.startswith(("lovable-gold/", "backups/", "admin-desk/")) and not os.path.basename(f).startswith("00-")]
for _sf in _sqlnew:
    try:
        _st = open(_sf, errors="ignore").read()
    except OSError:
        continue
    _hd = "\n".join(_st.splitlines()[:60])
    _up = _st.upper()
    if "SCHEMA-FIRST:" not in _hd:
        fail("SQL WORLD-CLASS", f"{_sf}: first 60 lines need '-- SCHEMA-FIRST: <older SQL files you read>' (his 23 Nov law, founder + awam + Desk)")
    _am = re.search(r"-- ADVANCE-RESEARCH: \[([^\]]+)\] \S+", _hd)
    if not _am:
        fail("SQL WORLD-CLASS", f"{_sf}: first 60 lines need '-- ADVANCE-RESEARCH: [<phase>] <what the web research gave this SQL>'")
    _cm = re.search(r"-- CHECK-FILE: (\S+)", _hd)
    if not _cm or not os.path.exists(_cm.group(1)):
        fail("SQL WORLD-CLASS", f"{_sf}: first 60 lines need '-- CHECK-FILE: <path>' and that CHECK file must exist")
    if "SELFTEST" not in _up or not re.search(r"ROLLBACK|P0[A-Z0-9]{3}|RAISE EXCEPTION", _up):
        fail("SQL WORLD-CLASS", f"{_sf}: no selftest that rolls back (raise + catch, or ROLLBACK): world-class SQL proves itself")
    if "CREATE TABLE" in _up and "FORCE ROW LEVEL SECURITY" not in _up:
        fail("SQL WORLD-CLASS", f"{_sf}: CREATE TABLE without FORCE ROW LEVEL SECURITY")
    if "SECURITY DEFINER" in _up and not re.search(r"SET SEARCH_PATH", _up):
        fail("SQL WORLD-CLASS", f"{_sf}: SECURITY DEFINER without a fixed 'SET search_path'")
    if "CREATE FUNCTION" in _up.replace("CREATE OR REPLACE FUNCTION", "CREATE FUNCTION") and not re.search(r"REVOKE[^;]*FROM PUBLIC", _up):
        fail("SQL WORLD-CLASS", f"{_sf}: functions are created but nothing is REVOKEd FROM PUBLIC (AD1c lesson)")
# FUTURE-PROOF (his word 23 Nov 2026 06:42 PKT, STRICT, whole website): the system is built ONCE for when the business is big; "Not measured" is an excuse, a real signal (zero is data) is the work. New lines in Desk source may not say it.
_fp = [f for f in staged if re.match(r"(founder-web/src/desk/|docs/claude/admin-desk/server/src/).*\.(ts|tsx|rs)$", f)]
for _f in _fp:
    _d = subprocess.run(["git", "diff", "--cached", "-U0", "--no-color", "--", _f], capture_output=True, text=True).stdout
    for _l in _d.splitlines():
        if _l.startswith("+") and not _l.startswith("+++") and re.search(r"not measured", _l, re.I) and "future-proof-gate-ok" not in _l:
            fail("FUTURE-PROOF", f"{_f}: a new line says 'Not measured'. His law (23 Nov 06:42): build the real signal from the real tables (web-search the best systems first); a zero is data, 'not measured' is an excuse. docs/claude/FUTURE-PROOF-LAW-23NOV.md")
            break
# FOUNDER INBOX REMINDER (his word 23 Nov 2026 04:29 PKT): the Admin Desk sends escalations to the founder; the founder-side receiver (Founder Escalation Inbox) is a LATER phase that must never be forgotten.
# The plan file and its tag must stay in the Desk NOW-LIST, the Desk blueprint and the FOUNDER blueprint; once 1o DASHBOARD FINAL is GREEN the plan must say STATUS: STARTED or GREEN or the commit is stopped.
_fi = "docs/claude/admin-desk/FOUNDER-ESCALATION-INBOX-PLAN-23NOV.md"
if os.path.exists("docs/claude/admin-desk/NOW-LIST-23NOV.md"):
    if not os.path.exists(_fi):
        fail("FOUNDER INBOX REMINDER", f"{_fi} is missing: the Founder Escalation Inbox plan (what comes from the Admin Desk to the founder) must stay in the repo")
    else:
        for _f in ("docs/claude/admin-desk/NOW-LIST-23NOV.md", "docs/claude/admin-desk/DESK-D-SERIES-BLUEPRINT-22NOV.md", "docs/claude/FINAL-FOUNDER-BLUEPRINT.md"):
            if not os.path.exists(_f) or "FOUNDER-ESCALATION-INBOX" not in open(_f, errors="ignore").read():
                fail("FOUNDER INBOX REMINDER", f"the tag FOUNDER-ESCALATION-INBOX is missing in {_f}: the founder-side receiver of Desk escalations must stay on the list")
        _nlt = open("docs/claude/admin-desk/NOW-LIST-23NOV.md", errors="ignore").read()
        if re.search(r"1o DASHBOARD FINAL = GREEN", _nlt) and not re.search(r"STATUS: (STARTED|GREEN)", open(_fi, errors="ignore").read()):
            fail("FOUNDER INBOX REMINDER", "1o DASHBOARD FINAL is GREEN: the Founder Escalation Inbox (what the Admin Desk escalates to the founder) is due now, set its plan STATUS to STARTED and begin its research")
# OVERVIEW S4 REMINDER (his word 23 Nov 2026 05:10 PKT): the Overview screen (his 22.jpg look) comes LATER, at the end, after 1o DASHBOARD FINAL; the plan and its tag must stay in the Desk NOW-LIST, blueprint and WORKING-NOW.
_ov = "docs/claude/admin-desk/OVERVIEW-S4-PLAN-23NOV.md"
if os.path.exists("docs/claude/admin-desk/NOW-LIST-23NOV.md"):
    if not os.path.exists(_ov):
        fail("OVERVIEW S4 REMINDER", f"{_ov} is missing: the Overview (S4) plan must stay in the repo")
    else:
        for _f in ("docs/claude/admin-desk/NOW-LIST-23NOV.md", "docs/claude/admin-desk/DESK-D-SERIES-BLUEPRINT-22NOV.md", "docs/claude/state/WORKING-NOW.md"):
            if not os.path.exists(_f) or "OVERVIEW-S4-LATER" not in open(_f, errors="ignore").read():
                fail("OVERVIEW S4 REMINDER", f"the tag OVERVIEW-S4-LATER is missing in {_f}: the Overview (S4) phase must stay on the list")
# NO PROMISE (his word 22 Nov 2026 10:42 + 10:47, phase 1k D5b-3): the runbook seed says what the employee SAYS; a promise word, a missing part or a missing fixed never-line fails the commit.
# The SAME word list lives in SQL AD9 (fadm_runbook_clean) and in desk_runbook_pure.ts (noPromise); three layers, one list.
_seed = "docs/claude/admin-desk/runbooks.seed.json"
if os.path.exists(_seed):
    import json as _json
    _POLICY = "Our published billing policy says payments are not refunded or credited once the service has been used. You can read it on the Billing Policy page."
    _PROMISE = re.compile(r"(promise|guarantee|definitely|for sure|100 percent|will be fixed|will be restored|refund|credit|compensation|discount|\bfree\b|i will make sure|within [0-9]+ *(hours?|minutes?|days?|mins?))", re.I)
    _NEVER = "Never promise a date, a refund, a credit, an upgrade or an owner decision."
    try:
        for _r in _json.load(open(_seed, encoding="utf-8"))["runbooks"]:
            _six = list(_r["parts"].keys()) == ["sees", "may", "never", "escalate", "say", "clock"]
            if not _six: fail("NO PROMISE", f"runbook {_r['key']}: must have exactly the six parts in order")
            if _NEVER not in _r["parts"]["never"]: fail("NO PROMISE", f"runbook {_r['key']}: part 3 must carry the fixed never-line")
            for _t in (_r["say_text"], _r["parts"]["say"]):
                _m = _PROMISE.search(_t.replace(_POLICY, ""))
                if _m: fail("NO PROMISE", f"runbook {_r['key']}: promise word '{_m.group(0)}' in what the employee says")
    except Exception as _e:
        fail("NO PROMISE", f"runbooks.seed.json unreadable: {_e}")
for led in ("docs/cursor-work/DONE-DO-NOT-REPEAT.md", "docs/claude/CLOSE-THE-GAPS-07NOV.md"):
    if led in staged:
        try:
            d = _sp.run(["git", "diff", "--cached", "-U0", "--", led], capture_output=True, text=True).stdout
            for l in d.splitlines():
                if l.startswith("+") and not l.startswith("+++") and re.search(r"\bGREEN\b", l) and "TECH-LAW CHECKED" not in l and "OPEN" not in l.upper().split("GREEN")[0][-40:]:
                    fail("TECH GREEN WORDS", f"{led}: a line says GREEN without 'TECH-LAW CHECKED' (and WIRED: YES / REAL: YES): {l[1:90]}")
        except OSError:
            pass

# NO TEST, NO COMMIT (his 23 Nov 2026 00:46 PKT, in anger: "test live kiye bina commit nahi send kerna, bina test ke pull nahi hoga"): a commit that stages Desk / Control Plane code, Desk SQL or Desk installer scripts must
# carry a ledger line (docs/claude/RESUME-POINT.md, added by rec.sh) with "TESTED:" followed by WHAT was run and its result (cargo N pass, CHECK n/n, real HTTP/3 or Chrome look). A line without it is refused.
_codeish = [f for f in staged if re.match(r"(docs/claude/admin-desk/server/src/|admin-desk/server/src/|control-plane/src/|docs/claude/admin-desk/sql/AD[0-9]|admin-desk/sql/AD[0-9]|docs/claude/admin-desk/scripts/.*\.sh$|admin-desk/scripts/.*\.sh$)", f)]
if _codeish:
    try:
        _d = _sp.run(["git", "diff", "--cached", "-U0", "--", "docs/claude/RESUME-POINT.md"], capture_output=True, text=True).stdout
        _ok = any(l.startswith("+") and not l.startswith("+++") and re.search(r"TESTED:\s*\S+.*(pass|true|OK|[0-9]+/[0-9]+|live)", l, re.I) for l in _d.splitlines())
        if not _ok:
            fail("NO TEST NO COMMIT", f"{len(_codeish)} code/SQL/installer file(s) staged ({_codeish[0]}) but the ledger line has no 'TESTED: <what ran + result>' (his 23 Nov law: docs/claude/NO-TEST-NO-COMMIT-LAW-23NOV.md)")
    except OSError:
        pass

# Q-SERIES STATE (his 13 Nov 2026 19:06 "advance automatic system"): the hash-chained step ledger must verify and HANDOFF-LIVE.md's generated block must match it, so a compaction can never hand the next chat a stale place.
try:
    import importlib.util as _iu
    _sp = _iu.spec_from_file_location("qstate", "docs/cursor-work/server/qstate.py"); _qs = _iu.module_from_spec(_sp); _sp.loader.exec_module(_qs)
    _qe = _qs.check()
    if _qe: fail("Q STATE", _qe + " (python3 docs/cursor-work/server/qstate.py verify / render)")
except Exception as _x:
    fail("Q STATE", "qstate.py cannot run: " + str(_x)[:120])
# FEATURES (his 18 Nov 2026 08:07 order): every feature of a phase is in docs/claude/features/*.json; a feature marked built must be found in the repo, a feature that exists must not be marked todo, a sub-phase that is done needs every feature built, and the generated lists must be fresh
try:
    _sp3 = _iu.spec_from_file_location("features", "docs/cursor-work/server/features.py"); _ft = _iu.module_from_spec(_sp3); _sp3.loader.exec_module(_ft)
    for _e in _ft.errors(): fail("FEATURES", _e)
except Exception as _x:
    fail("FEATURES", "features.py cannot run: " + str(_x)[:120])
# PHASE TECH (his order 15 Nov 2026 19:30): every phase in docs/claude/state/PHASES.json (and every Q step) names an ADVANCE technology, no old technology as a choice, GREEN needs WIRED/REAL/TECH-LAW CHECKED, and the generated blueprint equals the ledger. A violation blocks the commit.
try:
    _sp2 = _iu.spec_from_file_location("phases", "docs/cursor-work/server/phases.py"); _ph = _iu.module_from_spec(_sp2); _sp2.loader.exec_module(_ph)
    for _e in _ph.errors(): fail("PHASE TECH", _e + " (python3 docs/cursor-work/server/phases.py check / render / set)")
except Exception as _x:
    fail("PHASE TECH", "phases.py cannot run: " + str(_x)[:120])

# SERVER FIRST + H3 ONLY (founder 13 Nov 2026 21:08, one year, automatic): a change to the live server surface needs a fresh receipt of HIS pasted read-only output; no new h1/h2 serving code.
try:
    _sf = _iu.spec_from_file_location("serverfirst", "docs/cursor-work/server/serverfirst.py"); _sfm = _iu.module_from_spec(_sf); _sf.loader.exec_module(_sfm)
    for _e in _sfm.check(staged): fail("SERVER FIRST", _e)
except Exception as _x:
    fail("SERVER FIRST", "serverfirst.py cannot run: " + str(_x)[:120])
# AWAM INHERIT (founder 16 Nov 2026 00:48): the mailbox UI codes are preserved for Business Premium + Business MAX; a change needs the manifest updated in the same commit.
try:
    _ai = _iu.spec_from_file_location("awam_inherit", "docs/cursor-work/server/awam_inherit.py"); _aim = _iu.module_from_spec(_ai); _ai.loader.exec_module(_aim)
    for _e in _aim.check(staged): fail("AWAM INHERIT", _e)
except Exception as _x:
    fail("AWAM INHERIT", "awam_inherit.py cannot run: " + str(_x)[:120])
# VENDOR BAN (founder 13 Nov 2026 21:54): the banned CDN/DNS-proxy vendor may not appear in ANY added line except docs/claude/FOUNDER-VENDOR-BAN-13NOV.md.
try:
    import subprocess as _sp
    _pats = json.load(open("docs/claude/VENDOR-BAN-LIST.json"))["banned"]
    _d = _sp.run(["git", "diff", "--cached", "-U0", "--no-color"], capture_output=True, text=True).stdout
    _cur = ""
    for _ln in _d.splitlines():
        if _ln.startswith("+++ b/"): _cur = _ln[6:]
        elif _ln.startswith("+") and not _ln.startswith("+++") and any(_b in _ln.lower() for _b in _pats) and _cur not in ("docs/claude/FOUNDER-VENDOR-BAN-13NOV.md", "docs/claude/VENDOR-BAN-LIST.json", "docs/cursor-work/server/rules-gate.py"):
            fail("VENDOR BAN", "an added line in " + _cur + " names the banned vendor (docs/claude/FOUNDER-VENDOR-BAN-13NOV.md): remove it")
            break
except Exception as _x:
    fail("VENDOR BAN", "check cannot run: " + str(_x)[:120])
# RESUME POINT (founder 11 Nov 2026 04:45, "compact chat ka masla forever solve kero"): docs/claude/RESUME-POINT.md must travel with every code/ledger change, so a new chat always finds the real state.
rp = "docs/claude/RESUME-POINT.md"
if (code_staged or "docs/cursor-work/DONE-DO-NOT-REPEAT.md" in staged) and rp not in staged:
    fail("RESUME POINT", "code or the DONE ledger changed but docs/claude/RESUME-POINT.md (where we stopped + tomorrow's order) is not in this commit")
print("== " + TECH_RULE)

# FOLDER RULE (founder 11 Nov 2026 17:27): the technology rule file sits at the top of EVERY folder; AUDIT COUNTER: the auto audit after every 3 phases.
import importlib.util as _iu
_spec = _iu.spec_from_file_location("frs", "docs/cursor-work/server/folder-rule-sync.py"); _frs = _iu.module_from_spec(_spec); _spec.loader.exec_module(_frs)
_bad = _frs.main(check=True)
if _bad:
    fail("FOLDER RULE", f"{len(_bad)} folder(s) lack or have a stale 00-FOUNDER-TECH-RULE.md (run python3 docs/cursor-work/server/folder-rule-sync.py): {', '.join(_bad[:3])}")
try:
    _ac = json.load(open("docs/claude/AUDIT-COUNTER.json"))
    if _ac["phases_since_audit"] > 3:
        fail("AUDIT EVERY 3 PHASES", f"{_ac['phases_since_audit']} phases since the last audit: run the auto audit + loophole fix first (docs/claude/AUDIT-EVERY-3-PHASES.md)")
    elif _ac["phases_since_audit"] == 3:
        warn("AUDIT EVERY 3 PHASES", "3 phases since the last audit: the audit is DUE now, before the next phase")
except FileNotFoundError:
    fail("AUDIT EVERY 3 PHASES", "docs/claude/AUDIT-COUNTER.json is missing")
for w in warns:
    print(w)
for x in fails:
    print(x)

print(f"rules-gate: {len(fails)} fail, {len(warns)} warn, {len(staged)} staged file(s)")
sys.exit(1 if fails else 0)
