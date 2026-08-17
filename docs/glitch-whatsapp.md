# Phase 47 — Glitch truth → WhatsApp (2 min)

## 1. Supabase #4 → SQL Editor
`sql/phase47_glitch_whatsapp.sql` chalao. Tables: `customer_glitch_logs`,
`feedback_user_triggers`, `glitch_noise_rules`, `glitch_alerts`.

## 2. WhatsApp channel (Meta WhatsApp Cloud API — free tier)
1. developers.facebook.com → naya App → **WhatsApp** product add karo.
2. WhatsApp → API Setup: **Phone number ID** aur **permanent access token** (System User token) lo.
3. Apna personal number **recipient** ke tor par verify karo (Test number list).
4. Alert 24-hour window ke bahar bhi aaye is liye ek **template** banao:
   name `anexomail_glitch`, category *Utility*, body:
   `ANEXOMAIL glitch ({{1}}): {{2}} — page {{3}}, hits {{4}}`

## 3. Backend env (Hetzner Server 2)
```
nano /opt/anexomail/.env
```
```
WHATSAPP_TOKEN=EAAG...            # permanent system user token
WHATSAPP_PHONE_ID=1234567890      # phone number ID (number nahi)
WHATSAPP_TO=923001234567          # founder ka number, + ke baghair
WHATSAPP_TEMPLATE=anexomail_glitch  # khali chhodo to plain text bhejta hai
CRON_SECRET=<already set>
```
```
pm2 restart anexomail-leo && pm2 logs anexomail-leo --lines 30 --nostream
```

## 4. Frontend env (/opt/anexomail-web/.env)
```
VITE_POSTHOG_KEY=phc_xxx
VITE_POSTHOG_HOST=https://eu.i.posthog.com
```
Key na ho to telemetry chup-chaap band rehti hai (koi error nahi).

## 5. Cron — har minute sweep (2 min SLA)
```
crontab -e
* * * * * curl -s -X POST http://127.0.0.1:3100/api/public/glitch/sweep -H "x-cron-secret: $CRON_SECRET" >/dev/null
```

## 6. Test
```
curl -s -X POST http://127.0.0.1:3100/api/public/glitch/report \
  -H 'content-type: application/json' \
  -d '{"kind":"checkout_error","message":"TEST glitch","severity":"critical","route":"/plans"}'
curl -s -X POST http://127.0.0.1:3100/api/public/glitch/sweep -H "x-cron-secret: $CRON_SECRET"
```

## 7. Fazool alert kaise ruka
- `glitch_noise_rules` → ResizeObserver, chunk reload, extension errors, AbortError = ignore
- same fingerprint = ek hi alert, occurrences barhte hain
- 12 alert/hour cap → uske baad `muted` (log rehta hai, WhatsApp chup)
- `console.error` = severity warning → sirf log, WhatsApp nahi
- rage click alert sirf jab **3+ alag session** 15 min mein ek hi button par phansein
