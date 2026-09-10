# ANEXOMAIL — Implementation Master Plan
# Agent Personal Memory — Read This First Every Session

**Founder:** Muhammad Nauman Sherwani
**Last updated:** Sep 10 2026
**Rule:** Yeh file har session mein read karo. Phases kisi bhi tarteeb mein mat likho —
sirf is file ke mutabiq chalo.

## MAIL SEND + RECEIVE GATE (founder lock 10 Sep 2026)

**Agay nahi** jab tak website se asli mail jaaye aur asli mail inbox mein aaye.

F3 = list dikhana. F4 = send + receive. F5+ wait.

Aasan raasta:
1. User Compose se bhejta hai
2. Server ka Postfix internet par bhejta hai (DKIM pehle se installed)
3. Wapas aane wali mail Postfix → Dovecot pipe → database → Mail list

Proof: `bash server/gates/mail-gate.sh` green + founder live test.

---

## 1. ARCHITECTURE MAP — Rust vs Bun per Phase

```
BROWSER
  │
  ├── REST /api/*  ──────────────────►  Bun :3100 (Express)
  │                                        │
  │                                        │ Supabase admin client
  │                                        ▼
  │                                    PostgreSQL / Supabase
  │
  └── WebTransport /wt/*  ──────────►  Rust :3200
      (realtime channel)                async Tokio
                                        WebTransport / QUIC
                                           │
                                           │ sqlx async
                                           ▼
                                        PostgreSQL NOTIFY / LISTEN
```

