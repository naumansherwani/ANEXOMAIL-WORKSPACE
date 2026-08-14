# ANEXOMAIL — Server 2 (Brain, port 3100) route files

Rule (locked, SQL folder ki tarah): backend ki har file isi repo folder mein rehti hai.
Backend `/opt/anexomail` git repo nahi hai, is liye founder yahan se **poori file copy**
karta hai aur server par `nano` mein overwrite karta hai (select all -> paste).
Kabhi line-patch, sed ya python patch nahi.

| Repo file | Server path | Phase |
| --- | --- | --- |
| `index.ts` | `/opt/anexomail/src/index.ts` | main entry (mount order) |
| `routes/integrations.ts` | `/opt/anexomail/src/routes/integrations.ts` | 22 |
| `routes/settings.ts` | `/opt/anexomail/src/routes/settings.ts` | 23 |
| `routes/release.ts` | `/opt/anexomail/src/routes/release.ts` | 30 |

## Env naam (Server 2 par asli naam)

Supabase #4 ke naam **`SUPABASE4_URL`** aur **`SUPABASE4_SERVICE_ROLE_KEY`** hain.
Nayi file mein hamesha yeh naam pehle aur `SUPABASE_URL` fallback ho.
Aur `createClient` boot par throw na kare — warna poora Brain crash hota hai
(port 3100 dead, curl `000`). Missing env = sirf us router ka `503`.

## Copy + restart tareeqa

### 1) Main entry overwrite (mount order critical)

```bash
cd /opt/anexomail
cp src/index.ts src/index.ts.bak.$(date +%s)
nano /opt/anexomail/src/index.ts   # select all -> paste repo/server/index.ts -> Ctrl+O, Ctrl+X
pm2 restart anexomail-leo && sleep 3
```

### 2) Phase 22 — Integrations Platform

```bash
cd /opt/anexomail
cp src/routes/integrations.ts src/routes/integrations.ts.bak.$(date +%s)
nano /opt/anexomail/src/routes/integrations.ts   # select all -> paste repo/server/routes/integrations.ts -> Ctrl+O, Ctrl+X
pm2 restart anexomail-leo && sleep 3
for p in providers connections migrations delivery/health exports leo-actions; do
  printf "/api/integrations/%s -> " "$p"
  curl -s -o /dev/null -w "%{http_code}\n" "http://localhost:3100/api/integrations/$p"
done
```

### 3) Phase 23 — Settings Center

```bash
cd /opt/anexomail
cp src/routes/settings.ts src/routes/settings.ts.bak.$(date +%s)
nano /opt/anexomail/src/routes/settings.ts   # select all -> paste repo/server/routes/settings.ts -> Ctrl+O, Ctrl+X
pm2 restart anexomail-leo && sleep 3
for p in list save history blast-radius drift scheduled simulate explain revert; do
  printf "/api/settings/%s -> " "$p"
  curl -s -o /dev/null -w "%{http_code}\n" "http://localhost:3100/api/settings/$p"
done
printf "/api/founder/settings/overview -> "
curl -s -o /dev/null -w "%{http_code}\n" "http://localhost:3100/api/founder/settings/overview"
```

### 4) Phase 25 — Admin Center

```bash
cd /opt/anexomail
cp src/routes/admin.ts src/routes/admin.ts.bak.$(date +%s) 2>/dev/null
nano /opt/anexomail/src/routes/admin.ts   # select all -> paste repo/server/routes/admin.ts -> Ctrl+O, Ctrl+X
# phir src/index.ts bhi repo/server/index.ts se overwrite karo (admin mount uske andar hai)
pm2 restart anexomail-leo && sleep 3
for p in health storage incidents monitoring logs reports diagnostics; do
  printf "/api/admin/%s -> " "$p"
  curl -s -o /dev/null -w "%{http_code}\n" "http://localhost:3100/api/admin/$p"
done
printf "/api/founder/admin/overview -> "
curl -s -o /dev/null -w "%{http_code}\n" "http://localhost:3100/api/founder/admin/overview"
```

