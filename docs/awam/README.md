# AWAM REPO INDEX (audit of 17 Nov 2026 05:2x PKT, his order 05:14: every file and folder, none skipped)

Built from `docs/awam/INVENTORY.csv` (3414 files, one row each: path, class, lane, size, awam/founder word score, title). Regenerate any time: `python3 docs/awam/audit_inventory.py`. NOTHING was moved: gates, the lane map, AWAM-INHERIT-MANIFEST.json and the hash chain depend on the paths, so this folder is the ONE awam place by INDEX, not by moving.

Companion files here: `PENDING-AWAM.md` (all open awam work, with the source file of each item), `MESS-REPORT.md` (Lovable vs Cursor vs founder, what is stale, what to do), the clean blueprint `docs/claude/AWAM-BLUEPRINT-CLEAN-17NOV.md` (the order).

## Classes
awam = awam code/docs; founder = founder; shared = both (kernel, public, config); lovable-awam / lovable-founder = frozen Lovable copies; cursor-tooling / lovable-tooling = IDE tooling; claude-state = resume files; generated = build outputs; mixed = a doc that speaks of both; docs = general.

## Folder by folder (all 3414 files)

| Folder | Files | Class counts | What it is |
|---|---:|---|---|
| `lovable-gold/awam` | 823 | lovable-awam:823 | FROZEN Lovable copy of the awam site (822 files + manifest). Never edit |
| `docs/cursor-work` | 821 | awam:541, founder:206, docs:61, shared:7, mixed:6 | Cursor-era working folder: 541 awam files (server scripts, SQL E-files, frontend harness, live snapshots) + founder scripts |
| `src` | 648 | awam:601, founder:41, shared:6 | AWAM website (React/TanStack, Bun era). 601 awam files + 41 founder pages that still sit inside it (see MESS-REPORT) |
| `founder-web` | 226 | founder:201, generated:25 | FOUNDER UI (not awam) |
| `docs/claude` | 224 | founder:149, mixed:32, awam:30, docs:7, claude-state:6 | Claude-era docs: 30 awam docs, 149 founder docs, 32 mixed (state / plans) |
| `server/rust` | 114 | awam:105, shared:9 | AWAM Rust backend (axum). The migration target for the Lovable endpoints |
| `server/founder` | 59 | founder:58, generated:1 | FOUNDER Rust binary (not awam) |
| `sql` | 59 | awam:59 | AWAM SQL (59 files, Lovable era schema, RLS) |
| `lovable-gold/founder` | 48 | lovable-founder:48 | FROZEN Lovable copy of the OLD founder pages (48 files). Never edit |
| `server/routes` | 44 | awam:43, founder:1 | AWAM Bun endpoints (Lovable-era). Replaced by Rust twins in AW1, never edited now |
| `docs/packages` | 38 | awam:38 | AWAM package truth: features.tsv (every feature, starts_at, status), per-package INCLUDES / NOT-BUILT, CRM phases, trial design |
| `docs/wire` | 32 | awam:32 | AWAM wire audits (which UI button reaches which endpoint) |
| `server/lib` | 31 | awam:26, founder:5 | AWAM Bun helper libraries (webauthn, mail, billing ...) |
| `anexochat/sql` | 27 | awam:27 | AnexoChat SQL (awam product) |
| `web-wasm` | 26 | shared:25, generated:1 | Shared Rust WASM kernel |
| `(root files)` | 18 | shared:16, claude-state:1, generated:1 |  |
| `server/caddy` | 17 | awam:17 | AWAM Caddy files (23 awam hosts). Founder host is NOT here |
| `docs` | 15 | founder:8, mixed:4, docs:3 |  |
| `.cursor` | 14 | cursor-tooling:14 | Cursor IDE rules (14), tooling only |
| `server/gates` | 14 | awam:14 | AWAM gates (plan, membership, CRM gates) |
| `server/mail` | 14 | awam:14 | AWAM mail worker pieces |
| `server/founder-dns` | 13 | awam:12, generated:1 | DNS pieces for awam hosts |
| `lanes` | 11 | founder:6, mixed:3, awam:2 | Lane map (which file is founder / awam) |
| `public` | 10 | shared:10 | static assets, shared |
| `server` | 9 | awam:9 |  |
| `anexochat/docs` | 7 | awam:7 | AnexoChat docs |
| `server/awam-edge` | 7 | awam:6, generated:1 | AWAM TLS terminator crate (K5a LIVE: AES-256 only, h2 + http/1.1). K5b (HTTP/3) not done |
| `.lovable` | 6 | lovable-tooling:6 | Lovable plans + north star, tooling only |
| `scripts` | 5 | shared:5 | shared scripts |
| `server/config` | 5 | awam:5 | awam server config |
| `banned-countries` | 4 | shared:4 | shared geoblock data |
| `server/accounts` | 4 | awam:4 | awam accounts |
| `server/i18n` | 4 | awam:4 | awam i18n |
| `server/storage` | 4 | awam:4 | awam storage (Hetzner Storage Box) |
| `anexochat` | 3 | awam:3 |  |
| `anexochat/packages` | 3 | awam:3 | AnexoChat package notes |
| `anexomail inboxes to build` | 3 | shared:3 |  |
| `lovable-gold` | 2 | shared:1, mixed:1 |  |
| `.claude` | 1 | shared:1 | Claude tooling |
| `portal` | 1 | shared:1 | shared |

