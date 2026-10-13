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
instead of changing the existing subscription in place.

Polar's own docs confirm the correct, safe mechanism exists:
`PATCH /v1/subscriptions/{id}` with a new `product_id` (+ `proration_behavior`)
replaces the subscription's plan *in place* — no second subscription, Polar
handles proration. This can be added to `billing-sync.ts` (Bun, not the
locked Rust payment engine or the `polar.ts` bridge) as a genuinely new,
additive route.

**Why it isn't built yet:** finding the current subscription's
`polar_subscription_id` for a user requires reading the `polar_subscriptions`
table and/or the `polar_billing_state()` function — both created directly in
Supabase (not in this repo), and `polar_billing_state()` is explicitly
commented "Phase 50, no-touch" with its body not visible here. Writing a
query against a live payment table's exact columns from a guess, with zero
way to test it before it runs against real customer subscriptions, is
exactly the kind of payment-logic mistake Rule 4 exists to prevent — this
is not a "don't want to," it's "cannot verify from here."

**What unblocks it:** run this once in Supabase SQL Editor and paste the
output back:

```sql
select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'polar_subscriptions'
order by ordinal_position;
```

Once the real column names (status/active flag, product id, etc.) are
known, the "change plan in place" endpoint can be written against them
exactly, not guessed.

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
