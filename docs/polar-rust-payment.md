# POLAR RUST PAYMENT ENGINE — LIFETIME SOLUTION (locked 5 Sep 2026)

Yeh masla ek dafa hal hota hai, phir **no touch**. Payment/webhook logic Supabase
Edge Functions mein bilkul nahi — dedicated Hetzner Rust engine (`polar-rust-payment`,
PM2, port `3400`) handle karti hai. Secrets aur product IDs sirf us server ki
`.env` mein rehte hain, repo mein kabhi nahi.

## 0. Guardrail (kisi bhi agent ke liye)

> Do NOT modify or regenerate the Polar webhook verification logic, secret names,
> or payload handling. Webhook = verify + insert + 200 only. Business logic
> Postgres trigger mein hai.

## 1. Architecture (kyun webhook kabhi disable nahi hota)

```text
Polar  ──POST──►  TWO live HTTPS endpoints ──► Rust :3400 /api/v1/polar-webhook
                    1. HMAC-SHA256 signature verify
                    2. INSERT INTO polar_webhook_inbox (ON CONFLICT DO NOTHING)
                    3. return 200 "Event Accepted"        (<300ms, hamesha)
                                   │
                    Postgres AFTER INSERT trigger polar_inbox_apply()
                    → polar_subscriptions (canonical state)
                    → polar_mail_outbox   (receipt / welcome / grace warning)
```

- Engine ke andar koi network call ya sync nahi — is liye timeout ka sawal nahi.
- Internal error par bhi Polar ko **200** jaata hai (`"Logged internally"`).
  Sirf **invalid signature** par 401 — kyunki woh asli reject hai.
- Retry-safe: `event_id` unique, duplicate event chup-chaap ignore.
- Trigger fail ho to event zinda rehta hai (`processed=false`, `process_error`),
  reconcile dobara chala sakta hai — event kabhi kho nahi sakta.

## 2. Files (repo → server copy)

| Repo | Server |
|---|---|
| `server/rust/polar-payment/Cargo.toml` | `/opt/polar-rust-payment/Cargo.toml` |
| `server/rust/polar-payment/main.rs` | `/opt/polar-rust-payment/src/main.rs` |
| `sql/phase50_polar_rust_payment.sql` | Supabase #4 → SQL Editor |

## 3. Ek baar ka setup (Hetzner)

```bash
# 3.1 SQL pehle: Supabase #4 -> SQL Editor -> sql/phase50_polar_rust_payment.sql chalao

# 3.2 Engine folder
mkdir -p /opt/polar-rust-payment/src
cp /opt/anexomail-web/server/rust/polar-payment/Cargo.toml /opt/polar-rust-payment/Cargo.toml
cp /opt/anexomail-web/server/rust/polar-payment/main.rs   /opt/polar-rust-payment/src/main.rs

# 3.3 Secrets — sirf yahan. Repo mein kabhi nahi.
nano /opt/polar-rust-payment/.env
```

`.env` (poora content, select all → paste, values apne bharo):

```env
PORT=3400
DATABASE_URL=postgres://postgres.<ref>:<password>@aws-0-<region>.pooler.supabase.com:5432/postgres
POLAR_ACCESS_TOKEN=polar_oat_xxxxxxxx
POLAR_WEBHOOK_SECRET=whsec_xxxxxxxx
PUBLIC_APP_URL=https://anexomail.com
POLAR_PRODUCT_PLAN_BASIC_MONTHLY=5e1c7b50-fee5-4214-873c-ad9f350476d9
POLAR_PRODUCT_PLAN_BASIC_YEARLY=d3642ce7-a750-484c-940f-eb39039ed9c2
POLAR_PRODUCT_PLAN_PRO_MONTHLY=df1aa320-346f-451b-a16a-e737c0703e12
POLAR_PRODUCT_PLAN_PRO_YEARLY=7d87a72e-6be6-4aa2-86d6-5eca3d448956
POLAR_PRODUCT_PLAN_BUSINESS_MONTHLY=b12be1b1-a02d-4701-9475-08e796d99b69
POLAR_PRODUCT_PLAN_BUSINESS_YEARLY=7a1d5445-92c5-4472-81a3-4820b8579854
POLAR_PRODUCT_PLAN_BUSINESS_PRO_MONTHLY=3a1e1699-59c0-4334-8be0-d4b08a1202d1
POLAR_PRODUCT_PLAN_BUSINESS_PRO_YEARLY=80bca014-b832-474e-bd3e-084a04453de0
POLAR_PRODUCT_PRIORITY_SUPPORT=8f6d7c8e-1722-421f-b28c-2a031f63731d
```

```bash
# 3.4 Build + PM2
cd /opt/polar-rust-payment
cargo build --release
pm2 start ./target/release/polar-rust-payment --name polar-rust-payment --cwd /opt/polar-rust-payment
pm2 save

# 3.5 Sehat
curl -s http://127.0.0.1:3400/health
# { "service":"polar-rust-payment","db":true,"webhook_secret":true,"polar_token":true,"products":9 }
```

## 4. Caddy endpoints (dono hamesha live)

