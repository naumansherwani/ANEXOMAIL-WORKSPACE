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
        head = open(top, encoding="utf-8").read(9500)
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
# status ok = enforced on every commit; status open = known gap with a deadline (warning until closed).
import json
try:
    for c in json.load(open("docs/claude/TECH-LAW-GATE.json"))["checks"]:
        txt = open(c["file"], errors="ignore").read().lower() if os.path.exists(c["file"]) else ""
        good = (c["must"].lower() in txt) if "must" in c else (c["mustnot"].lower() not in txt)
        if c["status"] == "ok" and not good:
            fail("TECH LAW", f'{c["id"]}: {c["why"]} ({c["file"]})')
        elif c["status"] == "open" and not good:
            warn("TECH LAW OPEN", f'{c["id"]} until {c.get("deadline", "?")}: {c["why"]}')
        elif c["status"] == "open" and good:
            warn("TECH LAW", f'{c["id"]} now holds: change its status to ok in docs/claude/TECH-LAW-GATE.json')
except FileNotFoundError:
    fail("TECH LAW", "docs/claude/TECH-LAW-GATE.json is missing")

# TECH-FIRST PROTOCOL (founder 11 Nov 2026 04:33, "forever solution"): docs/claude/TECH-FIRST-PROTOCOL.md. Three mechanical gates so the listed technology can never be skipped again.
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
for led in ("docs/cursor-work/DONE-DO-NOT-REPEAT.md", "docs/claude/CLOSE-THE-GAPS-07NOV.md"):
    if led in staged:
        try:
            d = _sp.run(["git", "diff", "--cached", "-U0", "--", led], capture_output=True, text=True).stdout
            for l in d.splitlines():
                if l.startswith("+") and not l.startswith("+++") and re.search(r"\bGREEN\b", l) and "TECH-LAW CHECKED" not in l and "OPEN" not in l.upper().split("GREEN")[0][-40:]:
                    fail("TECH GREEN WORDS", f"{led}: a line says GREEN without 'TECH-LAW CHECKED' (and WIRED: YES / REAL: YES): {l[1:90]}")
        except OSError:
            pass

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
