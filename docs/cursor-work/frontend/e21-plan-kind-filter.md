# E21 — personal accounts only see/buy personal packages (13 Oct 2026)

Founder (13 Oct 2026): a personal-kind account should only ever be able to
choose from personal packages on `/plans`; after a first payment there
should be a smooth way to switch between personal tiers or move to a
business package, same email.

## What already existed vs. what was actually wired

- `/plans` had a Personal/Business toggle (default Personal) — but it was
  a plain `useState`, not tied to the signed-in account's real kind. Anyone
  could click the other tab and buy the wrong kind of package.
- `server/routes/billing-sync.ts` already had `enforceAccountKind()` — a
  403 (`product_not_available_for_account_kind`) gate on `/api/billing/intent`
  — but it was dead code: no product in `server/config/billing-products.ts`
  ever set the `accountKind` field it reads, so the check always passed.
- `/app/billing` already showed personal-kind accounts their correct
  3-tier "Your personal tiers" upgrade strip (Personal Basic/Pro+/Premium)
  — but it *also* unconditionally rendered the 4 generic
  Basic/Pro/Business/Business Pro cards underneath, for every kind,
  personal included.

## Fixed (frontend + one metadata field — no Polar/webhook code touched)

- **`server/config/billing-products.ts`** — added `accountKind?: "personal"
  | "business"` to the `BillingProduct` type, and set
  `accountKind: "personal"` on the six personal-tier product entries only
  (`PERSONAL_BASIC_*`, `PERSONAL_PRO_PLUS_*`, `PERSONAL_PREMIUM_*`). No
  `productId` / price / env key touched — this only activates the
  already-wired `enforceAccountKind()` check. The 4 generic business
  products were deliberately left untagged: the existing ABSM guest-checkout
  flow (`/api/public/billing/guest-intent`, Phase 49) lets a visitor buy a
  business plan *before* signing in, and `accountKind`-tagged products are
  blocked there on purpose (`personal_products_require_sign_in`) — tagging
  business products would have broken that live revenue path.
- **`src/routes/plans.tsx`** — a signed-in account's own `account_kind`
  (from the session) now locks the page to that kind and hides the
  Personal/Business toggle entirely. A guest (not signed in — kind not
  decided yet) still sees the full toggle, unchanged.
- **`src/components/site/PlanCheckoutButton.tsx`** — new `requireSignIn`
  prop on `CheckoutButton`. The personal-tier cards on `/plans` pass it, so
  a guest clicking "Get started" on a personal product is sent to
  `/auth?mode=signup` instead of hitting the new 403 as a raw error string.
- **`src/routes/app.billing.tsx`** — the 4 generic plan cards (and the
  now-stale "Business plans unlock company Org..." note) only render for
  `kind !== "personal"`. A personal-kind account on `/app/billing` now sees
  only its own 3-tier strip. The Monthly/Yearly cycle toggle stays visible
  for everyone either way, since it also drives that strip's prices.

## Also built (13 Oct 2026, founder: "100% sab hona chahiye")

