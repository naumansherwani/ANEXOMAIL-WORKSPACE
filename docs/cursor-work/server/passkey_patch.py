#!/usr/bin/env python3
"""B2 (G42): live Rust main.rs mein passkey module jodta hai. Idempotent, anchor-based (rust-engine-install jaisa), kuch na mile to STOP.
   python3 -I passkey_patch.py <main.rs>
Jodta hai: `mod passkey_core; mod passkey_glue;` (const PORT se pehle), PUBLIC hook (bearer se pehle: login khud public hai),
authenticated hook (whoami se pehle). Dono hooks `&headers` dete hain (Origin / User-Agent / X-Forwarded-For chahiye).
"""
import re, sys
p = sys.argv[1]
s = open(p).read()
PROCS = ['"auth.passkey.options"', '"auth.passkey.verify"', '"auth.recovery.redeem"',
         '"auth.passkey.register.options"', '"auth.passkey.register.verify"', '"auth.passkey.status"', '"auth.recovery.generate"']
have_mod = "mod passkey_glue;" in s
have_pub = "passkey_glue::public_owns(" in s
have_auth = "passkey_glue::owns(" in s
if have_mod and have_pub and have_auth:
    print("main.rs: passkey pehle se judi hai"); sys.exit(0)
if have_mod or have_pub or have_auth or "passkey_glue::" in s:
    print("PATCH FAIL: main.rs mein passkey adhoori judi hai — haath se dekhna padega"); sys.exit(4)
for pr in PROCS:
    if pr in s:
        print("PATCH FAIL: live main.rs mein %s pehle se maujood hai — double-handling se bachne ke liye ruk gaya" % pr); sys.exit(4)
a = re.search(r'^const PORT: u16 = 3200;', s, re.M)
if not a:
    print("PATCH FAIL: `const PORT: u16 = 3200;` anchor nahi mila"); sys.exit(4)
s = s[:a.start()] + "mod passkey_core;\nmod passkey_glue;\n\n" + s[a.start():]
d = re.search(r'^(?:pub )?async fn dispatch\(\s*Path\(proc\)', s, re.M)
if not d:
    print("PATCH FAIL: `async fn dispatch(Path(proc)...` nahi mila"); sys.exit(4)
bm = re.compile(r'^    let token = match bearer\(&headers\) \{', re.M).search(s, d.start())
if not bm:
    print("PATCH FAIL: dispatch mein `let token = match bearer(&headers)` nahi mila"); sys.exit(4)
pub = ('    // passkey / recovery LOGIN (B2) — public: yehi login hai, bearer nahi hota. Challenge DB mein single-use.\n'
       '    if passkey_glue::public_owns(&proc) {\n        return passkey_glue::public(&proc, &input, &headers).await;\n    }\n\n')
s = s[:bm.start()] + pub + s[bm.start():]
d = re.search(r'^(?:pub )?async fn dispatch\(\s*Path\(proc\)', s, re.M)
w = s.find('    if proc == "whoami" {', d.start())
if w < 0:
    w = s.find('    // 8o — founder-only expiry watch', d.start())
if w < 0:
    print("PATCH FAIL: whoami / 8o anchor nahi mila"); sys.exit(4)
auth = ('    // passkey enrol / status / recovery codes (B2) — Rust PRIMARY, Bun fallback (Rust 404/501/502/503 par).\n'
        '    if passkey_glue::owns(&proc) {\n        return passkey_glue::dispatch(&proc, &token, &input, &headers).await;\n    }\n\n')
s = s[:w] + auth + s[w:]
open(p, "w").write(s)
print("main.rs: passkey judi")