| Flow | REST (Bun :3100) | Realtime (Rust :3200) | Rust PRIMARY? |
|---|---|---|---|
| F1 Auth | ✅ login/signup/session/passkey | ❌ | Never — session Bun ka kaam |
| F2 Dashboard | ✅ /api/dashboard/* (summary, activity, analytics, calendar, ai-usage) | ❌ | No |
| F3 Mail Inbox | Bun `/api/mail/*` FALLBACK | `/rpc/mail.*` + `/wt/mail` | **YES — Rust PRIMARY** |
| F4 Compose+Send | ✅ POST /api/mail/send | ✅ delivery status push | **YES** — sent→delivered→read |
| F5 Thread View | ✅ GET /api/mail/thread/:id | ✅ inline reply push | Partial |
| F6 Contacts | ✅ GET /api/contacts | ❌ | No |
| F7 Calendar | ✅ GET /api/calendar/load | ✅ event reminders push | **YES** — 5min reminder push |
| F8 Work Layer | ✅ GET /api/work/* | ❌ | No |
| F9 Founder View | ✅ GET /api/founder/* | ✅ live system health stream | **YES** — live metrics |
| F10 ANEXOChat | ❌ (Rust handles all) | ✅ chat.send, chat.messages | **FULLY RUST** |
| F11 LEO AI | ✅ POST /api/ai/ask | ❌ (async job) | No |

### WebTransport — F3 se shuru kab:
```
1. Browser → WebTransport → wss://anexomail.com/wt/mail
2. Rust :3200 accepts (async Tokio task per connection)
3. Mail arrives → Postfix → deliver-to-supabase.ts → PostgreSQL
4. Rust: LISTEN on pg_notify('new_mail', org_id)
5. Rust → browser via WT stream
6. Browser inbox updates without refresh + animation plays
```

---

## 2. REAL CODE STATE AUDIT

### ANEXOMAIL Frontend (src/routes/)

| File | Kya hai | Real data? | Status |
|---|---|---|---|
| `auth.tsx` | Login/signup/passkey/magic-link | Supabase Auth ✅ | PARTIAL — live unproven |
| `app.index.tsx` | Dashboard command center | /api/dashboard/* | **P2 DONE ✅** |
| `app.mail.$folder.tsx` | Mail folder page (list+detail panels) | useThreads hook | SKELETON — hook exists, data unverified |
| `app.mail.$folder.index.tsx` | "Nothing selected" empty state | — | UI only |
| `app.mail.$folder.$threadId.tsx` | Thread detail + reply | /api/mail/thread/:id | SKELETON |
| `app.mail.outbox.tsx` | Outbox / drafts | — | SKELETON |
| `app.chat.tsx` | ANEXOChat shell | Rust :3200 | SKELETON |
| `app.people.tsx` | Contacts list | /api/contacts | SKELETON |
| `app.calendar.tsx` | Calendar week view | /api/calendar/load | SKELETON |
| `app.work.tsx` | Work / tasks | /api/work/* | SKELETON |
| `app.founder.tsx` | Founder shell (33 pages) | /api/founder/* | SKELETON |
| `app.admin.tsx` | Admin center | /api/admin/* | SKELETON |

### Backend (server/routes/)

| File | Endpoints | Real DB? | Status |
|---|---|---|---|
| `auth.ts` | /api/auth/* | Supabase ✅ | PARTIAL |
| `mail.ts` | /api/mail/threads, /send, /thread/:id, /deliver | Supabase ✅ | PARTIAL — Postfix wire ❌ |
| `contacts.ts` | /api/contacts | Supabase ✅ | PARTIAL |
| `calendar.ts` | /api/calendar/load, /events | Supabase ✅ | PARTIAL |
| `dashboard.ts` | /api/dashboard/* (5 endpoints) | Supabase ✅ | **WIRED** |
| `dashboard.ts` > /api/dashboard/calendar | calendar_events table | ✅ after SQL61 | READY |

### SQL Tables (after Phase 60/61/62)

| Table | Status |
|---|---|
| orgs / organisations | ✅ SQL60 run |
| org_members | ✅ SQL60 run |
| mail_accounts | ✅ SQL60 run |
| mail_threads | Pre-existed |
| mail_messages | Pre-existed |
| calendar_events | ✅ SQL61 run |
| contacts / contact_tags | ✅ SQL62 run |
| activity_log | Pre-existed |
| ai_credits | Pre-existed |

---

## 3. PACKAGE / PLAN FEATURE MATRIX
## SOURCE: src/lib/plans.ts (FOUNDER LOCKED — NEVER TOUCH)

### Workspace Plans — anexomail.com ONLY

| Feature | Basic £23/u/mo | Pro £46/u/mo | Business £97/u/mo | Business Pro £2850/co/mo |
|---|---|---|---|---|
| Mail send/receive | ✅ | ✅ | ✅ | ✅ |
| Contacts + Calendar | ✅ | ✅ | ✅ | ✅ |
| Mailbox storage | 5GB/mailbox | 10GB/mailbox | 25GB/mailbox | 1TB pooled |
| Addresses | 1 company | 3 company | unlimited | unlimited |
| Mailboxes | 3 | 5 | 30 users | Unlimited users |
| Undo send | ✅ 30s | ✅ | ✅ | ✅ |
| Snooze / Schedule send | ❌ | ✅ | ✅ | ✅ |
| Shared inbox | ❌ | ✅ | ✅ | ✅ |
| Thread tasks + analytics | ❌ | ✅ | ✅ | ✅ |
| ANEXOChat | ❌ | ❌ | ✅ (incl.) | ✅ Business Pro |
| Chat file transfer | — | — | 2GB max, 15GB/u/mo | 5GB max, resumable |
| Chat storage | — | — | workspace | 1TB pooled |
| Work layer (tasks etc.) | basic | ✅ | ✅ | ✅ (5000 objects) |
| Device Trust + Vault | ❌ | ❌ | ✅ | ✅ |
| ANEXOVideoCall | ❌ | ❌ | ✅ (group 8) | ✅ (group 40) |
| Audit ledger | ❌ | ❌ | ✅ | ✅ |
| LEO AI | ❌ | ❌ | ❌ | ❌ |
| Support | 72h | 48h | 24h | 12h |
| Annual saving | 1 mo free | 1 mo free | 2 mo free | 2 mo free |

### AI Plans — ai.anexomail.com ONLY

| Feature | AI Pro £400/mo | AI Business £1500/mo | AI Executive £4000/mo |
|---|---|---|---|
| Includes | All Business features | All AI Pro features | Everything in AI Business |
| LEO credits | 1,200/mo | 5,000/mo | 10,000/mo |
| ANEXOChat | ✅ (Phase 1-57) | ✅ (Phase 1-57) | ✅ (Phase 1-57) |
| Platform | Business tier | Business tier | Business Pro tier |
| Group calls | 8 | 40 | 60 |
| Storage | Business limits | Business limits | Business Pro 1TB |
| Top-up recharge | ✅ | ✅ | ✅ |
| Annual saving | 2 mo free | 2 mo free | 2 mo free |

**SEPARATION RULE (locked):**
- `WORKSPACE_PLANS` → `anexomail.com` → Basic/Pro/Business/BusinessPro
- `AI_PRICED_PLANS` → `ai.anexomail.com` → AI Pro/AI Business/AI Executive
- Code: `src/lib/host.ts` + `src/routes/index.tsx` already separates them
- Polar webhook: `server/routes/polar.ts` — FOUNDER FIXED, NO TOUCH EVER
- `src/lib/plans.ts` — NO TOUCH EVER — source of truth for all pricing

---

## 4. OPTIMIZED BUILD ORDER — Flow Groups (Sequential Numbered)

**Principle:** Blueprint phases = catalog. Build order = flow. Connected phases ek sath.

```
────────────────────────────────────────────────────────────────────
FLOW 1 — AUTH + SHELL (Day 1 AM)                          [PARTIAL]
────────────────────────────────────────────────────────────────────
F1.1  Auth real verify — login/signup live test
      Files: src/routes/auth.tsx, server/routes/auth.ts
      Wire: Supabase Auth → session cookie → /app redirect
      SQL: phase59 (account_lifecycle) — already run
      Security emerges: rate limit on /api/auth/login (5 req/min)

F1.2  AppShell host guard verify
      Files: src/components/app/AppShell.tsx, src/lib/host.ts
      Rule: anexomail.com → hide Chat/AI/Founder
             ai.anexomail.com → show AI, hide Founder
             founderworkspace.anexomail.com → show all

────────────────────────────────────────────────────────────────────
FLOW 2 — DASHBOARD (DONE ✅)                              [P2 LIVE]
────────────────────────────────────────────────────────────────────
F2.1  Greeting + situational awareness strip ✅
F2.2  Animated stat tiles + bar chart ✅
F2.3  Real data via /api/dashboard/* ✅

────────────────────────────────────────────────────────────────────
FLOW 3 — MAIL INBOX (Day 1 PM — Day 2 AM)           [READY — live unproven]
────────────────────────────────────────────────────────────────────
F3.1  Thread list — Rust `/rpc/mail.threads` PRIMARY, Bun REST fallback
      Files: src/lib/mail.ts (rpcOrRest), server/rust/main.rs dispatch_mail
      Wire: mail.threads → mail_threads org_scoped
      UI: unread pip, star toggle, snippet, time — Superhuman density

F3.2  Mail rail — Rust `/rpc/mail.counts` + `mail.accounts`
      Files: src/components/app/mail/MailRail.tsx
      UI: sidebar + unread badges; mobile folder chips

F3.3  WebTransport `/wt/mail` — stamp push, invalidate React Query
      Hello: { token, mode: "mail" } · mail_identity (org, not chat_access)
      Unavailable → honest HTTP poll 15s — fake live nahi

────────────────────────────────────────────────────────────────────
FLOW 3 A — FAMILY AWAM TESTERS (before F4)          [READY — live unproven]
────────────────────────────────────────────────────────────────────
FULL LOCK: docs/cursor-work/frontend/f3a-family-awam-testers.md
Passwords repo mein nahi.

Masood  Pro              masoodsherwani@     (Basic shamil)
Humza   Business Pro     humzasherwani@      (Basic+Pro+Business)
Raana   AI Executive     raanasherwani@      (puri site + AI grant)
WebAuthn public-key store LIVE (passkey_set flag = Face ID nahi).
Recovery reset → user ka Gmail/iCloud/Outlook (login mailbox qaid nahi).
Apple-equal passkey; recovery + honest gates + family/awam = ANEXOMAIL advance.
Secure Enclave / iCloud Keychain / Sign in with Apple = claim nahi.

────────────────────────────────────────────────────────────────────
FLOW 3 B — AWAM ONBOARDING POLISH (before F4)       [READY — live unproven]
────────────────────────────────────────────────────────────────────
FULL LOCK: docs/cursor-work/frontend/f3b-awam-onboarding-polish.md
Goal: Lovable mistakes hatao — trust pehli 60s mein.
Packages: Basic · Pro · Business · Business Pro (AI Exec → ai.anexomail.com LEO).
Personal | Business; domain Ownership Center baad; no owner-email print.
Create workspace → /plans pehle. Founder protocol mix nahi.
ai.anexomail.com = LEO only, duplicate org wizard nahi.
operational_membership → live organisations + slug (shared domain nahi).

────────────────────────────────────────────────────────────────────
FLOW 4 — COMPOSE + SEND (Day 2)                     [SKELETON→WIRE]
────────────────────────────────────────────────────────────────────
F4.1  ComposeStudio — rich compose UI
      Files: src/components/app/ComposeStudio.tsx
      Wire: POST /api/mail/send → mail.ts → nodemailer → Postfix :25
      Security emerges: sanitize HTML, attachment size limit

F4.2  Delivery states via Rust push                  [Rust PRIMARY]
      Postfix → deliver hook → mail_messages.delivered = true
      Rust: NOTIFY → push sent→delivered→read to browser
      UI: animated state badges (sending ⟳ → sent ✓ → delivered ✓✓ → read 👁)

F4.3  Scheduled send + Snooze (Pro+)
      Wire: POST /api/mail/send {scheduled_at} → Bun job queue

────────────────────────────────────────────────────────────────────
FLOW 5 — THREAD VIEW + REPLY (Day 2 PM)             [SKELETON→WIRE]
────────────────────────────────────────────────────────────────────
F5.1  Thread detail — message list in thread
      Files: src/routes/app.mail.$folder.$threadId.tsx
      Wire: GET /api/mail/thread/:id → mail_messages → org_scoped
      UI: conversation view, each message expandable, quoted text collapsed

F5.2  Inline reply
      Wire: POST /api/mail/reply → Postfix → delivery hook
      UI: reply box slides up from bottom of thread

F5.3  Thread actions — assign, snooze, star, archive, done
      Wire: PATCH /api/mail/thread/:id/status → mail_threads.status
      UI: right-click menu + keyboard shortcuts (e=archive, #=trash, s=snooze)

────────────────────────────────────────────────────────────────────
FLOW 6 — CONTACTS (Day 3 AM)                        [SKELETON→WIRE]
────────────────────────────────────────────────────────────────────
F6.1  Contact list — real people from contacts table
      Files: src/routes/app.people.tsx, server/routes/contacts.ts
      Wire: GET /api/contacts → contacts table (SQL62 done)
      UI: search, avatar, email, last contacted, tags

F6.2  Contact profile — full view
      Wire: GET /api/contacts/:id → contact + mail history
      UI: profile card + thread history

────────────────────────────────────────────────────────────────────
FLOW 7 — CALENDAR (Day 3 PM)                        [SKELETON→WIRE]
────────────────────────────────────────────────────────────────────
F7.1  Week view — real events
      Files: src/routes/app.calendar.tsx, server/routes/calendar.ts
      Wire: GET /api/calendar/load → calendar_events (SQL61 done)
      UI: week grid, event blocks, today highlighted

F7.2  Event CRUD — create, edit, delete
      Wire: POST/PATCH/DELETE /api/calendar/events

F7.3  Reminders via Rust push                        [Rust PRIMARY]
      Rust: 5min before event → push to browser
      UI: toast notification slides in

────────────────────────────────────────────────────────────────────
FLOW 8 — WORK LAYER (Day 4 AM)                      [SKELETON→WIRE]
────────────────────────────────────────────────────────────────────
F8.1  Task list — real tasks
      Wire: GET /api/work/tasks → work_tasks (SQL61 done)
      UI: kanban or list, owner, due date, status

F8.2  Mail → Task (right-click → create task)
      Wire: POST /api/work/tasks {source: thread_id}
      UI: context menu on thread → "Create task"

────────────────────────────────────────────────────────────────────
FLOW 9 — FOUNDER WORKSPACE (Day 4 PM)               [SKELETON→WIRE]
────────────────────────────────────────────────────────────────────
F9.1  Founder view — live metrics            [Rust PRIMARY for live]
      Files: src/routes/app.founder_.analytics.tsx
      Wire: GET /api/founder/overview → org stats, user count, mail volume
      Rust: live system health stream via /wt/founder

F9.2  Revenue dashboard
      Files: src/routes/app.founder_.revenue.tsx
      Wire: GET /api/founder/revenue → Polar webhook data

F9.3  Admin center — members, domains, audit
      Files: src/routes/app.admin.tsx
      Wire: GET/POST /api/admin/* → org_members, audit_log

────────────────────────────────────────────────────────────────────
FLOW 10 — SECURITY (Emerges with each flow)
────────────────────────────────────────────────────────────────────
S1  Rate limiting — on auth, mail send, compose (emerges with F1+F4)
S2  RLS — already in Supabase, verify with each flow
S3  Device trust — login fingerprint, session list (emerges with F1.2)
S4  Caddy headers — HSTS, CSP, X-Frame (server config, S3 phase)
S5  Postfix — SPF/DKIM/DMARC proof (server deploy, emerges with F4)
S6  Audit log — every admin action logged (emerges with F9.3)

────────────────────────────────────────────────────────────────────
FLOW 11 — ANEXOCHAT (Parallel — Day 1-5)           [FULLY RUST]
────────────────────────────────────────────────────────────────────
C1  Message engine — Rust WebTransport, PostgreSQL, send/receive A→B
    Wire: browser → /wt/chat → Rust → chat_messages → NOTIFY → recipient
    Tables: chat_conversations, chat_messages, chat_participants

C2  Message states — sending/sent/delivered/read
    Rust: per-message state machine, push to all participants

C3  Typing + presence
    Rust: ephemeral state (not DB), broadcast to conversation

C4  Group chat — create, add members, group messages
    Tables: chat_groups, chat_group_members

C5  File transfer — Rust chunked upload, 5GB, resumable
    Wire: browser → /wt/upload → Rust transfer engine → storage

C6  Business superpowers — Task/Promise/Decision from chat
    Wire: POST /api/chat/task, /promise, /decision → work_tasks table

C7  Search + export — permanent business search
    Wire: GET /api/chat/search?q= → PostgreSQL full-text

C8  Cinematic UI — weather atmosphere, send sweep animation
    Frontend: Framer Motion + Three.js atmosphere
    Note: Open-Meteo only for weather (founder decision Sep 7 2026)

────────────────────────────────────────────────────────────────────
FLOW 12 — LEO AI (Week 2 / AI plans only)
────────────────────────────────────────────────────────────────────
AI1  Smart reply — 3 suggestions on thread (AI plans only)
AI2  Thread summary — LEO summarizes long threads
AI3  Compose assist — tone, grammar, rewrite
AI4  ANEXOChat Phase 57 — Leo in chat (AI plan gate)

```

---

## 5. 1-WEEK SPRINT PLAN

```
Day 1  (Sep 10)  F1 Auth verify + F2 Dashboard confirm + C1 Chat engine start
Day 2  (Sep 11)  F3 Mail inbox wire + F4 Compose+Send + C2 Message states
Day 3  (Sep 12)  F5 Thread view + F6 Contacts + C3 Typing+Presence+Groups
Day 4  (Sep 13)  F7 Calendar + F8 Work layer + C4 File engine
Day 5  (Sep 14)  F9 Founder workspace + Security S1-S4 + C5 Business superpowers
Day 6  (Sep 15)  Mail gate live test + ANEXOChat A→B prove + End-to-end
Day 7  (Sep 16)  Launch: anexomail.com + founderworkspace + ANEXOChat Business tier
```

**Parallel rule:** ANEXOMAIL + ANEXOChat parallel — backend same PostgreSQL, RLS separates.

---

## 6. PER-SURFACE HOST RULES (locked)

| Surface | Host | Features visible | Hidden |
|---|---|---|---|
| Awam | `anexomail.com` | Mail, Contacts, Calendar, Work, ⌘K | Chat, AI, Speed, Admin, Founder |
| AI workspace | `ai.anexomail.com` | All above + LEO AI chat + AI Studio | Founder |
| Founder | `founderworkspace.anexomail.com` | Everything | Nothing |

Code: `src/lib/host.ts` → `isPublicMailHost()`, `founderSurfaceAllowed()`
Shell: `src/components/app/AppShell.tsx` L113 `hideOnAwam` array

---

## 7. TECHNOLOGY STACK PER FEATURE

| Feature | Frontend | Backend | Realtime | DB |
|---|---|---|---|---|
| Auth | React + Supabase.js | Bun Express | — | Supabase Auth |
| Mail inbox | ThreadList + Framer Motion | Bun /api/mail/threads | Rust WT push | mail_threads |
| Mail send | ComposeStudio | Bun /api/mail/send → nodemailer | Rust delivery states | mail_messages |
| Calendar | Week grid component | Bun /api/calendar | Rust reminder push | calendar_events |
| Contacts | People list | Bun /api/contacts | — | contacts |
| ANEXOChat | Chat UI + Three.js | **Rust only** | Rust WT full-duplex | chat_messages |
| Founder metrics | Dashboard React | Bun /api/founder | Rust live stream | org_members + logs |
| LEO AI | AI panel | Bun /api/ai (calls local/self-hosted model) | — | ai_credits |

---

## 8. KEY FILES MAP (Agent memory — these are the authoritative files)

### Frontend
```
src/routes/auth.tsx                      ← auth page (P1 ✅)
src/routes/app.index.tsx                 ← dashboard (P2 ✅)
src/routes/app.mail.$folder.tsx          ← mail list (F3 next)
src/routes/app.mail.$folder.$threadId.tsx ← thread (F5)
src/routes/app.people.tsx                ← contacts (F6)
src/routes/app.calendar.tsx              ← calendar (F7)
src/routes/app.work.tsx                  ← work (F8)
src/routes/app.founder.tsx               ← founder (F9)
src/routes/app.chat.tsx                  ← ANEXOChat shell (C1)
src/components/app/AppShell.tsx          ← shell + rail (locked)
src/lib/host.ts                          ← host detection (locked)
src/lib/ia.ts                            ← information architecture (locked)
src/lib/mail.ts                          ← mail hooks (fix, not rewrite)
src/lib/dashboard.ts                     ← dashboard hooks (P2 ✅)
src/styles.css                           ← Tailwind v4 (locked — no new packages)
```

### Backend
```
server/routes/auth.ts                    ← session management
server/routes/mail.ts                    ← mail core (fix Postfix wire)
server/routes/contacts.ts               ← contacts
server/routes/calendar.ts               ← calendar
server/routes/dashboard.ts              ← dashboard (P2 wired ✅)
server/routes/founder.ts                ← founder endpoints (wire)
server/lib/supa.ts                       ← Supabase admin client (locked)
```

### Rust (server/rust/ or separate repo)
```
/wt/mail      ← WT endpoint — new mail push
/wt/chat      ← WT endpoint — ANEXOChat full-duplex
/wt/upload    ← WT endpoint — file transfer
/wt/founder   ← WT endpoint — live metrics
```

### SQL (run in Supabase editor — tarteeb se)
```
sql/phase60_org_identity_repair.sql      ✅ DONE
sql/phase61_calendar_work.sql            ✅ DONE
sql/phase62_contacts_intelligence.sql   ✅ DONE
[Future SQL files → docs/cursor-work/sql/]
```

---

## 9. PULL COMMAND (server pe har session ke baad)

```bash
cd /opt/anexomail-web && git pull && bun install && bun run build:bun && pm2 restart anexomail-web && pm2 save
```

---

## 10. STATUS BOARD (update har session)

| Flow | Status | Last session |
|---|---|---|
| F1 Auth | PARTIAL — live unverified | Sep 9 |
| F2 Dashboard | **DONE ✅** | Sep 9 P2 |
| F3 Mail inbox | READY — live unproven | Sep 10 F3 |
| F3 A Family awam testers | READY — live unproven | Sep 10 F3 A |
| F3 B Awam onboarding polish | READY — live unproven | Sep 10 F3 B |
| F4 Compose+Send | TODO | after F3 B live proof |
| F5 Thread view | TODO | — |
| F6 Contacts | TODO | — |
| F7 Calendar | TODO | — |
| F8 Work layer | TODO | — |
| F9 Founder view | TODO | — |
| C1 Chat engine | TODO | — |
| C2 Message states | TODO | — |
| C3 Groups+Presence | TODO | — |
| C4 File engine | TODO | — |
| C5 Biz superpowers | TODO | — |
| S1-S6 Security | PARTIAL (RLS exists) | Sep 9 |
| AI1-AI4 LEO | TODO | — |

---

## 11. RULES (these never change)

1. Existing code fix karo — delete/rewrite sirf agar truly broken
2. Mock nahi — honest empty state sirf
3. Rust :3200 PRIMARY — sirf Bun fallback jab WT unavailable
4. Packages no touch — `package.json` / `vite.config.ts` / `bunfig.toml`
5. Polar payment no touch
6. Prices no touch
7. Landing pages no touch
8. `.env` / secrets no touch
9. ANEXOChat Phase 32+ sirf founder paste karne pe
10. Status: DONE / READY / TODO — baaki kuch nahi
11. Pull command har session ke baad founder ko dena hai
12. Blueprint files NEVER delete (Rule 12 in AGENTS.md)
