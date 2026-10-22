#!/usr/bin/env python3
# brain_identity_patch.py — live Brain (routes/auth.ts, routes/chat.ts, index.ts) par identity-vault ke tukde SURGICALLY lagata hai.
# Usage: brain_identity_patch.py <live_src> <repo_dir> <out_dir>      (repo_dir mein origin/main ki server/ tree ka copy: routes/auth.ts, routes/chat.ts, index.ts)
# Har file: pehle se juda ho to "same"; anchor na mile to STOP (exit 4, kuch nahi likhta). Idempotent. Raw values/secrets yahan nahi.
# E70 (hardening) upgrade bhi isi se: pehle se lagi E66-E69 wali live files par fingerprint/hold/gate ke tukde (marker: fingerprintFrom / integrity/identity/gate / identity_account_state).
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
st_a = []
if "identityGuard" not in a:
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
    st_a.append("vault")
# E70 upgrade: har qadam apni shart par (idempotent; fresh install ke baad bhi baqi qadam chalte hain)
if "fingerprintFrom(req.body" not in a:
    new_block = between(ra, "  let rawIdentity", "  const { data, error } = await getPublicAuth().auth.signUp({", "signup check (E70)")
    old_block = between(a, "  let rawIdentity", "  const { data, error } = await getPublicAuth().auth.signUp({", "signup check (live)")
    a = a.replace(old_block, new_block, 1); st_a.append("e70-check")
if "const reg = await identityGuard.register" not in a:
    reg_old = "    if (rawIdentity) await identityGuard.register(data.user.id, rawIdentity);\n"
    once(a, reg_old, "register call")
    reg_new = between(ra, "    if (rawIdentity) {\n      const reg", "  }\n  if (!data.session?.access_token)", "register + pending answer (E70)")
    a = a.replace(reg_old, reg_new, 1); st_a.append("e70-register")
if "user_banned" not in a:
    ae_old = between(a, "function authError(", '  if (fallback === "invalid_credentials") {', "authError (live)")
    ae_new = between(ra, "function authError(", '  if (fallback === "invalid_credentials") {', "authError (E70)")
    a = a.replace(ae_old, ae_new, 1); st_a.append("e70-banned")
if "import { fingerprintFrom }" not in a:
    imp = 'import * as identityGuard from "../lib/identity-guard";'
    once(a, imp, "identityGuard import")
    a = a.replace(imp, imp + '\nimport { fingerprintFrom } from "../lib/identity-guard";', 1); st_a.append("e70-import")
res["auth.ts"] = "+".join(st_a) if st_a else "same"
open(os.path.join(out, "routes/auth.ts"), "w", encoding="utf-8").write(a)

# ---- routes/chat.ts ----
c = rd(os.path.join(live, "routes/chat.ts")); rc = rd(os.path.join(repo, "routes/chat.ts"))
an = 'chatRouter.post("/integrity/export"'
blk = between(rc, 'chatRouter.get("/integrity/identity"', an, "identity routes")
if '"/integrity/identity"' not in c:
    once(c, an, "integrity/export route")
    c = c.replace(an, blk + an, 1)
    res["chat.ts"] = "patched"
elif '"/integrity/identity/gate"' not in c:
    live_blk = between(c, 'chatRouter.get("/integrity/identity"', an, "identity routes (live)")
    c = c.replace(live_blk, blk, 1)
    res["chat.ts"] = "patched-e70"
else:
    res["chat.ts"] = "same"
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

# ---- lib/integrity-gate.ts (E70: pending/rejected hold bhi 403) ----
os.makedirs(os.path.join(out, "lib"), exist_ok=True)
gp = os.path.join(live, "lib/integrity-gate.ts")
if os.path.exists(gp):
    g = rd(gp); rg = rd(os.path.join(repo, "lib/integrity-gate.ts"))
    if "identity_account_state" in g:
        res["integrity-gate.ts"] = "same"
    else:
        a0 = '    const { data, error } = await supa.from("account_integrity").select("state").eq("user_id", sub).maybeSingle();\n'
        once(g, a0, "integrity-gate account_integrity query")
        add = between(rg, a0, "  } catch {\n    blocked = false;", "integrity-gate E70 block")
        i = g.index(a0); j = g.index("  } catch {\n    blocked = false;", i)
        g = g[:i] + add + g[j:]
        res["integrity-gate.ts"] = "patched-e70"
    open(os.path.join(out, "lib/integrity-gate.ts"), "w", encoding="utf-8").write(g)
else:
    res["integrity-gate.ts"] = "absent"

print(" ".join("%s=%s" % kv for kv in res.items()))
