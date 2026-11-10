> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

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
2. **Activate:** Rust :3200 `/rpc/account.signup.activate` **PRIMARY** (Bun `POST /api/trial/subscribe` fallback). Client ka plan/payment_ref ignore; sirf `entitlement_state` dekhta (`trial_activate_if_paid`).
3. **Settle:** Rust :3200 `/rpc/billing.settle` **PRIMARY** -- intent `entitled` / `paid` / `stuck` ko Supabase ke verified RPC (`billing_intent_confirm`) se settle karta hai. Intent abhi `open` ho (Polar se paisa pull karna) to Rust 503 deta hai aur frontend (`rpcOrRest`) Bun fallback `POST /api/billing/settle` (`pullTruthForIntent`) bulata hai -- kyunke Polar :3400 ka `read_checkout` sirf `status` deta hai (amount/product nahi) aur woh engine no-touch hai. **Open item (aap ki ijazat chahiye):** `read_checkout` mein amount/currency/product/order_id add ho to yeh hissa bhi Rust mein aa jata hai.
4. **`/checkout/done`**: settle ke retry ke baad hi auto-redirect; settle na ho to "plan activate ho raha hai, ek minute"
   likha aata hai, bounce nahi.
Webhook / Rust engine / Phase 50 SQL ko haath nahi.

## Deploy
1. Supabase #4: E23 SQL paste -> Run.
2. Rust engine (PRIMARY): `docs/cursor-work/server/e24-account-deletion.md` ke "Deploy order" step 2 wala diff-check + `bash server/rust/deploy.sh` + `bash server/gates/rust-gate.sh` (E23 aur E24 ke Rust arms ek hi `main.rs` mein hain, ek hi deploy).
3. Web: Rule-1 command. 4. Brain (fallback): `bash server/deploy-brain.sh`.

## Live verify (DONE ke liye)
Naya personal test signup -> /plans -> asli payment -> `/checkout/done` "Payment confirmed" -> `/dashboard` khule (bounce nahi);
`select status, plan from trial_accounts where user_id='…'` -> `active` + plan. £0-discount test mein account active NAHI hoga
(amount guard) — yeh intentional hai.
**Status:** READY (Rule 5).
