<!--TECHLAW-->
# RESUME POINT (the ONE file to open when the founder says "shuru kero / jahan rukay thay"; kept current by rules-gate)
LAST UPDATED: 11 Nov 2026 17:30 PKT. Per-phase technology status table: docs/claude/FOUNDER-PHASES-TECH-STATUS-11NOV.md. Tomorrow = GAP 1 (K8d) then GAP 2 (ML-DSA hybrid), see below.

## STEP 0 (every Claude, after compaction or a new chat, in this order)
1. docs/claude/TECH-FIRST-PROTOCOL.md  2. docs/claude/tech-contracts/CURRENT.md  3. this file  4. newest "RESUME HERE" at the bottom of docs/cursor-work/CLAUDE-CHAT-CONTEXT-WITH-FOUNDER-NAUMAN-SHERWANI.md  5. docs/claude/START-HERE-AFTER-COMPACTION.md (8 rules). Then talk: Roman Urdu, short, "Aap / Nauman bhai", end with the Rule-70 table + "Abhi code mein NAHI".

## WHERE WE STOPPED (facts, with proof)
- GREEN and live-proven (11 Nov): K8a h2 fallback, K8b HTTP/3 on UDP 443, K8c X25519MLKEM768, K7 wire fix (Devices & sessions "All clear 4/4", Device key GOOD, his Chrome 04:24), E158 key attach, E159 DBSC chain fix (chain 120/120), aurora seal UI.
- OPEN GAPS (visible in rules-gate as TECH LAW OPEN warnings): K8d kernel WebTransport RPC (api.ts/devicekey.ts still raw fetch: ratchet 11), K7-devicekey-pq (ML-DSA hybrid, Q phase), L-gsap, L-webgpu, M-moq, Q-pq-sign, Scene3D three types (tsc).
- His words: "pehle jo gaps hain unko KAL fix kiya jaye ga, uske baad agli tarteeb se kaam"; K8d "aaj/kal"; K7c enforce: his "haan" is given ("read the technology rules first").

## TOMORROW STARTS HERE (his 04:43 word): THE TWO K7 GAPS, in this order
- GAP 1 = K7-devicekey-fetch = K8d: the device-key register (devicekey.ts) and the exchange (api.ts) leave the raw fetch and go kernel -> WebTransport/HTTP3 (Rule 52).
- GAP 2 = K7-devicekey-pq: the device proof becomes post-quantum HYBRID (ML-DSA with the existing ECDSA P-256 proof; the DBSC cookie path stays ES256 because that is the browser standard). Technology first: research the current ML-DSA support (Rust crate + WebCrypto/WASM) and write the choice into tech-contracts/CURRENT.md BEFORE code.
Only after both gaps are green does the order below continue.

## TODAY'S ORDER (his 11 Nov 17:27: everything TODAY, no phase waits)
0. GAP 1 K8d, GAP 2 ML-DSA hybrid. 1. D-series continues and COMPLETES today: order in the blueprint block 'D-SERIES (DEVICES & SESSIONS)' (policy touch + phone/tablet screenshots are his hands; geo file = his command; D4 live proof). 2. K7c enforce. 3. L, M, N..X, Q. EVERY 3 PHASES: auto audit + autofix + pull command (docs/claude/AUDIT-EVERY-3-PHASES.md, counter docs/claude/AUDIT-COUNTER.json). Repo is PUBLIC: docs/claude/REPO-THEFT-DEFENCE-11NOV.md (private + deploy key = his hands, steps A/B).

## OLDER ORDER (letter order never breaks)
1. FIX THE GAPS FIRST: K8d (contract already in tech-contracts/CURRENT.md: /wt/rpc in wt.rs through the same router gates; kernel rpc@1 in kernel.worker.ts/kernel.ts; wasm rebuild + version bump + pin sha; api.ts get/getOnce/post/put, devicekey.ts register, Surface.tsx on it; fetch = fallback only; lower TECH-RATCHET.json; flip K8d-api-not-fetch + K7-devicekey-fetch to ok). Then his founder-install, my live Chrome proof (network panel shows WebTransport, not fetch).
2. K7c enforce (FOUNDER_DBSC=enforce) with rollback (founder.env.bak) after he confirms the Devices page shows his browser key.
3. Then the next letters: L (Framer Motion + GSAP + WebGPU renderer, fix Scene3D three types), M (MoQ), N..V, X, Q (ML-DSA hybrid, OpenPGP PQC).
4. His hands: key-touched "Change policy..." (Live sessions 20 -> 19 + reason), phone 390 + tablet 820 screenshots of Devices & sessions.
5. D-series PAUSED. Awam AP1..AP9 only after founder-complete (RULE 9).

## TECHNOLOGY (his capitals, CLAUDE.md line 18): Rust WASM kernel, Rust/Tokio/Axum, HTTP/3 PRIMARY (h2/h1.1 fallback only), WebTransport/QUIC, MoQ, React 19/TS/TanStack Router (Start for awam only if static)/Vite 8/Tailwind 4/Radix-shadcn/Framer Motion/GSAP/Three.js, PostgreSQL RLS, Hetzner Storage Box, ClamAV, X25519MLKEM768 + AES-256-GCM, ML-DSA hybrid + OpenPGP PQC. A listed technology missing from code = OPEN GAP, never green.

## MOBILE / TABLET / LAPTOP (his standing rule)
ONE build, same code on all four, only the layout flexes. No phase is green until seen live at 390 (phone), 820 (tablet), 1200+ (laptop): his screenshots + my sandbox measurement. 44 px touch targets, no sideways scroll, nothing cut off. Live bundle hash must equal the repo build before any green.

## CODES / RULES POINTERS
AGENTS.md (Rules 1-73), docs/claude/founder/CODES/00-README-RULES.md (FC1-FC42), docs/claude/BLUEPRINT-ABC-01NOV.md (TECH LAW cell per phase), docs/claude/TECH-LAW-GATE.json, docs/claude/FOUNDER-TECH-AUDIT-11NOV.md, docs/claude/FOUNDER-FILE-AUDIT-11NOV.md, docs/claude/FOUNDER-UI-WOW-RULES-11NOV.md, docs/cursor-work/founder/founder-commands.md, PULL-COMMANDS.md. Server law: PORTS RED LINE (docs/claude/SERVER-PORTS-RED-LINE-08NOV.md), Caddy law, one server command at a time, one line, no quotes; SQL only via sql-run.sh (never the Supabase dashboard: it clips long lines).

## PENDING SERVER COMMANDS: none (everything above is installed). The next command arrives with K8d.
- hook installed 11 Nov 17:40 PKT (pre-commit: a failing gate blocks the commit).
