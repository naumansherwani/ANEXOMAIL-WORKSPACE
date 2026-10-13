# Phase 47 — Glitch truth → EMAIL + LEO diagnose (2 min)

> WhatsApp channel RETIRED (founder decision 19 Aug 2026). Alerts ab email par
> jati hain, aur LEO unko diagnose karta hai (AI feature nahi deta — sirf
> diagnosis line, non-AI product ke glitch par bhi).

## 1. Supabase #4 → SQL Editor
`sql/phase47_glitch_whatsapp.sql` chalao. Tables: `customer_glitch_logs`,
`feedback_user_triggers`, `glitch_noise_rules`, `glitch_alerts`.

## 2. Email channel (koi third-party nahi — Server 2 ka apna Postfix)
Alert local SMTP `127.0.0.1:25` se jata hai, is liye na API key, na cost.
From `noreply@anexomail.com`, To founder inbox. Header `Auto-Submitted: auto-generated`
lagta hai, is liye auto-reply loop nahi banta.

## 3. Backend env (Hetzner Server 2)
```
nano /opt/anexomail/.env
```
```
GLITCH_ALERT_TO=hello@anexomail.com     # founder inbox (khali = alert band, sirf DB log)
GLITCH_ALERT_FROM=noreply@anexomail.com
GLITCH_SMTP_HOST=127.0.0.1
GLITCH_SMTP_PORT=25
GLITCH_MIN_SEVERITY=critical            # sirf critical email; error/warning sirf DB
GLITCH_MIN_OCCURRENCES=2                # ek-baar ki hichki par email nahi
LEO_DIAGNOSE=true                       # LEO diagnosis email mein add
LEO_URL=http://127.0.0.1:3100/api/leo
CRON_SECRET=<already set>
```

## 3b. Server par files update (repo git nahi hai /opt/anexomail mein)
```
cd /opt/anexomail-web && git pull
cp /opt/anexomail-web/server/routes/glitch.ts       /opt/anexomail/src/routes/glitch.ts
cp /opt/anexomail-web/server/routes/billing-sync.ts /opt/anexomail/src/routes/billing-sync.ts
cp /opt/anexomail-web/server/index.ts               /opt/anexomail/src/index.ts
pm2 restart anexomail-leo
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
- 12 alert/hour cap → uske baad `muted` (log rehta hai, email chup)
- `console.error` = severity warning → sirf log, email nahi
- `GLITCH_MIN_OCCURRENCES=2` → pehli akeli hichki pending rehti hai, email nahi
- `GLITCH_ALERT_TO` khali = koi email nahi (radar phir bhi log karta hai)
- rage click alert sirf jab **3+ alag session** 15 min mein ek hi button par phansein
