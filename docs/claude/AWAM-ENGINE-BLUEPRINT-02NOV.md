# AWAM ENGINE BLUEPRINT — founder-proven features, rebuilt the awam way (founder 2 Nov 2026 07:52-07:57 PKT)

Docs only. No code, no price change, no new rule is locked by this file. Source of the order: `docs/cursor-work/founder/founder-commands.md` (07:57). Lane letters here are **AX1-AX8** so they never collide with the founder letters A-V or the awam W-rows in `BLUEPRINT-ABC-01NOV.md`.

## 0. Packages (from `src/lib/plans.ts` + the founder's 07:57 word)
| Package | Price | Users | In `plans.ts` today? |
|---|---|---|---|
| Basic | £40 / month | up to 5 | yes |
| Pro | £105 / month | up to 20 | yes |
| Business | £360 / month | up to 60 | yes |
| Business Pro | £2,850 / month | up to 570 | yes |
| **Business Premium** | **£21,000 / month**; yearly = 2 months free = **£210,000 / year** (founder 08:04, 08:11) | Backend cap **20,000 users**; the page shows no number (looks unlimited). Older locked docs already say "UNLIMITED users" for Premium | **NO card in `plans.ts` yet** |
| AI Pro / AI Business / AI Executive | "coming soon" until July 2027 | | no features from this file |

**Answered by the founder 08:04:** £21,000 is per month; Premium has a hidden backend cap of 20,000 users and looks unlimited to the user. **Two things I record but do not decide:** (1) (price is now updated everywhere in docs on 2 Nov 08:07-08:11; the line below is kept only as the record of why) older locked docs (`PACKAGE-FEATURE-FORMULA.md`, `PRICING-POSITIONING-26OCT.md`, `packages-pricing-v6-2026-10-25.md`) still say Business Premium **£18,500** — I changed no price file; the Polar product and `plans.ts` card are his step (P3). (2) A cap that is enforced but not shown must still be **written in the plan terms / fair-use page** (the bandwidth doc already requires "a written fair-use ceiling"), otherwise it reads as a hidden limit; the page can stay free of a number, the terms must say it.

## 1. How the engine reaches awam (the rule that needs his yes)
FC44 says: awam features go to the founder, same logic and UI. This file is the **other direction**: the founder's proven engine goes to awam, **but on awam's own lane and awam's own data** (a user sees only their own company's chain, never the founder's). Method = the one the kernel already uses: ONE pure Rust core file, included by `#[path]` in each place (founder server, awam server module, WASM kernel). Awam files are never edited from the founder lane (Rule 1 / FC18). **Proposed FC45 (NOT locked, waits for his "haan"): "founder engine -> awam, per-tenant, awam lane, shared core files, awam UI/UX in awam's own style".** The kernel pin already moves both lanes together (Rule 52, W6).

## 2. Features, in build order. Each starts only when the earlier AX row is GREEN with the founder's pastes and Chrome.
| Row | Awam name | Founder engine it reuses (already GREEN there) | Plans | Awam technology | Honest limit |
|---|---|---|---|---|---|
| **AX0** | **Bandwidth meter + throttle-first** (per the existing docs above) | — (new awam engine, not a founder reuse) | all (rates only Business and up) | Rust metering + SQL + Polar overage meter + live meter UI at 80/95% | Does not exist yet; docs only today. |
| **AX1** | **My account activity** (tamper-proof) | Merkle ledger E107 + signed checkpoints G5b + kernel `merkle@1/2`, `checkpoint@1` | Basic, Pro, Business, BP, Premium | SQL (per-tenant hash chain, RLS), Rust core `merkle_core.rs` / `checkpoint_core.rs`, awam page with kernel verify in the user's browser | Proves "nothing was changed after the log key signed it", not "an outsider watched". |
| **AX2** | **Outside time on my history** | G5c RFC 3161 + OpenTimestamps (`anchor_core.rs`, kernel `anchor@1`) | Pro and up (Basic sees the chain without outside time) | same cores; awam queue and gauge; uses the SAME public TSAs/calendars, no account | TSA signer is pinned not chained to a public root; Bitcoin proof takes hours. |
| **AX3** | **Live everywhere** (no refresh) | live feed SSE + signed events (`live.rs`) | all | Rust tick/SSE, kernel verify of events, awam UI | Only sources that really change. Never a fake tick. |
| **AX4** | **Trust page** (public `anexomail.com/trust`) | latest platform checkpoint + status | all (public) | Static page + one signed JSON; the visitor's browser verifies | Shows the platform log, not any customer data. |
| **AX5** | **Sealed Agreements** ("Seal this" on an important mail) | K1 design (`FOUNDER-KILLER-FEATURES-28OCT.md`), builds on AX1+AX2 | Business: a monthly number (proposal 20, founder decides); BP and Premium: unlimited | Rust seal + SQL + kernel `intent@1` finds the promise, human presses Seal; proof bundle verified offline | Evidence, not legal advice; cannot stop a mailbox deletion, only makes change provable. |
| **AX6** | **My devices** (where am I signed in, one-tap cut, Device Trust Map) | N1 Device Trust Map, device vault (Rule 45, no IP) | Pro: list + cut; Business and up: map | SQL + Rust + React | City is device-reported, never IP. |
| **AX7** | **Insider Guard** (admin alerts from metadata only) | P2 rules (founder design) | Business and up | Rust deterministic rules over metadata events, no content read, no AI | Alerts and a reversible hold; it does not read mail. |
| **AX8** | **Poison Pill + auditor pack** | S1 Poison Pill; G5 chain + AX2 proof bundle | BP: Poison Pill; **Premium (P): auditor read-only link** where an outside auditor verifies the chain in their own browser, plus a signed export pack | WebCrypto lease key (as S1), Rust export, kernel verify | Web cannot wipe disk sectors or Downloads (said on the page). |

