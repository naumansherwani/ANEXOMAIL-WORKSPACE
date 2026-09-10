# F3 — Mail Inbox wire

**Date:** Sep 10 2026  
**Status:** **READY** (repo). **DONE** nahi — live inbox + mail-gate unproven.

## Original blueprint → F3 (Claude grouping — confirm)

| Blueprint | F3 slice |
|---|---|
| Phase 2 IA (`ia.ts` folders) | Rail + mobile folder chips |
| Phase 4 honest states | Empty / 409 org / 401 session / API error — no fake threads |
| Phase 7 mail core | `GET /api/mail/threads` + counts + star |

Public pages (blueprint Phase 3), Polar, landing, packages — **no touch**.

## Hosts (parallel, same codebase)

| Host | Mail inbox |
|---|---|
| `anexomail.com` | Awam — Mail rail item already visible; this wire is that inbox |
| `ai.anexomail.com` | Awam still **Coming Soon** (`SiteLock` + `aiPublicPathAllowed` `/` only) — not opened |
| `founderworkspace.anexomail.com` | Same `/app/mail/*` + founder protocol rail |

`host.ts` / `SiteLock` / `AppShell` hideOnAwam — **not edited** this session.

## What changed

- `server/routes/mail.ts` — drop broken `mail_accounts` embed; counts; accounts unread; star; missing-table = empty not 500
- `src/lib/mail.ts` — `useFolderCounts`; star action; 20s poll (honest HTTP fallback; `/wt/mail` TODO)
- `ThreadList.tsx` — unread pip, star toggle, Framer stagger
- `MailRail.tsx` — folder unread badges
- `app.mail.$folder.tsx` — mobile folder chips
- `app.mail.$folder.index.tsx` — honest empty reading pane

## Not in F3 (next flows)

- Compose/send live (F4) · thread body (F5) · Rust `/wt/mail` (F3.3) · LEO pane (AI plans)

## Pull

```bash
cd /opt/anexomail-web && git pull && bun install && bun run build:bun && pm2 restart anexomail-web && pm2 save
```