SQL: `sql/phase25_admin.sql` (Supabase #4 mein chalao).

### 5) Phase 30 — Production & Founder Lock

```bash
cd /opt/anexomail
cp src/routes/release.ts src/routes/release.ts.bak.$(date +%s) 2>/dev/null
nano /opt/anexomail/src/routes/release.ts   # select all -> paste repo/server/routes/release.ts -> Ctrl+O, Ctrl+X
# phir src/index.ts bhi repo/server/index.ts se overwrite karo (release mount uske andar hai)
pm2 restart anexomail-leo && sleep 3
printf "/api/public/status -> "
curl -s -o /dev/null -w "%{http_code}\n" "http://localhost:3100/api/public/status"
for p in overview checks checklist deployments lock roadmap; do
  printf "/api/founder/release/%s -> " "$p"
  curl -s -o /dev/null -w "%{http_code}\n" "http://localhost:3100/api/founder/release/$p"
done
printf "/api/founder/revenue/pipeline -> "
curl -s -o /dev/null -w "%{http_code}\n" "http://localhost:3100/api/founder/revenue/pipeline"
printf "/api/mail/outbox/send -> "
curl -s -o /dev/null -w "%{http_code}\n" -X POST "http://localhost:3100/api/mail/outbox/send"
```

SQL: `sql/phase30_release.sql` (Supabase #4 mein chalao).

### 6) Phase 34 — Polar billing truth + founder reply clock

Pehle Supabase #4 mein `sql/phase34_billing_support.sql` run karo. Phir server par
in **poori files** ko repo version se nano select-all overwrite karo:

```bash
cd /opt/anexomail
cp src/routes/integrations.ts src/routes/integrations.ts.bak.$(date +%s) 2>/dev/null
cp src/routes/polar.ts src/routes/polar.ts.bak.$(date +%s) 2>/dev/null
cp src/routes/billing-support.ts src/routes/billing-support.ts.bak.$(date +%s) 2>/dev/null
cp src/index.ts src/index.ts.bak.$(date +%s)
nano /opt/anexomail/src/routes/integrations.ts  # repo/server/routes/integrations.ts poori paste
nano /opt/anexomail/src/routes/polar.ts         # repo/server/routes/polar.ts poori paste
nano /opt/anexomail/src/routes/billing-support.ts # repo/server/routes/billing-support.ts poori paste
nano /opt/anexomail/src/index.ts                # repo/server/index.ts poori paste
bun install
pm2 restart anexomail-leo --update-env
sleep 3
pm2 logs anexomail-leo --lines 40 --nostream
printf "/health -> "; curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3100/health
printf "/api/integrations/providers -> "; curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3100/api/integrations/providers
printf "/api/founder/support/replies -> "; curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3100/api/founder/support/replies
```

Expected: health `200`; dono protected routes without token `401`. `000` = Brain
down, `404` = mount missing, `503` = Supabase #4 env missing.

`401` = green (guarded). `200` = public/health ok. `000` = server down. `404` = mount missing.

### 7) Phase 35 — Payment Safety Net (ek bhi payment zaya nahi)

Pehle Supabase #4 mein `sql/phase35_payment_safety.sql` run karo. Phir:

```bash
cd /opt/anexomail
cp src/routes/polar.ts src/routes/polar.ts.bak.$(date +%s) 2>/dev/null
nano /opt/anexomail/src/routes/polar.ts   # repo/server/routes/polar.ts poori paste
grep -q '^CRON_SECRET=' .env || echo "CRON_SECRET=$(openssl rand -hex 24)" >> .env
pm2 restart anexomail-leo --update-env && sleep 3
pm2 logs anexomail-leo --lines 30 --nostream
printf "/api/billing/invoices -> ";      curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3100/api/billing/invoices
printf "/api/billing/subscription -> ";  curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3100/api/billing/subscription
printf "/api/billing/payment-health -> ";curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3100/api/billing/payment-health
printf "/api/public/polar/replay -> ";   curl -s -o /dev/null -w "%{http_code}\n" -X POST http://localhost:3100/api/public/polar/replay
```

Expected: teen billing routes `401` (token ke bina) aur replay `401` (cron secret ke bina).

Retry sweep har 5 minute (cron):

```bash
( crontab -l 2>/dev/null; echo "*/5 * * * * curl -s -X POST -H \"x-anexomail-cron: $(grep '^CRON_SECRET=' /opt/anexomail/.env | cut -d= -f2)\" http://localhost:3100/api/public/polar/replay > /dev/null" ) | crontab -
```

### 8) Phase 36 — STATE SYNC ENGINE (Supabase = truth, Polar = messenger)

Pehle Supabase #4 mein `sql/phase36_state_sync.sql` run karo. Phir:

```bash
cd /opt/anexomail
cp src/index.ts src/index.ts.bak.$(date +%s) 2>/dev/null
nano /opt/anexomail/src/routes/billing-sync.ts   # repo/server/routes/billing-sync.ts poori paste
nano /opt/anexomail/src/index.ts                 # repo/server/index.ts poori paste
grep -q '^CRON_SECRET=' .env || echo "CRON_SECRET=$(openssl rand -hex 24)" >> .env
pm2 restart anexomail-leo --update-env && sleep 3
pm2 logs anexomail-leo --lines 30 --nostream
printf "/api/billing/intent (POST) -> ";  curl -s -o /dev/null -w "%{http_code}\n" -X POST http://localhost:3100/api/billing/intent
printf "/api/billing/state -> ";          curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3100/api/billing/state
printf "/api/billing/state-health -> ";   curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3100/api/billing/state-health
printf "/api/public/billing/sync -> ";    curl -s -o /dev/null -w "%{http_code}\n" -X POST http://localhost:3100/api/public/billing/sync
```

Expected: teen billing routes `401` (token ke bina) aur sync `401` (cron secret ke bina).

Pull-truth sweep har minute (yeh hi "no payment failure" ka engine hai):

```bash
( crontab -l 2>/dev/null; echo "* * * * * curl -s -X POST -H \"x-anexomail-cron: $(grep '^CRON_SECRET=' /opt/anexomail/.env | cut -d= -f2)\" http://localhost:3100/api/public/billing/sync > /dev/null" ) | crontab -
```

### 9) Phase 37 — MOVE-IN OPERATIONS & REVENUE COCKPIT (money machine)

Pehle Supabase #4 mein `sql/phase37_movein_ops.sql` run karo. Phir:

```bash
cd /opt/anexomail
nano /opt/anexomail/src/routes/movein.ts   # repo/server/routes/movein.ts poori paste
cp src/index.ts src/index.ts.bak.$(date +%s) 2>/dev/null
nano /opt/anexomail/src/index.ts           # repo/server/index.ts poori paste
pm2 restart anexomail-leo --update-env && sleep 3
pm2 logs anexomail-leo --lines 30 --nostream
printf "/api/public/movein/capacity -> ";  curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3100/api/public/movein/capacity
printf "/api/public/movein/request -> ";   curl -s -o /dev/null -w "%{http_code}\n" -X POST http://localhost:3100/api/public/movein/request
printf "/api/movein/deal -> ";             curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3100/api/movein/deal
printf "/api/founder/movein/cockpit -> ";  curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3100/api/founder/movein/cockpit
printf "/api/public/movein/sweep -> ";     curl -s -o /dev/null -w "%{http_code}\n" -X POST http://localhost:3100/api/public/movein/sweep
```

Expected: capacity `200`, request `400` (body ke bina), deal + cockpit `401`, sweep `401`.

Sweep har 10 minute (payment + health truth):

```bash
( crontab -l 2>/dev/null; echo "*/10 * * * * curl -s -X POST -H \"x-anexomail-cron: $(grep '^CRON_SECRET=' /opt/anexomail/.env | cut -d= -f2)\" http://localhost:3100/api/public/movein/sweep > /dev/null" ) | crontab -
```

### 10) Phase 43/44 — Annual billing + Polar IDs v2 (LOCKED)

Pehle Supabase #4 SQL Editor mein `sql/phase43_annual_billing_lock.sql` (v3) poori run karo.
`sql/phase44_polar_ids_v2.sql` retired hai — mat chalao.

Server par yeh 4 files repo se nano select-all overwrite (naya folder `src/config/`):

```bash
cd /opt/anexomail
mkdir -p src/config
nano /opt/anexomail/src/config/billing-products.ts  # repo/server/config/billing-products.ts
nano /opt/anexomail/src/routes/polar.ts             # repo/server/routes/polar.ts
nano /opt/anexomail/src/routes/billing-sync.ts      # repo/server/routes/billing-sync.ts
nano /opt/anexomail/src/index.ts                    # repo/server/index.ts
```

Phir `.env` mein 13 Polar IDs (`docs/polar-products.md` §7 ka block) daal kar:

```bash
pm2 restart anexomail-leo --update-env && sleep 3
pm2 logs anexomail-leo --lines 40 --nostream
printf "/api/billing/intent -> ";  curl -s -o /dev/null -w "%{http_code}\n" -X POST http://127.0.0.1:3100/api/billing/intent
printf "/api/billing/state -> ";   curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:3100/api/billing/state
printf "/api/billing/checkout -> ";curl -s -o /dev/null -w "%{http_code}\n" -X POST http://127.0.0.1:3100/api/billing/checkout
```

Expected: intent + state `401` (token ke bina), purana checkout `410` (retired).
Polar dashboard ka "Checkout Link" hum use NAHI karte — checkout session API se banti hai
taake `billing_intents` id metadata mein jaaye (link static hota hai, metadata carry nahi karta).
