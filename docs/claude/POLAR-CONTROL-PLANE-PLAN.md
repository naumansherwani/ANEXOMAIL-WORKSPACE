# POLAR CONTROL PLANE — B6 (G16) ka hukm + design. Founder, 21 Oct 2026 21:41 PKT (verbatim ka matlab)
> "Webhook ko apne server ke control mein rakhna hai. Polar ka control plane meri server par, latest technology. Payment system TOOTNA NAHI chahiye.
> User checkout par click kare to seedha Polar checkout **1 ms se pehle** khule. Duniya ka best system soch samajh kar bana ke B6 isi guideline par shuru karo,
> repo + sandbox mein update. Polar par do webhook endpoints: `https://polarpayments.anexomail.com/api/v1/polar-webhook` (Sep 7, API 2026-10) aur
> `https://anexomail.com/api/v1/polar-webhook` (Aug 12, API 2026-10, 'Legacy signing')."
> Founder ne is hukm se **Polar engine par kaam ki ijazat di** (pehle "haath mat lagao" tha). Hadd: har badlav surgical + backup + build + restore-on-fail; webhook receiver ka raasta (WAL-first) KABHI nahi toota.

## 0. Pehle sach (server recon + repo `server/rust/polar-payment/main.rs`, 1245 lines)
- Webhook receiver **pehle se control plane jaisa hai**: verify -> **local WAL fsync** -> 200 (Supabase down ho to bhi 200); worker WAL->inbox insert (8 retries backoff); reconcile har 15 min Polar API se (OK/MISSING/DIVERGED -> synthetic event); signature-reject evidence log; endpoint secrets Polar API se auto-sync (do endpoints, "legacy signing" wala bhi). **Webhook ko "ghulam" banane ke liye naya kuch nahi chahiye — usay chhedna nahi.**
- Asli kamzoriyan: (1) `/api/v1/billing/:user_id` aur `/api/v1/checkout*` **bina auth + public** (Caddy anexomail.com par, aur polarpayments host par `/api/v1/*` sab) — Caddy logs: billing/ 1 hit (founder ka curl), checkout 0, webhook 264 => koi caller nahi; (2) `.env` world-readable (644), service **root**; (3) DB pool slow (reconcile query 1.0–1.35 s, acquire 2.9 s); (4) app ka checkout engine se NAHI, Brain `billing-sync.ts` seedha Polar API se banta hai — control plane do jagah; (5) cancel/card/VAT portal hai hi nahi (G16).
- Checkout speed ki haqeeqat: Polar API call hamari taraf se ~200–600 ms; "1 ms" sirf **pehle se tayyar (pre-warm)** session se mumkin: click par hamara hissa ~0 ms (URL pehle se maujood, sirf redirect). Polar ka apna page jitni der le woh Polar ki CDN par hai.

## 1. Design — "taale" (founder ko aasaan lafzon mein bataye gaye)
1. **Caddy ke 2 darwaaze band** (`/api/v1/billing/*`, `/api/v1/checkout*` anexomail.com par; polarpayments par `/api/v1/*` ki jagah sirf `/api/v1/polar-webhook*`). Caddy **tootta nahi**: backup -> `caddy validate` -> reload -> test -> rollback. Webhook darwaaza ek byte nahi badalta.
2. **Muhar (HMAC-SHA256)**: engine ke andar ke raaste (checkout, billing, replay, reconcile, portal) sirf wahi request jin par `x-pcp-ts`, `x-pcp-nonce`, `x-pcp-sig = HMAC(key, method|path|ts|nonce|SHA256(body))` ho; 60 s window; nonce dobara nahi (replay band); constant-time compare; **fail-closed** (key na ho to refuse). Webhook, /health, /ready par nahi.
3. **User pehchan**: engine bahar ka `user_id` nahi maanta; sirf Rust/Brain (jo login verify karte hain) muhar ke saath bhejte hain.
4. **Portal (G16)**: `POST /api/v1/portal {user_id}` -> Polar customer-session (`external_customer_id`) -> `customer_portal_url` (cancel/card/VAT). Sirf muhar ke saath, sirf localhost.
5. **Checkout pre-warm + cache**: `POST /api/v1/checkout` (muhar) ab (user, product, seats, return_to) par 10 min cache (single-flight: do click ek hi Polar call). Frontend billing/pricing par hover/touch/mount par "prepare", click par seedha redirect.
6. **Chaabi hifazat**: `.env` `chmod 600`; service root se alag user (pm2 `--uid`) — alag chhota step, backup ke saath.
7. **Alarm**: mismatch (amount/currency/product), signature-reject spike, WAL queue depth, reconcile DIVERGED — email (ALERT_EMAIL pehle se).
8. **Kill switch**: `POLAR_CHECKOUT_PAUSED` flag (ek tap): checkout rukta, webhook/worker chalte rahe.
9. **Diary (SHA-256 chain)** + roz reconcile report — baad mein.
10. WASM/kernel: Polar server par WASM se security nahi barhti (skip). Kernel: alag user + systemd sandbox + nftables localhost-only (step 6).

