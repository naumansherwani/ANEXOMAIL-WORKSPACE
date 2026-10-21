#!/usr/bin/env python3
"""B3 (R1): live Rust main.rs mein mail module + queue worker jodta hai. Idempotent, anchor-based, kuch na mile to STOP.
   python3 -I mail_patch.py <main.rs>
Jodta hai: `mod mail_core; mod mail_glue;` (const PORT se pehle), authenticated hook (whoami se pehle): mail.send/schedule/schedule.cancel + org.mailboxes.list/create, aur worker spawn (start_safety_worker ke baad).
Purane 501 `use_bun_fallback` arms main.rs mein rehte hain (hook unse pehle pakadta hai) — fallback ka rasta bana rehta hai.
"""
import re, sys
p = sys.argv[1]
s = open(p).read()
have_mod = "mod mail_glue;" in s
have_hook = "mail_glue::owns(" in s
if have_mod and have_hook:
    print("main.rs: mail pehle se judi hai"); sys.exit(0)
if have_mod or have_hook or "mail_glue::" in s:
    print("PATCH FAIL: main.rs mein mail adhoori judi hai — haath se dekhna padega"); sys.exit(4)
if "mod passkey_glue;" not in s:
    print("PATCH FAIL: B2 (passkey) pehle lagni chahiye (mail_glue passkey_core::iso_utc istemal karta hai)"); sys.exit(4)
a = re.search(r'^const PORT: u16 = 3200;', s, re.M)
if not a:
    print("PATCH FAIL: `const PORT: u16 = 3200;` anchor nahi mila"); sys.exit(4)
s = s[:a.start()] + "mod mail_core;\nmod mail_glue;\n\n" + s[a.start():]
d = re.search(r'^(?:pub )?async fn dispatch\(\s*Path\(proc\)', s, re.M)
if not d:
    print("PATCH FAIL: `async fn dispatch(Path(proc)...` nahi mila"); sys.exit(4)
w = s.find('    if proc == "whoami" {', d.start())
if w < 0:
    w = s.find('    // 8o — founder-only expiry watch', d.start())
if w < 0:
    print("PATCH FAIL: whoami / 8o anchor nahi mila"); sys.exit(4)
hook = ('    // mail.send + org.mailboxes.* (B3) — Rust PRIMARY, Bun fallback (Rust 404/501/502/503 par).\n'
        '    if mail_glue::owns(&proc) {\n        return mail_glue::dispatch(&proc, &token, &input, &headers).await;\n    }\n\n')
s = s[:w] + hook + s[w:]
sp = 'tokio::spawn(start_safety_worker());'
if sp not in s:
    print("PATCH FAIL: `tokio::spawn(start_safety_worker());` anchor nahi mila (mail worker spawn ke liye)"); sys.exit(4)
s = s.replace(sp, sp + '\n    // B3 — mail queue worker (Rust). Bun worker standby rehta hai; dono mail_queue_claim (E54) se uthate hain.\n    tokio::spawn(mail_glue::start_worker());', 1)
open(p, "w").write(s)
print("main.rs: mail judi")
