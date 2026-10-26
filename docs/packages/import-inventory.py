#!/usr/bin/env python3
"""ONE-TIME importer: docs/claude/inventory/INV-1/2/3 (kal raat ke 213 features) + PP1 (docs/claude/PP1-FULL-GATE-TABLE-26OCT.md)
-> docs/packages/features.tsv.  starts_at = PP1 + founder verdicts (04:39/04:48/04:56/07:10 PKT, 26 Oct). Phir build-views.py chalao.
status: MATCHES-CODE (code gate == starts_at) | GATE-TO-BUILD (code gate alag; server/UI gate banana baqi) | PROPOSED (naya feature, code nahi) | LATER (not built)."""
import os, re

H = os.path.dirname(os.path.abspath(__file__))
INV = os.path.join(H, "..", "claude", "inventory")
ORD = ["basic", "pro", "business", "business_pro", "enterprise"]


def cells(fn):
    for l in open(os.path.join(INV, fn), encoding="utf-8"):
        if l.startswith("|"):
            yield [x.strip() for x in l.strip().strip("|").split("|")]


def code_tier(g):
    g = g.lower()
    if "founder" in g or "internal" in g:
        return "founder"
    if "ai host" in g:
        return "ai_soon"
    if "business pro" in g:
        return "business_pro"
    if "business+" in g or "showorg" in g or "showchat" in g or "showcrmcollab" in g or "showcrmrisk" in g or "showworkbusiness" in g or "showdomains" in g:
        return "basic" if "showdomains" in g else "business"
    if "pro+" in g or "showpro" in g or "showwork" in g or "showcrm" in g or "showmultiple" in g or "requires=pro" in g:
        return "pro"
    return "basic"


# ---- PP1 + founder verdicts ----
PRO_CAL = ("overlap matrix", "focus ring", "availability / free-busy", "files on a meeting", "meeting cost", "meeting goal")
PRO_MAIL = ("keyboard shortcuts", "snooze", "private note", "per-thread analytics", "thread rescue", "schedule send", "templates",
            "snippets", "pre-send", "follow-up", "word prediction", "reading time", "send from a chosen identity", "cross-device draft")


def inv1(c):
    area, name, gate = c[0], c[1], c[-1]
    n = name.lower()
    t = "basic"
    if area == "CAL":
        if n.startswith("meeting rooms"):
            t = "business"
        elif any(n.startswith(k) for k in PRO_CAL):
            t = "pro"
    elif area == "MAIL":
        if "ai compose" in n:
            t = "ai_soon"
        elif n.startswith("thread header"):
            t = "business"  # chat link
        elif any(n.startswith(k) for k in PRO_MAIL):
            t = "pro"
    elif area == "PPL" and n.startswith("link to full crm"):
        t = "pro"
    return t


def inv2(c):
    i = int(c[0])
    name = c[1]
    if i in range(1, 12) or i in (13, 14, 15, 16, 17, 18, 19, 20):
        return "business"
    if i == 12:
        return "business"  # decision ledger -> chat work-layer (PP1 #24)
    if i == 21:
        return "pro"
    if i in (22, 23, 24, 33, 36, 37, 58, 64, 67, 68, 69, 70, 71, 73):
        return "basic"
    if 25 <= i <= 32:
        return "business"
    if i == 34:
        return "business_pro"
    if i == 35:
        return "later"
    if 38 <= i <= 48 or i == 56:
        return "pro"
    if i in (49, 50, 51, 52, 53):
        return "business"
    if i in (54, 55):
        return "business_pro"
    if i == 57:
        return "founder"
    if 59 <= i <= 62 or i == 65:
        return "pro"
    if i == 63:
        return "business"  # CEO: Promise recovery code+INV mein Business+ (showWorkBusinessRecord); PP1 #15 ka P+ is se override
    if i == 66 or i == 72 or i in (75, 76, 77, 78, 80):
        return "business"
    if i in (74, 79):
        return "pro"
    return "basic"


def inv3(c):
    i = int(c[0])
    if i in (8, 9):
        return "business_pro"
    if 1 <= i <= 7 or i == 10 or i == 17:
        return "business"
    if i in (13, 26):
        return "founder"
    if i in (27, 28, 29):
        return "business_pro"
    if i == 47:
        return "ai_soon"
    if i == 57:
        return "enterprise"  # Priority Support: Enterprise included, baaki add-on
    return "basic"


rows, seen = [], set()


def add(id_, area, name, tier, evidence, gate, note=""):
    if tier in ("founder", "ai_soon", "later", "enterprise"):
        st = "LATER" if tier == "later" else "OUT-OF-PACKAGE" if tier in ("founder", "ai_soon") else "PP1"
    else:
        ct = code_tier(gate)
        st = "MATCHES-CODE" if ct == tier else "GATE-TO-BUILD"
    rows.append([id_, area, name.replace("\t", " "), tier, st, evidence.replace("\t", " ")[:120], (f"code-gate: {gate}" + (f" · {note}" if note else "")).replace("\t", " ")[:140]])


