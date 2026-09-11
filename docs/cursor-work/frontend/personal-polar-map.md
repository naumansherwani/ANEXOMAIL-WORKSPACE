# Personal pay — Polar cards, naya SKU nahi

**Status:** READY (repo). Polar webhook / `plans.ts` / landing **no-touch**. Phase 60s SQL **no-touch**.

Do axes mix nahi:

1. **Kind** (signup): Personal | Business — `account_kind`. Polar product nahi.
2. **Paise** (landing `/plans`): Basic £23 · Pro £46 · Business £97 · Business Pro £2,850.

Personal user landing pe wahi 4 cards se paid karta hai. Alag “Personal Polar” card **nahi**.

| Landing Polar card | Kind | Workspace naam | Power |
|---|---|---|---|
| Basic £23 | personal | **Personal Basic** | Mail People Calendar Work. Chat/full CRM nahi |
| Pro £46 | personal | **Personal Pro** | = Business Pro power, Org nahi |
| Business £97 | **business** | Business | Org + Chat + CRM shared |
| Business Pro £2,850 | personal | **Personal Premium** | same SKU, kind personal, Org nahi |
| Business Pro £2,850 | business | Business Pro | Org + Chat + CRM activity |

`workspace_plan` Polar webhook pehle se likhta hai. SQL naya price table **nahi**. Map: `polarToPersonalTier()` in `src/lib/plan-surface.ts`.

Tarteeb: landing card (optional / trial baad) → Create account → Personal | Business → claim `@anexomail.com` → Personal seedha `/dashboard` · Business org name + domain → `/dashboard`.
