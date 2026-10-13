# ANEXOMAIL — Implementation Master Plan
# Agent Personal Memory — Read This First Every Session

**Founder:** Muhammad Nauman Sherwani
**Last updated:** Sep 10 2026 (E1 packages — existing cards)
**Execute (implement yahi):**
- Mail: `docs/cursor-work/ANEXOMAIL-EXECUTE.md` — **ab**
- AI: `docs/cursor-work/AI-EXECUTE.md` — mail DONE ke baad
- Founder: `docs/cursor-work/FOUNDER-EXECUTE.md` — end
**GATE:** PARTIAL se next nahi. DONE = wire + live test.
**Founder rule:** yeh master TODO board nahi. Product TODO se nahi chalti. Status: **DONE / READY / not live**.
**Original no-touch:** `docs/anexomail-blueprint.md` · `src/lib/plans.ts`
**Rule:** Phases kisi bhi tarteeb mein mat likho — **EXECUTE E1–E8**. Inbox rewrite nahi. Packages = existing cards (Basic £23 / Pro £46 / Business £97 / Business Pro £2850).

## MAIL SEND + RECEIVE GATE (founder lock 10 Sep 2026)

**Agay nahi** jab tak website se asli mail jaaye aur asli mail inbox mein aaye.

F3 = list dikhana. F4 = send + receive. F5+ wait.

Aasan raasta:
1. User Compose se bhejta hai
2. Server ka Postfix internet par bhejta hai (DKIM pehle se installed)
3. Wapas aane wali mail Postfix → Dovecot pipe → database → Mail list

Proof: `bash server/gates/mail-gate.sh` green + founder live test.

---

## 0. UNMIX AUDIT — Lovable mix vs blueprint vs package cards (10 Sep 2026)

**Yeh section pehle parho.** Founder ne existing packages implement bola — E1 rail/gate **usi** `AppShell` + `host.ts` + `plan-surface.ts` pe. Naya stack nahi.  
**NO TOUCH:** `src/lib/plans.ts` · `src/lib/ai-packages.ts` · Polar Rust webhook · landing · logo.

### 0.1 Ek codebase — teen darwaze (57×3 copy nahi)

| Host | Product | 1-week matlab |
|---|---|---|
| `anexomail.com` | Mail workspace + plan cards Basic/Pro/Business/Business Pro | Login, Dashboard, Mail. Chat/Video **sirf Business+**. LEO **zero**. |
| `ai.anexomail.com` | LEO + AI plans (AI Pro / AI Business / AI Executive) | Awam **Coming Soon**. Raana grant baad. Duplicate org wizard **nahi**. |
| `founderworkspace.anexomail.com` | Founder protocol — sirf Nauman (`founder_accounts`) | Admin, Speed, revenue, health. Family testers yahan **kabhi nahi**. |

Har naya page **naya subdomain nahi**. Same `AppShell` + `host.ts` + **plan gate**.

### 0.2 Founder protocol (mix yahan se toot’ti hai)

Founder ≠ Business Pro ≠ AI Executive.

| | Founder | Awam (koi bhi plan) |
|---|---|---|
| Host | `founderworkspace.anexomail.com` | `anexomail.com` / `ai.` |
| DB | `founder_accounts` | `family_accounts` / Polar entitlement |
| Rail | Sab dikhe (Admin, Speed, Founder) | Plan matrix neeche |
| Onboarding | Skip — seedha `/app` | Personal \| Business (F3 B) |
| Payment | Nahi | Polar (no touch) |

Humza/Raana/Masood **founder nahi**. Unko founder rail / Admin **nahi**.

### 0.3 Package → kya dikhe (SOURCE: PACKAGE-FEATURE-FORMULA + plans.ts — prices no touch)

**Workspace (`anexomail.com`)**

