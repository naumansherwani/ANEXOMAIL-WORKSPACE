> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# Repo audit, 3 Nov 2026 08:40 PKT (founder order 08:30 + 08:33)

Method (honest): all **1898 tracked files** were inventoried and each put in one lane by path and, for SQL, by content. Not every line of every file was read by eye; the code that matters for the lanes (imports, includes, RPC names, deploy scripts, manifests) was searched exhaustively with grep. Nothing was moved, deleted or restyled.

## 1. Where I2 is written
| Part | Files | State |
|---|---|---|
| SQL | `docs/cursor-work/sql/E114_founder_appearance_ambient.sql` + `CHECK_E114.sql` (also E113, E115) | GREEN (I1) |
| Rust | `server/founder/src/ambient.rs` + routes in `main.rs` (`/founder/v1/ambient/*`) | on the server since the 08:21 founder-install |
| UI | `founder-web/src/AmbientStudio.tsx`, `ambient.ts`, `appearance.ts`, `Settings.tsx` | on the server since 08:21 |
Chrome look 08:33: Settings > Appearance renders (Motion, Text size, Transitions), Ambient Studio shows the catalog (patterns, blends, "Another (1 of 65,536)"). Still open for I2: the key registry look and a CHECK_E114 paste.

## 2. Lanes (file counts; lists in `lanes/*.txt`, per file in `lanes/ALL-FILES.csv`)
founder 189 · awam 1315 · shared 65 · lovable 52 · docs 277 (= 1898). The Lovable-era code is frozen as a copy in `lovable-gold/` (52 files, sha256 manifest). Rule 73 in AGENTS.md; the rules-gate runs `lanes/lane-sync.py --check`.

## 3. Lovable code (preserved)
* `.lovable/` (5), 41 old founder pages `src/routes/app.founder*`, `founder*.tsx` + `FounderBar`, `src/lib/founder*.ts` on the awam site, 6 old Bun endpoints `server/routes/founder.ts`, `server/lib/founder-*`. 25 of them are deployed by pull.sh (DEPLOY-MANIFEST). They stay live until cutover T by the founder's word.
* The awam site `src/` itself (564 files) is a Lovable TanStack Start template that the team built on; it is awam lane, not frozen (it changes).

## 4. Mixing found (read-only findings, nothing changed)
1. **Founder is isolated**: `founder-web/src` and `server/founder/src` import nothing from awam `src/` or `server/routes|lib` (the `@/` alias is founder-web's own `src`). Awam `src` imports nothing from founder code. `lane-check` enforces it.
2. **Shared by design (8 files)**: the founder crate reads `server/rust/{jwt_core,checkpoint_core,anchor_core,merkle_core}.rs` + 4 vector JSONs; the installer copies each. One kernel (`web-wasm`) with the SAME wasm sha `9d75716b...` in `public/kernel`, `founder-web/public/kernel`, `founder-web/dist/kernel`.
3. **Awam code that calls founder objects**: `founder_accounts` (identity: auth.ts, create-accounts.ts, org.ts, polar.ts, billing-*, Rust main/authx/billx/setx) is legitimate shared identity. The Lovable-era pages use `founder_admin_overview`, `founder_analytics_overview`, `founder_revenue_truth`, `founder_security_overview`, `founder_integrations_overview`, `founder_perf_overview` (Bun routes admin/analytics/security/integrations/perf + Rust analytics_glue/setx_glue). These belong to the Lovable lane and go away only at cutover T.
4. **SQL**: the founder E-series (E102-E138) are founder-only. The older `sql/phase22-27, 34, 47, 55` and `E89/E90` define awam objects AND a few `founder_*` RPCs for the old pages (mixed files, kept as is: they are already applied on the server and editing them is destruction).
5. **AnexoChat** has hard-coded family-workspace names (`phase31b_family_chat_workspace.sql`) and `chat_is_founder`. Awam lane; flagged for the awam migration.
6. Docs say founder/awam in many places; the lanes lists are now the single map.

## 5. Final pull command
Nothing in Rust, SQL or the founder SPA changed in this step (docs, rules, `lanes/`, `lovable-gold/`, the gate only). The server needs only the memory sync:
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -15`
The old full chain (SQL, founder Rust+SPA, Caddy, Web in one go) is `all-pull.sh`; use it when several technologies change at once (it restarts the founder service once).
