# ANEXOMAIL Workspace — Blueprint (Consolidated)

Source files: `.lovable/plan/` + `roadmap.md` + `sql/` + `docs/wire/`
**Yeh file delete nahi hogi. Sirf append hogi.**

---

## IDENTITY

- **Product:** ANEXOMAIL Workspace — Google Workspace / Zoho Mail ka ultimate replacement
- **Mission:** AI-native email workspace. Cinematic, disruptive.
- **Founder:** Muhammad Nauman Sherwani
- **Server 2:** `root@62.238.98.98` → `/opt/anexomail-web` (frontend + backend)
- **Supabase:** #4 = ANEXOMAIL single source of truth. pgvector active.
- **Payments:** Polar — Rust webhook (PM2 mein, founder ne fix kiya)

---

## DESIGN SYSTEM (locked)

- **Font:** Inter 700 headings / 400–500 body
- **Radius:** 12–16px | **Spacing:** 8px grid | **Icons:** Lucide
- **Dark:** bg `#0B1220`, surface `#111827/#1F2937`, border `#374151`, text `#F9FAFB/#9CA3AF`
- **Light:** `#FFFFFF/#F8FAFC/#E5E7EB/#111827/#6B7280`
- **Colors:** Primary `#2563EB`, Indigo `#4F46E5`, Cyan `#06B6D4`, Success `#10B981`, Warning `#F59E0B`, Danger `#EF4444`
- **AI actions:** indigo gradient
- **Layout:** three-panel mail (nav / list / reading+LEO), Cmd+K palette, AI always visible

---

## HOST MAP

| Domain | Surface |
|---|---|
| `anexomail.com` | Awam mail workspace |
| `ai.anexomail.com` | LEO AI workspace (Coming Soon publicly) |
| `founderworkspace.anexomail.com` | Founder protocol (sirf Nauman) |

---

## PHASES — ANEXOMAIL WORKSPACE

### PHASE 1 — Design shell + tokens
- `src/styles.css`, `AppShell.tsx`, `SiteNav.tsx`, `__root.tsx`, landing `index.tsx`
- Status: **PARTIAL** (SiteLock + preview mix — pull se theek hoga)

### PHASE 2 — IA (Inbox Architecture)
- `src/lib/ia.ts` — inbox/assigned/waiting/sent/drafts folders
- DB folders mail routes se
- Status: **PARTIAL**

### PHASE 3 — Public pages
- `/about`, `/security`, `/auth`, `/get-started`, `/plans`, `/enterprise`
- Status: **PARTIAL** (pages exist, kuch content missing)

### PHASE 4 — Honest states
- `StateBlock.tsx`, `Skeletons.tsx`, `notify.ts`
- Status: **PARTIAL** (states exist, live data nahi)

### PHASE 5A — Auth (login / signup / session)
- `src/routes/auth.tsx`, `server/routes/auth.ts`, `src/routes/claim.tsx`, `src/routes/onboarding.tsx`
- SQL: `sql/phase59_account_lifecycle.sql`
- Status: **READY** (eye icon fix pushed — pull + SQL run karo)

### PHASE 6 — Dashboard
- `src/routes/app.index.tsx`, `server/routes/dashboard.ts`
- Status: **BROKEN** (session ke baghair — Phase 5A + SQL 60 ke baad theek hoga)

### PHASE 7 — Mail core
- `server/routes/mail.ts`, `src/routes/app.mail.$folder.tsx`, `sql/phase52_mail_launch.sql`
- SQL: phase52, phase54, phase57, phase58
- Status: **READY** (live 401 — SQL run ke baad)

### PHASE 8 — LEO delivery
- `src/lib/mail.ts` leoSupportPipeline
- Status: **SKELETON** (awam mail ke liye zaruri nahi abhi)

### PHASE 9 — Compose + send
- `src/routes/app.mail.outbox.tsx`, `server/routes/mail-compose.ts`, `server/mail/sendmail.ts`
- Status: **READY** (live send unproven — mail-gate ke baad)

### PHASE 10 — Contacts / People
- `src/routes/app.people.tsx`, `server/routes/contacts.ts`
- SQL: `sql/phase62_contacts_intelligence.sql`
- Status: **READY** (SQL 62 run ke baad)

### PHASE 11 — Calendar
- `src/routes/app.calendar.tsx`, `server/routes/calendar.ts`
- SQL: `sql/phase61_calendar_work.sql`
- Status: **READY** (SQL 61 run ke baad)

### PHASE 12A — Mail prediction
- `sql/phase12a_mail_prediction.sql`, `server/routes/mail-predict.ts`
- Status: **READY**

### PHASE 17 — AI Studio
- `sql/phase17_ai_studio.sql`, `server/routes/ai-studio.ts`, `src/routes/app.ai-center.tsx`
- Status: **READY**

### PHASE 18 — AI Automation
- `sql/phase18_ai_automation.sql`, `server/routes/ai-automation.ts`
- Status: **READY**

### PHASE 19 — AI Billing
- `sql/phase19_ai_billing.sql`
- Status: **READY**

### PHASE 20 — AI Knowledge
- `sql/phase20_ai_knowledge.sql`, `server/routes/integrations.ts`
- Status: **READY**

