# E23 — payment ke baad account khud active (#20 ka wiring) — 14 Oct 2026

## E20 audit: kya wired tha, kya nahi
| E20 hissa | Haal |
|---|---|
| `pending_plan` status + constraints + funnel view + `pending_plan_stale()` | DONE — SQL run, founder confirm |
| `/signup` ab `ensure_trial_account_row()` (48h clock nahi) | DONE — deployed |
| `personal_workspace_label()` NULL, `has_chosen_plan`, "Choose your plan" | DONE — SQL + deploy |
| `/claim` personal -> `/plans` | DONE — founder ne Ali ke account pe dekha |
| `/app` pending_plan -> `/plans` bounce | DONE — founder ne live confirm kiya |
| Ali ka backfill | DONE |
| **payment ke baad `pending_plan` -> `active`** | **NOT WIRED** — yehi #20 ka gap tha |

Gap ki asal sooorat: `billing_apply_entitlement()` sirf `entitlement_state` likhta; `trial_subscribe()` kisi
payment path se call nahi hota tha; `/checkout/done` sirf Polar ka status dekhta, hamara intent cron ke
bharose settle hota. Yani paisa dene ke baad bhi user `/plans` par wapas bounce hota.
**Alag, security:** `POST /api/trial/subscribe` bas `payment_ref != ""` dekhta tha — koi bhi login user kisi
bhi string se apna plan 'active' kar sakta tha, bina payment (E20 ka lockout bhi is se bypass hota).

## Kya wire kiya
1. **E23 SQL** (`docs/cursor-work/sql/E23_payment_activates_account.sql`): `entitlement_state.plan` set hote hi
   (jo sirf `billing_intent_confirm` ke verified amount/currency/product ke baad hota) `trial_accounts`
   `pending_plan|trial` -> `active` (`trial_subscribe`). £0/mismatch payment entitlement tak jati hi nahi, account
   active nahi hota. Trigger payment ko kabhi nahi rokta (error = WARNING). Purane paid-par-atke accounts ka backfill.
2. **`POST /api/trial/subscribe`** ab client ka plan/payment_ref ignore karta hai; sirf `entitlement_state` dekhta.
3. **`POST /api/billing/settle`** (`billing-sync.ts`): `/checkout/done` Polar "confirmed" ke baad apna intent usi waqt
   pull-truth se settle karta hai (wohi `pullTruthForIntent` jo cron/`/intent/:id` use karte hain).
4. **`/checkout/done`**: settle ke retry ke baad hi auto-redirect; settle na ho to "plan activate ho raha hai, ek minute"
   likha aata hai, bounce nahi.
Webhook / Rust engine / Phase 50 SQL ko haath nahi.

## Deploy
1. Supabase #4: E23 SQL paste -> Run.
2. Web: Rule-1 command. 3. Brain: `bash server/deploy-brain.sh`.

## Live verify (DONE ke liye)
Naya personal test signup -> /plans -> asli payment -> `/checkout/done` "Payment confirmed" -> `/dashboard` khule (bounce nahi);
`select status, plan from trial_accounts where user_id='…'` -> `active` + plan. £0-discount test mein account active NAHI hoga
(amount guard) — yeh intentional hai.
**Status:** READY (Rule 5).