## Where the awam truth lives (read in this order)

1. `docs/claude/AWAM-BLUEPRINT-CLEAN-17NOV.md` : order AW0 to AW6 + his 12 instructions.
2. `docs/awam/PENDING-AWAM.md` : everything still open.
3. `docs/packages/features.tsv` + `docs/packages/*/INCLUDES.md` : what each package contains and which gates are built.
4. `docs/claude/AWAM-PACKAGES-PROPOSAL-07NOV.md` : package numbers (users, storage, prices), Hetzner capacity.
5. `docs/claude/AWAM-LOVABLE-MIGRATION-15NOV.md` : the per-file migration rule for the 822 Lovable files.
6. `docs/claude/AWAM-INHERITS-FOUNDER-TECH-LAW-13NOV.md`, `AWAM-MAILBOX-UI-INHERIT-LAW-16NOV.md`, `AWAM-INHERIT-MANIFEST.json` : what the awam takes from the founder (pure modules, SHA-256 manifest, gate AWAM INHERIT).
7. Sign-in: `AWAM-PASSKEY-ONLY-PLAN-10NOV.md`, `AWAM-PASSKEY-AUDIT-10NOV.md`, `AWAM-PASSKEY-PRESERVE-10NOV.md`, `AWAM-NO-2FA-10NOV.md`, `docs/claude/awam-passkey-reference/`.
8. Look and features: `AWAM-SETTINGS-CENTER-LIVE-LIST-01NOV.md`, `FOUNDER-VS-AWAM-SETTINGS-COMPARE-01NOV.md`, `AWAM-MOBILE-LOGIN-COUNTRY-REQUIREMENT-01NOV.md`, `AWAM-FEATURES-BUN-TO-LATEST-03NOV.md`.
9. Transport: `TLS-AES256-PLAN-01NOV.md`, `NEXT-ORDER-09NOV-K5B-TO-20NOV.md`, `server/awam-edge/`.
10. Later products: `AX-P11-ANEXOSUITE-TECH-PLAN-07NOV.md`, `AWAM-PROTON-PLUS-PLAN-07NOV.md`, `anexochat/` (blueprint + SQL), `docs/packages/crm/CRM-PHASES.md`.
11. Old awam rules: `docs/claude/ONE-ORDER-27OCT.md`, `AWAM-PARKED-ORDER-02NOV.md`, `PERSONAL-PLANS-REMOVAL-PLAN-02NOV.md`.

## Awam server scripts (docs/cursor-work/server): 262 awam, 20 founder
The awam scripts are the brain-*, caddy-*, attach-*, awam-edge-install.sh, pull.sh family. They are deploy tools for the CURRENT awam site (Bun + Caddy). They stay until AW1 replaces the site; do not delete.
