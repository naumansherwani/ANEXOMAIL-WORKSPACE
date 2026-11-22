#!/usr/bin/env python3
"""DESK PHASE START REMINDER (his 22 Nov 2026 06:41: "her phase se pehle rules read kerna hai, working now read kerna hai, reminder technology").
Usage: python3 docs/cursor-work/server/desk-phase-start.py <phase, e.g. C or R4-1b>   (rules-read.py also runs it).
PRINTS the Desk strict rules, the phase row (technology + features) from DESK-PHASES-22NOV.md, both WORKING-NOW heads and the last ledger lines, then writes
.git/desk-phase-receipt.json. rules-gate.py --staged FAILS a Desk code commit without a receipt younger than 2 hours (gate 'DESK PHASE START')."""
import hashlib, json, os, re, sys, time
P = "docs/claude/admin-desk/DESK-PHASES-22NOV.md"; R = ".git/desk-phase-receipt.json"
def main():
    ph = (sys.argv[1] if len(sys.argv) > 1 else "").strip()
    t = open(P, errors="ignore").read().split("\n")
    print("##### DESK STRICT RULES + PHASE ROW (" + P + ")")
    on = False
    for l in t:
        if l.startswith("## STRICT RULES"): on = True
        elif l.startswith("## PHASES"): on = False
        if on: print(l[:400])
    print("\n##### PHASE ROW" + (f" matching '{ph}'" if ph else " (no phase given: whole table)"))
    for l in t:
        if l.startswith("| ") and (not ph or re.search(r"\b" + re.escape(ph) + r"\b", l.split("|")[1], re.I)): print(l[:600])
    for f, n in (("docs/claude/admin-desk/state/WORKING-NOW.md", 14), ("docs/claude/state/WORKING-NOW.md", 6)):
        print(f"\n##### {f} (head)"); print("\n".join(x[:260] for x in open(f, errors="ignore").read().split("\n")[:n]) if os.path.exists(f) else "missing")
    print("\n##### LEDGER TAIL (docs/cursor-work/founder/founder-commands.md)")
    print("\n".join(x[:300] for x in open("docs/cursor-work/founder/founder-commands.md", errors="ignore").read().rstrip().split("\n")[-4:]))
    json.dump({"time": time.time(), "phase": ph, "sha": hashlib.sha256(open(P, "rb").read()).hexdigest()}, open(R, "w"))
    print("\nDESK PHASE RECEIPT WRITTEN (valid 2 h). Technology listed for this phase becomes CODE; HTTP/1 and HTTP/2 are never named; GREEN only after my live Chrome look.")
if __name__ == "__main__": main()
