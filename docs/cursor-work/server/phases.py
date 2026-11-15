#!/usr/bin/env python3
# AUTO PHASE LEDGER + BLUEPRINT (his order 15 Nov 2026 19:30 PKT: "auto ledger update system, advance technology only, a phase without advance technology = commit blocked automatically").
# ONE source of truth: docs/claude/state/PHASES.json. The readable blueprint docs/claude/FOUNDER-BLUEPRINT-CLEAN-14NOV.md is GENERATED from it (between the PHASES markers),
# together with the Q series live list from qstate.py. Nobody edits that table by hand.
#   python3 docs/cursor-work/server/phases.py render                    rewrite the table in the blueprint
#   python3 docs/cursor-work/server/phases.py check                     what the commit gate runs (exit 1 = commit blocked)
#   python3 docs/cursor-work/server/phases.py set <id> <status> "<proof>" [--tech "<advance technology>"]   status = GREEN | IN PROGRESS | PARTLY | NOT GREEN | PAUSED
#   python3 docs/cursor-work/server/phases.py show                      print the table
# GATE RULES (a violation blocks the commit, rules-gate "PHASE TECH"):
#  1. every phase has a technology text that names at least one ADVANCE technology from the founder law (Rust, WASM kernel, WebTransport, HTTP/3, QUIC, ML-KEM, ML-DSA, AES-256, React 19, TanStack, PostgreSQL/SQL RLS, ClamAV, Hetzner, WebGPU, Three.js, GSAP, passkey/WebAuthn, Ed25519, Merkle ...);
#  2. no OLD technology as a choice (Bun, Node, WebSocket, SSE, HTTP/2, HTTP/1.1, jQuery ...) unless the text says "no <that>";
#  3. GREEN needs the words 'WIRED: YES', 'REAL: YES', 'TECH-LAW CHECKED' in its proof (rows marked legacy were green before this system and are kept as they were);
#  4. the generated blueprint table must equal PHASES.json + qstate (a stale or hand-edited table = blocked, run render);
#  5. the Q series steps in qstate.py must also name an advance technology.
import json, os, re, sys, time
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
J = os.path.join(ROOT, "docs/claude/state/PHASES.json"); BP = os.path.join(ROOT, "docs/claude/FOUNDER-BLUEPRINT-CLEAN-14NOV.md")
BEG, END = "<!--PHASES-BEGIN-->", "<!--PHASES-END-->"
STATUS = ("GREEN", "IN PROGRESS", "PARTLY", "NOT GREEN", "PAUSED")
GOOD = re.compile(r"rust|wasm|kernel|webtransport|http/3|quic|ml-kem|mlkem|ml-dsa|aes-256|react 19|tanstack|postgres|\bsql\b|\brls\b|clamav|hetzner|webgpu|three\.js|gsap|framer|passkey|webauthn|ed25519|merkle|tokio|axum|moq|openpgp|rfc \d+|dbsc|tailwind|shadcn|radix|typescript|vite|sha-256", re.I)
BAD = ["bun", "node", "websocket", "sse", "http/2", "h2", "http/1.1", "jquery", "express", "php"]
def load(): return json.load(open(J, encoding="utf-8"))["phases"]
def save(p): json.dump({"phases": p}, open(J, "w", encoding="utf-8"), indent=1, ensure_ascii=False); open(J, "a").write("\n")
def qrows():
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import qstate
    st = qstate.status(); return [(i, t, tech, st[i][0], st[i][1]) for i, t, tech in qstate.PLAN]
def bad_old(tech):
    t = tech.lower(); out = []
    for b in BAD:
        for m in re.finditer(r"(?<![a-z0-9])" + re.escape(b) + r"(?![a-z0-9])", t):
            clause = re.split(r"[,;()]", t[:m.start()])[-1] + " " + re.split(r"[,;()]", t[m.end():])[0]
            if not re.search(r"\b(no|never|without|removed?|deleted?|banned?|gone|instead of|replaces?)\b", clause): out.append(b)
    return out
