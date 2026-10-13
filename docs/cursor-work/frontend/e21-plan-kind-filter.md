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

## Known gaps this does NOT close (flagged to founder, needs its own
approval before building — real money / Polar subscription logic)

1. **No double-charge protection on "upgrade" yet.** The personal-tier
   "Upgrade" button opens a brand-new Polar checkout for the target tier
   (`/api/billing/intent`) without cancelling the current subscription
   first. `polar_subscription_id` is stored (`server/routes/polar.ts`,
   locked webhook), so a real fix is possible — but it means calling
   Polar's live API to cancel a subscription, which needs careful testing
   before it touches a real customer, not a same-session change.
2. **Personal → Business account-kind conversion does not exist anywhere.**
   `account_kind` (`account_profiles.preferences.workspace_kind`) is only
   ever written once, at signup/onboarding
   (`server/routes/auth.ts`, `onboarding.tsx`, `claim.tsx`, `workspace.ts`)
   — nothing updates it afterwards. "Pay for a business package on the
   same personal email" is a new feature, not a fix.

## Verify (zaroori, deploy ke baad)

1. Server deploy — same Rule-1 command, carries `server/config/billing-products.ts`,
   `src/routes/plans.tsx`, `src/routes/app.billing.tsx`,
   `src/components/site/PlanCheckoutButton.tsx`.
2. Signed-in **personal** account → `/plans`: no Personal/Business toggle,
   only the 3 personal cards. → `/app/billing`: only "Your personal tiers",
   no 4-card generic grid.
3. Signed-in **business** account → `/plans`: no toggle, only the 4
   business cards (unchanged from before).
4. **Guest** (not signed in) → `/plans`: toggle still there, both tabs
   still work exactly as before — business guest-checkout unaffected.
5. Guest clicks "Get started" on a personal card → sent to
   `/auth?mode=signup`, not a raw error.

**Status:** READY (repo mein, server par abhi deploy/verify nahi hui — Rule 5).
