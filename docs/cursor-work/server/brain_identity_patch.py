#!/usr/bin/env python3
# brain_identity_patch.py — live Brain (routes/auth.ts, routes/chat.ts, index.ts) par identity-vault ke tukde SURGICALLY lagata hai.
# Usage: brain_identity_patch.py <live_src> <repo_dir> <out_dir>      (repo_dir mein origin/main ki server/ tree ka copy: routes/auth.ts, routes/chat.ts, index.ts)
# Har file: pehle se juda ho to "same"; anchor na mile to STOP (exit 4, kuch nahi likhta). Idempotent. Raw values/secrets yahan nahi.
import os, sys

live, repo, out = sys.argv[1:4]

def rd(p):
    return open(p, encoding="utf-8").read()

def between(s, a, b, what):
    i = s.find(a)
    j = s.find(b, i + 1) if i >= 0 else -1
    if i < 0 or j < 0:
        print("STOP: repo file mein '%s' ka hissa nahi mila" % what); sys.exit(4)
    return s[i:j]

def once(s, anchor, what):
    if s.count(anchor) != 1:
        print("STOP: live file mein anchor '%s' %d baar mila (1 chahiye): %s" % (what, s.count(anchor), anchor[:70].replace("\n", "\\n"))); sys.exit(4)

res = {}
os.makedirs(os.path.join(out, "routes"), exist_ok=True)

# ---- routes/auth.ts ----
a = rd(os.path.join(live, "routes/auth.ts")); ra = rd(os.path.join(repo, "routes/auth.ts"))
if "identityGuard" in a:
    res["auth.ts"] = "same"
else:
    blockA = between(ra, "  let rawIdentity", "  const { data, error } = await getPublicAuth().auth.signUp({", "signup check")
    blockC = between(ra, "// Logged-out appeal after a refused signup", 'authRouter.post("/login"', "signup-appeal route")
    anchor_sign = "  const { data, error } = await getPublicAuth().auth.signUp({"
    anchor_vault = '      console.error("[auth.signup.vault]", err);\n    }\n'
    anchor_login = 'authRouter.post("/login", async (req, res) => {'
    for an, w in ((anchor_sign, "signUp call"), (anchor_vault, "device_vault_register catch"), (anchor_login, "login route")):
        once(a, an, w)
    a = a.replace(anchor_sign, "  // E66/E68/E69 identity vault: ek insaan, ek account (mirror + database; deny => 403, vault band aur mirror nahi => 503)\n" + blockA + anchor_sign, 1)
    a = a.replace(anchor_vault, anchor_vault + "    if (rawIdentity) await identityGuard.register(data.user.id, rawIdentity);\n", 1)
    a = a.replace(anchor_login, blockC + anchor_login, 1)
    lines = a.split("\n")
    last = max(n for n, l in enumerate(lines[:80]) if l.startswith("import ") or l.startswith("} from "))
    lines.insert(last + 1, 'import * as identityGuard from "../lib/identity-guard";\nimport { shapeFromSignals, verifyDeviceKeyProof } from "../lib/identity-vault";')
    a = "\n".join(lines)
    res["auth.ts"] = "patched"
open(os.path.join(out, "routes/auth.ts"), "w", encoding="utf-8").write(a)

# ---- routes/chat.ts ----
c = rd(os.path.join(live, "routes/chat.ts")); rc = rd(os.path.join(repo, "routes/chat.ts"))
if '"/integrity/identity"' in c:
    res["chat.ts"] = "same"
else:
    blk = between(rc, 'chatRouter.get("/integrity/identity"', 'chatRouter.post("/integrity/export"', "identity routes")
    an = 'chatRouter.post("/integrity/export"'
    once(c, an, "integrity/export route")
    c = c.replace(an, blk + an, 1)
    res["chat.ts"] = "patched"
open(os.path.join(out, "routes/chat.ts"), "w", encoding="utf-8").write(c)

# ---- index.ts ----
x = rd(os.path.join(live, "index.ts"))
if "startIdentityWorkers" in x:
    res["index.ts"] = "same"
else:
    imp = 'import { authRouter } from "./routes/auth";'
    call = "  startMailWorker();\n"
    once(x, imp, "authRouter import"); once(x, call, "startMailWorker() call")
    x = x.replace(imp, 'import { startIdentityWorkers } from "./lib/identity-guard";\n' + imp, 1)
    x = x.replace(call, call + "  startIdentityWorkers();\n", 1)
    res["index.ts"] = "patched"
open(os.path.join(out, "index.ts"), "w", encoding="utf-8").write(x)

print(" ".join("%s=%s" % kv for kv in res.items()))
