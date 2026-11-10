> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# FOUNDER LEGACY REVIVAL — old founder and admin pages live on, on the new technology, never mixed with the user app (30 Oct 2026, 22:10 PKT)
Founder order (22:00, verbatim in founder-commands.md): "purane saray pages codes founder side ke preserve kerna hai un ke features ko founder side pe use hoga aur technology latest hoga? common sense use kero founder aur admin ke bina yeh website ka plane brain hai ... old walay ko user se bina mix kiye founder side pe kaise zinda kerna hai new technology ke saath aur UI UX ke saath."
Principle: Founder and Admin are the control plane (the brain) of the website. Nothing they do today is dropped. Every old page is a feature list to carry over. The old file is retired only after its checklist (below) is ticked in Chrome (Rule: Rust == Bun proof first). "Removed at F9" always means "retired after its replacement is proven", never "deleted and lost".
How the old features become the new ones (per page): 1) read the old page + its endpoints (ENDPOINT-PACKAGE-MAP.csv), 2) write its feature checklist, 3) port the logic to a Rust endpoint on `anexomail-founder` (signed answer, kernel verifies), 4) build the page in `founder-web` with the same plain, simple look as the Dashboard, 5) prove in Chrome that every checklist line works with real data, 6) only then retire the old route. User-side files are never edited (FC18/FC22); the only shared piece is the one kernel (crypto), never data, tokens or design.

## The 33 old founder pages (counted by `ls src/routes | grep ^app.founder`; titles are the pages' own headings)
| Old page (lines) | What it does today | New home | Technology | Step |
|---|---|---|---|---|
| `founder` home (342) | planned mailboxes, home tiles | Dashboard + Bridge (done) | UI + RUST | done |
| `admin` (88) "The whole platform on one screen" | platform-wide admin view, 11 Bun endpoints | Systems > Admin | RUST + SQL + UI | F6 (12) |
| `analytics` (75) "Platform-wide truth" | all-tenant analytics | Systems > Analytics | RUST + UI | F6 |
| `perf` (79) "Speed across every tenant" | speed per tenant, 9 Bun endpoints | Systems > Speed | RUST + UI | F6 |
| `security` (75), `settings` (95), `integrations` (107), `safety` (40) | platform security, tenant settings, connections, safety | Systems + Settings S2-S4 + Control | RUST + UI | F6, S2-S4, F8 |
| `revenue` (114), `revenue_.pipeline` (140) "Committed MRR vs pipeline vs the gap", `billing` (185) | money in one screen | Finance | RUST + SQL + UI | F3 (9) |
| `org` (214), `crm` (213) | organisations and CRM across tenants | People | RUST + SQL + UI | F4 (10) |
| `launch` x7 (index, checklist, deployments, lock, qa, roadmap, shell: ~860 lines) "One screen, one verdict", "Sign v1.0, freeze the product" | release verdict, QA receipts, roadmap, v1.0 lock | Release deck (read) then Control executor | RUST + SQL + UI | F3 (9) then F8 |
| `movein` (373) "Active move-ins" | migrating customers in | Move-In | RUST + UI | F3 (9) |
| `ai` x10 (arena, automation 572, billing 366, index 348, knowledge 351, memory, prompts, receipts, studio 417, shell: ~2,800 lines) | AI workflows, balance, knowledge, memory, prompts, receipts, studio recipes | AI (inside Systems, founder-only, read first, he presses send) | RUST + SQL + UI | F6 (12) |
| `calls` (162) "Call engine telemetry", `motion` (250) "Every animation has a budget" | measured telemetry pages | kept: Systems > Speed (calls telemetry, motion budgets); founder confirms at F6 | RUST + UI | F6 |

## Checklist rule (so nothing is lost)
Each row above gets a short file `docs/claude/legacy/<page>.md` when its phase starts: every button, number, filter and endpoint of the old page as a tick list. A line is ticked only when Chrome shows it working with real data on the founder page. The old route is retired when all lines are ticked. Until then the sidebar group "Workspace (user app)" keeps opening the old pages, so daily work never stops.

## Do not mix (checked, 30 Oct)
`founder-web/` imports nothing from `src/`. The user app only knows the flag `is_founder`. The two links "Founder" and "Admin" in the user-app group are the old pages and stay until their replacement is proven (F6/F9). They are the only visible overlap.
