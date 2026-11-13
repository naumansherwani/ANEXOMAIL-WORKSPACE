#!/usr/bin/env python3
"""Q-series STATE MACHINE (his 13 Nov 2026 19:06 order: an advance AUTOMATIC handoff system so no compaction loses the place).
State = append-only, SHA-256 hash-chained ledger docs/claude/state/Q-STATE.jsonl (same technology as the mail ledger: every event carries prev_hash + hash, a change to history breaks the chain).
The PLAN below is the Q-series order with the advance technology per step. HANDOFF-LIVE.md's step block is GENERATED from the ledger (never hand-edited), rules-gate verifies chain + block, and the SessionStart hook (.claude/settings.json) prints it after every start, resume and compaction.
  qstate.py show                      current step, next steps, standing rules
  qstate.py brief                     what the SessionStart hook prints
  qstate.py start <id>                mark a step started
  qstate.py done <id> "<proof>"       mark a step done (the proof text must say where it was seen: his output / my Chrome look)
  qstate.py defer <id> "<reason>"     his order moved the proof of a part to a later step
  qstate.py verify                    chain + handoff block check (the gate calls this)
  qstate.py render                    rewrite the generated block in HANDOFF-LIVE.md
"""
import hashlib, json, os, sys, time
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
LEDGER = os.path.join(ROOT, "docs/claude/state/Q-STATE.jsonl"); HAND = os.path.join(ROOT, "docs/claude/HANDOFF-LIVE.md")
BEG, END = "<!--QSTATE-->", "<!--/QSTATE-->"
PLAN = [  # (id, title, advance technology)
 ("Q1b3-T1", "Postfix inbound TLS X25519MLKEM768 first", "Postfix 3.10 + OpenSSL 3.5, ML-KEM-768 hybrid, TLS 1.3 AES-256-GCM"),
 ("Q1b3-T2", "clamd AlertEncrypted + AlertExceedsMax", "ClamAV INSTREAM, fail-closed quarantine"),
 ("Q1b3-T3", "first real mail through the intake", "Postfix per-address LMTP RFC 2033, ClamAV, seal on arrival, ledger; end-to-end self-test mails sent by Postfix itself (NOT deferred, his order 19:11)"),
 ("Q1b3-T4", "SQL E171: scan state 'opaque'", "PostgreSQL RLS, append-only ledger, selftest + CHECK"),
 ("SF", "SERVER-FIRST law + H3-ONLY gate, automatic for one year (his 13 Nov 21:08)", "hash-chained receipt ledger of his pasted read-only server output (serverfirst.py), pre-commit gate SERVER FIRST + H3 ONLY, TECH LAW text = HTTP/3 only"),
 ("KP1", "ports / Caddy / SNI front / UDP / DNS audit, read-only (replaces the false-STOP founder-h3-check.sh)", "ss -H with /proc exe names (no 15-char cut), Caddy admin config read, founder.env ports, dig HTTPS, ufw, GO/STOP table"),
 ("KP1b", "own Rust authoritative DNS for founderworkspace.anexomail.com only (Namecheap has no HTTPS record type: his screenshot 13 Nov 22:03; no third-party vendor, ever)", "Rust + tokio, hickory-proto, UDP+TCP 53 bound to 62.238.98.98 and 2a01:4f9:c014:5df6::1 (never wildcard: systemd-resolved owns 127.0.0.53/54:53), SOA/NS/A/AAAA/CAA/HTTPS type 65 alpn=h3 (RFC 9460), DNSSEC Ed25519 NSEC3, DNS cookies + RRL, zone in PostgreSQL + hash-chain ledger, NS delegation from Namecheap (ns1/ns2.anexomail.com A = 62.238.98.98 already exist)"),
 ("QUI-H", "ledger-box hybrid P1+P2 (his haan 13 Nov 19:55, backup /root/backups/ledger-hybrid-13nov taken, restore = fmail-ui-rollback.sh or commit 9fe8155e)", "kernel WASM SHA-256 chain verify in the background, passive status chip, Bridge Mail-ledger card (new file + one-line mount, Scene3D.tsx never edited), React 19 TS"),
 ("QUI-H1", "sub-phase: passive ledger chip + auto verify + slim empty pane", "React 19 TS, signed kernel-verified proof door, hash-chain SHA-256 ledger (Proton KT / Apple CKV style: automatic, passive status)"),
 ("QUI-H2", "sub-phase: Bridge 'Mail ledger' audit card + deep link into the mailbox folder", "React 19 TS, E168 bridge feed, new file + one-line mount (Scene3D.tsx untouched)"),
 ("K8e", "HTTP/3 ONLY: h1 and h2 removed for ever (his order 13 Nov 20:30)", "quinn + h3, ALPN h3 only, tcp 443 closed, Alt-Svc 1y persist, DNS HTTPS record alpn=h3 (RFC 9460), TLS 1.3 AES-256-GCM X25519MLKEM768"),
 ("KP2", "UDP-blocked network break-glass: SSH tunnel to the loopback listener, tested at home first (the khatra he asked to make a phase)", "SSH local forward to 127.0.0.1:3210, host-proof + DBSC behaviour measured, never assumed"),
 ("KP3", "WebTransport on UDP 443 same-origin (CSP 'self'), no SSE / H2 / H1 fallback, honest 'QUIC blocked by network' status (his typed order 14 Nov 00:41)", "h3 0.0.8 + h3-quinn 0.0.10 + h3-webtransport 0.1.2 on the ONE quinn UDP 443 endpoint (HTTP/3 requests and WebTransport sessions together), TLS 1.3 AES-256-GCM X25519MLKEM768, Rust Tokio, kernel WebTransport RPC, React 19 TS honest status"),
 ("QUI-H3", "sub-phase: Q-ledger-kernel, the WASM kernel re-hashes the whole chain in the browser (SQL E172 door, Rust Tokio door, kernel sha256 chain check)", "Rust WASM kernel SHA-256 (web-wasm/src/hash.rs), length-prefixed fmail-ledger-v1 formula, rows streamed over the kernel WebTransport RPC, PostgreSQL RLS door"),
 ("QUI-H4", "sub-phase: per-message Merkle inclusion proof (U1 link) against the founder audit batch", "RFC 6962 style Merkle audit path verified in the WASM kernel, founder_audit anchor"),
 ("QPERF", "mail latency percentiles p50/p90/p95/p99/p99.9 + SLO burn (his 13 Nov 20:01: p90, p95 and more advanced; SQL E173)", "PostgreSQL percentile_cont + append-only mail_latency samples (SQL E172), Rust Tokio timing at LMTP accept/scan/seal/commit, HDR-histogram style buckets, Bridge card"),
 ("Q1d-1", "DKIM key from Compose + DNS TXT", "Ed25519 + RSA DKIM, passkey touch (mail.key)"),
 ("Q1d-2", "FMAIL_SEND=on + real outgoing mail", "Rust Tokio SMTP, STARTTLS TLS 1.3 X25519MLKEM768, undo window, outgoing PQ TLS proof"),
 ("Q1b4", "SPF / DKIM / DMARC verdicts + trust ring (U3)", "Rust mail-auth, Framer Motion ring"),
 ("Q3", "attachments + live over WebTransport + 8-segment ring (U4)", "Rust Tokio WebTransport, Hetzner Storage Box, ClamAV, WASM kernel"),
 ("Qtls", "MTA-STS / DANE / TLS-RPT", "RFC 8461 / 7672 / 8460"),
 ("U1U2", "ledger proof pill + Touch-to-Unseal live proof (U1), PQC pill segment (U2)", "kernel SHA-256/Merkle verify, passkey touch, React 19 TS"),
 ("Q4", "kernel pqmail OpenPGP RFC 9980", "Rust WASM kernel ML-KEM-768 + X25519, ML-DSA-65 + Ed25519"),
 ("U5", "Who-can-read-this sheet, Ctrl K mail actions, light theme (approved)", "Radix Dialog, command palette, React 19 TS"),
 ("Q1e", "calendar E174-E175", "Rust + SQL RLS + React TS, same sealing"),
]
RULES = "docs/claude/HANDOFF-LIVE.md (his standing rules, tools, server facts) + docs/claude/Q-FIX-ORDER-13NOV.md"
def sha(b): return hashlib.sha256(b).hexdigest()
def events():
    if not os.path.exists(LEDGER): return []
    return [json.loads(l) for l in open(LEDGER, encoding="utf-8") if l.strip()]