Everything not in the table (Ctrl K palette, device vault list, the status keywords) already has files on the awam side (keyword scan, not a full audit): they are **checked first** at the start of each row ("grep before building", Rule 1), never rebuilt.

## 2b. Bandwidth: already written, NOT repeated here
Per-package bandwidth (Business 10 TB @ £12, Business Pro 30 TB @ £11, Business Premium 50 TB @ £10 with a written fair-use ceiling; Basic/Pro fair-use throttle only), the competitor check, and the four user promises (throttle first then money, inbound never blocked, live meter at 80% / 95%, Premium unlimited-ish with a written ceiling) are already in the repo, awam side: `docs/cursor-work/PACKAGE-FEATURE-FORMULA.md` (section "Bandwidth: competitor check + honest-bandwidth promise", founder 28 Oct 08:30) and `docs/claude/CEO-DECISIONS-AND-FIX-PHASES-26OCT.md` (D). The ledger says "do not write again". The competitor figures there are the **verified** ones; the Google upload/IMAP GB-per-day numbers in the chat text are marked NOT verified in that doc, so they stay out. **Rust metering / throttle / Polar overage billing is NOT built** — it becomes the first awam code step (meter first, then the rate), as a row **AX0** before AX1, only when the founder says go.

## 2c. Business Premium (£21,000 / month): the whole website, on the latest technology (founder 08:07: "is package ki technology likhi jaye gi latest wali")
Business Premium = every awam feature (Business Pro's all features, Rule 23: no AI) + AX0-AX8 in full + the P rows. One code path (`resolve_plan`, no copy); the hidden 20,000-user cap is enforced in the backend there, and the page shows no number. Status words are the blueprint's: **GREEN** = proven on the server and in Chrome, **planned** = a letter in `BLUEPRINT-ABC-01NOV.md` that is not GREEN yet. Nothing below is claimed as shipped to awam unless its row says so.

| Layer | Latest technology for this package | Where it stands (2 Nov) |
|---|---|---|
| Server | Rust (axum 0.8 + tokio, `ring`, rustls); no Bun / Node (Rule 61) for Premium endpoints | founder lane GREEN; awam Bun-free move = lettered W-rows |
| Transport | HTTP/3 + WebTransport (QUIC, `wtransport`) for live data, calls stay WebRTC | **planned** K6 |
| Key exchange / cipher | X25519MLKEM768 (post-quantum hybrid), AES-256-GCM terminator | **GREEN** K1, K2 (founder hosts); awam hosts K5 **planned** |
| Mail content | OpenPGP post-quantum, RFC 9980 (PQM) | **planned** Q4 |
| Live data protection | PQN | **planned** Q5 |
| Tamper-proof history | Merkle log (RFC 6962/9162) + signed checkpoints (C2SP) + outside time (RFC 3161 + OpenTimestamps), verified in the browser by the WASM kernel | **GREEN** founder G5a-G5c; awam = AX1/AX2 |
| Browser engine | ONE WASM kernel (Rule 52, pinned, Worker), modules `merkle@2`, `checkpoint@1`, `anchor@1`, `intent@1`, `sha256@1` | **GREEN** (kernel 0.9.0) |
| Sign-in | Passkeys (`webauthn-rs`), device-bound sessions (DBSC) | **planned** J3-J6, K7 |
| Database | Postgres with RLS on, per-tenant hash-chained tables, append-only guards | **GREEN** pattern (E107, E123, E124) |
| Front end | React 19.2, Vite 8.2, TypeScript (strict), TanStack Router, Tailwind 4.2, shadcn, Framer Motion + GSAP, Three.js WebGPU (lazy) | awam is already on the latest line (FC44); L1/L2 **planned** |
| Streaming | MoQ on an own Rust relay (one-to-many only) | **planned** M |
| Metering and billing | Rust bandwidth meter, throttle-first, Polar overage meter at 50 TB @ £10 | **not built** (AX0) |
| Hidden user cap | 20,000 users, enforced in `resolve_plan`'s single path; written in the terms | **not built**; terms text is a founder item |

## 3. Not in this file
Plan prices, plan caps, Polar products and the plan copy on `/plans` are **not touched** here. Putting any AX row onto a plan card is a separate order from the founder after the row is GREEN.
