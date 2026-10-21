#!/usr/bin/env python3
"""B6 (G16) Brain patch — surgical, idempotent. Live Brain ki billing-sync.ts + index.ts par:
  1) billing-sync.ts: `POST /api/billing/portal` (Bun FALLBACK; Rust billing.portal PRIMARY) — block repo ki billing-sync.ts se nikala jata hai
  2) index.ts: billingSyncAuthRouter ko polarAuthRouter se PEHLE mount (purana polar.ts ka /subscription /invoices ab shadow nahi karta)
Usage: brain_portal_patch.py <live_src_dir> <repo_billing_sync.ts> <out_dir>
Exit: 0 = kuch badla (out_dir mein nayi files) · 4 = sab pehle se laga · 3 = anchor nahi mila (kuch nahi badla)"""
import os, re, sys

live, repo_bs, out = sys.argv[1:4]
bs_p, ix_p = os.path.join(live, "routes", "billing-sync.ts"), os.path.join(live, "index.ts")
bs, ix = open(bs_p).read(), open(ix_p).read()
repo = open(repo_bs).read()
changed = []

# --- 1) portal block ---
START = "// ---------------------------------------------------------------------------\n// B6 (G16): POST /api/billing/portal"
ANCHOR = "// ---------------------------------------------------------------------------\n// 2) GET /api/billing/state"
a, b = repo.find(START), repo.find(ANCHOR)
if a < 0 or b < 0 or b < a:
    print("STOP: repo billing-sync.ts mein portal block / anchor nahi"); sys.exit(3)
block = repo[a:b]
if 'authRouter.post("/portal"' in bs:
    print("billing-sync.ts: portal pehle se hai")
else:
    if bs.count(ANCHOR) != 1:
        print("STOP: live billing-sync.ts mein '// 2) GET /api/billing/state' anchor %d baar (1 chahiye)" % bs.count(ANCHOR)); sys.exit(3)
    for name, imp in (("createHash", 'import { createHash, createHmac, randomBytes } from "node:crypto";\n'),
                      ("readFileSync", 'import { readFileSync } from "node:fs";\n')):
        if name not in bs:
            m = re.search(r'^import \{ Router \} from "express";\n', bs, re.M)
            if not m:
                print("STOP: live billing-sync.ts mein express import line nahi"); sys.exit(3)
            bs = bs[:m.end()] + imp + bs[m.end():]
        elif imp not in bs:
            print("STOP: live billing-sync.ts mein %s pehle se kisi aur tareeqe se import hai — haath se dekhna padega" % name); sys.exit(3)
    bs = bs.replace(ANCHOR, block + ANCHOR, 1)
    changed.append("billing-sync.ts (+portal)")

# --- 2) mount order ---
L_SYNC, L_POLAR = 'app.use("/api/billing", billingSyncAuthRouter);\n', 'app.use("/api/billing", polarAuthRouter);\n'
if ix.count(L_SYNC) != 1 or ix.count(L_POLAR) != 1:
    print("STOP: live index.ts mein mount lines nahi mili (sync %d, polar %d)" % (ix.count(L_SYNC), ix.count(L_POLAR))); sys.exit(3)
if ix.index(L_SYNC) < ix.index(L_POLAR):
    print("index.ts: mount order pehle se theek hai")
else:
    ix = ix.replace(L_SYNC, "", 1)
    note = ("// B6: billing-sync PEHLE mount — uski /subscription + /invoices (get_billing_subscription RPC, lifetime/family\n"
            "// samet, wahi jo Rust deta hai) ab asli hain; polar.ts ke purane table-reading dono routes un ke peeche rehte hain.\n")
    ix = ix.replace(L_POLAR, note + L_SYNC + L_POLAR, 1)
    changed.append("index.ts (mount order)")

if not changed:
    sys.exit(4)
os.makedirs(os.path.join(out, "routes"), exist_ok=True)
open(os.path.join(out, "routes", "billing-sync.ts"), "w").write(bs)
open(os.path.join(out, "index.ts"), "w").write(ix)
print("badla:", ", ".join(changed))
