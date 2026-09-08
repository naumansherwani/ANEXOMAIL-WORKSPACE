# WIRE 18 — CRM DO HOST (aicrm + AI-free crm) — sirf copy-paste

Founder: Muhammad Nauman Sherwani

Do host, ek hi pipeline:

- `aicrm.anexomail.com` → `/app/crm` — **AI CRM** (Leo insight panels ON)
- `crm.anexomail.com` → `/app/crm` — **AI-free CRM** (same leads/pipeline, AI panels OFF)

Dono ab repo-managed hain (`server/caddy/aicrm.Caddyfile`, `server/caddy/crm.Caddyfile`),
is liye deploy script khud wire karti hai — koi nano nahi.

## A · DNS (sirf yeh manual hai)

Registrar/Hetzner panel mein do A record, wahi IP jo `anexomail.com` ka hai:

| Type | Host | Value | TTL |
|---|---|---|---|
| A | `aicrm` | server ka public IP | Automatic |
| A | `crm` | server ka public IP | Automatic |

## B · deploy (Caddy blocks + cert + reload)

```bash
cd /opt/anexomail-web && git pull && bash server/caddy/deploy-sites.sh
```

## C · gate (asli HTTP code + h3 + founder-leak check)

```bash
cd /opt/anexomail-web && bash server/gates/web-gate.sh
```

Gate in dono host ka `/`, `/app/crm`, `/app/crm/leads`, `/app/crm/pipeline`,
`/app/crm/activity` padhta hai, HTTP/3 (`alt-svc: h3`) confirm karta hai, aur yeh
bhi ke `/app/founder` in host par band hai (404/403/302). Poora output mujhe do.
