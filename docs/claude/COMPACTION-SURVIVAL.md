# COMPACTION SURVIVAL (his order 15 Nov 2026 19:25 PKT). Printed by the SessionStart hook after EVERY start / resume / compaction / clear. Short on purpose: read it, then open the named files.

## 1. WHO AND HOW
Founder Nauman Sherwani. Roman Urdu, short, "Nauman bhai", often angry, London seminar in January so finishing phases is the priority. Every reply ends with the Rule-70 table (Code | Technology | Phase) and a line "Abhi code mein NAHI: ...". I commit and push myself after every step (rec.sh), never ask "commit kero?".

## 2. THE TECHNOLOGY (never older, a listed item missing from code = OPEN GAP, never green)
Rust WASM kernel (one kernel), Rust + Tokio + Axum, HTTP/3 ONLY on the founder host (quinn + h3, UDP 443, WebTransport /wt/rpc + /wt/live, no H2, no H1, no SSE, no WebSocket), X25519MLKEM768, AES-256-GCM only, ML-DSA hybrid, OpenPGP PQC (RFC 9980) where listed, React 19 + TS + TanStack + Vite 8 + Tailwind 4 + Radix/shadcn + Framer + GSAP + Three.js WebGPU, PostgreSQL with RLS, Hetzner Storage Box, ClamAV. No Bun/Node in the website or any server runtime (my sandbox tools are fine). No third-party vendor ever (allowed: Caddy, Namecheap by his hands, Hetzner, his own Rust). Full text: CLAUDE.md line 18 block.

## 3. THE PROCESS (every phase, no exception)
rules-read.py first -> tech contract in docs/claude/tech-contracts/CURRENT.md BEFORE code -> code -> sandbox build + tests -> his server command -> his paste recorded with serverfirst.py -> my live Chrome look (live bundle = repo build) -> GREEN only with "WIRED: YES / REAL: YES / TECH-LAW CHECKED" -> rec.sh (ledger + context + RESUME-POINT + CLAUDE.md line 1 + gates + commit + push). Looks at 390 / 820 / 1200+. No mock data. UI law: never touch the existing orb/UI without his haan; new features additive.
SERVER COMMAND = ONE line, plain ASCII, no quotes, no heredoc, one per reply: git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/<script>). 0.1% doubt about his server = no guess, one read-only command first. Ports: fresh ss before any listener; never touch udp 3443 (anexomail-rust), 18443 (Caddy/awam), /etc/anexomail/tls. Never run founder-install twice in a row.

## 4. THE ORDER (his word 15 Nov 19:19)
L series CLOSED GREEN. NOW = Q SERIES (mail + calendar) until complete: state = Q-SERIES block in docs/claude/HANDOFF-LIVE.md (qstate.py, hash-chained; update ONLY with qstate.py start|done|defer). THEN S5 (TanStack Start SPA mode), then M, N, then the Lovable-migration phases O, P, R, S, V, then T (cutover) and U. Parked on his word: audit FIX (fewer database calls per page load), repo private + deploy key, KP2 laptop SSH test, D3, 0-RTT, /wt/core, ssh key-only hardening.

## 5. LOVABLE CODES AND THE SEPARATION
The Lovable (Bun) codes are PRESERVED AS WRITTEN in lovable-gold/ (read-only, manifest, gate). Job = move each to the advance technology, FIX loopholes, POLISH, deliver. Founder map: docs/claude/FOUNDER-LOVABLE-MIGRATION-15NOV.md. Awam map: docs/claude/AWAM-LOVABLE-MIGRATION-15NOV.md (separate, starts after the founder lane). Lanes: lanes/FOUNDER-INDEX.md. Founder/awam NEVER mixed: docs/claude/FOUNDER-AWAM-SEPARATION-LAW-14NOV.md. Awam problems = awam blueprint only.

## 6. ADMIN > MAIL DESK (R3, separate from the founder Mail)
Plan + method: docs/claude/FOUNDER-ADMIN-MAIL-DESK-03NOV.md (status block at its top). Own folder founder-web/src/admin/maildesk/, routes /founder/v1/admin/maildesk/*, tables fadm_mail_*, own ledger, passkey for sends on behalf of the company. Starts only after the founder Mail (Q) cores exist.

## 7. WHERE THINGS ARE
Blueprint (readable): docs/claude/FOUNDER-BLUEPRINT-CLEAN-14NOV.md. History: BLUEPRINT-ABC-01NOV.md. Resume: RESUME-POINT.md line 3, PHASE-NOW.md, START-HERE-AFTER-COMPACTION.md. Ledgers: docs/claude/DONE-DO-NOT-REPEAT.md, docs/claude/state/SERVER-FIRST.jsonl (receipts), Q-STATE.jsonl. Gates: rules-gate.py (VENDOR BAN, H3 ONLY, SERVER FIRST, TECH GREEN WORDS, CLAUDE.md size, manifest). CLAUDE.md: only line 1 is edited by rec.sh; the file must stay under 16000 characters.
