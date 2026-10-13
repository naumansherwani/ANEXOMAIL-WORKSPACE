# ANEXOMAIL — Master Build Plan
# Locked: Sep 9 2026 | Founder: Muhammad Nauman Sherwani

> Yeh document code shuru hone se pehle lock hai.
> Har phase founder approve kare → tab code. Polar → no touch. Prices → no touch. Landing → no touch.

---

## THREE SURFACES — PARALLEL BUILD

Ek hi codebase. `src/lib/host.ts` decide karta hai kaunsa surface dikhao.

```
github.com/naumansherwani/ANEXOMAIL-WORKSPACE
              │
    ┌─────────┼──────────────┐
    ▼         ▼              ▼
anexomail.com  ai.anexomail.com  founderworkspace.anexomail.com
  AWAM MAIL    LEO AI WORKSPACE   FOUNDER PROTOCOL
```

| Surface | Kaun | Kya milta hai |
|---|---|---|
| `anexomail.com` | Registered users | Mail + Chat + People + Calendar + Work |
| `ai.anexomail.com` | AI plan users | Sab + LEO AI always-on |
| `founderworkspace.anexomail.com` | Sirf Nauman | God-view + all surfaces + founder protocol |

**Parallel kya matlab hai:** Har phase mein teenon surfaces ka kaam ek saath push hoga.
Jab P1 (Auth) banega — teeno pe theek hoga. Alag alag deploy nahi.

---

## WIRE MODEL (locked — har phase ke baad)

```
1. Code likha (frontend + backend wire)
2. GitHub push
3. Aap ek command:
   cd /opt/anexomail-web && git pull && bun install && bun run build:bun && pm2 restart anexomail-web && pm2 save
4. Browser test — real data, no errors
5. DONE confirm → next phase
```

**Backend stack (locked):**
- Rust :3200 → PRIMARY — har request pehle yahan
- Bun :3100 → FALLBACK — Rust 502/timeout pe auto-switch
- Async Tokio + WebTransport → real-time mail/chat
- Supabase/PostgreSQL → data truth
- Postfix/Dovecot → real mail send/receive

---

## PRE-BUILD BLOCKER (SQL — aap ka kaam)

Yeh karo pehle — warna P1 bhi nahi chalega:

```
Supabase #4 SQL Editor mein (tarteeb se):
1. sql/phase60_org_identity_repair.sql  → "No organisation yet" fix
2. sql/phase61_calendar_work.sql        → Calendar/Work tables
3. sql/phase62_contacts_intelligence.sql → Contacts tables

Phir server:
cd /opt/anexomail-web && git pull && bun install && bun run build:bun && pm2 restart anexomail-web && pm2 save
```

---

## BUILD PHASES — TARTEEB

### P1 — AUTH (sab se pehle, teenon surface)

**Existing:** `src/routes/auth.tsx`, `server/routes/auth.ts`, `src/routes/claim.tsx`, `src/routes/onboarding.tsx`
**Already pushed:** Eye icon fix, API error messages

**Kya banega (polish):**
- [ ] Login form — cinematic entry animation (Framer Motion)
- [ ] Error states — inline, clear, no generic message
- [ ] Password strength indicator (signup pe)
- [ ] "Forgot password" flow — real email
- [ ] Email confirmation state — clear UI
- [ ] Session persist — refresh pe logout nahi

**Wire:** `auth.tsx` → `POST /api/auth/login` → Supabase Auth → session → `/app`

**DONE criteria:** Real email/password login, session stays on refresh, `/auth` → `/app` no error

---

### P2 — DASHBOARD (awam + founder god-view)

**Existing:** `src/routes/app.index.tsx`, `server/routes/dashboard.ts`, `src/components/app/dashboard/Panels.tsx`

**Kya banega:**
- [ ] Real mail counters (unread, starred, today)
- [ ] Activity feed — last 10 actions
- [ ] Quick Actions bar — Compose, Search, Invite teammate, Domain
- [ ] Upcoming panel — today's calendar events
- [ ] AI usage panel (AI plan users pe)
- [ ] Founder version: GOD-VIEW — all workspace stats

**Wire:** `/app` → `GET /api/dashboard/summary` → Rust :3200 → real data

**DONE criteria:** Numbers change when mail arrives. No `no_workspace` error.

---

### P3 — MAIL INBOX (core product)

**Existing:** `src/routes/app.mail.$folder.tsx`, `server/routes/mail.ts`, `src/components/app/mail/ThreadList.tsx`

