#!/usr/bin/env python3
"""B4 (R5): live Rust main.rs mein events module jodta hai. Idempotent, anchor-based, kuch na mile to STOP.
   python3 -I events_patch.py <main.rs>
Jodta hai: `mod events_core; mod events_glue;`, WebTransport hello hook (`mode == "events"` ya events ON ho to `mode == "mail"` bhi hub se;
EVENTS=off par purana 700 ms poll chalta rahta hai), /internal/event route, publish layer (har kamyab mutating /rpc/* ke baad)."""
import re, sys
p = sys.argv[1]
s = open(p).read()
if "mod events_glue;" in s and "events_glue::serve(" in s and "events_glue::publish_layer" in s:
    print("main.rs: events pehle se judi hai"); sys.exit(0)
if "events_glue::" in s or "mod events_glue;" in s:
    print("PATCH FAIL: main.rs mein events adhoori judi hai — haath se dekhna padega"); sys.exit(4)
a = re.search(r'^const PORT: u16 = 3200;', s, re.M)
if not a: print("PATCH FAIL: `const PORT: u16 = 3200;` anchor nahi mila"); sys.exit(4)
s = s[:a.start()] + "mod events_core;\nmod events_glue;\n\n" + s[a.start():]
anchor = '    // F3 — mail inbox live stamp (org-scoped). Chat hello still needs conversation_id.\n    if mode == "mail" {'
if s.count(anchor) != 1: print("PATCH FAIL: wt_session ka `mode == \"mail\"` anchor nahi mila (%d)" % s.count(anchor)); sys.exit(4)
hook = ('    // B4 (R5) — event-driven hub: ek org ka ek hub, polling per-session nahi. EVENTS=off => neeche purana 700 ms poll.\n'
        '    if events_glue::enabled() && (mode == "events" || mode == "mail") {\n'
        '        events_glue::serve(send, &token, &hello).await;\n        return;\n    }\n\n')
s = s.replace(anchor, hook + anchor, 1)
r = '        .route("/file/download", get(file_download))\n        .layer(cors);'
if s.count(r) != 1: print("PATCH FAIL: router end anchor nahi mila (%d)" % s.count(r)); sys.exit(4)
s = s.replace(r, '        .route("/file/download", get(file_download))\n'
              '        // B4: loopback + secret; inbound mail pipe / Bun fallback yahan se live push dete hain\n'
              '        .route("/internal/event", post(events_glue::internal_event))\n'
              '        .layer(axum::middleware::from_fn(events_glue::publish_layer))\n'
              '        .layer(cors);', 1)
open(p, "w").write(s)
print("main.rs: events judi")
