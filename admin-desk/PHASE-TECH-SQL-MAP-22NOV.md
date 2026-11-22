# PHASE -> ADVANCE TECHNOLOGY -> SQL MAP (his word 22 Nov 2026 20:04 PKT: "kaun se phase mein kaun si advance technology aaye gi aur SQL kaun se phase mein aaye ga, clearly detail summary mein")
Rule 52 (every answer signed by Rust, verified by the Desk's own Rust WASM kernel in the browser, no raw fetch) is on EVERY row. HTTP/3 + WebTransport only, TLS 1.3 AES-256-GCM + X25519MLKEM768, Desk isolation (own tables fadm_*, own role desk_app). GREEN only after WIRED: YES / REAL: YES / TECH-LAW CHECKED and my live Chrome look (390 / 820 / 1200+). SQL numbers after AD7 are PLANNED numbers; each SQL is written schema-first on the file that owns the tables and runs through his one ad-auto line.
## 1. SQL ALREADY ON HIS SERVER (his pastes, ad-auto "run and CHECK OK")
| SQL | What it holds | Phases that use it | Wired to Rust / screen? |
|---|---|---|---|
| AD1 + AD1b | owner, session, passkey, mailbox, hash-chained ledger | R3a2 login (LIVE) | yes (login door) |
| AD2 | organisation units, relation tuples, deny-by-default policy, staff, recovery, JIT elevation, burst breaker, alerts | G Org + policy, H Staff accounts, B Bridge alerts | alerts yes; staff/policy doors NOT yet |
| AD3 | alert state + events, services, probes, incidents, alert watch | B, C, D2, D3, D7, S6 Incidents | yes (Bridge read path GREEN) |
| AD4 | company lookup audit (reason, fields, outcome, burst 30/min) | D5a-4, D5 | NO (waits for Rust lookup door D5a-3) |
| AD5 (11:1x) | 10 addresses and their role, billing restricted + grants, founder address private, routing, reply-from | I Mailboxes | NO (waits for Rust mail door) |
| AD6 (11:38) | versioned package registry, no price | D5a-2, D5 | NO (empty, waits for his package list + Rust read door) |
| AD7 (20:0x) | cases, Priority Support label + 2-business-day clock, assignment, status machine, reply record | K Cases + SLA, My Work, All Cases | NO (waits for the mail door + screens) |
## 2. PLANNED SQL (numbers may shift, order follows the phases)
| Planned SQL | What | Phase it belongs to |
|---|---|---|
| AD8 | mail THREADS and MESSAGES of the Desk (thread id, message ids, original recipient, headers, attachment metadata, virus-scan state; bodies and files on Hetzner Storage Box) | I Mailboxes, N Mail craft + attachments, "Replies" |
| AD9 | versioned runbooks (six parts each), no-promise word list, full-text knowledge search | D5b Runbooks, S3 Knowledge |
| AD10 | escalation hand-over (one-way signed request id, result link) | D5c Escalate |
| AD11 | SLA clocks for all queues, automations, 7-day per-sender auto-mail gate | J Auto mail, K rest, S4 Overview |
| AD12 | Managed Move-In work record per company (state machine, slots, DNS/mailbox checks; no money legs) | P Managed Move-In |
| AD13 | CRM accounts, leads, pipeline, tasks | O CRM |
| AD14 | transparency log (Merkle tiles, signed tree head) | L |
| AD15 | hybrid post-quantum keys (ML-DSA + Ed25519, ML-KEM) | M |
| AD16 | search index over cases, customers (opaque refs), runbooks | T1 Search (top bar) |
## 3. PHASE BY PHASE: ADVANCE TECHNOLOGY, SUBPHASES, SQL
| Phase | Advance technology | Subphases | SQL |
|---|---|---|---|
| R3a0..R3d (host, login, Rule 52) | Rust Tokio Axum 0.8, quinn + h3, TLS 1.3 AES-256-GCM, X25519MLKEM768, Argon2id, Ed25519 + HKDF, Desk-own Rust WASM kernel | done, LIVE | AD1 |
| A Browser HTTP/3 | HTTP/3 page load, Alt-Svc, DNS HTTPS record (his Namecheap) | OPEN | none |
| B Bridge, C WebTransport, D Command bar, D1..D10 | Rust h3-webtransport (QUIC), signed frames, kernel verify_frame, React 19, Framer Motion | green read path; D3b trend, D2 act | AD2, AD3 |
| D5a Foundation | Ed25519 signed read-only lookup (audience desk-lookup, 60 s), PostgreSQL versioned registry | a1 contract (done), a2 registry SQL (AD6 live), a3 Rust lookup door (NEXT), a4 audit (AD4 live), a5 fail-closed proof | AD4, AD6 |
| D5 Plan context screen | React 19 + TS + Tailwind 4, kernel-verified data, original UI intact | after a3 | uses AD4, AD6 |
| D5b Runbooks | React + PostgreSQL versioned runbooks, no-promise gate | b1 nine runbooks, b2 guided checklist, b3 say-this text | AD9 |
| D5c Escalate, D6 | Rust one-way signed hand-over | c1 request, c2 result, D6 card | AD10 |
| S Six sections (Overview, My Work, All Cases, Customers, Incidents, Knowledge) | React 19 + TS module registry, PostgreSQL full text | S1 rail order (needs his haan), S2..S6 | AD7 (cases), AD9 |
| T Top bar | React 19, Framer Motion, signed doors, WebTransport push | T1 Search, T2 Quick actions, T3 Bell, T4 Theme | AD16 |
| E Team fan-out | Tokio broadcast over WebTransport streams | one DB read per tick | none |
| F MoQ | Media over QUIC tracks (IETF) | summary/services/alerts tracks | none |
| G Org + policy | PostgreSQL tuples (Zanzibar style), Rust evaluator | staff, relations, policy screens | AD2 (live) |
| H Staff accounts | webauthn-rs, Argon2id, DBSC, device-bound passkeys | enrollment, devices, leaver, recovery | AD2 (live) |
| I Mailboxes | Rust mail door (Tokio, QUIC), PostgreSQL RLS, ClamAV | i1 inbound routing via AD5 + case ingest AD7, i2 sender identity, i3 founder draft/approve, i4 real send/receive tests | AD5, AD7 (live), AD8 |
| J Auto mail | Rust, RFC 3834 Auto-Submitted | 7-day gate | AD11 |
| K Cases + SLA | Rust, SQL SLA engine, SKIP LOCKED routing | assign, reply, clock, root-cause note | AD7 (live), AD11 |
| L Transparency log | Merkle tiles, signed tree head | audit log browsers remember | AD14 |
| M Hybrid post-quantum | ML-DSA + Ed25519, ML-KEM | signatures and mail | AD15 |
| N Mail craft + attachments | React, Tiptap 3, ML-KEM, WebTransport, Hetzner Storage Box, ClamAV, OpenPGP PQC (RFC 9980) | compose, rich text, attachments | AD8 |
| O CRM | React 19, Rust, RLS | accounts, leads, pipeline | AD13 |
| P Managed Move-In | Rust async IMAP migrator | per-company work record | AD12 |
| Q Final audit + load proof | Rust, React | audit, load proof | none |
## 4. THE "THREAD" QUESTION (his 20:04 word: the awam/founder system has threads; where does the Admin Desk get them?)
What exists: the awam site has its own mail threads (src/routes/app.mail.$folder.tsx, server/mail-worker.ts, sql phase52 mail truth tables) and the founder mailbox has its own (QC series). The Desk must NOT import or share them (isolation law); they are remade NEW for the Desk from the same method (preserve, advance technology, fix loopholes, polish).
Where the Desk gets its threads: phase I Mailboxes + the Replies folder. AD7 already keeps one case per (address, thread id); the thread's messages, original recipient, headers and attachments come with AD8 (planned) and the Rust mail door, bodies and files on Hetzner Storage Box with ClamAV. Every email keeps its original recipient and thread history (his point 4).
His remark that the earlier thread codes are "left open": I will audit the awam thread code and the founder thread code (read-only) for loopholes in phase I step i0 and write each loophole into CLOSE-THE-GAPS-07NOV.md; the awam code is frozen (his law), so the Desk copy gets the fix, the awam fix waits for his word.

## 5. GATES (commit gates in docs/cursor-work/server/rules-gate.py) AND THEIR ADVANCE TECHNOLOGY, PHASE BY PHASE (his 20:15 order)
| Gate | Phase it guards | Advance technology | What it refuses |
|---|---|---|---|
| RULES NOT READ | every phase | signed receipt file (2 h), SHA-256 of rule files | a commit without a fresh rules-read |
| DESK PHASE START | every Desk code commit | desk-phase-start.py receipt per phase | Desk code before the phase's contract is read |
| DESK ISOLATION | all Desk phases | static import + table + key scan | any mix with founder or awam code, doors, keys, tables |
| DESK NO-MONEY | D5a, D5, D6 | contract JSON (DESK-LOOKUP-CONTRACT.json) + pattern scan over Desk files | amount, invoice, card, Polar, webhook fields on the Desk |
| DESK WIRING | D1..D6 cards | desk_cards.ts registry + test | a card without route, track and phase; phase names visible to employees |
| NO-PROMISE (planned) | D5b runbooks | closed banned-word list over runbook text | date, restore, refund, credit, upgrade, owner decision promises |
| DESK CONTRACT DRIFT (planned) | D5a | JSON allowed_fields vs AD4 field list compare | the contract and the SQL list disagreeing |
| TECH LAW | all phases | tech-contracts/CURRENT.md + TECH-LAW-GATE.json | a listed advance technology missing from code, GREEN without TECH-LAW CHECKED |
| SERVER FIRST | server surface (ports, TLS, HTTP/3, Caddy, installers) | hash-chained receipt ledger of his pasted read-only output | a server change without his fresh paste |
| 73 lanes + manifest | every commit | lane-sync, SHA-256 manifest | stale lane files, changed files not in the manifest |
| VENDOR BAN | all | VENDOR-BAN-LIST.json | any third-party vendor name |
| HTTP/3 only, no WebSocket / Bun / Node | all Desk phases | pattern scan | h1, h2, ws://, Bun, Node in Desk or server runtime |
