# COMPACTION SURVIVAL (his order 15 Nov 2026 19:25 PKT). Printed by the SessionStart hook after EVERY start / resume / compaction / clear. Short on purpose: read it, then open the named files.

> **AFTER THIS FILE, READ docs/claude/Q-MASTER-PLAN-15NOV.md (the Q series, its advance technology and code, the world-class SQL standard, Admin > Mail Desk) AND CONTINUE FROM ITS 'NEXT ACTION'.**

## 1. WHO AND HOW
Founder Nauman Sherwani. Roman Urdu, short, "Nauman bhai", often angry, London seminar in January so finishing phases is the priority. Every reply ends with the Rule-70 table (Code | Technology | Phase) and a line "Abhi code mein NAHI: ...". I commit and push myself after every step (rec.sh), never ask "commit kero?".

## 2. THE TECHNOLOGY (never older, a listed item missing from code = OPEN GAP, never green)
Rust WASM kernel (one kernel), Rust + Tokio + Axum, HTTP/3 ONLY on the founder host (quinn + h3, UDP 443, WebTransport /wt/rpc + /wt/live, no H2, no H1, no SSE, no WebSocket), X25519MLKEM768, AES-256-GCM only, ML-DSA hybrid, OpenPGP PQC (RFC 9980) where listed, React 19 + TS + TanStack + Vite 8 + Tailwind 4 + Radix/shadcn + Framer + GSAP + Three.js WebGPU, PostgreSQL with RLS, Hetzner Storage Box, ClamAV. No Bun/Node in the website or any server runtime (my sandbox tools are fine). No third-party vendor ever (allowed: Caddy, Namecheap by his hands, Hetzner, his own Rust). Full text: CLAUDE.md line 18 block.

## 3. THE PROCESS (every phase, no exception)
rules-read.py first -> tech contract in docs/claude/tech-contracts/CURRENT.md BEFORE code -> code -> sandbox build + tests -> his server command -> his paste recorded with serverfirst.py -> my live Chrome look (live bundle = repo build) -> GREEN only with "WIRED: YES / REAL: YES / TECH-LAW CHECKED" -> rec.sh (ledger + context + RESUME-POINT + CLAUDE.md line 1 + gates + commit + push). Looks at 390 / 820 / 1200+. No mock data. UI law: never touch the existing orb/UI without his haan; new features additive.
SERVER COMMAND = ONE line, plain ASCII, no quotes, no heredoc, one per reply: git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/<script>). 0.1% doubt about his server = no guess, one read-only command first. Ports: fresh ss before any listener; never touch udp 3443 (anexomail-rust), 18443 (Caddy/awam), /etc/anexomail/tls. Never run founder-install twice in a row.

## 4. THE ORDER (his word 15 Nov 19:19)
L series CLOSED GREEN. NOW = Q SERIES (mail + calendar) until complete: state = Q-SERIES block in docs/claude/HANDOFF-LIVE.md (qstate.py, hash-chained; update ONLY with qstate.py start|done|defer). THEN S5 (TanStack Start SPA mode), then M, N, then the Lovable-migration phases O, P, R, S, V, then T (cutover) and U. Parked on his word: audit FIX (fewer database calls per page load), repo private + deploy key, D3, 0-RTT, /wt/core, ssh key-only hardening.

## 5. LOVABLE CODES AND THE SEPARATION
The Lovable (Bun) codes are PRESERVED AS WRITTEN in lovable-gold/ (read-only, manifest, gate). Job = move each to the advance technology, FIX loopholes, POLISH, deliver. Founder map: docs/claude/FOUNDER-LOVABLE-MIGRATION-15NOV.md. Awam map: docs/claude/AWAM-LOVABLE-MIGRATION-15NOV.md (separate, starts after the founder lane). Lanes: lanes/FOUNDER-INDEX.md. Founder/awam NEVER mixed: docs/claude/FOUNDER-AWAM-SEPARATION-LAW-14NOV.md. Awam problems = awam blueprint only.

## 6. ADMIN > MAIL DESK (R3, separate from the founder Mail)
Plan + method: docs/claude/FOUNDER-ADMIN-MAIL-DESK-03NOV.md (status block at its top). Own folder founder-web/src/admin/maildesk/, routes /founder/v1/admin/maildesk/*, tables fadm_mail_*, own ledger, passkey for sends on behalf of the company. Starts only after the founder Mail (Q) cores exist.

## 7. WHERE THINGS ARE
Blueprint (readable): docs/claude/FOUNDER-BLUEPRINT-CLEAN-14NOV.md. History: BLUEPRINT-ABC-01NOV.md. Resume: RESUME-POINT.md line 3, PHASE-NOW.md, START-HERE-AFTER-COMPACTION.md. Ledgers: docs/claude/DONE-DO-NOT-REPEAT.md, docs/claude/state/SERVER-FIRST.jsonl (receipts), Q-STATE.jsonl. Gates: rules-gate.py (VENDOR BAN, H3 ONLY, SERVER FIRST, TECH GREEN WORDS, CLAUDE.md size, manifest). CLAUDE.md: only line 1 is edited by rec.sh; the file must stay under 16000 characters.

## 8. AUTO LEDGER + BLUEPRINT (his order 15 Nov 19:30). The blueprint table is GENERATED, never hand-edited
Source: docs/claude/state/PHASES.json (every phase: advance technology, in code, status, proof) + Q-STATE.jsonl (the Q steps). Tool: `python3 docs/cursor-work/server/phases.py set <id> <status> "<proof>" [--tech "..."]` (or rec.sh with the 4th/5th/6th args), `render`, `check`. The commit gate "PHASE TECH" BLOCKS the commit automatically when a phase or Q step names no advance technology, names an old one (Bun, Node, WebSocket, SSE, H2, H1) as a choice, says GREEN without WIRED: YES / REAL: YES / TECH-LAW CHECKED, or when the generated blueprint table is stale. KP2 and everything related are closed (his word 15 Nov 19:30): never list them again.

## 9. K / KP RE-PROOF (his order 15 Nov 19:38, on row 13 of the blueprint): give him the read-only server proof, then MATCH it with my live Chrome, line by line
Server: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-k-proof.sh)` (read-only; services, port owners, TCP 443 = no HTTP, h3 request, no FOUNDER_WT env, cert dates, journal key lines, device/audit row counts). Chrome side measured 15 Nov 19:50 on #/bridge: live bundle index-CVaJk1v6 = repo; 16 resources over h3; 4 Inter fonts LABELLED http/1.1 but transferSize 0 = served from the browser cache with an old label; a forced reload of one font arrived over h3 (21,216 bytes); CSP = default-src none, connect-src self, require-trusted-types-for script; WebTransport available; secure context. After his paste: one match table (server line vs Chrome line) and the row-13 proof text is updated with phases.py set.
