"""ADMIN DESK advanced-technology gate (his 21 Nov 2026 08:19). Called by docs/cursor-work/server/rules-gate.py. Returns (fails, warns). Shouts."""
import json, os, datetime, glob, re
SHOUT = "!!! ADMIN DESK ADVANCED TECHNOLOGY MISSING !!! "
def check(root="."):
    fails, warns = [], []
    p = os.path.join(root, "admin-desk/gates/DESK-FEATURES.json")
    if not os.path.exists(p):
        return [SHOUT + "admin-desk/gates/DESK-FEATURES.json is missing"], []
    today = datetime.date.today().isoformat()
    for f in json.load(open(p))["features"]:
        fp = os.path.join(root, f["file"])
        txt = open(fp, errors="ignore").read().lower() if os.path.exists(fp) else ""
        good = os.path.exists(fp) and all(m.lower() in txt for m in f["must"])
        tag = f'{f["id"]} [{f["phase"]}] {f["feature"]} -> needs {f["tech"]} in {f["file"]}'
        if f["status"] == "code" and not good:
            fails.append(SHOUT + tag + " (marked CODE but the technology is NOT in the file: NO COMMIT)")
        elif f["status"] == "planned" and good:
            warns.append(f'{f["id"]} now holds in code: change its status to code in admin-desk/gates/DESK-FEATURES.json')
        elif f["status"] == "planned" and today >= f.get("fail_after", "9999"):
            fails.append(SHOUT + tag + f' (planned, date {f["fail_after"]} has come: NO COMMIT)')
        elif f["status"] == "planned":
            warns.append(f'ADMIN DESK OPEN until {f.get("deadline","?")}: {tag}')
    # HTTP/3 HARD BLOCK + HTTP/2 BAN (his 21 Nov 2026 09:18)
    cfg = json.load(open(p)).get("_h3_block", {})
    s2 = [f for f in json.load(open(p))["features"] if f["id"] == "R3a0-stage2"]
    h3_live = bool(s2) and s2[0]["status"] == "code"
    HB = "!!! ADMIN DESK HTTP/3 NOT LIVE: NO NEXT PHASE, NO COMMIT !!! "
    if not h3_live:
        for pat in cfg.get("blocked_until_h3", []):
            for hit in glob.glob(os.path.join(root, pat)):
                fails.append(HB + os.path.relpath(hit, root) + " belongs to a later Desk phase; the Desk's own HTTP/3 + X25519MLKEM768 listener (R3a0-stage2) must be live and in code first")
    allow = set(cfg.get("h2_ban_allow", []))
    for base in cfg.get("h2_ban_scan", []):
        bp = os.path.join(root, base)
        files = [bp] if os.path.isfile(bp) else [os.path.join(dp, n) for dp, _, ns in os.walk(bp) for n in ns]
        for fp in files:
            rel = os.path.relpath(fp, root)
            if rel in allow or not rel.endswith((".rs", ".toml", ".ts", ".tsx")) or "target/" in rel:
                continue
            t = open(fp, errors="ignore").read()
            if re.search(r'http/?2|"http2"|\bh2\b|http/1\.1', t, re.I):
                fails.append("!!! ADMIN DESK HTTP/2 / HTTP/1.1 IS BANNED (HTTP/3 only) !!! " + rel + " mentions it; remove it")
    return fails, warns
if __name__ == "__main__":
    a, b = check()
    for x in a: print("FAIL", x)
    for x in b: print("warn", x)
