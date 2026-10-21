# POLAR RUST PAYMENT ENGINE — nakshा (founder server recon, 21 Oct 2026 21:22 PKT). SOURCE OF TRUTH = yeh service. NO TOUCH bina founder ki ijazat.
Recon founder ne server par chalaya (read-only); repo copy: `server/rust/polar-payment/main.rs` (1245 lines).
## Hakikat (server)
- pm2 id 4 `polar-rust-payment`, online, 6 restarts, 8 MB. `cwd=/opt/polar-rust-payment` (`.env` 1750 bytes dotenv, `src/main.rs`, `wal/`, `target/`). Cargo: axum 0.7, tokio, **sqlx 0.8 direct Postgres** (PostgREST nahi), reqwest rustls, hmac/sha2/subtle, edition 2021. Listen `127.0.0.1:3400`.
- Env: pm2 env mein koi POLAR key nahi => token `.env` se dotenvy (service khud). OPENROUTER_* pm2 env mein hain (is service ke liye nahi, shell se).
## Routes (main.rs:367-375)
`GET /health` `/ready` `/metrics` · `POST /api/v1/polar-webhook` (verify -> insert -> instant 200; state sync Postgres trigger) · `POST /api/v1/replay` · `POST /api/v1/reconcile` · `POST /api/v1/checkout` (body: product_key, seats, user_id, email, return_to) · `GET /api/v1/checkout/:id` · `GET /api/v1/billing/:user_id` (`select public.polar_billing_state($1::uuid)`).
## Polar API jo woh bulata hai
`POST /v1/checkouts/` · `GET /v1/checkouts/{id}` · `GET /v1/subscriptions…` (reconcile) · `DELETE /v1/subscriptions/{old_sub}` (plan replace: pehle naya paid, tab SIRF purani revoke) · `GET /v1/webhooks/endpoints`.
**Portal / customer-session / user-cancel endpoint: HAI HI NAHI.** (G16 yahi kami.)
## Caddy
Purani backups mein `anexomail.com` par `/api/v1/polar-webhook*`, `/api/v1/checkout*`, `/api/v1/billing/*` -> 127.0.0.1:3400 (public). Alag host `polarpayments.anexomail.com` (`/api/v1/*`, /metrics sirf local). **LIVE Caddyfile abhi dekha NAHI** (recon mein sirf .bak files aayin).
## ⚠ SECURITY KHATRA (verify baqi)
`read_billing` aur `create_checkout` mein **koi auth nahi** (code mein). Agar live Caddy `anexomail.com/api/v1/billing/*` public forward karta hai to koi bhi, kisi user ka UUID jaan kar, uska billing state parh sakta hai (privacy). Check command founder ko di gayi (21:25). Fix (agar khula): Caddy se `/api/v1/billing/*` aur `/api/v1/checkout*` hatana YA service mein internal-secret (HMAC) — Polar ki ijazat se.
## Perf nishani
Reconcile query (`polar_*` pending replacements) har ~15 min 1.0–1.35 s (slow-statement WARN) + connection acquire 2.9 s => index missing / pool chhota. Sirf nigrani; fix = SQL index (CONCURRENTLY) founder ki ijazat se.
## B6 (G16) ka asli design
1. **Polar service mein ek naya endpoint** `POST /api/v1/portal` {user_id} -> Polar `POST /v1/customer-sessions/` {external_customer_id (= Supabase user id, checkout isi se banta hai), return_url fixed} -> `customer_portal_url`. **Sirf 127.0.0.1 (Caddy mein NAHI)** + internal HMAC-SHA256 header (shared secret, constant-time) — koi public auth-less raasta nahi. Installer: backup, cargo build, swap binary (webhook downtime ~seconds, Polar retry karta hai), health/ready, rollback. **FOUNDER KI IJAZAT CHAHIYE.**
2. `anexomail-rust`: `billing.portal` (login, subscription active/past_due check, rate-limit, internal HMAC call) + Bun fallback `/api/billing/portal`.
3. Frontend `app.billing`: "Manage billing" (cancel/card/VAT) — dead end "email karein" hatao. 390/820/1440.
4. Alag chhota: Bun `/api/billing/subscription` shadow bug (polar.ts purana route pehle mount hota hai) -> `index.ts` mount order, polar.ts untouched.

## Update 21:41
Webhook receiver already WAL-first (verify -> WAL fsync -> 200; worker; reconcile 15 min; reject log; secrets auto-sync, 2 Polar endpoints: polarpayments.anexomail.com (Sep 7) + anexomail.com (Aug 12, legacy signing)). Caddy logs: billing/ 1 hit, checkout 0, webhook 264. Design: POLAR-CONTROL-PLANE-PLAN.md.
