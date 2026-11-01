#!/usr/bin/env python3
"""Technology proof: for every 'latest technology' the founder had noted, is it IN THE CODE of the founder lane and the awam lane?
Reads the repo only. Prints one line per technology: PROVEN (with file:line evidence) or MISSING (with the phase that must build it).
  python3 docs/cursor-work/server/tech-proof.py            # table
  python3 docs/cursor-work/server/tech-proof.py --md       # markdown for the ledger
Exit code 0 always (it is a report, not a gate). Rule 69: nothing is claimed that this script cannot find in a file."""
import os, re, subprocess, sys
ROOT = subprocess.check_output(["git", "rev-parse", "--show-toplevel"]).decode().strip()

def find(path, pat, flags=re.I):
    """first 'file:line' under path (file or dir) whose line matches pat, else None"""
    p = os.path.join(ROOT, path)
    files = [p] if os.path.isfile(p) else [os.path.join(d, f) for d, _, fs in os.walk(p) if "node_modules" not in d and "/target" not in d and "/dist" not in d for f in fs if f.endswith((".rs", ".toml", ".ts", ".tsx", ".json", ".sql"))]
    rx = re.compile(pat, flags)
    for f in files:
        try:
            for i, line in enumerate(open(f, errors="ignore"), 1):
                if rx.search(line):
                    return f"{os.path.relpath(f, ROOT)}:{i}"
        except OSError:
            pass
    return None

