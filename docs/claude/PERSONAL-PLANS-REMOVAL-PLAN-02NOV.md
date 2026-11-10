> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

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

## UPDATE 2 Nov 09:10 — PX0 result and E125
Founder paste (08:36): 18 accounts; 3 personal-kind: **masoodsherwani@anexomail.com** (plan already **pro**, no subscription), **basic.test@anexomail.com**, **alikhan@anexomail.com** (both test accounts: created 10 and 13 Oct, no plan, no subscription); **0 paid subscriptions**.
- **E125** (`E125_retire_personal_packages.sql` + `CHECK_E125.sql`, tested twice on a scratch database): empties `personal_polar_map`, switches off and deletes the 6 Personal price-book rows (kept off if referenced), makes sure Masood is on `pro`. Masood's workspace kind is deliberately NOT changed: inside the plan engine a Basic/Pro workspace without an organisation IS "personal" kind, and the same engine serves the Business ladder, so changing it would push him through business onboarding. The `personal_workspace_label()` function stays (the login session calls it); with the map empty it returns no label.
- **Test accounts:** NOT deleted. `CHECK_PX0B_TEST_FOOTPRINT.sql` (read-only) lists every table row that would go with them; after he sees it and says haan on the two emails, E126 deletes them. Mail-server mailboxes are outside the database and are listed as a separate step.


## Status 2 Nov 08:57 — Polar
Founder deleted all 6 Personal products in Polar himself. Repo side was already clean (contracts removed + guard test). Nothing left to do in Polar for Personal.

## PX2 — Sign-up / Create account, REVISED 2 Nov 09:07 PKT (founder: no unfair walls, advanced, latest technology; code goes phase by phase)
Founder's words are verbatim in `founder-commands.md` (09:02 and 09:07). What is decided and why:

1. **Remove the "Personal / Business" choice** on sign-up AND create-account (`WorkspaceKindCards.tsx`, `auth.tsx` KIND_KEY, `onboarding.tsx`, `claim.tsx`, Rust `workspace.personal`). Everyone is on the Business ladder. Legacy `personal` kind rows stay readable (shared engine).
2. **Country + Mobile numbers on create account.** Country = ISO list with flag, stored `account_profiles.country_iso2`. Mobile: a person may add **many numbers** (max 5), the **same number may exist on more than one account** (founder: "yeh zulam user ke saath nahi kero"). Stored E.164 in `account_phones` (E127). Honest: with no SMS provider chosen, numbers are saved **unverified** and are NOT used to sign in yet.
3. **Availability, red / green, without hurting anyone:**
   - **ANEXOMAIL username / address:** live RED "already taken / reserved" or GREEN "available" (a handle is public by nature, like any mail provider). The door exists (`GET /api/auth/identity/check`, `claim.tsx`); it moves into the create-account form.
   - **Outside e-mail (Gmail, Outlook, Yahoo, any):** NO red "already used" and NO number-based red either. Instead the **verify-first pattern**: the person always sees the same neutral screen ("Check your inbox"); a link is mailed. If the address is free it continues sign-up; if it already belongs to an account, the OWNER gets a safe notice mail and nothing is revealed to the typist. This stops anyone counting who has an account (no enumeration) and is not unfair to a real user.
   - Rate-limit per IP + per target, same response time.
4. **Passkey is compulsory (already in code: `needs_passkey` after sign-up) and becomes the everyday way in: after sign-out the phone shows the biometric prompt (fingerprint / face) straight away.**
   - **Gap found in code (2 Nov):** passkey login today needs the e-mail typed first (`login_options` in `server/rust/passkey_glue.rs`; Bun `auth-passkey.ts`), and registration asks `residentKey: "preferred"`. For the "just touch the sensor" flow we need **discoverable credentials**: `residentKey: "required"` for NEW passkeys, a username-less `login_options` (empty allow list, challenge not tied to a user), verify resolves the user from the credential id / `userHandle`, and the browser side uses WebAuthn **conditional mediation** (`mediation: "conditional"`, passkey autofill) plus an auto-prompt on the sign-in screen when this device remembers a passkey. Existing passkeys on phones are mostly discoverable already; old ones keep the typed-email path.
   - Recovery codes stay as the fallback (G35). Test accounts exempt as before.
5. **Phases (one at a time; GREEN only with his paste + my Chrome look):**
   - **PX2a SQL = E127 + CHECK_E127** (written 2 Nov, scratch-tested; he runs `sql-run E127_signup_country_phones CHECK_E127`).
   - **PX2b doors:** Rust username-less passkey login + `residentKey required` for new passkeys; verify-first e-mail door; phones add/list/remove door (`account_phones`, max 5, E.164). Bun fallback kept in step.
   - **PX2c UI:** remove kind cards; Country + Mobile fields (several numbers); red/green for the ANEXOMAIL name; passkey autofill / auto-biometric on sign-in.
   - **PX2d Chrome proof** on sign-up, create-account and sign-in.
6. NOT in this step: SMS verification / mobile login (needs a provider decision, see `AWAM-MOBILE-LOGIN-COUNTRY-REQUIREMENT-01NOV.md`), mail-server mailboxes of the two deleted test accounts (waits for his "haan").

