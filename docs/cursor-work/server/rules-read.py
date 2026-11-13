#!/usr/bin/env python3
"""RULES-READ RECEIPT (founder 11 Nov 2026 22:05: "compact ke baad rules nahi padhay ga to gate fail hoga").
Run this FIRST after every compaction / new chat / every 2 hours. It PRINTS the rules the commit gate stands on (so they are in Claude's context) and writes
.git/rules-read-receipt.json. rules-gate.py --staged FAILS the commit when the receipt is missing, older than 2 hours, or the protocol / contract / gate files changed since it was written."""
import hashlib, json, os, re, sys, time
FILES = ["docs/claude/HANDOFF-LIVE.md", "docs/claude/RESUME-POINT.md", "docs/claude/TECH-FIRST-PROTOCOL.md", "docs/claude/tech-contracts/CURRENT.md", "docs/claude/TECH-LAW-GATE.json"]
RECEIPT = ".git/rules-read-receipt.json"
def sha(p): return hashlib.sha256(open(p, "rb").read()).hexdigest() if os.path.exists(p) else ""
def head(p, a, b):
    L = open(p, errors="ignore").read().split("\n"); print(f"\n##### {p} (lines {a}-{b})"); print("\n".join(x[:330] for x in L[a:b]))
if __name__ == "__main__":
    print("FOUNDER TECHNOLOGY LAW (CLAUDE.md line 18): Rust WASM kernel, Rust Tokio/Axum, WebTransport/QUIC, HTTP/3 primary (H2/H1 fallback only), MoQ, React 19, TS, TanStack Start+Router, Vite 8, Tailwind 4, Radix/shadcn, Framer, GSAP, Three.js, Postgres RLS, Hetzner Storage Box, ClamAV, X25519MLKEM768, AES-256-GCM, ML-DSA hybrid, OpenPGP PQC. NEVER OLDER. A LISTED ITEM MISSING FROM CODE = OPEN GAP = NEVER GREEN = GATE FAILS.")
    head("docs/claude/TECH-FIRST-PROTOCOL.md", 0, 22)
    t = open("docs/claude/RESUME-POINT.md", errors="ignore").read().split("\n")
    i = next((k for k, l in enumerate(t) if "STATE AT" in l and l.startswith("##")), 0); print("\n##### RESUME-POINT state block"); print("\n".join(x[:300] for x in t[i:i + 8]))
    head("docs/claude/tech-contracts/CURRENT.md", 0, 20)
    print("\n##### PHASE NOW (ONE phase, read first: docs/claude/PHASE-NOW.md)"); print(open("docs/claude/PHASE-NOW.md", errors="ignore").read()[:5000])
    print("\n##### HANDOFF LIVE (current step + his standing rules + tools; docs/claude/HANDOFF-LIVE.md)"); print(open("docs/claude/HANDOFF-LIVE.md", errors="ignore").read()[:7000])
    print("\n##### OPEN / OVERDUE technologies (TECH-LAW-GATE.json)")
    for c in json.load(open("docs/claude/TECH-LAW-GATE.json"))["checks"]:
        if c["status"] == "open": print(f'  OPEN {c["id"]}: fails from {c.get("fail_after", "?")} - {c["why"][:140]}')
    print("\n##### BLUEPRINT TECH LAW header"); b = open("docs/claude/BLUEPRINT-ABC-01NOV.md", errors="ignore").read().split("\n")
    for l in b:
        if l.startswith("> **TECH LAW"): print(l[:700]); break
    json.dump({"time": time.time(), "hashes": {f: sha(f) for f in FILES}}, open(RECEIPT, "w"))
    print("\nRECEIPT WRITTEN (valid 2 h, until a rule/contract/gate file changes). Now work: contract first, code second, GREEN only with proof.")
