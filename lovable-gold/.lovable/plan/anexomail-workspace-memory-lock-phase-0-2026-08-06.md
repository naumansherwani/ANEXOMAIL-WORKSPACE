# ANEXOMAIL Workspace — Memory Lock (Phase 0)

Nauman, poori report line-by-line padh li. Neeche wahi baseline hai jo memory book mein lock hoga. Approve karo, phir memory files likh dunga aur blueprint ka intezar karunga.

## Identity
- Product: **ANEXOMAIL** — product name **ANEXOMAIL Workspace**. Mission: Google Workspace / Zoho Mail ka ultimate replacement, AI-native email workspace. Cinematic, disruptive mindset.
- Parent: NEXATECT Global Ltd. Founder: Muhammad Nauman Sherwani. Site: https://anexomail.com
- Baseline doc: "Founder Lock v1.0". Ye baseline hai — koi duplicate implementation nahi.

## Stack lock
- Bun · Rust · tRPC · WebTransport · Caddy HTTP/3 · Supabase · Express (current Leo runtime) · TypeScript · PM2 (auto restart + auto boot).
- Hosting: Hetzner. Server 1 = NEXATECT platform. Server 2 = ANEXOMAIL dedicated (mail + AI, `root@62.238.98.98`, `/opt/anexomail`). Server 3 = reserved for AXONETIS.
- Supabase #4 = ANEXOMAIL, single source of truth. pgvector active. Keys/DB password server par hi rehte hain — kabhi frontend mein nahi.
- Payments: Polar integration pending (only remaining piece for billing).

## NO DUPLICATE (hard rule)
Do NOT build: local auth, local credit system, local AI logic, frontend SMTP/IMAP, duplicate mail DB, duplicate Supabase schema, duplicate email parser, mock production APIs, duplicate routing/permissions/session/workspace state. Do NOT invent or rename endpoints. Missing endpoint = TODO + wait for backend. Retired hostflowai.net routing kabhi recreate nahi.

## Already done on server (never rebuild)
DNS, TLS 1.3 + Let's Encrypt + on-demand TLS, Caddy reverse proxy (validated & formatted, HTTP→HTTPS auto redirect), Postfix, Dovecot, OpenDKIM, OpenDMARC, SPF/DKIM/DMARC, Maildir at `/var/mail/vhosts` with `vmail`, SMTP AUTH via Dovecot socket, PM2 (`anexomail-leo`, port 3100, `pm2 save` + `pm2 startup` done), Leo AI with OpenRouter streaming + fallback (deepseek-v4-flash → gemini-2.5-flash → llama-3.3-70b), RAG memory (`src/lib/rag-memory.ts` wired into Leo, ragContext in system prompt), ecosystem awareness (Leo under Jimmy John, SB1–SB4 map), Supabase #4 connected — `/api/leo/supabase-health` → `{ok:true,connected:true,rows:0}`.

## Caddy route map (locked)
`anexomail.com, www` → 3100 · `app` → 3000 · `ai` → 3100 · `aicrm` → 3002 · `runtime` → 3003 · `auth` → 54321 · `storage` → 9000 · `cdn` → static `/opt/anexomail/storage/cdn` · `docs` → 3004 · `status` → 3005 · `preview` → 3006 · `sandbox` → 3007 · `settings` → 3008 · `admin` → 3009 · `mail` → gateway 200.

## Existing APIs (only these are real today)
`POST /api/leo/chat` · `POST /api/leo/orchestrate` · `GET /health` · `GET /api/leo/health` · `GET /api/leo/supabase-health`.
Planned/pending (backend first, frontend TODO until live): `/api/auth/login`, `/api/mail/send`, `/api/mail/inbox`, `/api/mail/thread/:id`.
API contract format har endpoint ke liye: Method · Endpoint · Request · Response · Auth · Credits · Status.

## DB + credits
Tables: mail_domains, mail_users, mail_aliases, mailboxes, mail_sessions, mail_events. Koi production mail account nahi banaya abhi.
Credits: Free 10 · AI 500 · AI Pro 1500 · Business 6000 · Enterprise 10000 — backend calculates, frontend sirf dikhata hai.

## Frontend scope (my job)
Modules: AI Mail (Inbox, Sent, Drafts, Spam, Trash, Archive), Contacts, Calendar, Workspace, Tasks, AI CRM, AI Search, AI Composer, Templates, Analytics, Settings, Admin.
Design: Inter (700 headings / 400–500 body), 12–16px radius, 8px spacing, Lucide, Recharts, Framer Motion 150–250ms. Dark: bg #0B1220, surface #111827/#1F2937, border #374151, text #F9FAFB/#9CA3AF. Light: #FFFFFF/#F8FAFC/#E5E7EB/#111827/#6B7280. Primary #2563EB, Indigo #4F46E5, Cyan #06B6D4, Success #10B981, Warning #F59E0B, Danger #EF4444. AI actions = indigo gradient.
UI: three-panel mail (nav / list / reading+Leo), Cmd+K palette, AI always visible, desktop-first + full mobile, SPA nav, optimistic UI, realtime inbox/notifications/AI, loading+empty+error states everywhere, WCAG focus/contrast.
Env (public only): VITE_API_URL, VITE_APP_URL, VITE_BRAND=ANEXOMAIL, VITE_SUPPORT_EMAIL, VITE_ENV. Never: service role, OpenRouter key, DB URL, SMTP/mail passwords.
Components reusable, no duplicates: Button, Input, Modal, Dialog, Avatar, Sidebar, Data Table, Email List, Email Thread, AI Card, Credit Badge, Workspace Card, Task Card, Notification, Calendar Widget, Analytics Card.

## Working method (every phase, 30 phases)
1. Scope 2. Frontend built here 3. Backend files/code for repo 4. one copy-paste **SQL block** for Supabase 5. one copy-paste **server command block** for Hetzner 6. verify logs green (`pm2 logs`, curl health) 7. `git pull` + `pm2 restart` 8. memory book updated with phase status.
Main kuch execute nahi karunga — SQL aur shell sirf copy-paste ke liye dunga. Power aapke paas.

## Memory book files (created on approval)
```text
mem://index.md                      core rules, always applied
mem://~user                         Nauman ka style: Hinglish, copy-paste SQL + commands, no duplicates
mem://project/identity              ANEXOMAIL Workspace, NEXATECT, mission
mem://project/infrastructure        servers, domains, Caddy port map, PM2, mail stack
mem://project/api-contract          live endpoints + pending TODO endpoints + contract format
mem://project/no-duplicate          the full Do-NOT-build list
mem://project/design-system         colors, type, spacing, UI/UX rules
mem://project/database              Supabase #4 schema, pgvector, credits tiers
mem://project/phases                30-phase roadmap + per-phase status
```

## Next step
Approve → memory book lock. Uske baad aap blueprint bhejo, main 30 phases ki final list banaunga aur Phase 1 (frontend shell + design tokens + Leo chat on real `/api/leo/chat`) shuru karunga.