n1 = 0
for c in cells("INV-1-CALENDAR-MAIL.md"):
    if c[0] in ("CAL", "MAIL", "PPL", "SRCH", "MIG", "MOVE", "DOM"):
        n1 += 1
        add(f"I1-{n1:02d}", c[0], c[1], inv1(c), c[3] if len(c) > 3 else "", c[-1])
for c in cells("INV-2-CHAT-CRM-WORK-ANALYTICS.md"):
    if c[0].isdigit():
        add(f"I2-{int(c[0]):02d}", "INV2", c[1], inv2(c), c[3] if len(c) > 3 else "", c[-1])
for c in cells("INV-3-ORG-SECURITY-STORAGE-LANDING.md"):
    if c[0].isdigit() and len(c) >= 7 and c[0] != "59":
        add(f"I3-{int(c[0]):02d}", c[1], c[2], inv3(c), c[4], c[-1])

# NAYE features (inventory mein nahi) — PROPOSED, gate pehle (Rule 53)
NEW = [
    ("N-CRM-01", "CRM", "Multiple pipelines + custom fields (Pro 1/5, Business 5/25, Biz Pro unlimited)", "pro", "docs/packages/crm/CRM-PHASES.md P1"),
    ("N-CRM-02", "CRM", "Duplicate detect + merge", "pro", "CRM-PHASES P1"),
    ("N-CRM-03", "CRM", "Web form to lead (Pro 1, Business 10, Biz Pro unlimited)", "pro", "CRM-PHASES P2"),
    ("N-CRM-04", "CRM", "Lead scoring + assignment rules (round-robin)", "business", "CRM-PHASES P3"),
    ("N-CRM-05", "CRM", "Workflow automation / Blueprint (Business 10 rules, Biz Pro unlimited)", "business", "CRM-PHASES P4"),
    ("N-CRM-06", "CRM", "Quotes / CPQ", "business", "CRM-PHASES P5"),
    ("N-CRM-07", "CRM", "Deal approval process (discount limits)", "business_pro", "CRM-PHASES P5"),
    ("N-CRM-08", "CRM", "Sales cadences", "business", "CRM-PHASES P6"),
    ("N-CRM-09", "CRM", "Forecast + quotas", "business", "CRM-PHASES P6"),
    ("N-CRM-10", "CRM", "Territory management", "business_pro", "CRM-PHASES P6"),
    ("N-CRM-11", "CRM", "Custom CRM dashboards", "business", "CRM-PHASES P6"),
    ("N-DOC-01", "Docs", "CRDT collaborative docs (Personal NAHI)", "business", "PP1 #38, not built"),
    ("N-ENT-01", "Enterprise", "Unlimited users, 15TB, 100MB, Priority Support included, Rust-only (NO Bun)", "enterprise", "alag phase, abhi ZERO"),
    ("N-ANA-01", "Analytics", "Analytics Center data backend (7 reports, Rust+WT)", "basic", "E89 + analytics_glue.rs (response debt Basic; baqi LIMITS/gates features mein)"),
]
for id_, area, name, tier, ev in NEW:
    rows.append([id_, area, name, tier, "PROPOSED" if id_ != "N-ANA-01" and id_ != "N-ENT-01" else ("PP1" if id_ == "N-ENT-01" else "MATCHES-CODE"), ev, ""])

# 07:40 ke baad server-side gate GREEN (docs/packages/GREEN-LEDGER.md): inventory 04:30 ki thi, isliye override
GATED_SINCE_0740 = {"I1-08", "I1-09", "I1-18", "I1-53", "I1-54", "I1-59", "I2-74", "I2-79",
                    # 26 Oct 10:30 Pro-green batch: Rust cal_glue/calfile_glue/main.rs server gate + Bun fallback + UI
                    "I1-10", "I1-17", "I1-19", "I1-42", "I1-56", "I2-65", "I2-63"}
for r in rows:
    if r[0] in GATED_SINCE_0740:
        r[4] = "MATCHES-CODE"; r[6] = (r[6] + " · server gate GREEN 07:40 (ledger)")[:160]

hdr = ["# id\tarea\tfeature\tstarts_at\tstatus\tevidence\tnote",
       "# SOURCE: kal raat ke INV-1/2/3 (213 features) + PP1 gate table + founder verdicts. Banaya: import-inventory.py (one-time); ab sirf is file ko edit karo, phir build-views.py.",
       "# starts_at: basic|pro|business|business_pro|enterprise|founder|ai_soon|later  ; status: MATCHES-CODE | GATE-TO-BUILD (gate banana baqi) | PROPOSED | LATER | OUT-OF-PACKAGE | PP1"]
with open(os.path.join(H, "features.tsv"), "w", encoding="utf-8") as f:
    f.write("\n".join(hdr) + "\n" + "\n".join("\t".join(r) for r in rows) + "\n")
print(len(rows), "rows")
