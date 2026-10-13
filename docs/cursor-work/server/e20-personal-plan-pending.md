# E20 — real signup != trial: "Personal Basic" + fake countdown fixed (13 Oct 2026)

Founder tested a real signup live (legal name "Ali Khan", email/password,
personal kind) and landed on `/dashboard` reading:

> Good evening, khan
> **Personal Basic**
> 47h 56m left in your trial

Zero plan chosen, zero payment made. Founder called this "duniya ka sab se
bara bug" — a real account cannot be shown as a trial, and a trial account
(when it eventually exists) must be its own, separate, independent system
with its own landing page — not mixed into the real signup flow.

## Root cause — two independent "defaults to basic" bugs

1. **Every signup silently started a 48h trial clock.**
   `server/routes/auth.ts` `/signup` unconditionally called the Phase 32
   `trial_start()` RPC for *every* signup — business or personal. Checked
   across the whole codebase: there is no other entry point anywhere that
   deliberately starts a free trial (`useStartTrial()` in `src/lib/trial.ts`
   and the Rust `account.signup.start` procedure both exist but are never
   called from any UI). So 100% of real signups were being mislabelled as
   "trial" by a legacy Phase 32 plumbing call that nothing else in the
   product actually opts into.

2. **"No plan yet" rendered identically to "chose Basic."**
   - `personal_workspace_label()` (`docs/cursor-work/sql/E2_personal_polar.sql`)
     checked `family_accounts.plan` → `trial_accounts.plan` →
     `entitlement_state.plan`, and when all three were empty (true for any
     account that never paid), it fell back to `coalesce(..., 'basic')` and
     confidently returned `"Personal Basic"`.
   - `server/routes/auth.ts`'s session (`/me`) endpoint did the exact same
     thing for `workspace_plan`: `String(familyRow?.plan || trial?.plan ||
     "basic")`.
   - `get_billing_subscription()` (E5, the `/app/billing` page's real data
     source) was already correct — it returns `plan: null, display_name:
     null, state: 'none'` when nothing is found, and the billing page
     already renders `"No active plan"` for that. Not touched.

## Fix

Scoped to not touch the Phase 32 trial lifecycle itself — business
signups, `/trial-ended`, the AI hard-zero gate, and a future genuine
opt-in "2-day trial with its own landing page" (explicitly deferred by the
founder to later work) all keep working exactly as before.

- **New `trial_accounts.status = 'pending_plan'`** — "claimed an address,
  no plan selected or paid for yet." `account_state()` needed no code
  change: its `st = 'trial'` / `st = 'active'` comparisons already treat
  any other status value as "not trial, no countdown, no business_data, no
  AI" correctly by construction.
- **`ensure_trial_account_row()`** replaces the `trial_start()` call in
  `/signup`. Same plumbing row (needed for `trial_claim_address` /
  `trial_provision_workspace`, i.e. the already-DONE E17 mailbox/org
  provisioning — unaffected), but inserted with `status = 'pending_plan'`
  instead of the table's `'trial'` default.
- **`personal_workspace_label()`** no longer fakes `'basic'` — returns
  `NULL` when no real plan exists anywhere.
- **New `has_chosen_plan` signal** on the session (`server/routes/auth.ts`,
  `src/lib/auth.tsx`): `true` only when a real plan was found
  (`family_accounts.plan` or `trial_accounts.plan`, i.e. after
  `trial_subscribe()` actually ran). `src/lib/plan-surface.ts`
  `surfaceFromSession()` now shows `"Choose your plan"` instead of a
  fabricated plan name when `kind === "personal"` and
  `has_chosen_plan === false`. Only the *label* changed — `billed`/`power`
  (used everywhere else for feature-gating) are untouched, so no gating
  behaviour anywhere else in the app changes.
