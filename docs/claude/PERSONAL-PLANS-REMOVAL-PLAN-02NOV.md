# PERSONAL PLANS REMOVAL — plan (founder 2 Nov 2026 08:14 PKT). DOCS ONLY: nothing is deleted yet.

Founder, verbatim: "mainay personal packages delete kerne hain market main yeh competiotrs free daitay hain aur main free afford nahi ker sakta hoon aur pehle hi bhut zedia kaam hai mere akele ke liye yeh polar se bhi delete hoga. sirf business mile ga awam ko"

**Decision (locked from this minute):** the awam gets only the **Business ladder**: Basic £40, Pro £105, Business £360, Business Pro £2,850, Business Premium £21,000 (yearly = 2 months free). **Personal Basic £17 / Personal Pro+ £83 / Personal Premium £1,850 (yearly £187 / £913 / £18,500) are retired.** No new work, no new doc rows and no new tests for Personal from now on (also: the Personal ANEXOChat ladder and the Personal rows of the feature formula are retired with it). This also removes a whole axis of work for one person (Rule 54 market reason: competitors give single mailboxes free).

## What I found in the repo (keyword scan, blast radius — not a full audit)
| Layer | Files that mention Personal | What has to happen |
|---|---|---|
| Web (awam) | `src/lib/personal-tiers.ts`, `src/lib/plan-surface.ts`, `src/lib/tier-guard.test.ts`, `src/routes/plans.tsx`, `src/routes/app.billing.tsx`, `src/routes/claim.tsx`, `src/lib/auth.tsx`, `src/components/site/PlanCheckoutButton.tsx` | stop showing/selling Personal cards; remove tier code and its tests |
| Bun server | `server/config/billing-products.ts` (+ test), `server/routes/billing-sync.ts`, `server/routes/auth.ts` | remove the 6 `POLAR_PRODUCT_PLAN_PERSONAL_*` product contracts |
| Rust | `server/rust/authx_core.rs` (`resolve_account_kind` returns "personal") | what a solo person becomes after removal: see open point 2 |
| SQL | history: `E2`, `E5`, `E13`, `E17`, `E20`, `E40`, `E87`, `E88`, `E100`, `phase65`, `phase20/23` | history stays (applied files are never rewritten); ONE new E-file retires the Personal plan rows/labels |
| Polar | 6 Personal products (3 monthly, 3 yearly; ids in `docs/cursor-work/server/personal-polar-products.md`) | **founder's own step**: archive (Polar normally archives, deletes only if it has no orders) |
| Docs | `docs/packages/*`, `PACKAGE-FEATURE-FORMULA.md`, `packages-pricing-v6`, `FOUNDER-PARITY`, `mail-identities-locked-2026-10-14.md`, `personal-polar-map.md` | cleanup pass after the code is gone |

## Order (one phase at a time, each GREEN with the founder's pastes + my Chrome look before the next — Rule 64)
- **PX0 — read-only check on the server (first, before anything is removed):** count Personal accounts and Personal subscriptions. The founder dashboard already shows "0 active accounts / 0 subscriptions" for revenue, which is a good sign, but that is not the same as zero Personal sign-ups (e.g. `pending_plan` accounts). I write ONE read-only SQL check and he pastes the result. If anyone is paying, we stop and talk first.
- **PX1 — stop selling (UI, safe, reversible):** remove the Personal cards from `/plans`, the billing portal and the claim flow. Polar: founder archives the 6 products (his step).
- **PX2 — backend:** remove the 6 product contracts and the Personal paths in Bun/Rust, with their tests; one new E-file retires the Personal plan rows (idempotent), old SQL untouched.
- **PX3 — docs/packages cleanup**, then the price/limit tables lose the Personal axis.
Nothing starts before **G5d** is decided as the current code phase; PX0 is a tiny read-only check, so it may go first if he says so.

## Open points that are his to decide (I do not guess)
1. **Existing people:** if PX0 shows anyone on a Personal plan or in a Personal trial, what do they get (a Basic trial, or a refund and a mail)?
2. **A single person after removal:** they buy **Basic £40** (flat, up to 5 users) — is that right, or is there a free/"just look" state? (E20 already makes a new sign-up `pending_plan`: no plan, no countdown, "choose your plan".)
3. **The 48-hour trial** (`TRIAL-48H-DESIGN.md`): does it stay for the Business ladder only?
4. **Account kinds** `personal`, `basic_personal`, `family` inside `resolve_plan` / `authx_core.rs`: remove them in PX2 (my proposal), or keep them dormant?

## STATUS (2 Nov 08:45) — founder 08:18/08:21: "root se delete ... final ... business ka koi feature delete na ho, smartly"
Rule I follow: remove the Personal PACKAGES (price/display/checkout layer) only. The shared plan engine stays untouched (`plan-surface.ts` gates for basic/pro/business/business_pro, `account_kind` logic), because Basic and Pro of the Business ladder run through the same code — deleting "personal" blindly would delete Business features.
**DONE in the repo (PX1 + part of PX2), tsc clean, bun tests green:** `/plans` shows only Business (toggle, Personal cards, Personal compare table, Personal FAQ removed); Billing page lost the Personal tier cards; `src/lib/personal-tiers.ts` deleted; `PersonalTierId` removed from `plan-surface.ts`; the 6 `POLAR_PRODUCT_PLAN_PERSONAL_*` contracts removed from `billing-products.ts`, its test now FAILS if a Personal product comes back; `change-plan` only accepts Business-ladder plans.
**NOT done yet (needs care or his input):** (a) the sign-up choice "Personal | Business" (`WorkspaceKindCards`, `auth.tsx`, `onboarding.tsx`, `claim.tsx`, Rust `workspace.personal`) — changing it changes sign-up for everyone, one step with Chrome proof; (b) SQL E125: retire Personal rows, move Masood's account to Pro, delete test accounts — needs the PX0 list first (below); (c) Polar: archive the 6 products (his step); (d) docs/packages cleanup.
**PX0 first (read-only):** list of every account that is `personal` kind (email, kind, plan, subscription state) so that the delete touches ONLY test accounts the founder approves, and Masood's account is found by email.

## UPDATE 2 Nov 08:55 (founder 08:28: masood email + "ek bhi feature lost na ho" + founder side on hold)
- **Masood:** `masoodsherwani@anexomail.com` -> must end on **Pro**; E125 will set his plan to Pro and his workspace kind to business, and he is never deleted.
- **Lost-feature check (done):** diff of `/plans` and Billing reviewed line by line; every deleted line is Personal-only EXCEPT one, the "Convert to Business" escape hatch for a signed-in account that still has the old personal kind. That was a regression: **restored** (`legacyPersonal` section in `plans.tsx`). Business cards, services, compare table, FAQs, `WORKSPACE_PLANS` and the checkout buttons are untouched.
- **PX0 file written and tested on a scratch database:** `docs/cursor-work/sql/CHECK_PX0_PERSONAL_LIST.sql` (read-only; prints counts, every personal-kind account with plan and subscription state, and Masood's row).
- Founder-side code is on HOLD until he says go.
