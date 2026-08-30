# ANEXOMAIL — FRONTEND ONLY

> **ONLY USE FOR FRONTEND.**
> Yeh repo sirf ANEXOMAIL ka **frontend** (UI + routes + client transport) hai.
> Backend (Bun brain :3100, Rust engine :3200, mail stack, Postfix/Dovecot, Supabase #4)
> **alag** hai aur is repo ka hissa nahi. Yahan koi backend logic add nahi hoti.

---

## Kya is repo mein hai (frontend)

| Folder | Kaam |
| --- | --- |
| `src/routes/**` | Public site + `/app/*` workspace pages (TanStack Start) |
| `src/components/**` | UI components, AppShell, ANEXOChat/VideoCall UI |
| `src/lib/**` | **Transport only** — backend APIs ko call karti hui hooks (`rpcOrRest`) |
| `src/styles.css` | Design tokens / theme |

## Kya is repo mein NAHI hai (backend — alag server par)

- Auth, sessions, permissions
- Mail delivery, Postfix/Dovecot, IMAP/SMTP
- AI (LEO), credits, billing authority, Polar reconciliation
- Supabase #4 schema execution, service-role keys
- Rust engine (`/rpc/*`), WebTransport/QUIC, coturn

Reference copies jo yahan rakhi jaati hain (deploy ke liye copy-paste source, **run nahi hoti**):

- `server/**` → Bun backend files ki repo copy (`/opt/anexomail` par deploy hoti hain)
- `sql/**` → Supabase #4 migrations (dashboard SQL editor mein chalti hain)
- `docs/**` → ops runbooks (Caddy, TURN, storage, Polar)

## Frontend env (sirf ye — koi secret nahi)

```
VITE_API_URL=
VITE_APP_URL=
VITE_BRAND=ANEXOMAIL
VITE_SUPPORT_EMAIL=
VITE_ENV=
```

Service role key, DB URL, OpenRouter key, mail passwords — **frontend mein kabhi nahi**.

## Deploy (frontend)

```sh
cd /opt/anexomail-web && git pull && bun install && bun run build:node && pm2 restart anexomail-web
```

## Local dev

```sh
bun install
bun run dev
```