| Rail / feature | Basic | Pro | Business | Business Pro |
|---|---|---|---|---|
| Dashboard | ✅ | ✅ | ✅ | ✅ |
| Mail send/receive | ✅ | ✅ | ✅ | ✅ |
| People (contacts) | ✅ | ✅ | ✅ | ✅ |
| Calendar | ✅ | ✅ | ✅ | ✅ |
| Work (tasks / thread analytics) | basic | ✅ | ✅ | ✅ |
| Snooze / schedule / shared inbox | ❌ | ✅ | ✅ | ✅ |
| CRM (leads / pipeline) | ❌ | ✅ own book | ✅ team | ✅ + activity ledger |
| ANEXOChat | ❌ | ❌ | ✅ | ✅ |
| ANEXOVideoCall | ❌ | ❌ | ✅ (8) | ✅ (40) |
| Org / members / roles | ❌ | ❌ | ✅ | ✅ |
| Org Admin (unke domain/DNS — customer) | ❌ | ❌ | limited, F9 baad | ✅, F9 baad |
| Founder Admin / Speed / revenue | ❌ | ❌ | ❌ | ❌ |
| LEO / AI center / compose Leo | ❌ | ❌ | ❌ | ❌ |

**AI (`ai.anexomail.com`) — workspace platform ANDAR included, LEO alag meter**

| | AI Pro | AI Business | AI Executive |
|---|---|---|---|
| Platform | Business | Business | Business Pro |
| LEO credits | 1,200 | 5,000 | 10,000 |
| Chat | Ph 1–57 | Ph 1–57 | Ph 1–57 |
| Compose Leo / summary / smart reply | ✅ | ✅ | ✅ |

**Family testers (feel = unka plan, founder nahi)**

| Kaun | Plan | Anexomail.com rail |
|---|---|---|
| Masood | Pro | Dashboard, Mail, People, Calendar, Work — **no Chat, no AI, no Admin** |
| Humza | Business Pro | + Chat, Org, Video (plan) — **no LEO, no Founder Admin** |
| Raana | AI Executive | Business Pro workspace + **AI/Leo** (ai host / AI rail) — **no Founder Admin** |

### 0.4 Clash (Lovable + purani master file — isliye messy laga)

| Jagah | Galat kaha | Sahi (package cards) |
|---|---|---|
| Master §6 purana | anexomail.com pe Chat **hide** | Chat **Business+** pe dikhe |
| Live AppShell (pehle) | Sab ko same CRM/AI/Admin | Plan + host gate |
| ComposeStudio | Leo buttons har mail user | Sirf AI plan |
| Blueprint PHASE 6 copy | “AI always visible” | Sirf AI surface |
| F1.2 purana | awam pe Chat hide | Formula Rule 3 |

**Cinematic dashboard (Greeting, tiles) delete nahi** — Dashboard har package pe. Leo credits panel sirf AI plan.

### 0.5 Lovable dirt (alag karna — delete product nahi, gate)

1. Logo `/` → landing/sign-in (fix started: stay in `/app`)  
2. Dual workspace rows + `not_found`  
3. Hosted mailbox pe “Domain not verified”  
4. Forced org + domain day-1  
5. Same rail Basic = Business Pro = Founder  
6. Leo in compose / dashboard for non-AI  
7. Admin on family  
8. Claim-username vs mailbox identity  
9. `app/founder*` awam host pe clickable  
10. CRM dumped on mail host (CRM = `crm` / `aicrm` hosts, mail mix nahi)

### 0.6 1-week launch (57 phases yahan complete nahi)

**Week ka product:** asli send+receive (F4) + yeh gates.  
**Nahi:** 57 ANEXOChat phases × 3 hosts, landing redo, Polar, naya theme pack.

Tarteeb: F4 mail-gate → gates wire (AppShell + server 403) → F5+ wait.

**Gates wire tab:** founder bole **“gates wire shuru”**. Abhi discuss freeze.

### 0.7 Lovable mix ki asl jaga (blueprint vs cards vs code)

Teen “sach” files — ek dusre ko kaat’ti hain. Agent ne pehle kabhi yeh, kabhi woh wire kiya. Isliye rail barbad.