def body(e): return json.dumps({k: e[k] for k in ("seq", "ts", "id", "status", "proof", "prev")}, sort_keys=True, separators=(",", ":")).encode()
def verify_chain():
    prev = "0" * 64
    for i, e in enumerate(events(), 1):
        if e["seq"] != i or e["prev"] != prev or e["hash"] != sha(body(e)): return f"ledger broken at event {i}"
        if e["id"] not in {p[0] for p in PLAN}: return f"unknown step id {e['id']} at event {i}"
        prev = e["hash"]
    return None
def status():
    s = {p[0]: ("todo", "") for p in PLAN}
    for e in events(): s[e["id"]] = (e["status"], e["proof"])
    return s
def add(i, st, proof):
    err = verify_chain()
    if err: sys.exit("FAIL: " + err)
    if i not in {p[0] for p in PLAN}: sys.exit("FAIL: unknown step " + i)
    ev = events(); prev = ev[-1]["hash"] if ev else "0" * 64
    e = {"seq": len(ev) + 1, "ts": time.strftime("%Y-%m-%d %H:%M %z"), "id": i, "status": st, "proof": proof, "prev": prev}; e["hash"] = sha(body(e))
    open(LEDGER, "a", encoding="utf-8").write(json.dumps(e, sort_keys=True) + "\n"); render()
