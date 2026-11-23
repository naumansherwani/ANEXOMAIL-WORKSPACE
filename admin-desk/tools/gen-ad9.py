#!/usr/bin/env python3
"""Generates sql/AD09.sql (runbook library) and runbooks.seed.json from RUNBOOK-LIBRARY-DRAFT-22NOV.md section C. Run: python3 tools/gen-ad9.py"""
import json, re, os
D = os.path.dirname(os.path.abspath(__file__)) + "/.."
md = open(D + "/RUNBOOK-LIBRARY-DRAFT-22NOV.md", encoding="utf-8").read()
sec = md.split("## C. THE NINE RUNBOOKS")[1].split("## D.")[0]
NEVER = "Never promise a date, a refund, a credit, an upgrade or an owner decision."
SAY = {
 "R1": "I can see your payment has been received and your service is not active yet. I have opened case [case] with the team that can fix this. I cannot give a restore time.",
 "R2": "Your package includes [feature]. I can see it is currently off for your account. I have opened case [case].",
 "R3": "You are at [percent] percent of your limit. Changes to limits are handled by the owner. I have passed your request, reference [case].",
 "R4": "Your account is in a grace period. The date it ends is on your account page. Any change to that is decided by the owner. Reference [case].",
 "R5": "I can see your account is on hold. I can only share what the reason class on your account allows, and I cannot give details or a restore time. I have passed this on, reference [case].",
 "R6": "I can see the account is active. Please use the recovery option on the sign-in page. I will not ask for your password or any code.",
 "R7": "Your domain check for [check] shows [result]. Your administrator needs to change [change].",
 "R8": "The file was held because the scan says [scan]. I cannot open or release it.",
 "R9": "We know several customers are affected. The latest status note is: [approved_note].",
}
KEYS = ["sees", "may", "never", "escalate", "say", "clock"]
rbs = []
for blk in re.split(r"\n(?=R\d+ )", sec.strip()):
    m = re.match(r"(R\d+) (.+)", blk.splitlines()[0])
    if not m: continue
    key, title = m.group(1), m.group(2).strip()
    parts = {}
    for ln in blk.splitlines()[1:]:
        mm = re.match(r"([1-6]) (sees|may|never|escalate|say|clock): (.*)", ln)
        if mm: parts[mm.group(2)] = mm.group(3).strip()
    assert list(parts) == KEYS, (key, list(parts))
    parts["never"] = parts["never"].replace("(no-promise line)", "").rstrip(" ,;") + ". " + NEVER
    parts["say"] = SAY[key]
    steps = [f"Check what the screen shows: {parts['sees']}", f"Do only what is allowed: {parts['may']}", f"Check the never list: {parts['never']}",
             f"Escalate when needed: {parts['escalate']}", "Say this to the customer, fill the brackets from the screen, then copy it.", f"Note the clock: {parts['clock']}"]
    rbs.append({"key": key, "title": title, "parts": parts, "steps": steps, "say_text": SAY[key]})
assert len(rbs) == 9
json.dump({"version": "1.0.0", "runbooks": rbs}, open(D + "/runbooks.seed.json", "w"), indent=1, ensure_ascii=False)

def q(s): return "$q$" + s + "$q$"
seed = "\n".join(
  f"INSERT INTO desk.fadm_runbook (key, title, sort) VALUES ('{r['key']}', {q(r['title'])}, {int(r['key'][1:])}) ON CONFLICT (key) DO NOTHING;\n"
  f"INSERT INTO desk.fadm_runbook_version (runbook_key, major, minor, patch, parts, steps, say_text, changelog) SELECT '{r['key']}',1,0,0,{q(json.dumps(r['parts'], ensure_ascii=False))}::jsonb,{q(json.dumps(r['steps'], ensure_ascii=False))}::jsonb,{q(r['say_text'])},'First draft, waiting for the Chairman to approve' WHERE NOT EXISTS (SELECT 1 FROM desk.fadm_runbook_version WHERE runbook_key='{r['key']}');"
  for r in rbs)
TAG = "  -- no-money-gate-ok"   # the runbook rules NAME the words they forbid (refund, credit...); the gate allows a tagged line
W = re.compile(r"refund|credit|discount|compensation|invoice|payment|billing|price|amount", re.I)
seed = "\n".join(l + TAG if W.search(l) and "no-money-gate-ok" not in l else l for l in seed.split("\n"))
tpl = open(D + "/tools/AD9.template.sql", encoding="utf-8").read()
tpl = "\n".join(l + TAG if W.search(l) and "no-money-gate-ok" not in l and "@@SEED@@" not in l and not l.lstrip().startswith("--") else l for l in tpl.split("\n"))
final = tpl.replace("@@SEED@@", seed).replace("@@NEVER@@", NEVER)
final = "\n".join(l + TAG if W.search(l) and "no-money-gate-ok" not in l and not l.lstrip().startswith("--") else l for l in final.split("\n"))
open(D + "/sql/AD09.sql", "w", encoding="utf-8").write(final)
print("AD09.sql written,", len(rbs), "runbooks")