**Kya banega (three-panel):**
```
┌──────────┬───────────────────┬────────────────────────┐
│  Rail    │  Thread List      │  Reading Pane + LEO    │
│          │                   │                        │
│  Inbox   │  ★ ABC Contract  │  From: john@abc.com    │
│  Starred │  John — 14:32    │  Subject: Contract...  │
│  Sent    │  ──────────────  │                        │
│  Drafts  │  Newsletter      │  [Thread body]         │
│  Archive │  Postmark        │                        │
│  Trash   │  ──────────────  │  ────────────────────  │
│          │  Invoice rec'd   │  LEO: "This contract   │
│          │  Billing         │  needs signature by    │
│          │                  │  Friday."              │
└──────────┴───────────────────┴────────────────────────┘
```

**Advanced features (world-class):**
- [ ] **Email snooze** — Inbox se hatao, custom waqt pe wapas
- [ ] **Scheduled send** — Send tomorrow 9am, timezone-aware
- [ ] **Undo send** — 10 second window after send
- [ ] **Read receipts** — Kab khola, kahan se (Superhuman-level)
- [ ] **Thread intelligence** — Auto-label: Receipt / Newsletter / Important / Work
- [ ] **Split inbox** — Priority vs Everything else
- [ ] **Focus mode** — Ek thread, baqi sab fade out
- [ ] **Keyboard-first** — Every action bina mouse ke

**Wire:** `app.mail.*` → `GET /api/mail/threads` → Rust :3200 → `mail_threads` table

**DONE criteria:** Real inbox loads, mark read updates DB, send goes via Postfix

---

### P4 — COMPOSE + SEND

**Existing:** `src/components/app/compose/ComposeStudio.tsx`, `server/routes/mail-compose.ts`, `server/mail/sendmail.ts`

**Kya banega:**
- [ ] Rich text editor (bold, italic, lists, links)
- [ ] Attachment drag-drop
- [ ] Inline image paste
- [ ] CC/BCC toggle
- [ ] Scheduled send UI
- [ ] Undo send countdown (10s toast)
- [ ] Cinematic send animation (blueprint ka sweep effect)
- [ ] Draft auto-save every 30s
- [ ] **LEO integration** — "Fix grammar", "Make professional", "Translate"

**Wire:** `ComposeStudio.tsx` → `POST /api/mail/send` → `sendmail.ts` → Postfix SMTP → real delivery

**DONE criteria:** Email bheja → recipient ke inbox mein aaya (real)

---

### P5 — MAIL THREAD VIEW

**Existing:** `src/routes/app.mail.$folder.$threadId.tsx`, `src/components/app/mail/InlineReply.tsx`

**Kya banega:**
- [ ] Conversation view (all replies grouped)
- [ ] Inline reply (no new window)
- [ ] Quote original (toggle)
- [ ] "Discuss in ANEXOChat" button (Phase 29 bridge)
- [ ] Attachment preview inline (PDF/image)
- [ ] Thread actions: star, archive, snooze, delete, print
- [ ] Email → Task (right-click or action button)
- [ ] Link preview cards (auto-rich-preview for URLs)

---

### P6 — CONTACTS / PEOPLE

**Existing:** `src/routes/app.people.tsx`, `server/routes/contacts.ts`, `src/components/app/people/ContactProfile.tsx`

**Kya banega:**
- [ ] Contact list with search
- [ ] Contact profile — email history, stats, last contact
- [ ] Company profile — all contacts from that domain
- [ ] Contact timeline — every interaction
- [ ] Import from vCard/CSV
- [ ] **Relationship intelligence** — "You haven't talked to John in 30 days"

**Wire:** `app.people.tsx` → `GET /api/contacts` → Rust :3200 → `contacts` table

---

### P7 — CALENDAR

**Existing:** `src/routes/app.calendar.tsx`, `server/routes/calendar.ts`, `src/components/app/calendar/WeekGrid.tsx`

**Kya banega:**
- [ ] Week view (primary)
- [ ] Month view (toggle)
- [ ] Create/edit/delete event
- [ ] Attendees + RSVP
- [ ] Timezone support
- [ ] Email → Calendar (detect meeting requests)
- [ ] "Focus windows" — block time for deep work
- [ ] Availability sharing link

**Wire:** `app.calendar.tsx` → `GET /api/calendar/load` → Rust :3200 → `calendar_events` table

---

### P8 — FOUNDER WORKSPACE (founderworkspace.anexomail.com)

**Existing:** 20+ founder routes (`app.founder_.*`)

**TERMINOLOGY LOCKED:** "Founder View" — NOT "God View". Founder sees what is authorized by the system.

**Kya banega (Founder Protocol — real-time, no fake numbers):**