def errors():
    e = []; ph = load()
    for r in ph:
        n = f"phase {r['id']}"
        if not GOOD.search(r.get("tech", "")) or len(r.get("tech", "")) < 10: e.append(f"{n}: no ADVANCE technology written in front of the phase (technology = '{r.get('tech','')[:50]}')")
        for b in bad_old(r.get("tech", "")): e.append(f"{n}: old technology '{b}' written as a choice (founder law: latest only)")
        if r["status"] not in STATUS: e.append(f"{n}: status '{r['status']}' not one of {STATUS}")
        if r["status"] == "GREEN" and not r.get("legacy") and not all(w in r.get("proof", "") for w in ("WIRED: YES", "REAL: YES", "TECH-LAW CHECKED")):
            e.append(f"{n}: GREEN without 'WIRED: YES / REAL: YES / TECH-LAW CHECKED' in its proof")
    for i, t, tech, s, p in qrows():
        if not GOOD.search(tech): e.append(f"Q step {i}: no ADVANCE technology named ('{tech[:50]}')")
    try: cur = open(BP, encoding="utf-8").read()
    except Exception: return e + ["blueprint file missing"]
    if BEG not in cur or END not in cur: e.append("blueprint has no PHASES markers")
    elif cur[cur.index(BEG):cur.index(END) + len(END)] != block(): e.append("blueprint table is stale or was edited by hand: run python3 docs/cursor-work/server/phases.py render")
    return e
def cell(x): return str(x).replace("|", "/").replace("\n", " ")
def block():
    ph = load(); o = [BEG, "<!-- GENERATED from docs/claude/state/PHASES.json + Q-STATE.jsonl by docs/cursor-work/server/phases.py: never edit by hand. A phase with no advance technology blocks the commit. -->", "",
        "| # | Phase | What it is | Advance technology | In code | Status | Target (his day plan; a date is a TARGET, a phase closes only with proof) | Proof |", "|---|---|---|---|---|---|---|---|"]
    for r in ph: o.append("| %s | %s | %s | %s | %s | **%s** | %s | %s |" % (r["n"], cell(r["id"]), cell(r["what"]), cell(r["tech"]), cell(r["in_code"]), r["status"], cell(r.get("target", "")), cell(r["proof"])))
    o += ["", "### Q series (live from qstate.py, step by step; a step is done only with his paste + my live look)", "", "| Step | What | Advance technology | Status | Proof |", "|---|---|---|---|---|"]
    for i, t, tech, s, p in qrows(): o.append("| %s | %s | %s | %s | %s |" % (cell(i), cell(t), cell(tech), {"done": "GREEN", "started": "IN PROGRESS", "deferred": "his hands, closed by his word", "todo": "todo"}.get(s, s), cell(p)[:260]))
    o.append(END); return "\n".join(o)
def render():
    cur = open(BP, encoding="utf-8").read()
    if BEG in cur and END in cur: cur = cur[:cur.index(BEG)] + block() + cur[cur.index(END) + len(END):]
    else:
        a = cur.index("| # | Phase |"); b = cur.index("\nOrder of work from here")
        cur = cur[:a] + block() + "\n" + cur[b:]
    open(BP, "w", encoding="utf-8").write(cur)
def setp(argv):
    if len(argv) < 3: sys.exit("usage: phases.py set <id> <status> \"<proof>\" [--tech \"...\"]")
    i, st, pr = argv[0], argv[1], argv[2]; tech = argv[argv.index("--tech") + 1] if "--tech" in argv else None
    raw = open(J, encoding="utf-8").read(); ph = load(); r = next((x for x in ph if x["id"] == i), None)
    if not r: sys.exit("FAIL: unknown phase '%s' (ids: %s)" % (i, ", ".join(x["id"] for x in ph)))
    if st not in STATUS: sys.exit("FAIL: status must be one of %s" % (STATUS,))
    r["status"], r["proof"] = st, pr + " [" + time.strftime("%d %b %H:%M") + "]"; r.pop("legacy", None)
    if tech: r["tech"] = tech
    save(ph); e = errors()
    e = [x for x in e if "stale" not in x]
    if e: open(J, "w", encoding="utf-8").write(raw); print("\n".join("BLOCKED: " + x for x in e)); sys.exit(1)
    render(); print("OK phase %s = %s" % (i, st))
if __name__ == "__main__":
    c = sys.argv[1] if len(sys.argv) > 1 else "check"
    if c == "render": render(); print("rendered")
    elif c == "check":
        e = errors(); print("\n".join("PHASE TECH: " + x for x in e) if e else "phases: ok (%d phases, every one names advance technology)" % len(load())); sys.exit(1 if e else 0)
    elif c == "set": setp(sys.argv[2:])
    elif c == "show": print(block())