**4. Personal → Business conversion, same email, no new signup.**
`src/components/site/ConvertToBusiness.tsx` — a small escape hatch shown on
`/plans` (below the locked personal cards) and on `/app/billing` ("Your
personal tiers" strip). Deliberately reuses the *exact same two backend
calls* the existing business-onboarding flow already makes —
`POST /api/workspace/organisations` (`server/routes/workspace.ts`,
`createOperationalOrg` + `stampWorkspaceKind`) then
`POST /api/auth/onboarding/complete`. No new backend route, no new SQL, no
Polar/webhook code. After it succeeds, `useAuth().refresh()` re-fetches the
session — `account_kind` flips to `"business"` and every kind-gated section
(the new `/plans` lock, `/app/billing`'s personal-vs-generic cards) reacts
automatically. They can then buy a real business package through the
normal, already-working `/plans` business-tab checkout.

**Honest caveat, not hidden:** this calls code that was already live for
every business signup — I did not audit whether anything *besides*
`mail_accounts.org_id` is scoped by org id elsewhere in the product (threads,
contacts, calendar, etc.). For a brand-new business signup this never
mattered because there was no prior history. For a personal account
converting, it's the first time that existing code runs against an account
that *has* real history, so it deserves a real test with a test account
that has actual mail/contacts/calendar data before trusting it on a live
customer — not a new risk I introduced, but a pre-existing one this
surfaces for the first time.

## Known gap this does NOT close (blocked — need one thing from founder)

**3. No double-charge protection on "upgrade" yet.** The personal-tier
"Upgrade" button still opens a brand-new Polar checkout for the target tier
instead of changing the existing subscription in place. **13 Oct 2026 night
— now built**, once the founder pasted the real `polar_subscriptions` schema
(the one piece that was missing):

```
id uuid · polar_subscription_id text · polar_customer_id text · user_id uuid
· email text · product_key text · product_id text · status text ·
current_period_end timestamptz · grace_until timestamptz · seats integer ·
last_event_id text · created_at/updated_at timestamptz
```

**`POST /api/billing/change-plan`** (`server/routes/billing-sync.ts`, new
route, scoped to `accountKind === "personal"` products only):

1. Looks up the user's current row in `polar_subscriptions` where
   `status = 'active'`.
2. **No active row found** (first-time purchase, e.g. an E20 `pending_plan`
   account clicking a tier card) → falls back to `openCheckoutIntent()` —
   the `/intent` route's own logic, pulled into a shared function so there
   is no duplicate checkout-opening code (Rule 6). Behaves exactly like
   before.
3. **Active row found** → calls Polar's own documented mechanism,
   `PATCH /v1/subscriptions/{id}` with the target `product_id` and
   `proration_behavior: "prorate"` — this changes that one subscription's
   plan directly; Polar does not create a second subscription, so there is
   no double-billing.
4. On success, two narrow pull-truth writes (don't wait on whatever the
   Rust payment engine's webhook handling does with `subscription.updated`,
   same principle this file's own `pullTruthForIntent()` already uses for
   checkouts): `polar_subscriptions.product_id`/`product_key` on that row,
   and `entitlement_state.plan` — the latter matters because
   `get_billing_subscription()` reads `entitlement_state.plan` *before*
   falling back to parsing `polar_subscriptions`, so without this the
   billing page would still show the old plan name after a successful
   upgrade. Both are single-column updates to columns whose meaning is
   confirmed directly from existing, already-read code — not a guess.

**Frontend:** `CheckoutButton` (`PlanCheckoutButton.tsx`) gets a new
`changePlan` prop. When set, it posts to `/change-plan` instead of
`/intent`; the response is `{ ok: true }` (no checkout URL — nothing to
redirect to) when the in-place change ran, so the button sends the browser
straight to `/dashboard` instead of to Polar. Wired on both the `/app/billing`
"Upgrade" button and `/plans`' personal cards (so a signed-in personal
account that already has a subscription and browses back to `/plans` can't
accidentally open a second one either).

**Honest residual risk, not hidden:** `proration_behavior: "prorate"` was
chosen as the standard, documented option for "apply now, prorate the
difference" — Polar's guide names three options (`invoice`, `prorate`,
`next_period`) without spelling out the exact billing-moment difference
between the first two, so this is a reasonable default, not a certainty;
worth watching the first real upgrade's invoice. Also: this writes directly
to `entitlement_state` and `polar_subscriptions` from Bun code for the first
time outside the existing webhook/intent-confirm path — narrow, single
columns only, reasoned from code already read in this repo, but genuinely
new ground, so the first live test matters more than usual here.

## Part 4 (14 Oct 2026) — `/app/billing` "All plans" fixed: real business plans + convert

Founder screenshot: internal `/app/billing` (profile billing, **not** the
`/plans` landing page, which is fine) showed the 4 business-priced cards
relabelled "Personal Basic / Personal Pro…" with a false "Current" tag, under
an "All plans" heading — for personal *and* business accounts.

- **`src/routes/app.billing.tsx`** — `PlanCard` no longer has `personalLabel`
  at all: every card shows its real workspace name and price.
  - **Personal account:** "Your personal tiers" (unchanged) → "Billing cycle" →
    new **"Business plans"** block: the same 4 real plans (Basic / Pro /
    Business / Business Pro), never "Current". Button = **Convert to
    Business** → opens `ConvertToBusiness` for that plan (same sign-in, same
    email, same mailbox — no new account).
  - **Business account:** "All plans", the 4 real plans, real "Current";
    "Upgrade/Downgrade" uses `changePlan` (full-price checkout, old plan
    closed after payment — E22).
  - The old collapsed "Need a business workspace instead?" link under the
    personal tiers is gone from this page (the Business plans cards are the
    entry point now). `/plans` still has its link, untouched.
