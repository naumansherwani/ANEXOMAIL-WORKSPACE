> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

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
