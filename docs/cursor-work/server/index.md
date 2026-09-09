# Server — docs/cursor-work/server/

**Rule (locked):** Jo bhi server par chalna hai — bash command README ya yahan likhni hai.
Alag file nahi. Pull command ek. Sirf yeh:

```bash
cd /opt/anexomail-web && git pull && bun install && bun run build:bun && pm2 restart anexomail-web && pm2 save
```

---

## PM2 services (reference)
| Service | Port | Runtime | Status |
|---|---|---|---|
| anexomail-web | 3000 | bun | Frontend SSR |
| anexomail-brain | 3100 | bun | Brain API |
| anexomail-rust | 3200 | rust binary | PRIMARY backend |
| anexochat-fallback | 3300 | bun | ANEXOChat fallback |

---

Ab se har server-side script yahan track hoga.

Security blueprint (TODO, no code): `docs/anexomail-security-blueprint.md`