| Source | Woh kya kehta hai | Asal ghalti |
|---|---|---|
| Blueprint PHASE 6 / design | “AI always visible”, three-panel + LEO | Mail product pe LEO hamesha = mix. LEO = AI host / AI plan. |
| `docs/ai-packages.md` §6 | Chat + VideoCall **andar** `ai.anexomail.com` | Business card pe Chat **included** hai. Humza ko Coming Soon AI site pe mat bhejo. |
| PACKAGE formula Rule 3 | Chat Business+; LEO AI-only | Yeh **jeet’ta hai** entitlement ke liye. |
| Purana Master F1.2 | anexomail.com pe Chat **hide** | Package card ke khilaf. |
| `host.ts` extra | `anexochat.` `crm.` `aicrm.` + `.lovable.app` = founder | Teen locked hosts ke upar extra dukaan. Lovable preview = founder protocol nahi. |
| `ia.ts` Admin | Domains, members, DKIM — **org ka** admin | Live `showAdmin` = founder host only. Do alag cheezein ek label “Admin”. |
| Formula device-trust | Biz Pro + AI Exec top-tier safety queue | Family tester pe “Admin” dikhana ≠ founder protocol. Raana ko founder Admin nahi. |

**Mind (clone nahi):** entitlement package card se. Surface teen hosts se. UI Lovable dump se nahi.

### 0.8 LOCKED GATE — propose (founder confirm ke baad wire)

**Teen hosts sirf.** `anexochat.` / `crm.` / `aicrm.` is week **nahi**. CRM mail rail pe nahi.

**Do Admin (alag naam — mix yahan toot’ti hai)**

| Label | Kya hai | Kis ko | Kab |
|---|---|---|---|
| Org | Members, roles, unka workspace | Business+ (Humza) | Rail ab |
| Workspace Admin | Unka DNS/DKIM, audit, device-trust | Business limited / Biz Pro full | **F9 baad** — family testers pe OFF |
| Founder protocol | Speed, revenue, sab orgs, health, `/app/founder*` | Sirf Nauman + `founderworkspace` | F9, mail-gate ke baad |

**Chat kahan:** Business+ ko **anexomail.com rail**. AI host par LEO-in-chat + Ph 57. Alag chat subdomain nahi. Phase 32+ wait paste.

**LEO kahan:** Workspace plans (Basic→Biz Pro) **zero**. AI plan (Raana grant) → AI rail OK (same codebase). Awam `ai.anexomail.com` Coming Soon.

**Work:** Pro+ full. Basic = mail-first; Work rail optional later — ab hide (live `showWork`).

**Dashboard:** har package, har host (founder ke alawa public mail). Cinematic greeting delete nahi.

### 0.9 F-series → host → package (Claude F flow, unmixed)

| Flow | Host | Kis package | Status rule |
|---|---|---|---|
| F1 Auth | `anexomail.com` | Sab awam | Founder skip wizard |
| F1.2 Shell gates | teen hosts | §0.8 matrix | Wire sirf “gates wire shuru” |
| F2 Dashboard | mail + AI | Sab | DONE sirf live |
| F3 list | mail | Sab mail plans | READY |
| F3 A testers | mail | Masood Pro, Humza Biz Pro, Raana AI Exec | READY |
| F3 B onboarding | mail only | Personal \| Business | READY — AI/founder mix nahi |
| **F4 send+receive** | mail | Sab (Basic+ mail included) | **GATE — F5+ wait** |
| F5 thread | mail | Sab | wait F4 |
| F6 People | mail | Sab | wait F4 |
| F7 Calendar | mail | Sab | wait F4 |
| F8 Work | mail | Pro+ | wait F4 |
| F9 Founder protocol | **founder host only** | Nauman | wait F4 |
| C1–31A Chat | mail rail Business+ | Business, Biz Pro, AI plans | live wire; **32+ paste only** |
| VideoCall | Business+ entitlement | group 8 / 40 / 60 per card | not a 4th host |
| AI1–AI4 LEO | `ai.` + `ai_plan` | AI Pro / Biz / Exec | Coming Soon awam |