```
┌─────────────────────────────────────────────────────┐
│  FOUNDER VIEW                                       │
│                                                     │
│  LIVE SYSTEM                     TODAY              │
│  ● Rust :3200     HEALTHY        Mail: 247 sent     │
│  ● Bun :3100      HEALTHY        Users: 83 online   │
│  ● Postfix        HEALTHY        Revenue: £2,840    │
│  ● Caddy          HEALTHY        Errors: 0          │
│                                                     │
│  ALL WORKSPACES                                     │
│  ABC Ltd          83 users   684GB   ● Active       │
│  XYZ Corp         12 users   42GB    ● Active       │
│                                                     │
│  SAFETY QUEUE    REVENUE PIPELINE    AI USAGE       │
│  0 reports       £8,400 MRR          12,450 credits │
└─────────────────────────────────────────────────────┘
```

**Features (founder only — is_founder server-side check, not client):**
- [ ] Live system health (Rust :3200, Bun :3100, Postfix, Caddy — real ports)
- [ ] All workspaces founder-view (real data, real counts)
- [ ] Revenue dashboard (MRR, ARR, churn — Polar webhook data)
- [ ] Safety queue — reports review (privacy-preserving)
- [ ] AI usage across all users (credit consumption)
- [ ] Launch checklist (existing route — wire to real checks)
- [ ] SiteLock control — lock/unlock any surface
- [ ] Move-in manager — new company onboarding
- [ ] Founder single inbox (all company mail via phase55)

**Wire:** `app.founder.tsx` → `GET /api/founder/*` → Rust :3200 → full DB (founder-only RLS)
**Realtime:** WebTransport `/wt/founder` → Rust async Tokio → live system metrics stream

---

### P9 — AI SURFACE (ai.anexomail.com)

**Existing:** `src/routes/ai_.studio.tsx`, `src/routes/ai_.knowledge.tsx`, `src/routes/app.ai-center.tsx`

**Kya banega:**
- [ ] LEO chat — always visible sidebar
- [ ] AI Studio — structured AI operations
- [ ] Knowledge base — upload docs, ask questions
- [ ] AI Automation — workflow builder
- [ ] Credit wallet — always visible balance
- [ ] Usage history + receipts

**Coming Soon gate (awam ke liye):** Already in SiteLock — theek hai

---

## UI/UX SYSTEM (locked)

### Design tokens (already in `src/styles.css` + Tailwind v4)
```
Dark:  bg #0B1220 | surface #111827/#1F2937 | border #374151
Light: #FFFFFF/#F8FAFC | text #111827
Primary: #2563EB | Indigo: #4F46E5 | AI: indigo gradient
```

### Motion budget (Framer Motion)
- Page transition: 150ms ease-out
- Panel open: 200ms ease-out
- Send animation: 300ms sweep (blueprint design)
- Toast: 250ms slide-in
- Modal: 200ms scale+fade

### Layout rules
- Three-panel on desktop (1280px+)
- Two-panel on tablet (768px–1279px)
- Single-panel mobile with back nav
- Rail always visible (icons only, collapsible)
- Reading pane min-width: 480px

### ⌘K Command Palette (already exists — wire karenge)
| Key | Action |
|---|---|
| `c` | Compose new |
| `r` | Reply |
| `f` | Forward |
| `e` | Archive |
| `s` | Snooze |
| `#` | Delete |
| `/` | Search |
| `g i` | Go to inbox |
| `g s` | Go to starred |
| `g d` | Go to drafts |
| `?` | Show shortcuts |

---

## WORLD-CLASS FEATURES — ranked by impact

| Priority | Feature | Duniya mein kahan hai | ANEXOMAIL mein |
|---|---|---|---|
| 🔴 P1 | Real-time mail delivery proof | Nowhere (most fake) | Rust WebTransport → real receipt |
| 🔴 P1 | Email snooze + scheduled send | Superhuman only | Todo |
| 🔴 P1 | Undo send | Gmail (10s), Superhuman | Todo |
| 🟡 P2 | Read receipts (real) | HEY, Superhuman | Todo |
| 🟡 P2 | Thread intelligence auto-labels | Gmail (basic) | Todo — smarter |
| 🟡 P2 | ⌘K everything | Superhuman | Partial — wiring |
| 🟡 P2 | Focus mode | Hey.com | Todo |
| 🟢 P3 | Email → Task (real link) | Notion only (separate) | Todo — integrated |
| 🟢 P3 | Attachment hub | Nobody does this well | Todo |
| 🟢 P3 | Link preview rich cards | Slack, Notion | Todo |
| 🟢 P3 | Email health score (LEO) | Nobody | Todo (LEO phase) |
| 🟢 P3 | Cinematic send animation | Nobody | Blueprint ready |
| 🟢 P3 | Dark atmospheric mode | Nobody (Three.js) | Partial |
| ⭐ P4 | Mail → ANEXOChat bridge | Nobody | Phase 29 ready |
| ⭐ P4 | AI drafts with citations | Nobody | LEO Phase 57 |
| ⭐ P4 | Founder god-view real-time | Nobody public | Building |