- **`src/components/site/ConvertToBusiness.tsx`** — new props
  `defaultOpen`, `checkoutProductKey`, `planLabel`, `onCancel`. With a
  `checkoutProductKey` it converts the account (org + `account_kind` →
  business), then calls `/api/billing/change-plan` for that plan. Conversion
  runs **once**: if the plan step fails, the form shows the error and a
  "Try again" button that skips the conversion (never a second organisation).
- **`src/components/site/PlanCheckoutButton.tsx`** — the post→follow-the-answer
  logic is now one exported `openPolarCheckout()` (used by `CheckoutButton` and
  `ConvertToBusiness`; Rule 6, no copy). New `billingErrorMessage()` turns the
  few plan-change error codes into a sentence.
- **`server/routes/billing-sync.ts` `/change-plan`** — targets now: personal
  tiers (personal account only, as before) **or** generic workspace plans
  (`kind: "plan"`, untagged). Workspace plan for an account explicitly
  `personal` → 403 `convert_to_business_first`. Any active *plan*
  subscription (personal tier or workspace plan) is replaced in place via
  `PATCH /v1/subscriptions/{id}` — so a just-converted account moves off its
  old personal tier instead of paying for both. Same product → `{ok, unchanged}`
  (no call). No active subscription → first-time checkout (`openCheckoutIntent`).
  Polar/webhook/Rust `:3400` untouched.

**Superseded by E22 (14 Oct 2026, founder rule):** the in-place `PATCH` with
`proration_behavior: "prorate"` described in "Also built" #3 and in the
`/change-plan` bullet above is **removed** — it credited the old payment.
Rule: a user who moves to another package pays the **new package in full**,
the old subscription is closed. `/change-plan` now opens a normal full-price
checkout and records which subscription it replaces
(`public.polar_plan_replacements`); the Rust payment engine closes the old one
only after the new one is active. This also removes the old seat-based →
Business Pro limit (nothing is switched in place any more). Full write-up:
`docs/cursor-work/server/e22-plan-replacement.md`.

## Verify (zaroori, deploy ke baad)

1. Server deploy — same Rule-1 command, carries `server/config/billing-products.ts`,
   `server/routes/billing-sync.ts`, `src/routes/plans.tsx`,
   `src/routes/app.billing.tsx`, `src/components/site/PlanCheckoutButton.tsx`,
   `src/components/site/ConvertToBusiness.tsx`.
2. Signed-in **personal** account → `/plans`: no Personal/Business toggle,
   only the 3 personal cards + "Need a business workspace instead?" link.
   → `/app/billing`: "Your personal tiers" + a **"Business plans"** block with
   the 4 real plans (real names/prices, no "Personal X", no "Current"), each
   with **Convert to Business**. Stale-build check on the server:
   `grep -l "Business plans" .output/public/assets/app.billing-*.js` must
   print a file name (empty = old bundle still being served).
3. Signed-in **business** account → `/plans`: no toggle, only the 4
   business cards (unchanged from before).
4. **Guest** (not signed in) → `/plans`: toggle still there, both tabs
   still work exactly as before — business guest-checkout unaffected.
5. Guest clicks "Get started" on a personal card → sent to
   `/auth?mode=signup`, not a raw error.
6. **Real test, carefully, with a test account that has an active personal
   subscription:** click "Upgrade" on a different personal tier →
   confirm in Polar's own dashboard that the *same* subscription id now
   shows the new product (not a second subscription), confirm only one
   invoice/proration line appears, then confirm `/app/billing` shows the
   new plan name immediately.
7. `/app/billing` → "Business plans" → **Convert to Business** on a personal
   test account → confirm one new organisation is created, `account_kind`
   flips to business, mailbox still works, nothing about existing mail
   history looks broken, and (with an active personal subscription) the
   *same* Polar subscription id now shows the business product — not a
   second subscription.
8. Signed-in **business** account → `/app/billing`: heading "All plans", 4
   real cards, real "Current", Upgrade changes in place.
9. Any account → Business Pro: normal full-price Polar checkout; after payment
   the old subscription is closed by the Rust engine (see E22 verify).

**Status:** READY — all 4 parts built (repo mein), server deploy + live
re-verify, especially #6–#9 above, abhi baaqi hai (Rule 5).