### 0.10 Extra host dirt (Lovable leftover — build nahi)

`src/lib/host.ts` ab bhi: `anexochat.anexomail.com`, `crm.anexomail.com`, `aicrm.anexomail.com`, `*.lovable.app` = founder.  
**Locked map teen hosts.** In extra ko naya product mat banao. Founder protocol `.lovable.app` pe nahi.

### 0.11 Founder se 3 sawaal (wire se pehle — ek jawab kaafi)

1. **Chat:** Business+ ko `anexomail.com` pe Chat rail — **haan** (recommend) ya AI host pe bhejo (Coming Soon)?
2. **Org Admin:** Humza ko `/app/org` dikhe; `/app/admin` family pe band — **haan** (recommend, testers)? Product Admin F9 pe unke domain ke liye?
3. **Raana LEO:** `anexomail.com` pe AI rail (grant) **ya** sirf `ai.anexomail.com`?

Jawab ke baghair **AppShell dubara nahi chhedna.** Polar / `plans.ts` / landing **no touch**.

**10 Sep shaam lock:** screenshot + sure-shot path → **§12**. Shuru se rewrite **nahi**.  
Founder emails: `docs/cursor-work/founder/address-audit.md`. Retain map: `docs/cursor-work/LOVABLE-RETAIN-MAP.md`.

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

F1.2  AppShell host + **plan** guard (Lovable mix hatao)
      Files: src/components/app/AppShell.tsx, src/lib/host.ts, src/lib/plan-surface.ts
      Rule: §0.8 — Chat Business+ on anexomail.com; LEO AI-plan/AI-host;
             Founder/Speed sirf founder host; CRM mail rail pe nahi.
             Purana “awam pe Chat hide” **galat** — package cards jeet’te hain.

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
HONEST WEEK (mail-gate jeet’ta hai — 57×3 copy nahi):
  Abhi     F3 list + F3A/B testers READY — live unproven
  Blocker  F4 send+receive + bash server/gates/mail-gate.sh GREEN
  Uske baad  F1.2 gates wire (founder: “gates wire shuru”)
  F5+ / F9 / Chat 32+ / cinematic paint  WAIT
