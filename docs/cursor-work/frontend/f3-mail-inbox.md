# F3 — Mail Inbox (Rust PRIMARY)

**Date:** Sep 10 2026  
**Status:** **READY** (repo). **DONE** nahi — live test + `bash server/rust/deploy.sh` baqi.

## Technology (constitution)

| Path | Role |
|---|---|
| Rust `:3200` `/rpc/mail.threads` · `mail.counts` · `mail.accounts` · `mail.labels` · `mail.star` | PRIMARY |
| Rust UDP 3443 `/wt/mail` hello `{ token, mode: "mail" }` | PRIMARY live stamp |
| Bun `:3100` `/api/mail/*` | FALLBACK only (Rust 404/502/503) |

Mail identity = `org_members` (Basic/Pro inbox chalti hai). `chat_access` nahi.

Frontend: `rpcOrRest` — pehle Rust, phir Bun. `rpc.ts` same-origin BASE empty-string fix.

## Hosts (parallel, same wire)

| Host | Mail |
|---|---|
| `anexomail.com` | Awam inbox |
| `ai.anexomail.com` | Coming Soon — SiteLock `/` only |
| `founderworkspace.anexomail.com` | Same inbox + founder rail |

Landing / Polar / packages / `host.ts` / `AppShell` — no touch this pass.

## Founder test

```bash
cd /opt/anexomail-web && git pull && bun install && bun run build:bun && pm2 restart anexomail-web && pm2 save
bash server/rust/deploy.sh
```

Login → Mail. List Rust se (header chip: `Rust WT live` ya `Rust RPC · poll`). Inbox zero = real empty. Phir next (F4) founder ke test ke baad.
