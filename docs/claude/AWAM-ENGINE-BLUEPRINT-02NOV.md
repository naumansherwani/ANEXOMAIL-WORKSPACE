# AWAM ENGINE BLUEPRINT — founder-proven features, rebuilt the awam way (founder 2 Nov 2026 07:52-07:57 PKT)

Docs only. No code, no price change, no new rule is locked by this file. Source of the order: `docs/cursor-work/founder/founder-commands.md` (07:57). Lane letters here are **AX1-AX8** so they never collide with the founder letters A-V or the awam W-rows in `BLUEPRINT-ABC-01NOV.md`.

## 0. Packages (from `src/lib/plans.ts` + the founder's 07:57 word)
| Package | Price | Users | In `plans.ts` today? |
|---|---|---|---|
| Basic | £40 / month | up to 5 | yes |
| Pro | £105 / month | up to 20 | yes |
| Business | £360 / month | up to 60 | yes |
| Business Pro | £2,850 / month | up to 570 | yes |
| **Business Premium** | **£21,000** (founder 07:57; per-month or per-year NOT stated, user cap NOT stated) | ? | **NO card in `plans.ts` yet** (older docs only name it: 50 TB bandwidth at £10, CEO-DECISIONS-26OCT) |
| AI Pro / AI Business / AI Executive | "coming soon" until July 2027 | | no features from this file |

**Open facts for the founder (I will not guess them):** (1) is £21,000 per month or per year; (2) the Business Premium user cap; (3) the Polar product for it (his own step, P3 in CEO-DECISIONS). Until he answers, this file only says "Premium = everything in Business Pro plus the rows marked P".

## 1. How the engine reaches awam (the rule that needs his yes)
FC44 says: awam features go to the founder, same logic and UI. This file is the **other direction**: the founder's proven engine goes to awam, **but on awam's own lane and awam's own data** (a user sees only their own company's chain, never the founder's). Method = the one the kernel already uses: ONE pure Rust core file, included by `#[path]` in each place (founder server, awam server module, WASM kernel). Awam files are never edited from the founder lane (Rule 1 / FC18). **Proposed FC45 (NOT locked, waits for his "haan"): "founder engine -> awam, per-tenant, awam lane, shared core files, awam UI/UX in awam's own style".** The kernel pin already moves both lanes together (Rule 52, W6).

## 2. Features, in build order. Each starts only when the earlier AX row is GREEN with the founder's pastes and Chrome.
| Row | Awam name | Founder engine it reuses (already GREEN there) | Plans | Awam technology | Honest limit |
|---|---|---|---|---|---|
| **AX1** | **My account activity** (tamper-proof) | Merkle ledger E107 + signed checkpoints G5b + kernel `merkle@1/2`, `checkpoint@1` | Basic, Pro, Business, BP, Premium | SQL (per-tenant hash chain, RLS), Rust core `merkle_core.rs` / `checkpoint_core.rs`, awam page with kernel verify in the user's browser | Proves "nothing was changed after the log key signed it", not "an outsider watched". |
| **AX2** | **Outside time on my history** | G5c RFC 3161 + OpenTimestamps (`anchor_core.rs`, kernel `anchor@1`) | Pro and up (Basic sees the chain without outside time) | same cores; awam queue and gauge; uses the SAME public TSAs/calendars, no account | TSA signer is pinned not chained to a public root; Bitcoin proof takes hours. |
| **AX3** | **Live everywhere** (no refresh) | live feed SSE + signed events (`live.rs`) | all | Rust tick/SSE, kernel verify of events, awam UI | Only sources that really change. Never a fake tick. |
| **AX4** | **Trust page** (public `anexomail.com/trust`) | latest platform checkpoint + status | all (public) | Static page + one signed JSON; the visitor's browser verifies | Shows the platform log, not any customer data. |
| **AX5** | **Sealed Agreements** ("Seal this" on an important mail) | K1 design (`FOUNDER-KILLER-FEATURES-28OCT.md`), builds on AX1+AX2 | Business: a monthly number (proposal 20, founder decides); BP and Premium: unlimited | Rust seal + SQL + kernel `intent@1` finds the promise, human presses Seal; proof bundle verified offline | Evidence, not legal advice; cannot stop a mailbox deletion, only makes change provable. |
| **AX6** | **My devices** (where am I signed in, one-tap cut, Device Trust Map) | N1 Device Trust Map, device vault (Rule 45, no IP) | Pro: list + cut; Business and up: map | SQL + Rust + React | City is device-reported, never IP. |
| **AX7** | **Insider Guard** (admin alerts from metadata only) | P2 rules (founder design) | Business and up | Rust deterministic rules over metadata events, no content read, no AI | Alerts and a reversible hold; it does not read mail. |
| **AX8** | **Poison Pill + auditor pack** | S1 Poison Pill; G5 chain + AX2 proof bundle | BP: Poison Pill; **Premium (P): auditor read-only link** where an outside auditor verifies the chain in their own browser, plus a signed export pack | WebCrypto lease key (as S1), Rust export, kernel verify | Web cannot wipe disk sectors or Downloads (said on the page). |

Everything not in the table (Ctrl K palette, device vault list, the status keywords) already has files on the awam side (keyword scan, not a full audit): they are **checked first** at the start of each row ("grep before building", Rule 1), never rebuilt.

## 3. Not in this file
Plan prices, plan caps, Polar products and the plan copy on `/plans` are **not touched** here. Putting any AX row onto a plan card is a separate order from the founder after the row is GREEN.