```

**Parallel rule:** Chat engine Business+ ke liye parallel *soch* — live product pehle mail. F4 ke baghair F5+ nahi.

---

## 6. PER-SURFACE HOST RULES (locked — §0 jeet’ta hai)

Purana “awam pe Chat hide” **galat** tha (Lovable mix). Package cards jeet’te hain:

| Surface | Host | Dikhe | Kabhi nahi |
|---|---|---|---|
| Mail workspace | `anexomail.com` | Dashboard + Mail + People + Calendar; Work Pro+; Chat/Video/Org **Business+** | LEO (zero on workspace plans), Founder, Speed |
| AI workspace | `ai.anexomail.com` | LEO + AI plan ladder; platform = Business / Business Pro included | Founder protocol |
| Founder | `founderworkspace.anexomail.com` | Sab + Admin + Speed | Awam / family accounts |

Code: `src/lib/host.ts` (locked) + `src/lib/plan-surface.ts` (gates) + `src/components/app/AppShell.tsx`  
Formula: `docs/cursor-work/PACKAGE-FEATURE-FORMULA.md`  
Prices: `src/lib/plans.ts` — NO TOUCH

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
| C1 Chat engine | PARTIAL — Humza list+poll live, WT unproven | Sep 10 screenshot |
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

---

## 12. SURE-SHOT BUILD PATH (10 Sep shaam — screenshot lock)

**Faisla:** website shuru se **nahi** banegi. 67+ SQL, Polar, Postfix, Caddy, Auth (Humza login), mail tables — yeh spine. Lovable dump + galat gates ko **alag** karo. Naya stack / naya repo / SQL dubara = doosri century.

Latest tech pehle se constitution mein hai: Hetzner, Caddy HTTP/3, TanStack Start, Bun :3000, **Rust :3200 WebTransport PRIMARY**. Dead feel isliye hai ke Command Center zeros + Gmail-unlike chrome — tech missing nahi.

### 12.1 Screenshots kya bolti hain

| Image | Kya dikha | Matlab |
|---|---|---|
| 1 Raana `anexomail.com/app` | Rail patli + header **Raana Sherwani** | AI Exec ko Chat+Org+Work+AI. Naam header se nahi (logo retain). Session `ai_plan` poora nahi. |
| 2 Humza `/app/chat` | Chat+Org+Work + 1 conversation, HTTP/3 polling | Business Pro rail **zinda**. Chat shell pehle se repo mein thi — rail khuli to dikhi. Blank nahi = wire shuru. WT PRIMARY abhi nahi (honest poll). |
| 3 Sessions | Mozilla UA + Bun + 127.0.0.1 | Hardcoded UA dump. Insaan ka device nahi. |
| Gmail (ref) | Inbox, folders, naam brand nahi | Logo retain; header mein **display name chip nahi**. Identity avatar. |
| Mixed rail (purani) | Today Chat CRM Org Work AI Speed Admin | Family pe kabhi nahi. Founder host, teen groups. |

**URL:** `/app` Lovable file-route hai (`app.tsx`). Address bar page ke naam se match kare: Dashboard → `anexomail.com/dashboard`, Mail → `anexomail.com/mail/inbox`. Ab `/mail` **redirect** karta hai `/app/mail` pe — ulta hai. Canonical short path; `/app` piche reh sakta hai.

### 12.2 Existing phases: alag karo, delete mat karo

| Karo | Mat karo |
|---|---|
| Shell + session plan + URL aliases unmix | 160 routes rewrite |
| SQL jo chal chuki use karo | 67 SQL dubara / naya Supabase |
| Chat 1–31A jo repo mein hai usi ko gate | 57 phases naya likho |
| Chat 32+ wait founder paste | ChatGPT/Lovable suggestions se 32+ |
| Polar / `plans.ts` / landing / logo | Naya payment, naya theme pack, NEXATECT public |

### 12.3 Image 4 kahan jati hai (rail split)

**anexomail.com (package cards)**

- Har plan: Dashboard · Mail (folders Mail pane mein, Gmail jaisa) · People · Calendar
- Pro+: Work
- Business+: ANEXOChat · Org · VideoCall (chat ke andar, 4th host nahi)
- AI plan (Raana): + AI/Leo
- Kabhi nahi: CRM, Speed, Founder Admin

**ai.anexomail.com:** LEO studio / credits / compose-Leo. Awam Coming Soon.

**founderworkspace (Image 4 ka asl ghar — saaf groups)**

1. Product: Dashboard Mail Chat People Calendar Work Org
2. Founder deck: Founder · Speed · revenue · health · launch
3. Platform Admin: DNS/all-orgs/audit — **customer Admin nahi**

CRM is week mail pe nahi.

### 12.4 Honest URLs (canonical — `/app` hidden)

| Page | Address bar |
|---|---|
| Dashboard | `/dashboard` |
| Mail inbox | `/mail/inbox` |
| Thread | `/mail/inbox/:id` |
| People | `/people` |
| Calendar | `/calendar` |
| Work | `/work` |
| Chat | `/chat` |
| Org | `/org` |
| AI | `/ai` (AI plan / AI host) |
| Account | `/account` (avatar) |
| Founder deck | `founderworkspace…/founder/…` |

Purane `/app/*` 301 → in paths. 160 files rename ek raat mein **nahi** — alias + redirect invert. Phase naam: **URL honesty**.

### 12.5 Chrome (Gmail se seekho, clone nahi)

- Header: logo + **ANEXOMAIL** (product). Insaan ka poora naam brand nahi.
- Identity: **ek** avatar top-right → profile, mailbox, sessions. Address 2 jagah: Mail accounts + profile.
- Mail kholo to **folders** (Inbox Assigned Waiting…) Mail column mein — left rail product sections.
- Dashboard zeros se product “dead” lagta hai jab tak F4 mail na chale. Beauty **mail three-panel** ke baad; landing no-touch.

### 12.6 Founder protocol — kya powers (mix yahan khatam)

Sirf `founder_accounts` + `founderworkspace.anexomail.com` (Caddy allowlist). Polar se login nahi. Family kabhi nahi.

| Power | Matlab |
|---|---|
| Skip onboarding | Seedha workspace, claim/org wizard nahi |
| God view | Sab orgs ke metrics — customer mailbox padhna nahi (Wire 19) |
| Revenue | Polar data dekho — webhook **no touch** |
| Launch / health / Speed | Deploy, PM2, WT live, perf |
| System mailboxes | hello@, billing@, … founder inbox mein; family mail **alag** |
| Preview `?founder=1` | Bina session tour — awam login pe sticky nahi |
| File/ops ceiling | Package map: founder row alag limits |
| Kill switch | Org freeze / safety — awam Admin button nahi |

Customer **Org** (Humza members) ≠ Founder Admin.

### 12.7 Tarteeb (ek line pe, mix nahi)

```
1. Session plan truth     Humza=BizPro, Raana=AI Exec, Masood=Pro  (rail ab Basic clone isliye hai)
2. Package rail §0.8      Chat/Org Humza; AI Raana; Speed/Admin founder host
3. URL honesty            /dashboard /mail/inbox address bar mein
4. Chrome                 naam header se hatao, avatar
5. F4 mail-gate           send+receive GREEN — yahan product zinda
6. F5–F8                  thread, people, calendar, work — mail ke baad
7. Chat                   1–31A gate Business+; 32+ paste only
8. F9 founder             powers §12.6 founder host pe
9. AI host                Coming Soon awam; Raana grant
10. UI polish             zeros ke baad cinematic mail — landing no-touch
```

**Blocker 5 se pehle 6–10 “DONE” nahi.**
**Shuru karne ka jumla:** pehle `session plan truth shuru` — phir `gates wire shuru` — phir `URL honesty shuru`. Ek saath 160 files nahi.

---

## 13. % COMPLETE + DUPLICATE AUDIT (10 Sep raat — founder sawal)

**Sawal:** Lovable mix alag + Master F-series tarteeb se implement + saath wire → website kitne %?

Teen yardsticks — ek number jhoot hai.

### 13.1 Ab (live, 10 Sep)

| Yardstick | Ab | Master F1–F9 + C1–C5 **wire ke baad** | 57-phase poora sapna |
|---|---|---|---|
| **Awam mail product** (`anexomail.com` login + send/receive + package rail) | **~35%** | **~85%** | — |
| **Master Plan file khud** (F1–F9, C1–C5, S, AI1–4) | **~30%** | **~100% us file ka** | — |
| **2-saal blueprint** (mail 1–62 + Chat 1–57 + AI host + founder) | **~25%** | **~40–45%** | 100% = 32+ paste + F4 green + AI live + founder F9 |

**Kyun 85% mail, 45% sapna:** Master **jaan-boojh kar** Chat 32–57, AI Coming Soon, cinematic mail polish ko baad rakhta hai. F4 ke baghair mail product 35% pe atka rehta hai.

**Ab ke tukre (jhoot DONE nahi):**

| Tukra | % | Proof |
|---|---|---|
| Polar / plans / Caddy / SQL 60–63 | spine | no-touch |
| F1 login | ~60 | Humza/Raana session |
| F2 dashboard | ~70 UI / 20 data | zeros |
| F3 mail list | ~40 | list, send unproven |
| F4 send+receive | **0 live** | mail-gate |
| F5–F9 | ~10 skeleton | wait F4 |
| C1 Chat | ~35 | Humza: 1 real conversation, **HTTP/3 polling** (WT nahi), messages khali |
| C2–C5 / AI | ~5–10 | repo files, awam nahi |
| Chrome naam | 0 live | Raana/Humza chip — logo retain, naam nahi; GitHub pe nahi |

### 13.2 Image 2 khush khabri (hardcoded nahi)

`/app/chat` pehle se tha (`useConversations`, `useChatBootstrap`, `chatCall`). Pehle **blank** isliye: rail ne Chat chhupa di / Humza plan `basic` tha. Ab Business Pro rail khuli → wahi shell dikhi.

- “Muhammad Nauman Sherwani · No messages yet” = DB conversation, fake thread nahi.
- “HTTP/3 polling” = **imaandar** — Rust WebTransport PRIMARY abhi nahi.
- Chand/sky = Atmosphere UI empty state ke peeche — messages invent nahi.
- **57 phases complete nahi.** C1 surface. 32+ wait paste.

### 13.3 Image 3 hardcoded (theek nahi)

`saveSession` ne `device`/`browser` mein poora UA + Bun + `127.0.0.1` likh diya. Yeh mock nahi, **ghalat storage**. Local fix READY, live nahi jab tak push + `deploy-brain.sh`.

### 13.4 Master Plan — mix / duplicate (no-mix audit)

| Duplicate / mix | Kya galat | Jeet |
|---|---|---|
| Blueprint PHASE N vs F1–F9 vs Chat PHASE N | Teen catalog | Mail = F-series. Chat = anexochat blueprint. Mix number nahi |
| F2 “DONE” vs zeros | Status inflation | DONE sirf mail-gate / live proof |
| C1 “TODO” vs Humza screenshot | Board stale | PARTIAL |
| Purana F1.2 Chat hide vs cards | Mix | Chat Business+ |
| `host.ts` extra (`crm.` `anexochat.` lovable=founder) | 4th dukaan | Teen hosts |
| `/app/admin` vs founder Admin vs Org | Ek label | §0.8 |
| CRM on mail rail | Dump | hide |
| phase56 Humza/Raana dono AI Exec vs F3 A | Tester mix | F3 A jeet: Humza Biz Pro, Raana AI Exec |
| `/app` vs `/dashboard` | Lovable path | URL honesty baad |
| Header naam + logo | Mix pehchan | **Logo lockup har page. Naam nahi.** |
| Chat 57 vs Master C1–C5 | Duplicate build | 1–31A wire; 32+ paste only |
| Landing / Polar / `plans.ts` | Touch = mix | no-touch |

**Implement rule:** ek flow ek dafa. Purani F-file + naya clone nahi. SQL same filename.

### 13.5 Shuru kab

Is audit ke baad founder bole: **`session plan truth shuru`**. Us se pehle 160 files nahi.

---

## 14. FINAL TARTEEB (founder 10 Sep raat — lock)

**Sahi hai:** pehle `anexomail.com` complete → phir AI tarteeb se → **end pe** founder deck.  
**Galat hai:** teen sites parallel, ya F9 founder pages mail se pehle.

### Product order

```
1. anexomail.com     Blueprint 1→7→9→10→11 + mail-gate GREEN
2. ai.anexomail.com  PHASE 8 / 17+ — baad
3. founderworkspace  PHASE 25/27/F9 — END
```

**Abhi bhi (end tak wait nahi):** founder **guard** — family `founderworkspace` pe nahi, Admin/Speed family pe nahi. Pages baad, wall ab.

### Wire vs parallel

| | Faisla |
|---|---|
| Products | **Sequential** — mail khatam, phir AI, phir founder kaam |
| Har flow ke andar | **Wire saath** — list ke baad send, skeleton dump nahi |
| 3 hosts ek saath 57×3 | **Nahi** |
| Polar / landing / plans.ts / logo SVG | **No touch** |

### Header (screenshot lock)

- Left: **sirf** BrandMark (A + ANEXOMAIL WORKSPACE)
- Right avatar: naam + mailbox + Profile + Sign out — photo mein pehle se yahi sahi hai
- Logo ke saath Humza/Raana chip: **delete** (`AppShell` local READY — live tab pull)

Mail rail `raanasherwani@…` = mailbox, brand nahi.

---

## 15. ANEXOMAIL-ONLY TRACK (10 Sep raat — founder lock)

**57 phases ANEXOMAIL ki file nahi.** 57 = dusra product (bhool jao is track pe).  
Claude ka ANEXOMAIL follow = `docs/anexomail-blueprint.md` + is file ka F-map. Catalog: **Phase 1–62, gaps ke saath** (8, 17–22, 31 = AI — ab nahi).

**Source:** `docs/anexomail-blueprint.md` (PROTECTED). Claude order = neeche MAIL ONLY.

### Ab `anexomail.com` — yeh sequence (AI/founder skip)

| Blueprint | Claude F | Kya | Ab |
|---|---|---|---|
| **1** Shell + tokens | F1.2 | AppShell, logo lockup, **naam chip nahi** | PARTIAL — chip fix local |
| **2** IA folders | — | Mail pane folders | PARTIAL |
| **3** Public pages | — | landing **no-touch** | skip polish |
| **4** Honest states | — | empty/error sach | PARTIAL |
| **5A** Auth | **F1** | login/session | PARTIAL live |
| **6** Dashboard | **F2** | command center | UI live, zeros |
| **7** Mail core | **F3** | list | READY unproven |
| **8** LEO delivery | — | **SKIP** → AI baad | — |
| **9** Compose + send | **F4 GATE** | Postfix out + in | TODO |
| **10** People | F6 | wait F4 | — |
| **11** Calendar | F7 | wait F4 | — |
| 12A prediction | — | mail baad | — |
| 17–22, 31 AI | — | **SKIP** | — |
| 23 Settings | — | account/profile | PARTIAL |
| 25 Admin / 27 Speed | — | **SKIP** founder end | — |
| 32–51 Polar/trial | — | **no-touch** | spine |
| 52–58 mail infra | — | Postfix/Dovecot | READY deploy |
| 59–62 SQL | — | pehle se | run |

**Agli line:** Phase **1** khatam (header live) → **5A** session plan → **7** list proof → **9** mail-gate.  
Phase 1 se CSS/logo SVG dubara nahi. Follow = wire, rewrite nahi.

---

## 17. EK BLUEPRINT — ABHI KAUN SA (10 Sep raat — confusion band)

**Ab implement:** `docs/anexomail-blueprint.md`  
**Kahan:** `anexomail.com`  
**Kaise:** har phase **UI + UX + real wire** (browser + API + DB). Mock nahi.

**Ab nahi:** ANEXOChat 1–57 original (file no-touch, baad). Master C1–C8. AI host pehle.

Claude Master F1–F9 = **us mail blueprint ka order**, teesri kitab nahi.

```
anexomail.com  =  blueprint MAIL phases (1, 2, 4, 5A, 6, 7, 9, 10, 11…)
                  skip 8 + 17–22 + 31 (AI)
                  Polar/landing/plans.ts no-touch

ai.anexomail.com  =  WAHI product (same codebase, same UX)
                  farq: AI phases tarteeb se ADD (8, 17, 18… Leo)
                  naya clone / naya design nahi

founderworkspace  =  end
```

**Agli line:** `ANEXOMAIL Phase 1 shuru` — shell (logo, naam chip off) wire + live.

---

## 16. ANEXOChat original paste vs Master (10 Sep raat)

Founder ne original 1–57 paste kiya = **pehle se** `anexochat/docs/anexochat-blueprint-original.md`. **File no-touch.**  
Deep report: `docs/cursor-work/ANEXOCHAT-VS-MASTER-AUDIT.md`.

- Master **C1–C8 = duplicate short** — dusri chat nahi.
- C8 Open-Meteo **galat** — original API-free jeet.
- Prices paste ke £250/£85 — **`plans.ts` jeet**.
- 1–31A repo READY, live DONE nahi. 32–57 TODO. 57 = AI plans only.
- Ab build = **anexomail.com** blueprint. Chat 32+ wait.