`anexomail.com` site block ke andar, baqi routes se **pehle**:

```caddyfile
	# POLAR PAYMENT ENGINE (dedicated Rust, :3400) — no-touch
	handle /api/v1/polar-webhook* {
		reverse_proxy 127.0.0.1:3400
	}
	handle /api/v1/checkout* {
		reverse_proxy 127.0.0.1:3400
	}
	handle /api/v1/billing/* {
		reverse_proxy 127.0.0.1:3400
	}
```

```bash
caddy validate --config /etc/caddy/Caddyfile && systemctl reload caddy
```

Polar dashboard → Settings → Webhooks mein do endpoints:

1. **ANEXOMAIL Production Webhook** — `https://polarpayments.anexomail.com/api/v1/polar-webhook`
2. **ANEXOMAIL Backup Webhook** — `https://anexomail.com/api/v1/polar-webhook`

Dono format **Raw** aur API version **2026-04** rakhte hain. Polar har endpoint ka
alag signing secret banata hai; engine `POLAR_ACCESS_TOKEN` se dono automatically
load karti hai. `.env` wala secret purane endpoint ka fallback rehta hai.
Purana `anexomail.com` endpoint delete, replace ya modify nahi hota. `event_id` uniqueness
ki wajah se dono par same delivery duplicate state nahi banati.

### Purana Express path (bridge, na hataayen)

`https://anexomail.com/api/public/polar/webhook` (Express :3100) ab **koi logic nahi**
rakhta — raw body jaisi ki taisi `127.0.0.1:3400/api/v1/polar-webhook` par forward hoti hai
(`POLAR_ENGINE_URL`, default `http://127.0.0.1:3400`). Engine down ho to 503 jaata hai taake
Polar retry kare. Polar dashboard mein yeh URL **nahi** dalna.

### Response time (sach)

Engine ka kaam sirf verify + ek chhota INSERT hai — aam tor par **10–40ms**. Slow network par
bhi target **< 300ms**; Polar ka asli limit 10 second hai, hum us se bohat neeche hain.
"50ms guarantee" likhna jhoot hoga, is liye budget 300ms locked hai.


## 5. Signature scheme LOCK (Polar docs, 8 Sep 2026 cutoff)

Polar sirf **ek** header bhejta hai: `webhook-signature: v1,<base64>` (+ `webhook-id`,
`webhook-timestamp`). Signed content = `{id}.{timestamp}.{raw body}`. HMAC key secret
ki **umr** par hai:

- **Standard Webhooks** (secret 8 Sep 2026 00:00 UTC ke baad banaya/reset):
  key = base64-decode(`whsec_` strip karke).
- **Polar HMAC** (us se pehle ka secret):
  key = poora `whsec_...` string ke UTF-8 bytes, as-is.

Engine **dono keys** try karti hai — secret reset ho ya purana ho, kuch badalna nahi.
Timestamp tolerance 5 min (replay protection). `.env` mein purana
`POLAR_WEBHOOK_SECRET=whsec_...` fallback rehta hai; naya endpoint secret Polar API
se auto-load hota hai — **koi nayi env line ya manual overwrite nahi**.

## 5b. `invalid_signature` ka ilaj

1. `POLAR_ACCESS_TOKEN` ke paas `webhooks:read` scope hona chahiye; deploy log mein
   `Polar webhook signing secrets loaded count=2` expected hai.
2. Koi naya secret `.env` mein copy nahi karna.
3. Test: `cd /opt/anexomail-web && git pull && bash server/rust/polar-payment/test-event.sh` → phir
   `select event_type, processed, process_error from public.polar_webhook_inbox order by received_at desc limit 5;`
4. Polar dashboard ka **delivery overview** har delivery ka payload + status dikhata hai —
   wahan se redeliver bhi kar sakte ho.

## 6. User journey (locked)

1. Card/package par click → `POST /api/v1/checkout` (`product_key`, optional `user_id`/`email`, `return_to`).
2. Polar checkout khulta hai → payment success.
3. Polar `success_url` → `/checkout/done?checkout_id=…&return_to=…` → verify → **2 second baad usi jagah wapas**.
4. Webhook `order.paid` → receipt row `polar_mail_outbox` mein.
5. Webhook `subscription.active` → package activate (`polar_subscriptions`) + welcome email row.
6. Next month payment miss → `subscription.past_due` → `grace_until = now() + 3 days`,
   warning email. **Service block nahi hoti** — `polar_billing_state()` mein
   `service_blocked` hamesha `false`.
7. Account ke andar "Pay now" → wahi `/api/v1/checkout` with `return_to = window.location.pathname`.

## 7. Roz ka sach (queries)

```sql
select count(*) filter (where not processed) as pending,
       count(*) filter (where process_error is not null) as failed
from public.polar_webhook_inbox;

-- Individual events (inbox mein column event_type hai; type/attempts nahi)
select event_id, event_type, processed, process_error, received_at, processed_at
from public.polar_webhook_inbox
order by received_at desc
limit 10;

select product_key, status, grace_until from public.polar_subscriptions order by updated_at desc limit 20;

select kind, to_email, sent_at from public.polar_mail_outbox where sent_at is null order by created_at;
```