- **Routing — the actual flow fix the founder described:**
  `create account → claim address → choose a plan on /plans → Polar
  checkout → payment → back to signed-in /dashboard, billing shows the
  real plan`.
  - `src/routes/claim.tsx`: the personal-kind branch now does
    `window.location.replace("/plans")` instead of `"/dashboard"`.
  - `/plans`' existing `PlanCheckoutButton` / `CheckoutButton` needed no
    change — its already-locked return-to rule ("signed-in, personal →
    `/dashboard`") already does exactly what's needed once the user pays.
  - `src/routes/app.tsx`: any `/app/*` route now bounces a `pending_plan`
    account straight to `/plans`, so the broken state can't be reached by
    a direct link, bookmark, or back-button either.
- **One-time backfill** in the SQL file moves any account that is *already*
  stuck in this bug (status `'trial'`, `plan` null, no real billing row
  anywhere — exactly the founder's own "Ali Khan" test account) to
  `pending_plan` immediately, without needing a fresh signup.

## Hardening (added after founder review — real engineering value, not bulk)

- **DB-level invariant**: a new `CHECK` constraint guarantees a
  `pending_plan` row can never carry a `plan` value — even a future buggy
  write can't recreate this bug class, because Postgres itself rejects it,
  not just application code discipline.
- **Funnel audit trail**: a new `trial_events` value, `pending_plan_entered`
  (idempotent, same technique E17 used for `workspace_provisioned`), so the
  signup → plan-pending transition is queryable history, not just a
  current-state snapshot.
- **`v_signup_plan_funnel`** (service_role-only view): one query shows how
  many accounts are in each state and the average time spent there — where
  the signup → payment funnel is actually leaking.
- **`pending_plan_stale(_hours)`** (service_role-only, read-only): flags
  accounts stuck in `pending_plan` past a threshold (abandoned checkout).
  Follows the same Phase 24A philosophy already locked elsewhere — it only
  *surfaces* data for a human win-back decision, it never auto-emails,
  auto-blocks, or auto-deletes anything.
- **Self-documenting schema**: `comment on function/view/column` for every
  new object, visible via `\d+` or `information_schema`.
- **`docs/cursor-work/sql/E20_rollback.sql`** — a dedicated, separate
  rollback script (never pasted together with the migration by accident):
  reverts the status/event-type constraints, drops the new view/function,
  restores `personal_workspace_label()`'s original `'basic'` fallback, and
  moves any `pending_plan` rows back to `trial`. SQL-side only — says
  plainly at the top that the application-code half (`server/routes/auth.ts`,
  `claim.tsx`, `app.tsx`, `plan-surface.ts`) needs its own `git revert` of
  the E20 commit alongside it, or a fresh signup will call a function this
  script just dropped.

## Known gap this does NOT close

Item #20 in the blueprint ("Asli card charge — checkout green hai, paisa
cut + workspace active hona baqi") is a separate, already-tracked TODO: the
Polar webhook that actually completes a charge and writes the real plan
back (`trial_subscribe` / `entitlement_state`) is not wired yet. After this
fix, a real signup correctly shows "Choose your plan" (never a fabricated
"Personal Basic" + fake countdown) all the way through checkout — but the
dashboard will only show the *real, paid* plan name once #20 is done.

## Verify (zaroori, deploy ke baad)

1. `E20_personal_plan_pending.sql` → Supabase #4 SQL Editor → Run.
2. Server deploy — `server/routes/auth.ts` (same file as E18/E19, already
   carries all three), plus the frontend build (`claim.tsx`, `app.tsx`,
   `plan-surface.ts`, `auth.tsx`, `trial.ts`).
3. Live test: fresh personal signup → claim an address → should land on
   `/plans`, **not** `/dashboard`. No "...left in your trial" anywhere.
4. Check the founder's existing "Ali Khan" account: dashboard should now
   read a neutral "Choose your plan" label, no countdown.
5. Pick a plan on `/plans`, complete Polar checkout → should return to
   `/dashboard` (existing, unchanged rule). Billing page behaviour depends
   on item #20 (separate, not re-verified here).

**Status:** READY (repo mein, Supabase + server par abhi deploy/verify nahi
hui — Rule 5).
