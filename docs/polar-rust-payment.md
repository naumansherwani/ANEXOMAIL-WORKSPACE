# POLAR RUST PAYMENT ENGINE — LIFETIME SOLUTION (locked 5 Sep 2026)

Yeh masla ek dafa hal hota hai, phir **no touch**. Payment/webhook logic Supabase
Edge Functions mein bilkul nahi — dedicated Hetzner Rust engine (`polar-rust-payment`,
PM2, port `3400`) handle karti hai. Secrets aur product IDs sirf us server ki
`.env` mein rehte hain, repo mein kabhi nahi.

## 0. Guardrail (Lovable / kisi bhi agent ke liye)

> Do NOT modify or regenerate the Polar webhook verification logic, secret names,
> or payload handling. Webhook = verify + insert + 200 only. Business logic
> Postgres trigger mein hai.

## 1. Architecture (kyun webhook kabhi disable nahi hota)

```text
Polar  ──POST──►  Rust engine :3400 /api/v1/polar-webhook
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

## 4. Caddy block (webhook public URL)

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

Polar dashboard → Settings → Webhooks → URL:
`https://anexomail.com/api/v1/polar-webhook` · format **Raw** · secret wahi jo `.env` mein hai.

## 5. `invalid_signature` ka ilaj

1. Polar dashboard se secret **as-is** copy karo — `whsec_` prefix samet.
   Engine khud prefix strip karti hai aur base64 decode karti hai.
2. Secret ke aage/peeche space ya newline nahi (nano mein line ke end par Enter na dabao).
3. Secret kabhi double-encode na karo (base64 ka base64 sabse aam ghalti hai).
4. Test: Polar dashboard se "Send test event" → phir
   `select event_type, processed, process_error from public.polar_webhook_inbox order by received_at desc limit 5;`

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

select product_key, status, grace_until from public.polar_subscriptions order by updated_at desc limit 20;

select kind, to_email, sent_at from public.polar_mail_outbox where sent_at is null order by created_at;
```
