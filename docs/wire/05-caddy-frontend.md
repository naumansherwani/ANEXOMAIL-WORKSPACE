# WIRE 05 — CADDY + FRONTEND (awam + founder host) — sirf copy-paste

## A · frontend build + restart (Bun runtime lock)

```bash
cd /opt/anexomail-web && git pull && bun install && bun run build:bun && pm2 restart anexomail-web --update-env && pm2 save
```

## B · Caddy site blocks (repo se auto-sync + validate + reload)

```bash
cd /opt/anexomail-web && bash server/caddy/deploy-sites.sh
```

## C · gate (har route ka asli HTTP code)

```bash
cd /opt/anexomail-web && bash server/gates/web-gate.sh
```

Gate 3 hosts padhta hai — `anexomail.com` (awam), `founderworkspace.anexomail.com`
(founder), `ai.anexomail.com` — plus yeh bhi ke public host par `/app/founder` band hai.