### PHASE 21 — Billing platform
- `sql/phase21_billing_platform.sql`
- Status: **READY**

### PHASE 22 — Integrations
- `sql/phase22_integrations.sql`, `server/routes/integrations.ts`
- Status: **READY**

### PHASE 23 — Settings
- `sql/phase23_settings.sql`, `server/routes/settings.ts`
- Status: **READY**

### PHASE 24 — Analytics
- `sql/phase24_analytics.sql`, `src/routes/app.analytics.tsx`
- Status: **READY**

### PHASE 25 — Admin
- `sql/phase25_admin.sql`, `server/routes/admin.ts`, `src/routes/app.admin.tsx`
- Status: **READY**

### PHASE 26 — Security
- `sql/phase26_security.sql`, `server/routes/security.ts`
- Status: **READY**

### PHASE 27 — Performance
- `sql/phase27_perf.sql`, `server/routes/perf.ts`
- Status: **READY**

### PHASE 28 — Handoff + Revenue
- `sql/phase28_handoff.sql`, `sql/phase28_revenue.sql`
- Status: **READY**

### PHASE 30 — Release
- `sql/phase30_release.sql`, `server/routes/release.ts`
- Status: **READY**

### PHASE 31 — AI Credits
- `sql/phase31_ai_credits.sql`, `server/routes/ai-credits.ts`
- Status: **READY**

### PHASE 32 — Trial
- `sql/phase32_trial.sql` (trial only — ANEXOChat se alag)
- Status: **READY**

### PHASE 33 — Polar checkout
- `sql/phase33_polar_checkout.sql`
- Status: **READY**

### PHASE 35 — Payment safety
- `sql/phase35_payment_safety.sql`
- Status: **READY**

### PHASE 36 — State sync
- `sql/phase36_state_sync.sql`
- Status: **READY**

### PHASE 37-39 — Move-In ops
- `sql/phase37_movein_ops.sql`, `sql/phase38_movein_hardening.sql`, `sql/phase39_movein_fixes.sql`
- Status: **READY**

### PHASE 40 — Evidence truth
- `sql/phase40_evidence_truth.sql`
- Status: **READY**

### PHASE 43-51 — Billing + Polar hardening
- phases 43, 44, 45, 46, 47, 48, 49, 49b, 50, 51
- Status: **READY**

### PHASE 52 — Mail launch (CRITICAL)
- `sql/phase52_mail_launch.sql` — 13 asli anexomail.com addresses seed
- `server/mail/deploy-mail.sh` — Postfix + Dovecot + DKIM
- Status: **READY** (server par deploy baqi)

### PHASE 53 — Legacy RLS lock
- `sql/editor/phase53_legacy_rls_lock.sql`
- Status: **READY**

### PHASE 54-58 — Mail contract hardening
- phases 54, 55, 56, 57, 58
- Status: **READY**

### PHASE 59 — Account lifecycle (login core)
- `sql/phase59_account_lifecycle.sql`
- Status: **READY** (Supabase run baqi)

### PHASE 60 — Org identity repair (Cursor work)
- `sql/phase60_org_identity_repair.sql`
- **"No organisation yet" ki asli fix**
- Status: **READY** (Supabase run baqi)

### PHASE 61 — Calendar + work schema (Cursor work)
- `sql/phase61_calendar_work.sql`
- Status: **READY** (Supabase run baqi)

### PHASE 62 — Contacts intelligence (Cursor work)
- `sql/phase62_contacts_intelligence.sql`
- Status: **READY** (Supabase run baqi)

---

## 13 MAIL ADDRESSES (anexomail.com)

| Address | Type |
|---|---|
| `hello@anexomail.com` | Real mailbox — support |
| `moveyourbusiness@anexomail.com` | Real mailbox — Move-In leads |
| `support@anexomail.com` | Alias → hello@ |
| `billing@anexomail.com` | Real mailbox — invoices |
| `noreply@anexomail.com` | Send-only — system mails |
| `trials@anexomail.com` | Real mailbox — trial lifecycle |
| `abuse@anexomail.com` | Real mailbox — RFC required |
| `postmaster@anexomail.com` | Alias → abuse@ |
| `dmarc@anexomail.com` | Real mailbox — DMARC reports |
| `naumansherwani.founder@anexomail.com` | Founder primary |
| `nauman@anexomail.com` | Alias → founder primary |
| `leo@anexomail.com` | LEO AI — auto-reply pipeline |

---

## TARTEEB — Kya pehle live karna hai

1. ✅ Server pull (git pull + build)
2. ⏳ SQL Phase 60 → 61 → 62 (Supabase #4 SQL Editor)
3. ⏳ Login test — `anexomail.com/auth`
4. ⏳ Phase 52 mail deploy — `bash server/mail/deploy-mail.sh`
5. ⏳ Mail gate — `bash server/gates/mail-gate.sh`
6. ⏳ Founder workspace separate verify
7. ⏳ ANEXOChat live proof

---

## RECOVERY RULES (from .lovable/plan)

1. Existing code phenknaa nahi — wire karo
2. Har feature: browser action + server response + database proof = DONE
3. Blank screen / 404 = FAIL
4. Mock / dummy success = FAIL
5. Secrets kabhi output/log mein nahi
6. Har nayi table ke saath RLS + GRANT same migration mein