## 2. Phases (B6)
- **B6a** (security + portal + pre-warm): `pcp_core.rs` (pure: HMAC sign/verify, window, nonce cache, cache key, kill switch; tests) + `main.rs` surgical patch + `polar-control-plane-install.sh` (backup, cargo build, swap, /ready, **webhook proof**, rollback) + `caddy-polar-lockdown.sh` (read-only plan pehle, phir apply) + Rust `billing.portal` / `billing.checkout.prepare` (anexomail-rust, muhar ke saath) + Bun fallback + frontend "Manage billing" + prepare-on-hover + sandbox proof.
- **B6b**: Brain `billing-sync.ts` ke intent/change-plan/guest-intent/claim-guest ko engine ke through (ek control plane), 783 lines ka differential proof. Payment tootna nahi chahiye => pehle shadow mode.
- **B6c**: diary chain, alarms, kill switch UI (founder workspace), pool/index tuning (E55 index CONCURRENTLY).
## 3. Server par kya founder chalayega (har step alag, ijazat se)
`caddy-polar-lockdown.sh` (read-only plan) -> apply; `chmod 600 /opt/polar-rust-payment/.env`; `polar-control-plane-install.sh`; Rust `MODULES=b5` (+ naya billing module); Web pull. Webhook ke liye proof: install ke baad test event (`test-event.sh`) + `/metrics` received counter.

## 4. B6a — STATUS (21 Oct 2026, raat) — BANA + SANDBOX-PROVEN, server par founder ke output ka intezaar (GREEN nahi)
**Kya bana (repo):**
| Hissa | File | Kaam |
|---|---|---|
| Muhar core | `server/rust/polar-payment/pcp.rs` | HMAC-SHA256, 60 s, nonce replay-band, fail-closed, kill-switch file, UUID/URL allowlist (10 unit tests) |
| Polar engine | `server/rust/polar-payment/main.rs` (surgical) | `pcp_gate` middleware: checkout/billing/portal = muhar; replay/reconcile/sab internal = proxy-header (X-Forwarded-For) par 403; naya `POST /api/v1/portal`; `PAUSE_PORTAL`/`PAUSE_CHECKOUT`; `/metrics` mein `pcp_ok`/`pcp_denied`. **Webhook/WAL/worker/reconcile/health/ready: ek line nahi badli** |
| Installer | `docs/cursor-work/server/polar-control-plane-install.sh` | backup -> key -> build (fail = purani src, service chalti rehti) -> restart -> PROOF (ready, webhook test-event received barhe, bina muhar 401, proxy-header 403) -> koi fail = binary+src wapas |
| Caddy | `caddy-polar-lockdown.sh` (+ repo Caddyfiles) | `plan` (sirf dikhata) / `MODE=apply`: 2 darwaaze band, validate, reload, post-check, rollback. Caddy khud rehta hai |
| Rust app | `server/rust/b6_core.rs` + `b6_glue.rs` (module `b6` in rust-engine-install.sh) | `billing.portal`: login se user -> muhar-band call -> sirf https://*.polar.sh URL |
| Bun fallback | `brain_portal_patch.py` + `brain-portal-install.sh` | `POST /api/billing/portal` + mount-order fix (purana polar.ts `/subscription` shadow band) |
| Frontend | `src/components/app/billing/ManageBilling.tsx` + `billing-platform.ts` + `app.billing.tsx` | "Manage billing" button (cancel/card/VAT); hover/touch par link pehle se tayyar => click par foran; "email us" dead-end hata |
| Operator tool | `pcp-call.sh` | server se muhar-band call (`pcp-call POST /api/v1/portal ...`) |

**Sandbox saboot:** `polar-cp-proof.py` — purana vs naya engine saath: **54 pass, 0 fail** (webhook dono par 200/401 barabar, WAL byte-barabar, X-Forwarded-For wali webhook 200, DB band par bhi 200, key na ho tab bhi webhook 200, purana engine bina muhar billing/checkout deta tha, naya 401, replay/stale/tamper/wrong-key 401, proxy-header 403, kill switch, 413). `b6-sandbox-proof.py` — asli Rust app -> asli naya engine -> mock Polar: **13 pass, 0 fail** (+ Bun signer bhi). Rust unit tests: pcp 10, b6_core 5. Cross-language vector Rust = Bun = Python.
**Sandbox ki hadd (sach):** asli Polar API sandbox se nahi milti — portal ka Polar-wala hissa (customer-sessions endpoint ka asli jawab) SIRF server par verify hota hai (installer ka qadam 5 nakli UUID se poochta hai). Frontend 390/820/1440 ka screenshot sandbox mein nahi ban sakta (npm/Vite install DNS band) — sirf syntax check; asli check founder ke Chrome mein.

**Install ki tarteeb (har qadam alag, jawab ke baad agla):**
1. Web pull (UI) -> 2. `polar-control-plane-install.sh` (engine+key) -> 3. `MODULES=b6` Rust install -> 4. `brain-portal-install.sh` -> 5. `caddy-polar-lockdown.sh` plan, phir `MODE=apply` -> 6. Billing page par "Manage billing" asli click.

**Abhi baqi (B6b/B6c — jaan-boojh kar B6a mein nahi):**
- *Checkout "1 ms se pehle"*: live checkout Brain `billing-sync.ts /intent` se banta hai (Supabase intent PEHLE, phir Polar) — yeh payment ki asli reedh hai aur `PlanCheckoutButton.tsx` landing ke qareeb hai (founder: landing/prices NO TOUCH). Isko chhedne se pehle founder ki ijazat + shadow-mode. Pre-warm (hover par intent+checkout tayyar, click par sirf redirect) B6b mein, billing page se shuru (landing nahi).
- webhook ke liye DB pool/index tuning (reconcile 1.0-1.35 s), alarm (amount/currency mismatch, reject spike), hash-chain diary, `.env chmod 600`, non-root user = B6c (har ek founder ki ijazat se).
