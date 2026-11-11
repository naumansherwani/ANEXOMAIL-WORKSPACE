#!/usr/bin/env python3
"""Writes/updates the founder technology rule file at the top of EVERY folder of the repo (founder 11 Nov 2026 17:27: "AJJ SE EK RULE PURAY REPO KE HER FOLDER KE TOP PE LIKHO").
Run after adding folders: python3 docs/cursor-work/server/folder-rule-sync.py   (rules-gate fails when a folder lacks the file)."""
import os, subprocess, sys
NAME = "00-FOUNDER-TECH-RULE.md"
SKIP = ("lovable-gold", "node_modules", "dist", "target", "__pycache__", "public", ".git")
BODY = """<!--TECHLAW-->
# RULE FOR EVERY CLAUDE WHO TOUCHES THIS FOLDER (founder 11 Nov 2026, capitals, repeated)
**FOUNDER TECHNOLOGY = ONLY SUPER ADVANCED LATEST: RUST WASM KERNEL + RUST/TOKIO/AXUM + HTTP/3 (QUIC) PRIMARY (H2/H1.1 FALLBACK ONLY) + WEBTRANSPORT + MOQ + REACT 19/TYPESCRIPT/TANSTACK/VITE 8/TAILWIND 4/RADIX-SHADCN/FRAMER MOTION/GSAP/THREE.JS + POSTGRESQL RLS + X25519MLKEM768 + AES-256-GCM + ML-DSA HYBRID. NEVER OLDER. A LISTED TECHNOLOGY MISSING FROM THE CODE = OPEN GAP, NEVER GREEN.**
THE CODE IN THIS FOLDER GOES INTO THE PHASE NAMED IN docs/claude/tech-contracts/CURRENT.md AND MUST USE THAT PHASE'S LISTED TECHNOLOGY (blueprint row, TECH LAW cell).
BEFORE ANY CODE: read docs/claude/RESUME-POINT.md, docs/claude/TECH-FIRST-PROTOCOL.md, docs/claude/tech-contracts/CURRENT.md. Every commit carries `Phase:` and `Tech:` lines (commit-msg hook). After every 3 phases: AUTO AUDIT + AUTO LOOPHOLE FIX, then the pull command (docs/claude/AUDIT-EVERY-3-PHASES.md). Founder and awam code are NEVER mixed. The repo is public: never commit a secret (docs/claude/REPO-THEFT-DEFENCE-11NOV.md).
"""
def dirs():
    out = subprocess.check_output(["git", "ls-files"], text=True).splitlines()
    ds = set()
    for f in out:
        parts = f.split("/")[:-1]
        if any(p in SKIP or p.startswith(".") for p in parts):
            continue
        for i in range(1, len(parts) + 1):
            ds.add("/".join(parts[:i]))
    ds.add("")
    return sorted(ds)
def main(check=False):
    bad = []
    for d in dirs():
        p = os.path.join(d, NAME) if d else NAME
        if not os.path.exists(p) or open(p).read() != BODY:
            bad.append(p)
            if not check:
                open(p, "w").write(BODY)
    return bad
if __name__ == "__main__":
    b = main(check="--check" in sys.argv)
    print(f"folder-rule-sync: {len(b)} {'missing/stale' if '--check' in sys.argv else 'written'}")
    sys.exit(1 if ("--check" in sys.argv and b) else 0)
