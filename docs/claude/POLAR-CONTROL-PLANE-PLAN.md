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