# (technology, founder check (path, regex) or None, awam check or None, phase that builds a missing one)
T = [
 ("Rust + axum 0.8",                 ("server/founder/Cargo.toml", r'^axum\s*=\s*"0\.8'), ("server/rust/Cargo.toml", r'^axum\s*=\s*"0\.8'), "-"),
 ("Tokio async runtime",             ("server/founder/Cargo.toml", r'^tokio\s*='),       ("server/rust/Cargo.toml", r'^tokio\s*='), "-"),
 ("WebTransport / QUIC (wtransport)", ("server/founder/Cargo.toml", r'^wtransport'),      ("server/rust/Cargo.toml", r'^wtransport'), "founder 7a"),
 ("HTTP/3 edge (Caddy)",             None,                                               None, "server check (not repo code)"),
 ("Ed25519 server->browser",         ("server/founder/src/sign.rs", r'Ed25519'),         None, "-"),
 ("HMAC + HKDF browser->server",     ("server/founder/src/sign.rs", r'hkdf'),            None, "-"),
 ("SHA-256 audit chain + Merkle",    ("server/founder/src/ledger.rs", r'merkle'),        None, "-"),
 ("Rust WASM kernel (Rule 52)",      ("web-wasm/src/lib.rs", r'MODULES'),                ("src/lib/rpc-contract.ts", r'kernel'), "-"),
 ("Kernel runs in a Web Worker",     ("founder-web/src/kernel.worker.ts", r'onmessage|self\.'), None, "-"),
 ("Kernel module merkle@1",          ("web-wasm/src/lib.rs", r'merkle@1'),               None, "-"),
 ("React 19.2",                      ("founder-web/package.json", r'"react":\s*"\^19'),  ("package.json", r'"react":\s*"\^19'), "-"),
 ("Vite 8",                          ("founder-web/package.json", r'"vite":\s*"\^8'),    ("package.json", r'"vite":\s*"\^8'), "-"),
 ("TypeScript",                      ("founder-web/package.json", r'"typescript"'),      ("package.json", r'"typescript"'), "-"),
 ("TanStack Router",                 ("founder-web/package.json", r'@tanstack/react-router'), ("package.json", r'@tanstack/react-router'), "-"),
 ("TanStack Start (SSR)",            None,                                               ("package.json", r'@tanstack/react-start'), "founder is a static SPA by design"),
 ("Tailwind CSS 4.2",                ("founder-web/package.json", r'"tailwindcss":\s*"4\.2'), ("package.json", r'"tailwindcss":\s*"\^4\.2'), "-"),
 ("shadcn / Radix + cva",            ("founder-web/package.json", r'class-variance-authority'), ("package.json", r'@radix-ui'), "-"),
 ("Three.js (lazy)",                 ("founder-web/src/Scene3D.tsx", r'import\("three"\)'), ("package.json", r'"three"'), "-"),
 ("Three.js WebGPU renderer",        ("founder-web/src/Scene3D.tsx", r'WebGPURenderer'), ("src", r'WebGPURenderer'), "founder UI phase 'WebGPU' (after 7-4)"),
 ("Framer Motion",                   ("founder-web/package.json", r'framer-motion|"motion"'), ("package.json", r'framer-motion'), "founder UI phase 'Motion + GSAP' (after 7-4)"),
 ("GSAP",                            ("founder-web/package.json", r'"gsap"'),            ("package.json", r'"gsap"'), "founder UI phase 'Motion + GSAP' (after 7-4)"),
 ("PostgreSQL + RLS",                ("docs/cursor-work/sql/E117_founder_passkey_stepup_recovery.sql", r'row level security'), ("docs/cursor-work/sql", r'row level security'), "-"),
 ("Passkey / WebAuthn in SQL",       ("docs/cursor-work/sql/E118_founder_chairman_protocol.sql", r'founder_t3_begin'), None, "-"),
 ("webauthn-rs (Rust passkey)",      ("server/founder/Cargo.toml", r'webauthn'),         None, "founder 7-2"),
 ("DBSC (device-bound sessions)",    ("server/founder/src", r'DBSC|Secure-Session'),    None, "founder 7b"),
 ("Post-quantum hybrid TLS check",   None,                                               None, "founder 7b (server check first)"),
 ("TLS 1.3 AES-256-GCM-only terminator (rustls)", ("server/founder/src/tls256.rs", r'TLS13_AES_256_GCM_SHA384'), ("server/rust", r'TLS13_AES_256_GCM_SHA384'), "founder T256-1 written; awam T256-2 (after founder proof + his written haan)"),
 ("TLS posture ledger (SQL, real handshakes)", ("docs/cursor-work/sql/E119_founder_tls_posture.sql", r'founder_tls_posture'), None, "-"),
 ("PQ mail-content encryption (OpenPGP RFC 9980: ML-KEM-768+X25519, ML-DSA-65+Ed25519)", ("server/founder/src", r'ml.?kem|ml.?dsa|9980'), ("server/rust", r'ml.?kem|ml.?dsa|9980'), "founder PQM (after 11) then awam PQM"),
 ("Streaming attachment encryption (hybrid ML-KEM + chunked AEAD)", ("server/founder/src", r'chunked_aead|stream_seal'), ("server/rust", r'chunked_aead|stream_seal'), "PQN1-PQN2 (with PQM)"),
 ("Live state sync encrypted at app level (WebTransport)", ("server/founder/src", r'state_seal|live_seal'), ("server/rust", r'state_seal|live_seal'), "PQN3 (after 7a)"),
 ("MoQ (Media over QUIC)",           ("server/founder/src", r'moq'),                     ("server/rust", r'moq'), "founder MoQ-F (after 7a); awam MQ0-MQ4"),
]
rows = []
for name, fo, aw, phase in T:
    f = find(*fo) if fo else None
    a = find(*aw) if aw else None
    rows.append((name, fo is not None, f, aw is not None, a, phase))

def cell(applicable, ev):
    if not applicable: return "n/a here"
    return "PROVEN " + ev if ev else "MISSING"
if "--md" in sys.argv:
    print("| Technology | Founder lane | Awam lane | Built by |\n|---|---|---|---|")
    for n, fa, f, aa, a, ph in rows: print(f"| {n} | {cell(fa, f)} | {cell(aa, a)} | {ph} |")
else:
    for n, fa, f, aa, a, ph in rows: print(f"{n:36} founder: {cell(fa, f):70} awam: {cell(aa, a):55} {ph}")
miss = [n for n, fa, f, aa, a, ph in rows if (fa and not f) or (aa and not a)]
print(f"\nMISSING somewhere: {len(miss)} -> " + "; ".join(miss), file=sys.stderr)