---

## EXISTING CODE — NO DELETE RULE

Jo pehle se hai woh sab USE karenge:

| File | Kya hai | Plan |
|---|---|---|
| `ComposeStudio.tsx` | Rich compose | Wire to real send |
| `CommandPalette.tsx` | ⌘K palette | Wire all shortcuts |
| `ThreadList.tsx` | Mail list | Polish + real data |
| `WeekGrid.tsx` | Calendar UI | Wire to real events |
| `ContactProfile.tsx` | Contact view | Wire to real contacts |
| `MessageTruth.tsx` | Chat message actions | Already wired |
| `ConversationTruthBar.tsx` | Chat health | Already wired |
| `app.founder_.*` (20+ files) | Founder pages | Wire to real data |
| `ai_.*.tsx` | AI pages | Wire to LEO |
| `Panels.tsx` | Dashboard widgets | Wire to real counters |

---

## ASYNC TOKIO — KAHAN AAYEGA (locked)

```
Rust main.rs:
  #[tokio::main]          ← async runtime — ek thread hazaron connections
  async fn main() { ... }

Async Tokio phases:
  P3 Mail inbox    → tokio::spawn(watch_mail_notify())  — PostgreSQL LISTEN/NOTIFY
                     New mail insert → NOTIFY → Tokio watcher → WebTransport push → browser
  P4 Compose/Send  → tokio::spawn(delivery_tracker())   — SMTP delivery state tracking
  P7 Calendar      → tokio::spawn(reminder_scheduler()) — time-based event push
  P8 Founder view  → tokio::spawn(metrics_streamer())   — live system stats per 2s
  P9 ANEXOChat     → tokio::spawn(chat_room(conv_id))   — already in main.rs (chat.send)

Bun :3100 pe (fallback/REST):
  → CRUD operations (no long-lived connections needed)
  → Auth (Supabase Auth, no async runtime needed)
  → Mail send (Postfix handoff — fire-and-forget)
```

## SECURITY — PHASES KE SAATH EMERGE (locked)

DKIM pehle se Hetzner pe installed — touch nahi. Security yahan se shuru hogi:

```
P1 Auth     → S4: rate limit /api/auth/login (5 attempts / 15min window)
              S3: cookie Secure+HttpOnly+SameSite=Strict
              S3: CORS allow-list (only anexomail.com + subdomains)
P2 Dashboard → RLS already Supabase mein — no extra code
P3 Mail     → S4: attachment size limit enforce (5MB per attachment)
              S4: input sanitize mail body (XSS prevention)
P4 Compose  → DKIM signing already via OpenDKIM (Hetzner, no touch)
              S4: outbound rate limit (no spam abuse)
P5 Thread   → S3: CSP header — no inline scripts in mail HTML rendering
P8 Founder  → S4: is_founder check server-side ONLY — never trust client
              S8: ADMIN_ACTION audit event on every founder API call
S1-S10      → Server hardening (UFW, SSH, integrity) — jab founder bole
```

## SQL RULE (locked)

> Jab bhi nayi SQL file banegi main explicitly likhun ga:
>
> ⚠️ SQL NEEDED: `sql/phaseNN_naam.sql`
> GitHub link: https://github.com/naumansherwani/ANEXOMAIL-WORKSPACE/blob/main/sql/phaseNN_naam.sql
> Supabase #4 SQL Editor → Raw → Copy → Paste → Run

## PREVIEW RULE (locked)

> Har phase push hone ke baad main browser screenshot lunga aur dikhaunga.
> Aap server pull karo → main screenshot → aap confirm → next phase.

## STATUS BOARD

| Item | Status |
|---|---|
| SQL phase60/61/62 | ✅ DONE (aap ne run kiya) |
| P1 Auth — cinema split | ✅ LIVE — screenshot liya |
| P2 Dashboard | 🔨 NEXT |
| P3 Mail inbox + WebTransport | TODO |
| P4 Compose + send | TODO |
| P5 Thread view | TODO |
| P6 Contacts | TODO |
| P7 Calendar | TODO |
| P8 Founder View (not god-view) | TODO |
| P9 ANEXOChat live proof | TODO |
| Polar payments | 🔒 NO TOUCH |
| Prices | 🔒 NO TOUCH |
| Landing page | 🔒 NO TOUCH |
| Existing UI components | 🔒 NO DELETE |
| DKIM / Postfix / Dovecot | 🔒 NO TOUCH (already installed Hetzner) |
