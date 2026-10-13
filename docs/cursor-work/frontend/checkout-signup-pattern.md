# Founder pattern — Get started / Sign in / Polar / land

**Status:** READY in repo. Polar rust payment `:3400` no-touch.

ANEXOChat Polar pe **Business account** ka offer hai. Personal Pro ko wahi **power** milti hai (Org nahi).

## Door 1 — Get started

Get started → `/plans` → card Get started → Polar checkout.

Payment success → recovery account pe Polar/engine wali email. Codes no-touch.

## Door 2 — Sign in then create workspace

`/auth` Sign in. Footer: **Create your account for workspace** → Personal | Business → form.

Account create ke baad → `/plans` (dashboard nahi, claim skip nahi tore — pehle plan).

`/plans` → Polar. Success:

- **Personal** → `/dashboard`. CRM → Billing = existing `/app/billing` (Supabase entitlement, Polar messenger).
- **Business** → `/onboarding` organisation name + domain, phir dashboard. CRM Billing wahi.

Existing buyers Sign in → workspace. `/plans` nahi.

## Files (polish only)

`SiteNav` Get started · `auth.tsx` signup land `/plans` · `PlanCheckoutButton` `return_to` · `billing-sync.ts` success_url query · `checkout.done.tsx` · CRM nav Billing → `/app/billing`.

**Banned:** `plans.ts` · Polar product IDs · `server/rust/polar-payment/` · polar webhook bridge.