## Status 2 Nov 09:07 — E126
Founder ran E126: CHECK_E126 7/7 OK, E65 sweep OK. basic.test@ and alikhan@ are gone; masoodsherwani@anexomail.com is on Business kind, plan Pro (account count 18 -> 16, no personal-kind account left). Not yet looked at in Chrome (needs Masood's own sign-in).

## PX2 — REVISION 2 (founder 2 Nov 09:17 PKT; this replaces items 3 and 4 above where they differ)
- **E-mail / username availability = the Gmail way first (the ABC), advanced layers on top.** Taken -> RED "already taken" **plus 3-5 suggestions that are free right now**; free -> GREEN. Applies to the ANEXOMAIL name and to the outside e-mail the person types. The earlier "never say taken / verify-first" idea is WITHDRAWN. Advanced layers added AFTER the base works: per-IP and per-target rate limit, same-time answers, bot score, and a lock after many tries (so the red/green cannot be used to scan the user list).
- **Passkey compulsory + biometric sign-in applies to normal users only. It does NOT apply to the founder and his family** (family accounts already skip it: `res.family` in `auth.tsx`; the founder and family stay exempt in every new door).
- **Mobile numbers / SMS:** the user's own country handles it; we build ONE working system for ALL countries. Many numbers per user, the same number allowed on several accounts (E127, server GREEN 2 Nov 09:17).

## GEO1 — Country block: Afghanistan, Israel, North Korea (founder order 09:17; NOTHING built yet)
Order in his words: those three countries are not on the website, their IPs are blocked, the site never opens for them, not even through a VPN; a person who is in ANOTHER country is a different matter. Plan (layers, all defensive):
1. **Edge IP block (the main wall):** country of the visitor's IP = AF, IL or KP -> a plain 403 page for the whole site (web, API, mail web, WebTransport). Mechanism depends on what stands in front of the server: if the site is behind Cloudflare = a WAF country rule (one rule, no code); if visitors reach our own nginx directly = nginx + a GeoIP2 country database. **Need from the founder: is the website behind Cloudflare or direct to nginx?** (AGENTS.md says the MoQ relay is not on Cloudflare; nothing says what the main site uses.)
2. **Sign-up wall:** the three countries are not in the Country list; phone prefixes +93 (Afghanistan), +972 (Israel), +850 (North Korea) are refused in `account_phones` doors (+970 Palestine is NOT touched). Server-side check, not only the form.
3. **VPN / proxy / Tor signals (best effort):** an IP that is listed as Tor / known anonymiser AND a browser timezone or language of those countries (Asia/Kabul, Asia/Jerusalem, Asia/Tel_Aviv, Asia/Pyongyang) -> same 403. Honest limit, said once: nobody can make this 100%. A person physically inside those countries who connects through a VPN exit in another country looks exactly like a person in that other country. We can make it hard (layers 1-3), not impossible; we do not block every VPN user of other countries, because the founder said people in other countries are fine.
4. **Existing accounts:** list accounts whose `country_iso2` / phone prefix / signup country is one of the three; founder decides what happens to each (none expected yet).
5. **Log:** every blocked attempt writes only the country code and a time (no personal data), so the counter shows on the founder dashboard later.
6. Legal note for the founder (not advice): write the country list in the Terms of Service page so the block is not a surprise to anyone.
Phases: GEO1a decision (Cloudflare or nginx) -> GEO1b edge rule + 403 page -> GEO1c sign-up/phone refusal (rides with PX2b) -> GEO1d Chrome proof from the server side (a test request with a forged country header, and the real page). Real proof from inside those countries is not possible from here; the proof is: rule installed + test with the provider's test header.


## Status 2 Nov 09:45 — PX2b code written (Rust only)
`server/rust/signx_core.rs` (21 tests: country wall, E.164, suggestions, HMAC door token, rate window, phone blind index), `signx_glue.rs` (8 procs, type-checked in a stub crate), installer module `signx`, SQL E128, Caddy `server/caddy/geoblock.sh` (GEO1). Server steps in PULL-COMMANDS ("PX2b signx + GEO1"). Security rationale: `SIGNUP-SECURITY-MILITARY-GRADE-02NOV.md`. Still to write: username-less passkey login + residentKey required (Rust `passkey_glue.rs`), UI (PX2c).

## Status 2 Nov 09:50 — PX2c on the server, domain made optional (founder: "user ke mindset se socho")
- PX2c pulled by the founder (pull.sh OK, build OK, 605 files same). Chrome proof of the new sign-up screen still to do by Claude.
- **Company domain is now OPTIONAL at onboarding** (Rust `wsx_core::normalize_org_domain_optional`, 5 wsx tests; UI helper text "No company domain yet? Leave it empty"). Reason: with Personal retired every person is Business-ladder; forcing a company domain would stop individuals at the last step. A domain-less workspace already exists in production (family-* orgs have domain NULL), so downstream code copes. Needs a Rust rebuild: `MODULES=wsx` install (PULL-COMMANDS).
- What users like (proposals, not built, each its own small phase): one-screen sign-up, passkey autofill sign-in (PX2b-2), password strength meter, "show password", live name check (done), clear error text next to the field, no forced phone number (done: optional), Country auto-guessed from the browser language (suggestion only).