---

## 8. PHASE 51 — HARDENING (locked 7 Sep 2026)

Postgres trigger **zinda hai** (fast path wahi hai). Iske ooper 5 layer add hue:

```text
Polar ──HTTPS──► polarpayments.anexomail.com ──► Caddy ──► :3400
                                             1. HMAC verify (2 keys)
                                             2. local WAL fsync  ──► 200 (10–40ms)
                                                     │
                              worker (har 2s) ──► polar_webhook_inbox ──► trigger ──► state
                                                     │ fail: 30s,2m,10m,1h,6h,24h × 8
                                                     └─► wal/dead/ (row zinda, replay)
                              reconcile (har 15 min) ──► Polar API vs internal state
                              watchdog (har 60s)     ──► polar_payment_alerts
```

### 8.1 Local durable WAL — "ek bhi payment na gire" ka asli jawab

- `WAL_DIR` (default `/opt/polar-rust-payment/wal`) mein `pending/ done/ dead/`.
- Ek event = ek file. Likhna atomic: `tmp` → `fsync` → `rename` → dir fsync.
- **200 sirf WAL fsync ke baad** jaata hai — Supabase down ho to bhi Polar ko 200 milta hai.
- `done/` 14 din baad khud saaf hota hai (asli truth Supabase mein hai).

### 8.2 Worker + dead letter

- Worker WAL → `polar_webhook_inbox` insert (`on conflict (event_id) do nothing`).
- Fail par backoff: **30s · 2m · 10m · 1h · 6h · 24h · 24h · 24h**, 8 attempt ke baad
  `wal/dead/` — row **kabhi delete nahi** hoti.
- Replay: `curl -s -X POST http://127.0.0.1:3400/api/v1/replay` (signature-reject rows
  replay nahi hoti — woh sirf evidence hain).

### 8.3 Reconciliation — webhook-independence

Har 15 min engine khud Polar API se subscriptions pull karti hai aur apne state se
compare karti hai: `ok` / `missing` / `diverged` / `unknown` → `polar_reconcile_log`.
`missing`/`diverged` par synthetic event WAL mein daal deti hai (event_id
`reconcile:<sub>:<modified_at>:<status>` — duplicate-safe), phir trigger package
activate kar deta hai. **Webhook kabhi na aaye to bhi payment activate ho jaati hai.**
Manual: `curl -s -X POST http://127.0.0.1:3400/api/v1/reconcile`.

### 8.4 Signature 401 ka permanent ilaj

401 spec ke mutabiq wapas jaata hai, **magar** raw body + headers
`polar_signature_rejects` mein log ho jaate hain (aur `wal/dead/` mein bhi). Ghalat
secret ab silently events nahi khata:

```sql
select reason, headers->>'webhook-id' as webhook_id, created_at
from public.polar_signature_rejects order by created_at desc limit 10;
```

### 8.5 Watchdog + endpoints

- `GET /ready` — 200 sirf jab WAL writable (db state sach ke saath report hoti hai).
- `GET /metrics` — received · duplicate · synced · failed · dead_letter(+depth) ·
  signature_rejects · queue_depth · oldest_pending_secs · reconcile_runs/gap/last.
- Watchdog har 60s: `oldest_pending > 10 min`, `queue_depth > 200`, ya dead letter
  maujood → `polar_payment_alerts` (hourly bucket, spam nahi). `ALERT_EMAIL` env se.

### 8.6 Deploy — Nauman ke liye sirf 2 line (koi file overwrite nahi)

```bash
# 1) SQL (repo se copy-paste): sql/phase51_polar_payment_hardening.sql -> Supabase #4
# 2) Server:
cd /opt/anexomail-web && git pull && bash server/rust/polar-payment/deploy.sh
```

`deploy.sh` khud: repo → `/opt/polar-rust-payment` sync (backup ke saath), WAL folders,
`cargo build --release`, pm2 start/restart + save, phir `/health` `/ready` `/metrics`
print. **`.env` ko kabhi touch nahi karta.**

Ingress (ek dafa): `docs/caddy-payments-host.md` — `polarpayments.anexomail.com` on Server 2 (`62.238.98.98`).

### 8.7 Roz ka sach — ek query

```sql
select public.polar_payment_pulse();
```

### 8.8 Polar dashboard — exact webhook form

Do endpoints banao: primary `https://polarpayments.anexomail.com/api/v1/polar-webhook`
aur backup `https://anexomail.com/api/v1/polar-webhook`. Dono ka format **Raw**, API
version **2026-04**, aur secret engine `.env` wala same `whsec_...` ho.

Sirf yeh events select karo:

- `order.paid`
- `subscription.created`
- `subscription.active`
- `subscription.past_due`
- `subscription.canceled`
- `subscription.revoked`
- `subscription.uncanceled`

`order.refunded` select nahi karna (no-refunds lock). Baqi Benefit, Checkout,
Customer, Seat, Discount, Member, Organization, Product aur Refund events is engine
ko darkar nahi.
