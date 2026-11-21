"""ADMIN DESK advanced-technology gate (his 21 Nov 2026 08:19). Called by docs/cursor-work/server/rules-gate.py. Returns (fails, warns). Shouts."""
import json, os, datetime
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
    return fails, warns
if __name__ == "__main__":
    a, b = check()
    for x in a: print("FAIL", x)
    for x in b: print("warn", x)
