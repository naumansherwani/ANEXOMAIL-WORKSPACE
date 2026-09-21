# Server — docs/cursor-work/server/

**Rule (locked):** Jo bhi server par chalna hai — bash command README ya yahan likhni hai.
Alag file nahi. Pull command ek. Sirf yeh:

```bash
cd /opt/anexomail-web && git restore src/routeTree.gen.ts && git pull --rebase origin main && bun install && bun run build:bun && pm2 restart anexomail-web --update-env && pm2 save && curl -s -o /dev/null -w "web /health %{http_code}\n" --max-time 5 http://127.0.0.1:3000/health
```

**Locked:** ALWAYS `git pull --rebase origin main`. NEVER `--no-rebase`. One `&&` block only.

---

## PM2 services (reference)
| Service | Port | Runtime | Status |
|---|---|---|---|
| anexomail-web | 3000 | bun | Frontend SSR |
| anexomail-brain | 3100 | bun | Brain API |
| anexomail-rust | 3200 | rust binary | PRIMARY backend |
| anexochat-fallback | 3300 | bun | ANEXOChat fallback |

---

Frontend pull 21 Sep 2026: **DONE** — `web /health 200`. Proof: `docs/cursor-work/server/pull-20260921-web.md`.

Ab se har server-side script yahan track hoga.

Security blueprint (TODO, no code): `docs/anexomail-security-blueprint.md`