def now_step(s):
    for p in PLAN:
        if s[p[0]][0] in ("todo", "started"): return p
def block():
    s = status(); out = [BEG, "## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)"]
    n = now_step(s)
    out.append(f"NOW: {n[0]} - {n[1]}  [{n[2]}]" if n else "NOW: every planned Q step is done")
    for p in PLAN:
        st, pr = s[p[0]]; mark = {"done": "[x]", "deferred": "[~]", "started": "[>]", "todo": "[ ]"}[st]
        out.append(f"- {mark} {p[0]}: {p[1]}  ({p[2]})" + (f"  PROOF: {pr}" if pr and st != "todo" else ""))
    out.append(f"chain head: {(events()[-1]['hash'][:16] if events() else 'empty')} ({len(events())} events)"); out.append(END); return "\n".join(out)
def render():
    t = open(HAND, encoding="utf-8").read()
    if BEG in t: t = t[:t.index(BEG)] + block() + t[t.index(END) + len(END):]
    else: t = t.rstrip("\n") + "\n\n" + block() + "\n"
    open(HAND, "w", encoding="utf-8").write(t)
def check():
    err = verify_chain()
    if err: return err
    t = open(HAND, encoding="utf-8").read()
    if BEG not in t or END not in t: return "HANDOFF-LIVE.md has no generated state block: run qstate.py render"
    if t[t.index(BEG):t.index(END) + len(END)] != block(): return "HANDOFF-LIVE.md state block is stale: run qstate.py render"
    return None
if __name__ == "__main__":
    c = sys.argv[1] if len(sys.argv) > 1 else "show"
    if c == "verify": e = check(); print(e or "OK: chain valid, handoff block current"); sys.exit(1 if e else 0)
    elif c == "render": render(); print("rendered")
    elif c in ("start", "done", "defer") and len(sys.argv) >= 3:
        pr = sys.argv[3] if len(sys.argv) > 3 else ""
        if c != "start" and not pr: sys.exit("FAIL: a proof / reason text is required")
        add(sys.argv[2], {"start": "started", "done": "done", "defer": "deferred"}[c], pr); print(block())
    elif c == "brief":
        print("=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===\n" + open(os.path.join(ROOT, "docs/claude/PHASE-NOW.md"), errors="ignore").read()[:2500] + "\n=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===\n" + block() + "\nRead " + RULES + " before any reply (his standing rules: Roman Urdu, one phase at a time, no history rewrite, no Co-Authored line, GREEN only with proof, Rule-70 table + 'Abhi code mein NAHI').")
    else: print(block()); print("\nRules/tools/server facts: " + RULES)
