# 21 — FOUNDER SHORT PATHS (status: READY)

Founder ka faisla (8 Sep 2026): lambe subdomain nahi — sab kuch
`founderworkspace.anexomail.com/` ke chhote paths par.

| Chhota pata | Asli surface |
| --- | --- |
| `/anexochat` | `/app/chat` (founder host par; awam host par public page waisa hi) |
| `/anexovideocall` | `/app/chat` (call surface) |
| `/chat` | `/app/chat` |
| `/mail` | `/app/mail` |
| `/calendar` | `/app/calendar` |
| `/crm` | `/app/crm` |
| `/people` | `/app/people` |
| `/work` | `/app/work` |
| `/storage` | `/app/storage` |
| `/search` | `/app/search` |
| `/analytics` | `/app/analytics` |
| `/settings` | `/app/settings` |
| `/billing` | `/app/billing` |
| `/devices` | `/app/devices` |

Koi naya host nahi bana, koi DNS kaam nahi. Founder deck `/app/founder` par hi hai.

## Steps

```bash
cd /opt/anexomail-web && git pull && bun install && bun run build:bun && pm2 restart anexomail-web --update-env && pm2 save
```

## Verify

```bash
for p in anexochat anexovideocall chat mail calendar crm people work storage search analytics settings billing devices; do
  echo "$p -> $(curl -s -o /dev/null -w '%{http_code}' https://founderworkspace.anexomail.com/$p)"
done
```

307/200 = pass. Status **DONE** sirf tab jab yeh output green ho.

## Founder deck ke chhote paste (READY)

`/founder` aur `/founder/<kuch bhi>` ab seedha `/app/founder/<wahi>` kholta hai —
misal: `/founder/crm` · `/founder/revenue` · `/founder/launch/qa`. Bina login yeh
sign-in screen dikhata hai (khali page nahi).

## Ek command auto-sync (READY)

```bash
cd /opt/anexomail-web && git pull && bash server/deploy-all.sh
```

Yeh script khud: SQL heal (`phase57`) + final mailbox list (`phase56`) → frontend
build + pm2 → Rust :3200 → payments :3400 → Caddy → services → mail + TURN →
saare gates. Pehli RED cheez par ruk jati hai.
