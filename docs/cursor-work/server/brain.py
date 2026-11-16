#!/usr/bin/env python3
"""HEARTBEAT + BRAIN of the repo (founder 16 Nov 2026 03:3x: "repo ki heartbeat bana do, brain bhi saath").
Writes founder-web/src/system_brain.json (read by the Systems page panel) and docs/claude/state/HEARTBEAT.json. rec.sh runs it on every step.
HEARTBEAT = where the repo is NOW (commit, current step, phases green / not, open technologies, machine checks). BRAIN = which advance technology and which feature lives in which layer.
The feature map below is hand-kept: when a feature is added or its status changes, edit FEATURES and run this script (the gate does not read it)."""
import json, os, subprocess, time
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
def rd(p): return json.load(open(os.path.join(ROOT, p), encoding="utf-8"))
def git(*a):
    try: return subprocess.run(["git", *a], capture_output=True, text=True, cwd=ROOT).stdout.strip()
    except Exception: return ""
# layer ids: rust, kernel (Rust WASM kernel in the browser), sql, ui, mail (SMTP/TLS wire), tracked (not built yet)
FEATURES = [
 ("Mail sealed on arrival", "Every inbound mail is encrypted (AES-256-GCM) before it is stored; the server opens it only for you", ["rust", "sql"], "live", "fmail_in.rs, fmail_seal.rs, E167-E169", "Rust + PostgreSQL RLS"),
 ("Virus scan before the inbox", "ClamAV scans every mail; anything unsafe goes to Quarantine", ["rust"], "live", "fmail_in.rs (clamd INSTREAM), E171", "ClamAV"),
 ("Ledger verified in your browser", "The mail ledger chain is re-checked by the WASM kernel in your browser, not trusted from the server", ["kernel", "sql", "rust"], "live", "kernel.ts, fmail_proof, E169/E170", "Rust WASM kernel, SHA-256 hash chain, Merkle"),
 ("Arrival to stored speed", "How long a real mail took from arrival to sealed and stored", ["sql", "rust", "ui"], "live", "fmail_perf.rs, E174, BridgeMailSpeed.tsx", "PostgreSQL, Tokio"),
 ("Transport to your browser", "QUIC + WebTransport, HTTP/3 only, DBSC bound session, AES-256 TLS 1.3 with X25519MLKEM768", ["rust", "kernel"], "live", "main.rs, tls256.rs, h3, kernel RPC", "Rust Tokio axum, HTTP/3, WebTransport, ML-KEM"),
 ("Passkey touch for risky actions", "Send, key creation and policy changes need a physical key touch on that exact action", ["rust", "kernel", "ui"], "live", "passkey.rs, passkey.ts", "WebAuthn, Rust"),
 ("Compose, undo window, outbox", "Write mail, undo before it leaves, scheduled send, sealed drafts", ["rust", "sql", "ui"], "installed", "fmail_out.rs, E170, MailCompose.tsx", "Rust Tokio, PostgreSQL"),
 ("DKIM dual signature + oversigning", "Ed25519 and RSA-2048 signatures; From, To, Subject, Date, Message-ID signed once more so nothing can be added after", ["rust"], "installed", "fmail_dkim.rs", "Rust ring, RFC 6376 / RFC 8463"),
 ("DKIM key lifecycle and evidence", "Dated selectors, rotation report, DNS check log, signature log, outside-receiver proof, one-way policy switches, send gate", ["sql", "rust", "ui"], "installed", "E175, fmail_out.rs doors, DkimPanel.tsx", "PostgreSQL 16 RLS hash chains, Tokio, hickory DNS"),
 ("Outgoing TLS to other servers", "Mail leaves over SMTP STARTTLS TLS 1.3 with the post-quantum key exchange; never plain", ["mail", "rust"], "live", "fmail_smtp.rs (rustls)", "rustls, X25519MLKEM768"),
 ("Real outgoing mail", "Sender ON: mail leaves 30 seconds after Send (undo hold), signed with DKIM, over TLS 1.3 with the post-quantum key exchange. First real mail reached Gmail 16 Nov 06:15", ["rust"], "live", "fmail_out.rs sender worker", "Rust Tokio SMTP"),
 ("Live pulse (Systems)", "Live pulse of the running server every 5 s: server clock, beat number, uptime, build commit and install time, database round trip, Tokio tasks and queue, sending switch; honest Stale badge after 12 s", ["rust","kernel","ui"], "written", "pulse.rs, build.rs, PulseCard.tsx, SYS-LIVE", "Rust Tokio RuntimeMetrics + Ed25519 signed door verified by the WASM kernel + React"),
 ("Sending ON/OFF switch", "Real switch for outgoing mail: OFF = mails wait in the Outbox and nothing is sent, ON = the exact-time sender takes them; every change is a hash-chained ledger line, no touch", ["rust","sql","ui"], "live", "E182, fmail_out.rs sending_ep, SendSwitch.tsx", "PostgreSQL policy + Rust Tokio door + React"),
 ("DKIM2 / ML-DSA-44", "Next-generation signature with a post-quantum algorithm. Tracked only: no receiver verifies it yet", ["tracked"], "tracked", "qstate step Q1d-DKIM2", "IETF draft, FIPS 204 ML-DSA-44"),
 ("Attachments over WebTransport", "Large files in sealed chunks over Tokio + WebTransport + Hetzner Storage Box", ["tracked"], "tracked", "TECH-LAW-GATE Q-att-wt", "Tokio, WebTransport, Hetzner"),
 ("Website framework", "Static single-page app with TanStack Router, Rust backend, one WASM kernel in the browser. TanStack Start (server rendering) is dropped for ever by your decision", ["ui", "rust", "kernel"], "live", "founder-web (React 19 + TanStack Router + Vite 8 + Tailwind 4), docs/claude/DECISION-TANSTACK-ROUTER-ONLY-16NOV.md", "React 19, TanStack Router, Vite, Tailwind"),
 ("Media over QUIC", "Live media relay", ["tracked"], "tracked", "TECH-LAW-GATE M-moq", "MoQ, IETF"),
]
def main():
    ph = rd("docs/claude/state/PHASES.json")["phases"]; gate = rd("docs/claude/TECH-LAW-GATE.json")["checks"]
    q = [json.loads(l) for l in open(os.path.join(ROOT, "docs/claude/state/Q-STATE.jsonl"), encoding="utf-8")]
    last = {}
    for e in q: last[e["id"]] = e
    started = [i for i, e in last.items() if e["status"] == "started"]
    now_ = started[-1] if started else "-"
    cnt = {}
    for p in ph: cnt[p["status"]] = cnt.get(p["status"], 0) + 1
    st = {i: e["status"] for i, e in last.items()}
    hb = {"generated": time.strftime("%d %b %Y %H:%M %z"), "head": git("rev-parse", "--short", "HEAD"), "head_subject": git("log", "-1", "--format=%s"),
          "now": now_, "phases": cnt, "q_done": sum(1 for s in st.values() if s == "done"), "q_open": sum(1 for s in st.values() if s in ("started", "deferred")),
          "checks_ok": sum(1 for c in gate if c.get("status") == "ok"), "checks_open": [c["id"] for c in gate if c.get("status") != "ok"][:12]}
    brain = {"heartbeat": hb, "features": [dict(name=n, what=w, layers=l, status=s, where=f, tech=t) for n, w, l, s, f, t in FEATURES],
             "phases": [dict(id=p["id"], what=p["what"], tech=p["tech"], status=p["status"]) for p in ph]}
    json.dump(brain, open(os.path.join(ROOT, "founder-web/src/system_brain.json"), "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    json.dump(hb, open(os.path.join(ROOT, "docs/claude/state/HEARTBEAT.json"), "w", encoding="utf-8"), indent=1)
    print("brain written:", hb["head"], "now", now_, "features", len(FEATURES))
main()
