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

---

## SESSION 18–21 SEP 2026 — COMPLETE (founder lock)

Founder ne yeh session **complete** declare kiya (25 Sep 2026). Agents is list ko dubara build / “missing” mat samjhein. Secrets, passwords, `DATABASE_URL` is file mein nahi.

### Infrastructure

- `server/lib/supa.ts` — Brain `:3100` ke liye admin client. `deploy-brain.sh` sync list mein.
- `deploy-brain.sh` — PM2 ko `--env-file` se fresh env. Stale cached env nahi.
- Working Postgres `DATABASE_URL` teen env files mein (anexomail, anexomail-web, polar-rust-payment). Purana password stale tha.
- `polar-rust-payment` crash-loop band. Polar webhook dashboard se re-enable. Engine codes no-touch.

### Founder login

- `naumansherwani.founder@anexomail.com` Supabase password reset. Family accounts no-touch.
- `ensureFounderOrg()` — organisation + `org_members` + `mail_accounts`. `no_workspace` band. `/api/mail/*` open.

### E4 mail send

- `mail_scheduled` columns: code `to` / `cc` / `bcc` (purana `to_addresses` mismatch theek).
- `mail-worker.ts` — har 5s `status=queued` ko Postfix se bhejta hai, `sent` / `failed`. Purani phansi mail bhi isi se gayi.
- `admin_storage_snapshots` har send se pehle quota check.
- Founder proof: login → org → compose → send → deliver.

### Plan caps (steps 1–4)

- Plan truth SQL `storage_plans`: Basic 3 mailbox / 5GB, Pro 5 / 10GB, Business 30 / 25GB, Business Pro unlimited / 1TB pooled.
- `POST /api/org/mailboxes` plan cap. Create + limit tested.
- `mail_domains` / `mail_aliases` pe `org_id` add + backfill.
- `POST /api/org/domains` aur `POST /api/org/aliases` plan cap. Tested.

### Personal Polar checkout

- Product key `PRO_PLUS` → `PRO` (Polar `+` allow nahi). Config + env.
- Trigger `billing_personal_product_guard`: NULL `workspace_kind` = unset, reject nahi. Guest checkout Business ki tarah allowed.
- `personal-tiers.ts` Pro+ keys `PRO` (monthly + yearly).
- Bfcache: Polar se Back par spinner `pageshow` se reset.
- Basic, Pro+, Premium — guest aur logged-in — Polar checkout URL tak verified. Card charge abhi nahi.

### ANEXOChat UI (is session)

- Radix Select (native OS dropdown hata).
- Message actions collapsed menu. Hover-stretch theek.
- `Scene.tsx` dark-stage + sunny override.
- Compact tools: Tasks/Files `+` ke peeche (Lovable UI). Lovable source files no-touch rehte hain.

### Plan-feature steps 1–5 — GREEN (26 Sep 2026). Do not redo.

| Step | Status |
|---|---|
| 1 plan.ts = SQL | GREEN. basic=3, pro=5, business=30, business_pro=unlimited. |
| 2 Mailbox create + cap | GREEN. `POST /api/org/mailboxes`. Cap live tested. |
| 3 Storage on send | GREEN. `chat_ensure_workspace` → `storage_reserve` → `storage_commit`. Real send tested. |
| 4 Domains + aliases | GREEN. `org_id` on `mail_domains` and `mail_aliases`. `/api/org/domains` and `/api/org/aliases`. Cap tested. |
| 5 Shared-inbox assign | GREEN. Name, email, UUID, and clear proven. Frontend Assign control live on the server: Pro+ open, Basic `FeatureGate` chip, 403/404, spinner, `t()`. |

`ThreadHeaderActions.tsx` in this GitHub tree was not overwritten — the Assign control source was not pasted here. Do not rebuild it. Do not replace the server file with the older GitHub header.

### Abhi pending — yahi agla kaam

1. Plan-feature steps 7–8: thread-analytics restrict to Pro+, integrations and LEO Actions lock to Business+.

### 27 Sep 2026 — Step 6 GREEN. Do not redo.

Rust `:3200`, Tokio, WebTransport. Health `up`, transport `rpc` + `http3`. Thread `fadd90c3-054f-4455-8f9a-ecb0b8a0c6f1`.

- `work.notes.upsert` twice, same id `b7b534a5-661e-4a37-b0f1-a3f888ffddc1`, both `ok: true`. List shows one row, body `Manual upsert test - call 2, should overwrite`.
- `resolve_plan` canonical SQL, `dispatch_work` Pro+ gate, `work.tasks.create` / `work.tasks.list`, Basic wall 403. Frontend Tasks/Notes on the thread. Do not build a second notes API.
- Same session, also green: sender identity no longer stuck on `hello@`. DMARC null-byte crash fixed. Thread messages load (`mail_attachments` column). Tasks/Notes panel collapsed so it does not cover the mail. Inline reply collapsed on every plan. Quoted text collapsed for reading.
- 27 Sep 2026 thread actions: two buttons side by side, Reply and Forward. Reply opens with To = sender and the same subject. Forward opens with To empty, subject `Fwd: ` plus the original subject, body prefilled with From / Date / Subject / To and the original message. Do not rebuild.

### 27 Sep 2026 — E4 send and receive GREEN

Founder confirmed after the mail work: email goes out and email comes in. Do not reopen send or receive. Do not treat inbound as still open.

### 27 Sep 2026 — mail.thread on Rust. Do not redo.

Frontend calls Rust `:3200` first for the thread. If Rust is down or returns 404, Bun answers. The site stays up. Duplicate import removed. Deploy succeeded.

| Call | Backend |
|---|---|
| mail.threads, mail.search | Rust primary |
| mail.counts | Rust primary |
| mail.accounts | Rust primary |
| mail.labels | Rust primary |
| mail.star | Rust primary |
| mail.thread | Rust primary |
| mail.send | Bun |

Do not move `mail.send` onto Rust. Do not add a second thread client.

### 28 Sep 2026 — CRM Promises and Follow-ups GREEN

Rust `:3200` primary. Do not add a second list.

| Feature | Backend | Frontend |
|---|---|---|
| Promises | `crm.promises.list` — the list, not only a count | CRM Overview card |
| Follow-ups | `crm.followups.list` and `crm.followups.setDays`, plus the SQL functions. Days are configurable. Detection is automatic. | CRM Overview card and the days input |

Do not rebuild these cards. Do not replace the list with a count.

### 28 Sep 2026 — CRM Capture GREEN

A new inbound address that is not already a contact is detected as a lead. Newsletter replies and spam stay out. Gate is the existing `resolve_plan()` — every package above Basic. Do not add a second capture path.

| Check | Live proof |
|---|---|
| Auto-detection | `naumansherwani27@gmail.com` detected on its own |
| Confidence | `0.35` = base `0.25` + 1 message × `0.1` |
| De-duplication | Existing leads are excluded. No second record for the same email or domain |
| Source | `inbound_email` |
| Auto-enrichment | `suggested_company` is only a guess from the sender domain. It is not the lead's company. The test address was an example. |
| Dismiss | `ok: true`, then the row left the list |
| First-response timer | `first_mail_at` and `last_mail_at` come back for the countdown |

28 Sep 2026 frontend is green on the same seven points. Do not rebuild the card.

| Check | On the card |
|---|---|
| Auto-detection | Shown |
| Confidence | `35% match` |
| De-duplication | Existing leads stay one record |
| Source | `inbound_email` is on the payload. It is not printed as its own label on the card |
| Auto-enrichment | The card shows the domain guess. That guess is not a company name. |
| Dismiss | Not a lead button is live |
| First-response | `Reply within 2h` is on the live deploy |

### 29 Sep 2026 — CRM Memory (Relationships) GREEN

Do not rebuild. One person, one record. Rust `:3200` `dispatch_crm()`. Frontend calls Rust through `rpc()`.

| Layer | Technology |
|---|---|
| Data | PostgreSQL: `crm_person_timeline`, `recompute_contact_stats`, `crm_extract_signature`, `add_contact_alias` |
| API | Rust, Axum, Tokio |
| Identity | Existing `mail_identity()`. No second auth |
| Database access | Existing `sb_rpc`, `sb_select`, `sb_patch` |
| Frontend | React, TypeScript, TanStack Query: `useCrmPersonTimeline`, `useContactStats`, `useSetContactNotes`, `useAddContactAlias`, `useExtractSignature` |

| Point | Call | Status |
|---|---|---|
| 1 Unified timeline | `crm.person.timeline` | Green. Mail, meeting, task, deal in one order |
| 2 Relationship health | `crm.contacts.recompute` | Green. Active, cooling, or cold on the person |
| 3 Response pace | same recompute | Green. The whole contact, not one thread |
| 4 Signature facts | `crm.contacts.extractSignature` | Green. Empty signature returns empty. No invented phone |
| 5 Team context | — | No new feature. Business already shares org-scoped rows |
| 6 Person notes | `crm.contacts.setNotes` | Green. Separate from thread notes |
| 7 Merge identities | `crm.contacts.addAlias` | Green. A second address joins the same person |

### 6 Oct 2026 — Accept lead creates the contact. Do not redo.

Verified in the browser on Humza's account. Accept (`POST /crm/leads`) wrote `crm_leads` and `contacts` 0.27s apart. No contacts insert failure in the logs. Duplicate `23505` is ignored. Insert errors are logged.

Live API is PM2 `anexomail-leo` on port 3100, folder `/opt/anexomail`, file `/opt/anexomail/src/routes/crm.ts`. Restart with `pm2 restart anexomail-leo`. No build step.

`/opt/anexomail-web/server/routes/*.ts` is not the process on port 3100. A patch only there does not go live. Frontend stays `/opt/anexomail-web` (`anexomail-web`, `bun run build:bun`, then restart).

`contacts.display_name` stays empty when the lead comes from a mail suggestion, because the suggestion has no name. That is not a failed Accept.

### 7 Oct 2026 — CRM promises board GREEN

Do not rebuild. Test ran inside `begin` / `rollback`. After rollback the fake org and its promises were gone.

| Call | Result |
|---|---|
| `crm_promises_scan` | First call inserted 2. Second call inserted 0 |
| `crm_promises_board` | Phases `kept`, `late`, `broken`, `pending`, `suggested`. Sides `mine` and `theirs` |
| Side `theirs` | One row |

Rust `:3200` procedure `crm.promises.board`. `scan: true` runs `crm_promises_scan` for 30 days, then the board. Release build finished. Live file is `/opt/anexomail-rust/src/main.rs`. This repo's `server/rust/main.rs` does not contain `crm.timeline`, so the arm was not pasted into a file that cannot compile it. Do not add a second board.

### 9 Oct 2026 — CRM Loop steps 3–9 in code. Do not rebuild.

Docs already on GitHub `e5ffc00..0d820cb`. Build wrote 375 assets, including `app.crm.next`. Site `/health` 200. Fake-org tests rolled back. Humza and Masood data were not changed. Steps 3–9 show for every plan except Basic. Each page reads the database.

| Step | Page | Seen in the test |
|---|---|---|
| 1, 2, 7 | Already built | Do not redo |
| 3 Timeline | `/app/crm` person | Browser showed "Re: hi" |
| 4 Promises | `/app/crm/promises` | Humza: empty list |
| 5 Health | `/app/crm/health` | Humza: "Waiting for your reply (1)" |
| 6 Risk | `/app/crm/risk` | Humza: 1 item |
| 8 Graph | `/app/crm/graph` | Humza: "Individuals (1)" |
| 9 Next | `/app/crm/next` | Humza: "1. From Risk" |

The Loop shows 9 steps. Each link opens its own page. A name on the timeline opens Relationships. The Meeting filter shows the empty message.

Still open, do not mark done: the real Work-board Done button (`completed_at`), a live mail that says "I'll send the quote by Friday" so Promises can catch it, graph of who a teammate talked to (Business only, not built), and the old CRM Overview Promises card (`crm.promises.list`) which still labels committed promises as open. A Pro account that can open steps 3–9 is not in hand. The owner has not yet pressed Ctrl+F5 on these pages.

### 11 Oct 2026 — remaining work. One list. Do not open a second. (Renumbered 12 Oct 2026 per founder's updated list — three new items inserted into A, three into B, five into C; everything after shifted. Statuses re-checked against this session's live verifies and prior founder-confirmed screenshots — not re-guessed.)

Status words: DONE, READY, TODO. Goal: signup, then address, then send, then receive, in as few steps as the buyer needs.

14 Oct 2026 — founder: baqi sab kaam isi list mein, aur end mein sirf yehi list green hogi (koi dusri list nahi). Naye items `a/b/c` suffix ke saath apni jagah par daale gaye hain taake 1–42 ke purane hawale na tootein. Tarteeb upar se neeche (A, B, C ...), har number ke baad uske `a/b/c`. Server ka sach server par hai (AGENTS.md Rule 15): jahan "live" likha hai woh server ke asli output se hai.

**Chalne ki tarteeb (founder, 14 Oct 2026, LOCKED):** 1) User side — saare user wale kaam apne number ke mutabiq (#3, #7, #7a, #8, #10, #13, #14–#35, #37–#39). 2) Founder side — `[FOUNDER]` tag wale: #3a, #11, #12, #36, #36a. Sirf Rust (tRPC, async/Tokio, UDP/QUIC/WebTransport); koi naya Bun/Node code nahi. 3) ANEXOChat — #40a, #40. 4) Sab se aakhir mein `ai.anexomail.com` (#41) — codes wahi, sirf AI wala hissa. #42 (F) founder ke apne zimme. **Founder protocol (founder side ka poora detail — kaun sa UI, kaun se addresses, kya kaise chalega) user website mukammal hone ke BAAD, full detail ke saath banega; us se pehle founder side ka koi code nahi.**

DONE this session, do not redo: domain system A (database), B (Rust, live DNS 5/5), C (inbound on a company address). Company-address mailbox cap and address re-create (smoke 17/17).

**A. Mail product**

1. DONE — founder screenshot confirmed (11 Oct 2026). Founder and public split: `resolved@` taken out of the basic org, `founder_accounts` SQL output used.
2. DONE — Gmail Show Original: SPF PASS, DKIM PASS (d=mailtest.axonetis.com), DMARC PASS (11 Oct 2026). Send from a company address, thread in Sent.
3. DONE (14 Oct 2026, founder ke server ka live output) — SECURITY. Founder ki apni list ka #3: `/accounts` company addresses + `/schedule` identity org-check + worker ka hello@ fallback. Live: `PATCHED`, `brain /health 200`; `lib/identity.ts` ne asli DB par founder org = `naumansherwani.founder@`, `resolved@` aur system org = `hello@`, `naumansherwani.founder@` diye, `billing@ allowed: false`. Ab `/schedule` mein From sirf user ke jaiz addresses se, aur worker queue ke purane rows ko bhi dobara jaanchta hai. Backup `/opt/anexomail/backups/e3-1791931841748/`. Installer: `docs/cursor-work/server/e3-identity-install.mjs`. Note: `/send` (fallback) abhi identity ignore karta hai aur org ka pehla mailbox uthata hai — woh #7 mein theek hoga.
    3a. TODO. [FOUNDER] Founder ke 6 addresses ek org mein (data). 14 Oct live: founder org `56592e36…` hai (E16 se `resolved@` wahan gaya). Lekin `mailboxes` mein `hello@` aur `naumansherwani.founder@` org `dbd5aef3…` mein hain, aur `billing@`, `leo@`, `moveyourbusiness@` ka `org_id` NULL hai (kisi inbox mein nahi dikhte). `mail_accounts.hello@` bhi `dbd5…` mein. Naya SQL `E29_…` (E16 ka tareeqa: mailbox + uske threads + bachhi rows). Pehle ek read-only query (org members, thread counts). #7 aur #11 isi par tikay hain. Founder protocol ke saath, user website complete hone ke baad.
4. DONE (12 Oct 2026). Test accounts for Basic, Pro, Business and Business Pro, four packages. Pro/Business Postfix routing fixed; Business Pro got a real account (auth.users + identities + organisations + mail_accounts + trial_accounts, plan=business_pro, mirrored off `pro.test`'s real row shape), confirmed with `postmap`.
5. DONE (12 Oct 2026). New buyer signup creates workspace, member, and trial plan in Rust — `account.signup.address/start/claim` RPC + `trial_provision_workspace` SQL (E17). Live-verified with a real fresh auth user: GoTrue login -> handle check -> start -> claim -> `organisations`/`mail_accounts`/`org_members` auto-created, confirmed in the database. Frontend `/claim` repointed to the real RPC (personal kind; business kind unchanged, still goes through `/onboarding`'s own domain flow). Caught and fixed live during this test: GoTrue rejects a manually-inserted `auth.users` row with NULL token columns (500 "Database error querying schema") — fixed by setting them to `''`; and `trial_events_event_type_check` did not allow `workspace_provisioned` — fixed by widening it, same E17 file (SQL fail rule).
6. DONE (12 Oct 2026). That buyer gets their own `@anexomail.com` address and Postfix syncs it — confirmed via `postmap -q` after the auto-sync cron ran. With 5. (The cron's own reliability bug — fragile env-sourcing plus a `%`-escaping regression — was fixed earlier this session and is the foundation this relies on.) Verified end to end over the real public route too: `https://anexomail.com/rpc/account.signup.address` through Caddy to Rust, both a flat body and the exact `{"input": {...}}` shape the frontend's `rpc()` client sends.

   13 Oct 2026 — the human click-through finally happened (founder tried a real signup, legal name "Ali Khan", classic `/auth` signup form). It surfaced a real bug, not in 5/6's Rust claim path but in the older classic signup gate: `signup_device_gate()` (written in phase63/F3A, 12 Oct) was hard-blocking new signups with a pre-auth 403 ("This device already has accounts") once the coarse device-shape hash crossed 3 accounts. That directly violated the already-locked Phase 24A rule ("Engine khud kisi ko block NAHI karti" — engine must never auto-block, only mark suspicious, human decides warn/block) and duplicated `device_vault_register()`, which already marks a device `suspicious` without ever blocking — a Rule 6 duplicate-system violation. Fixed in `docs/cursor-work/sql/E18_signup_device_gate_nonblocking.sql`: removed the automatic account-count block entirely; the gate now only turns away a device a human has already confirmed banned (`device_bans`). `server/routes/auth.ts` updated to match (dead `too_many_accounts` branch removed). Status: DONE (13 Oct 2026) — `server/routes/auth.ts` deployed (`web /health 200`, pm2 restart confirmed), `E18_signup_device_gate_nonblocking.sql` run in Supabase, founder confirmed success on both.
7. READY. Compose From selector, company address in its own colour. After 3. 6 choices: 5 company addresses + founder, real wire. Spec: `docs/cursor-work/founder/mail-identities-locked-2026-10-14.md`. (14 Oct: code likha — Rust `mail.identities` + Compose 'Send from' selector, har address apne rang ke dot ke saath; installers `docs/cursor-work/server/e7-rust-install.mjs` / `e7-web-install.mjs`. DONE tab jab founder browser mein selector dekhe aur ek asli send test ho. `/send` fallback ka identity-ignore masla abhi baqi.) 15 Oct 2026 live (founder ke server ka output, test account `pro.buyer`, plan pro, Business workspace): Rust `mail.identities` = `pro.buyer@anexomail.com` (login); `/schedule` apne address se 200 + id; kisi aur ka address 403 `identity_not_allowed`; worker ne Postfix se bheja (`mail.log` queue active); `mail.threads` mein subject sent aur inbox dono mein (send + receive Pro par chali). Browser mein 'Send from' selector dikhna abhi baqi, isliye READY.
    7a. DONE (14 Oct 2026, founder ke server ka live output). Domains A, B, C: DB functions maujood (`org_domain_add/list/set_checks/set_dkim`, `org_address_create`, `org_mail_sync_state`); Rust :3200: live binary repo ke `main.rs` se bani (diff match) aur `mail.domains.*` ne `mailtest.axonetis.com` asli verify kiya (pehle '401 = maujood' likha tha — woh tareeqa ghalat tha, token ke baghair har naam 401 deta hai); `mailtest.axonetis.com` verified (txt/mx/spf/dkim/dmarc sab `t`) aur `info@mailtest.axonetis.com` active; cron `anexomail-sync-domains` + `anexomail-sync-maps` installed. E (Compose From + Inbox label) #7 mein. Live code mein `hello@` auto-reply, billing receipt, domain wizard, MailRail Founder section — kuch nahi (grep 0).
8. READY (16 Oct 2026, code likha, server par install + browser dekhna baqi). Domain wizard, three scenes, DNS ticks, copy buttons. After 7. Yeh founder ki list ka hissa D hai — baqi A/B/C/E 7a mein DONE. Naya page `/app/domains` (Business account type, Pro ko bhi): `src/lib/domains.ts` + `src/routes/app.domains.tsx`, sirf Rust `mail.domains.list/add/verify/remove` aur `mail.addresses.list/create/remove` par (Bun fallback nahi; backend E15 pehle se). Qadam 1 domain naam, qadam 2 paanch DNS records (TXT ownership, MX, SPF, DKIM, DMARC) har Name/Value par Copy button + Namecheap / GoDaddy / Cloudflare hidayat, qadam 3 live ticks (har 20s auto-check, max ~10 min, phir 'Check now'). Verified domain par Addresses form (Mailbox / Shared / Alias, cap Rust se: mailbox_cap + 'aliases free'); har server error code ka insani text; remove par confirm. Rail + Cmd+K mein 'Domains' (Business kind ko; founder host par nahi), dashboard ka domain badge ab 'Connect your domain' / 'Finish setup' link, mail rail 'No address yet' ab isi page par le jata hai, purana khali `/app/admin/addresses` ab redirect. Personal account ko `surfaceDenial` ('Company domains are on a Business workspace') — E15 `business_required` ke mutabiq. Installer: `docs/cursor-work/server/i8-domains-install.mjs` (generator `i8-build-installer.py`), sirf web, anchor-gated, backup + restore.sh, build fail = sab wapas. DONE tab jab founder ke server ka output green ho (add -> 5 records -> verify -> address) aur browser mein page dikhe. Spec: `docs/cursor-work/founder/mail-identities-locked-2026-10-14.md`.
9. DONE — founder screenshot confirmed (11 Oct 2026). Mail cinema UI.
10. READY. Repo and server sync for the thread route and live-only files — done on side branch `wip/e15-ui`, not on `main` yet (needs founder's "repo update"). 14 Oct: ek aur live-only file mili — `/opt/anexomail/src/lib/plan.ts` (Brain `routes/mail.ts` isko import karta hai, repo mein nahi). Mirror karni hai. 14 Oct sha: live `routes/mail-compose.ts`, `routes/mail.ts`, `mail-worker.ts` teeno repo `main` ke barabar hain (isliye in par patch main se banta hai). Side branch `wip/e15-ui` purani aur main se bahut door hai — merge nahi karni.
11. TODO. [FOUNDER] MailRail: founder inbox and company inbox in separate sections. Founder -> `naumansherwani.founder@` only; Company -> 5 addresses unified with address badge. Founder ka UI/UX alag. Spec: `docs/cursor-work/founder/mail-identities-locked-2026-10-14.md`.
12. TODO. [FOUNDER] `hello@` auto-reply, Option C. No ticket number. Exact template aur loop-guard spec file mein. 14 Oct audit: `leoSupportPipeline` (user accounts ka LEO) alag cheez hai; `hello@` ka fixed Option C reply nahi bana. Spec: `docs/cursor-work/founder/mail-identities-locked-2026-10-14.md`.
13. TODO. `billing@` receipt on payment success. Polar engine `:3400` — no touch. Content: plan name, amount paid (asli Polar charge), date, next billing date, "Your workspace is now active", invoice ID. Plan/price card spec file mein. Trigger Polar engine ke bahar (settle/entitle ke baad), engine ko haath nahi. Spec: `docs/cursor-work/founder/mail-identities-locked-2026-10-14.md`.

**B. Plans and data**

14. TODO. Business Pro support 12h. Move it as an E-series file. Do not touch `polar.ts`.
15. READY. `workspace_plans.mailboxes_included` for Business Pro is 1. That number is wrong. (14 Oct: asli cap `storage_plans.mailbox_limit` = NULL = unlimited, `org_mailbox_cap('business_pro')` = NULL — sahi hai; galat sirf `workspace_plans` ka 1. Fix `docs/cursor-work/sql/E27_business_pro_mailboxes_unlimited.sql` (column nullable + NULL), seedha psql se chalta hai; DONE tab jab founder ka psql output green.) (14 Oct live: `workspace_plans` = basic 3, pro 5, business 30, business_pro 1. Cap ka asli source `storage_plans.mailbox_limit`, NULL = unlimited. Fix seedha psql se.)
16. READY. Copy limits from SQL into `plan.ts`. Drift is the risk. (14 Oct live: `plan.ts` ke numbers SQL se match karte hain — basic 3, pro 5, business 30, business_pro unlimited. Live file ab repo mein `server/lib/plan.ts` (hu-ba-hu copy, deploy-brain isko nahi chhoota). Chhota drift: `workspace_plans.storage_per_mailbox_gb` business_pro 1000 hai, `storage_plans`/`plan.ts` 1024 GB — sirf billing page ka display text, abhi chhua nahi. DB ka business_pro = #15.)
17. TODO. Test-account mailboxes are in `mail_accounts`, not `mailboxes`, so the mailbox cap was not really tested.
    17a. READY. Storage preflight mail-send flow mein: live `mail-worker.ts` mein Step 3 `storage_reserve` + `storage_commit` laga hai. Asli send test (reserve -> send -> commit) green nahi chala, isliye DONE nahi.
    17b. TODO. Brain mail-worker log spam: `chat_ensure_workspace failed: chat_not_entitled` (Basic/Pro ke paas chat nahi, yeh expected hai) — error ki jagah chup skip.
18. TODO. Thread analytics Pro+ only — backend `403`, chip on Basic, insights call must not fire. (14 Oct: backend ready — Rust `mail.thread.insights` Basic ko 403 deta hai; baqi sirf UI: Basic chip + insights call na jaye.) Steps 5 (assign) aur 6 (tasks/notes) purani record ke mutabiq GREEN hain (18a/18b); is item mein sirf Step 7 (insights) baqi hai, Step 8 = #19. Poora spec founder ki file mein. Spec: `docs/cursor-work/founder/mail-identities-locked-2026-10-14.md`.
    18a. DONE (27 Sep 2026 purani session record, "Step 6 GREEN, do not redo"; 14 Oct ko galti se TODO likha gaya tha). Rust `work.notes.upsert` / `work.tasks.create` / `work.tasks.list`, `dispatch_work` Pro+ gate, Basic ko 403, thread par Tasks/Notes panel (collapsed). Dobara mat banao. #20 mein `pro.buyer` se sirf gate dekhna hai.
    18b. DONE (26 Sep 2026 purani session record, "Step 5 GREEN"; 14 Oct ko galti se READY likha gaya tha). `POST /api/mail/thread/:id/assign` — naam, email, UUID aur clear sab proven; frontend Assign control server par live (Pro+ khula, Basic par FeatureGate chip, 403/404, `t()`). `ThreadHeaderActions.tsx` repo se overwrite NAHI karna (server wali alag hai). Dobara mat banao.
    18c. TODO. 18b ka Rust `/rpc` proc (Rust-first rule), Bun sirf fallback.
19. TODO. Integrations and LEO Actions — Business+ only. (14 Oct: server pe `integrations.ts` aur UI `app.integrations.tsx` dono mein koi plan check nahi. Rust gate proc + UI wall banana hai.)
    19a. TODO. Free-alias cap (`plan.ts` `freeAliases`): E15 mein aliases ginti se bahar hain, koi limit lagti hi nahi. Cap SQL + Rust address-create mein check.
20. TODO. A real card charge: checkout URL is green, but money actually being taken and the workspace going active is not confirmed yet.
    ASLI TEST KI TARTEEB (founder, 14 Oct — LOCKED): pehle BUSINESS packages, is tarteeb se: 20.1 Basic -> 20.2 Pro -> 20.3 Business -> 20.4 Business Pro. Har ek: asli signup -> checkout (card) -> `/dashboard` active -> mail send + receive -> us plan ke limits/gates (#17, #18, #19). Ek plan green hone par hi agla. Personal packages (Personal Basic, Pro+, Premium) in chaaron ke BAAD. **Real test account (founder, 14 Oct): asli buyer flow (auth -> Business -> claim/onboarding -> /plans), sirf payment skip.** Payment ki jagah ek `entitlement_state` row (plan, active_until +31 din); E23 trigger `activate_paid_account` account ko wahi active karta hai jo asli payment karta. **Account agent khud SQL se banata hai, browser signup nahi:** `docs/cursor-work/sql/E28_seed_buyer_test_account.sql` (auth user + profile + claim + organisation/domain + mailbox + entitlement; handle/plan/domain variable, ek dafa chalta hai, galti par rollback; sandbox mein Postgres par green). Baqi sab (limits, gates, mail) plan table aur repo features ke mutabiq. `pro.test` purana manual account hai, naya real wala alag handle (`pro.buyer`) se. Tarteeb ke bahar kaam (E18–E27) is ke andar dakhal nahi dete.
    14 Oct 2026 — adjacent work done outside the numbered order at the founder's direct request, all recorded as E-rows above: E20 (pending_plan lockout, DONE), E21 (plan-kind filter + convert, READY), E22 (package change = full price, old closed, READY), E23 (payment ke baad account active, READY), E24 (account delete system, READY). None of these makes #20 DONE: a real card charge and plan activation after payment is still unverified.
    20a. READY. E22 + E23 + E24 ka live verify: package-change ka asli upgrade, payment -> `/dashboard`, delete ka dry-run test account par. Code live hai (14 Oct founder output: Rust binary mein `account.delete.request`, Brain route 401, web 200); verify baqi.
    20b. TODO. E25 — Tokio loops: payment-intent settle sweeper, deletion-due watcher (details neeche E25).
    20c. TODO. E26 — WebTransport push `/checkout/done`. 14 Oct gate: HTTP/3 aur UDP 3443 listening hain; asli WT session ka sabut baqi.

**C. CRM**

21. TODO. Founder presses the real Work Done button. `completed_at` must fill.
22. TODO. Founder sends "I'll send the quote by Friday", then opens Promises.
23. TODO. Teammate graph. Business only. Not built.
24. TODO. Overview Promises card shows a committed promise as "open".
25. TODO. A Pro account that can open Loop steps 3–9. After 4. (15 Oct: `pro.buyer@anexomail.com` ban gaya — Pro plan, Business workspace, E28 SQL se, password server par `/root/test-accounts/pro.buyer.pw`; CRM pages ka browser check baqi.)
26. TODO. E5 — push replies through Rust. Thread detail is already on Rust.
27. TODO. E6 — People, Rust contacts.
28. TODO. E7 — Calendar, Rust reminders.
29. TODO. E8 — the rest of Work on Rust. Thread notes are already green.
30. TODO. E12 — CRM flagship. Screens are green. After E6.
    30a. TODO. CRM ideas jo founder ne paste kiye (follow-up reminder, lead temperature, deal-stuck warning, per-person timeline, relationship health, response pace, signature facts, person notes, duplicate merge, natural search, apne wade). Sirf record — founder ke kehne par, E12 ke baad.

**D. Founder browser checks**

31. TODO. Every CRM page from each plan's account. Ctrl+F5.
32. TODO. Basic 11-point checklist.
33. TODO. Undo send 30s hold, Cmd+K, plan gating.
34. TODO. Business Pro card promises (8K, QUIC, AV1, p50/p95/p99) are names in code only.

**E. Later**

35. TODO. Import old mail from Gmail or Outlook.
36. TODO. [FOUNDER] Founder host `founderworkspace.anexomail.com`.
    36a. TODO. [FOUNDER] Founder-side email addresses aur mailboxes (founder ke apne addresses/mailboxes): scope `founder_accounts`, `mail_accounts`, `mailboxes` ke asli rows dekh kar tay hoga (psql output founder se). #11 aur #17 se juda.
37. TODO. Spreadsheet. Never built. Ask the founder before starting.
38. TODO. Docs: test accounts, four packages, env names, Masood's real plan, SLA finding.
39. TODO. The full Zoho three-panel look. Mail cinema and the From selector do not complete this on their own.
40. TODO. [CHAT] Chat Phase 32+. Only when the founder pastes `## PHASE N`.
    40a. TODO. [CHAT] ANEXOChat Phase 1–31A live wire: server pe asal kya chal raha hai (pm2 `anexochat` online) pehle audit-by-command; phir jo wire nahi woh. Phase 32+ phir bhi sirf founder ke paste par.
41. TODO. [AI] LEO only on `ai.anexomail.com`.

**F. Security — founder only.** Do not write secrets into the repo. Plaintext passwords in `.env`, public repo to private, revoke the old Supabase token, rotate the database password that appeared in chat, rotate test passwords, set Git to the real email. Secrets never in the repo.
42. TODO. (Same item as F, numbered to match the founder's list.)

### 13 Oct 2026 — live-caught bugs, found after this list was locked (Rule 14: naya kaam yahan list mein pehle, tarteeb ke 1–42 mein chupke se nahi daala — founder decide karega kahan fit hota hai)

- **E19 — password reset sent a raw Supabase link.** Founder live-tested "forgot password" and got mailed `https://<project-ref>.supabase.co/auth/v1/verify?...` — the backend vendor's own domain, shown to an ANEXOMAIL user. Root cause: the code already had a branded link system (`account_recovery_tokens` → `https://anexomail.com/auth?mode=reset&recovery=...`) but it was wired as the *error fallback*, not the default, so the normal/success path mailed Supabase's raw link instead. Fixed: `server/routes/auth.ts` `/forgot-password` now always issues its own token (rate-limited, 5/hour) and mails only the branded link; `/reset-password`'s token branch now claims atomically (`consume_password_reset_token`), closing a SELECT-then-UPDATE race. SQL: `docs/cursor-work/sql/E19_password_reset_hardening.sql`. Status: **READY** — in the repo (committed to `main`), Supabase paste + server deploy + live re-verify (send reset, confirm only the `anexomail.com` link appears, click the same link twice and confirm the second attempt is rejected) still pending per Rule 5.

- **E20 — real personal signup showed as a free trial with a fabricated "Personal Basic" label.** Founder's own live test (legal name "Ali Khan", real signup, zero payment) landed on `/dashboard` reading "Personal Basic" + "47h 56m left in your trial" — a paid-tier name and a countdown for an account that never chose or paid for anything. Root cause, two independent "default to basic" bugs: (1) `server/routes/auth.ts` `/signup` unconditionally ran `trial_start()` on *every* signup (business or personal) — no code path anywhere in the product deliberately starts a free trial, so this legacy Phase 32 plumbing call alone mislabelled every real signup as "trial"; (2) `personal_workspace_label()` (E2) and the session endpoint's `workspace_plan` both silently fell back to `'basic'` whenever no real plan existed anywhere (no family/trial/entitlement row), so "chose nothing" and "chose Basic" rendered identically. Fixed, without touching the Phase 32 lifecycle used elsewhere (business accounts, `/trial-ended`, AI hard-zero gating all unchanged): new `trial_accounts.status = 'pending_plan'` (claimed, no plan chosen/paid yet — no countdown, no business_data, no AI, exactly like before for every *other* status); `ensure_trial_account_row()` replaces the `trial_start()` call at signup; `personal_workspace_label()` now returns `NULL` instead of faking `'basic'`; new `has_chosen_plan` signal on the session so the dashboard label reads "Choose your plan" instead of lying. Frontend: `/claim`'s personal branch now redirects to `/plans` instead of straight to `/dashboard` (founder's described flow: claim → choose package → Polar checkout → payment → back to `/dashboard`, where billing then shows the real plan — `PlanCheckoutButton`'s existing "signed-in personal → /dashboard" return-to rule already does the rest, untouched); `/app`'s layout now bounces a `pending_plan` account straight to `/plans` too, so it can never be reached by a direct link. A one-time SQL backfill also moves the founder's already-created "Ali Khan" test account (and any other pre-existing victim) out of the fake trial state immediately. SQL: `docs/cursor-work/sql/E20_personal_plan_pending.sql`. **Known, separate, pre-existing gap this does NOT close** (already tracked as item #20 above): the Polar webhook that actually completes a charge and flips `trial_accounts.plan`/`entitlement_state` to the real paid plan is still not wired — so after a real payment, the account will correctly stop looking like a fake trial, but will only show its *real* chosen plan once #20 is done. Status: **DONE** — Supabase SQL run, server deployed, `web /health 200`, and both behavioral checks live-confirmed by the founder (13 Oct 2026): (1) Ali's account lands on `/plans`, not `/dashboard`; (2) a `pending_plan` account cannot open `/dashboard` at all until a plan is chosen/paid for — `/app`'s layout bounces it back to `/plans` every time, exactly the behavior a real (non-test) user will see too.

- **E21 — a personal account could see and buy a Business-kind package, and vice versa (founder, 13 Oct 2026).** Founder: a personal-kind account should only ever be offered personal packages on `/plans`; after a first payment it should get a smooth way to move between personal tiers or into a business package, same email. Investigation found the pieces half-built: `/plans` already had a Personal/Business toggle (default Personal) but it was a plain click-toggle, not tied to the signed-in account's kind — anyone could flip tabs and buy the wrong kind of package; `server/routes/billing-sync.ts` already had an `enforceAccountKind()` 403 gate wired, but it was inert because no product in `server/config/billing-products.ts` ever carried the `accountKind` field it checks; `/app/billing` already showed personal-kind accounts their correct 3-tier "Your personal tiers" upgrade strip, but *also* unconditionally rendered the 4 generic Basic/Pro/Business/Business Pro cards underneath for everyone, personal included. **Fixed now (frontend + one metadata field — no Polar/webhook code touched):** `billing-products.ts` — added `accountKind?: "personal" | "business"` to the six personal-tier product entries only (business products deliberately left untagged so the existing ABSM guest-checkout flow for business plans keeps working); this activates the already-wired `enforceAccountKind()` 403 as real, server-side enforcement. `src/routes/plans.tsx` — a signed-in account's own `account_kind` now locks the page to that kind and hides the toggle entirely (guests/not-signed-in keep the full toggle, unchanged). `src/components/site/PlanCheckoutButton.tsx` — new `requireSignIn` prop on `CheckoutButton`; personal-tier cards pass it so a guest clicking "Get started" on a personal product is sent to `/auth?mode=signup` instead of hitting the new 403 as a raw error string. `src/routes/app.billing.tsx` — the 4 generic plan cards now only render for `kind !== "personal"`; personal-kind accounts see only their own 3-tier strip (the Monthly/Yearly cycle toggle stays visible either way since it also drives that strip's prices). **Also built, same ask ("100% sab, ek bhi point spare nahi"):** `src/components/site/ConvertToBusiness.tsx` — a personal account can switch to a business workspace, same sign-in, no new signup, shown on `/plans` and `/app/billing`; it deliberately reuses the exact two backend calls the existing business-onboarding flow already makes (`POST /api/workspace/organisations` + `POST /api/auth/onboarding/complete` — no new backend route, no SQL, no Polar code), then refreshes the session so every kind-gated section above reacts automatically. Honest caveat (not a new risk, but newly exercised): this is the first time that existing org-creation code runs against an account with real mail/contacts/calendar history rather than a fresh signup — worth a real test before trusting it live. Doc: `docs/cursor-work/frontend/e21-plan-kind-filter.md`. **Known gap, now closed (13 Oct 2026 night):** the personal-tier "Upgrade" button used to open a brand-new Polar checkout instead of changing the existing subscription in place. Once the founder pasted the real `polar_subscriptions` schema (the one thing missing), built `POST /api/billing/change-plan` (`server/routes/billing-sync.ts`): for a personal account with an existing active subscription, calls Polar's own documented mechanism (`PATCH /v1/subscriptions/{id}` with the target `product_id`, `proration_behavior: "prorate"`) — changes that subscription in place, no second subscription, Polar handles proration; for a first-time purchase (no active subscription yet) it falls back to the exact same checkout-opening code `/intent` already uses (refactored into a shared function, no duplicate logic). After a successful change it also updates `entitlement_state.plan` and the local `polar_subscriptions` row directly (narrow, single-column writes) so the billing page shows the new plan immediately rather than waiting on the Rust payment engine's own webhook handling. `src/components/site/PlanCheckoutButton.tsx` gained a `changePlan` prop wired on both `/app/billing`'s "Upgrade" button and `/plans`' personal cards. Doc: `docs/cursor-work/frontend/e21-plan-kind-filter.md` has the full writeup, including the two honest residual risks flagged there (the exact billing-moment difference between Polar's `prorate` vs `invoice` proration modes wasn't fully documented on their guide page, and this is the first code in the repo writing directly to `entitlement_state`/`polar_subscriptions` outside the existing webhook/intent-confirm path) — both reasoned from code already read, not guessed, but worth a careful first live test. **Part 4 (14 Oct 2026, founder screenshot of the internal `/app/billing`, not `/plans`):** the "All plans" grid there showed the 4 business-priced cards relabelled "Personal X" with a false "Current". Fixed: `personalLabel` removed; a personal account now sees its personal tiers plus a "Business plans" block with the 4 real plans and a **Convert to Business** button (same sign-in/email, `ConvertToBusiness` then `/api/billing/change-plan`, in place, converts once and never creates a second organisation); a business account sees its 4 real plans with in-place Upgrade. `/change-plan` now accepts workspace plans too (403 `convert_to_business_first` for an explicitly personal account); shared `openPolarCheckout()` helper (Rule 6). **Superseded by E22 (founder rule: new package = full price, old closed):** the in-place PATCH/prorate in `/change-plan` was removed — see E22. Status: **READY** — all 4 pieces of E21 built, in the repo, server deploy + live re-verify (especially a real upgrade on a test account with an active subscription, checked directly in Polar's dashboard that it's one subscription not two) still pending per Rule 5.
- **E22 — package badalna = naye plan ka poora price, purana plan band (founder rule, 14 Oct 2026).** No proration/credit. `/change-plan` (Bun fallback) opens a normal full-price checkout and records the subscription it replaces in `polar_plan_replacements` before handing out the URL; a new isolated `replace_loop` in the Rust payment engine (`server/rust/polar-payment/main.rs`, additive) revokes exactly that old Polar subscription only after the new product's subscription is active; abandoned checkout leaves the old plan untouched. `docs/cursor-work/sql/E22_plan_replacement.sql` also changes `polar_billing_state()` ordering (active rows first) so the revoked old row doesn't show on the billing page. Removes the seat-based → Business Pro limit. Doc: `docs/cursor-work/server/e22-plan-replacement.md`. Verified live (13 Oct 2026, founder-pasted evidence): live engine `main.rs` == repo (`diff` clean) before deploy; E22 SQL run — `polar_plan_replacements` exists (empty) and `polar_billing_state()` definition check = `true`; Rust engine built (`cargo build --release` Finished) + deployed, `/health` + `/ready` green, its `replace:` warnings stopped once the table existed (loop running); web redeployed (`web /health 200`, new `app.billing` bundle). Found by live test: `not_found` on Upgrade = the Brain (`anexomail-leo` :3100) was still on old routes, and `deploy-brain.sh` never synced `server/config/billing-products.ts` — fixed in `deploy-brain.sh` (config sync + backup + diff print); Brain deploy via `bash server/deploy-brain.sh` pending founder run. Also fixed: endless "Opening secure checkout…" spinner after Back (`PlanCheckoutButton`, pageshow reset + 20s timeout). NOT verified: a real upgrade end-to-end (pending row -> payment -> old subscription revoked -> billing page). Live checkout needs a real card, so that test is the founder's call (a 100%-off Polar discount code would allow it without a charge — founder to decide). Status: **READY**, not DONE (Rule 5). Test plan without a real charge (14 Oct 2026): a Polar 100%-off, Forever, single-use-style discount code limited to two monthly test products and expiring soon; two free checkouts on a test account (first purchase, then upgrade) exercise `pending` row -> old subscription revoked. Known and intentional: a £0 payment makes `billing_intent_confirm` raise `payment_amount_mismatch` (guard stays), so the billing page will not show the new plan in that test — that part needs one genuine paid upgrade.

- **E23 — payment ke baad account khud active (14 Oct 2026, #20 ka wire-gap).** `docs/cursor-work/sql/E23_payment_activates_account.sql`: `entitlement_state` par trigger `pending_plan`/`trial` account ko `trial_subscribe` se active karta hai; `trial_activate_if_paid()` sirf verified entitlement dekhta hai. `/api/trial/subscribe` pehle kisi bhi non-empty `payment_ref` par plan de deta tha (security hole) — ab client ka plan/ref ignore. Technology (founder correction, 14 Oct): activate + settle ab Rust :3200 `/rpc/account.signup.activate` + `/rpc/billing.settle` PRIMARY, Bun fallback; open-checkout ka Polar pull abhi Bun (Polar :3400 `read_checkout` sirf status deta hai, engine no-touch — amount/product expose karna founder ki ijazat par). `/checkout/done` settle ka intezar karke redirect karta hai. Doc: `docs/cursor-work/server/e23-payment-activates-account.md`. Status: **READY** — Supabase SQL run, web deploy, `deploy-brain.sh` aur naye signup se asli payment-to-`/dashboard` verify baqi (Rule 5).
- **E24 — account delete system (founder request, 14 Oct 2026).** Self-service: Account page par "Delete account" (typed-email confirm) -> `account_deletions` mein 7 din ka grace, beech mein cancel ho sakta hai. Purge (`account_purge`) sirf founder SQL Editor se chalta hai, default dry-run (asli deletes chala kar rollback). Founder account, aise org jis mein dusre members hon, aur active Polar subscription block karte hain. Test accounts/orgs (axonetis samet) isi se saaf honge; Ali ka account founder baad mein kehne par. Technology: Rust :3200 tRPC `/rpc/account.delete.{state,request,cancel}` PRIMARY (`server/rust/main.rs`), Bun `/api/account-deletion/*` fallback, truth PostgreSQL; purge SQL-only, no WebTransport/Tokio loop on purpose. Files: `docs/cursor-work/sql/E24_account_deletion.sql`, `server/rust/main.rs`, `server/routes/account-deletion.ts` (+ mount in `server/index.ts`), `src/routes/app.account.tsx`, `server/mail/remove-address.sh` (mail sync cron sirf ADD karta hai, isliye purge ke baad Postfix line + Maildir alag se hatana padta hai; script dry-run default, Maildir MOVE karta hai). Doc: `docs/cursor-work/server/e24-account-deletion.md`. Purge 7 append-only ledger tables ko sirf apni transaction ke liye unlock karta hai (unke triggers cascade delete ko bhi rokte hain) aur auth user delete hote hi wapas lock. Local Postgres par repo ki asli SQL ke saath test hua (dry-run rollback, sole-org purge, dusre org salamat, ledger re-lock, unknown trigger par clean fail); live nahi. Status: **READY** — Supabase SQL run, Rust deploy (`server/rust/deploy.sh`, cargo build server par pehli baar), web + `deploy-brain.sh`, aur Ali par live dry-run baqi (Rule 5). Ali ka account abhi delete nahi hoga.
- **E25 — Tokio background loops (founder ka sawal, 14 Oct 2026).** TODO. (a) Rust :3200 `tokio::spawn` payment-intent settle sweeper (`paid`/`stuck` -> `billing_sync_claim` + `billing_intent_confirm`) taake settle Bun cron ya user ke khule page par nirbhar na rahe; (b) deletion-due watcher (grace khatam hue accounts flag + alert; purge manual). Polar "open" pull ke liye :3400 `read_checkout` badalna padega — founder ki ijazat.
- **E26 — WebTransport push (14 Oct 2026).** TODO. `/checkout/done` par polling ki jagah "plan active" push; pehle WT ka live green hona (`rust-gate.sh`) verify.

### 15 Oct 2026 — pro.buyer ka asli login UX review (founder ke 4 screenshot + code). Rule 14: naya kaam pehle list mein; sab TODO; founder decide karega tarteeb mein kahan.

`Command center` founder-side nahi: yeh user Dashboard (`/app`, Phase 6) ka chhota heading hai — `src/components/app/dashboard/Greeting.tsx`. Founder cheezein (`/app/founder`, Admin, Speed) rail mein sirf founder host par dikhti hain (`railItemVisible`).

- **U1. READY (E30, live verify baqi). Dashboard ke numbers galat.** Screenshot: ek mail bheji + ek receive hui, dashboard `Received 0 / Sent 2 / Delivered 100%`. Wajah (code): `server/routes/dashboard.ts` `/analytics` direction ko `"inbound"` se milata hai, jabke DB check constraint `direction in ('in','out')` hai (phase52) aur Rust bhi `in`/`out` — isliye har aane wali mail `Sent` mein ginti hai, `Received` hamesha 0. `Delivered` hard-coded hai (`delivered++` har outbound par) — bounce hui mail bhi 100%. Fix: `in`/`out`, aur Delivered asli status se (nahi pata to `—`, jhoota 100% nahi). Live psql se confirm baqi (`select direction,count(*) from mail_messages group by 1`).
- **U2. READY (E30, live verify baqi). Storage tile plan se nahi.** Pro par `0 GB / 30 GB`; plan table: Pro = 10GB per mailbox x 5 mailboxes. `dashboard.ts`: `organisations.storage_limit_bytes ?? 30GB` (E17 ka flat 30GB). #16 wala hi drift. Plan (`storage_plans`) se aana chahiye.
- **U3. READY (frontend, live verify baqi). Plan ki copy jhooti.** Pro rail text `Shared inbox, boards, full CRM and ANEXOChat` (`AppShell.tsx`) — plan table mein ANEXOChat Business se shuru hai, aur Pro ke rail mein ANEXOChat/Org dikhte hi nahi. Dashboard subtitle `Company mail, org, chat and the shared book` bhi Pro par Org/chat ke baghair. Copy plan ke mutabiq.
- **U4. READY (16 Oct: #8 mein code, dashboard badge se link, Pro ko rail mein; live verify baqi). Business buyer ka pehla din.** Pro plan = 3 company addresses + 5 mailboxes, lekin Pro ke rail mein Org nahi (`showOrg` Business+) aur Admin platform-admin hai — domain/address jod'ne ki koi screen nahi milti; dashboard par setup checklist ya domain status nahi. #8 (domain wizard) Pro ko bhi dikhna chahiye aur dashboard se link hona chahiye. `ANEXOMAIL hosted` badge us org par aaya jis ka domain `probuyer.axonetis.com` hai (code ke hisaab se `Domain not verified` aana chahiye) — live `organisations.domain` dekh kar tay karna.
- **U5. TODO (founder decide). CRM Loop Pro par.** 4 step dikhte hain, numbers 1, 2, 5, 9 (gaps toote hue lagte hain); 3/4/6/8 gayab. 9 Oct record: steps 3–9 Basic ke ilawa sab par; code (`showCrmRisk`/`showCrmCollab` = Business+) kuch aur kehta hai. #25 yahi dekhta hai. Pehle tay ho Pro ko kaun se steps, phir numbering.
- **U6. READY (frontend, live verify baqi). Mail rail.** `YOUR LOGIN pro.buyer@anexomail.c / om` beech se toot'ta hai (ellipsis + tooltip); ek hi address par `All addresses` / `Unified inbox` dohrate hain; dashboard par `New email` do jagah.
- **15 Oct 2026 — U1/U2/U3/U6 ka fix (Rust PRIMARY, Bun fallback, repo mirror).** `docs/cursor-work/sql/E30_dashboard_truth.sql`: do Postgres functions `dashboard_summary` / `dashboard_analytics` — Rust `dashboard.summary|analytics|activity|ai-usage|calendar` (`server/rust/main.rs` `dispatch_dashboard`) aur Bun fallback (`server/routes/dashboard.ts`) dono yahi call karte hain, hisaab ek jagah. Asli wajah (sab live/schema se confirm): (1) KPI Unread/Assigned/Waiting/Closed nonexistent columns (`is_unread`, `assignee_id`, `state`, `closed_at`) par the, errors `count()` mein nigal liye jate the — ab `unread`+`folder='inbox'` (mail.counts jaisa), `assignee` (uuid = user id), `folder='waiting'`; "Closed today" ka tile `Sent` folder ko jata tha, ab "Sent today" (aaj ki `out` mail). (2) `direction` `in`/`out` hai, `inbound` nahi. (3) Delivered ab `mail_scheduled` sent/failed se (label "Send success"; koi row nahi to `—`); First reply asli messages se (`first_reply_seconds` column kahin nahi hai). (4) Storage limit `storage_plans` se (Pro = 10 GB x 5 mailbox = 50 GB, label ke saath), used message content + attachments se. **Naya finding:** Basic/Pro ke liye storage ledger (`mailbox_storage`) banti hi nahi — `chat_ensure_workspace` `chat_not_entitled` deta hai (chat Business+) aur mail-worker `workspaceId` null par reserve/commit chhor deta hai; yani Basic/Pro par storage quota enforce/record nahi hota (alag item, founder decide). (5) Domain: `organisations.domain_verified` column hai hi nahi — select fail hota tha, isliye "ANEXOMAIL hosted" aur 30 GB. Ab `org_domains` (E15) + `organisations.domain` se. Frontend: Pro rail copy se ANEXOChat hata, dashboard subtitle plan-aware, Mail rail mein address toot'na band + ek hi address par "Unified inbox"/"All addresses" nahi. `New email` do jagah (header CTA + Quick actions) jaan-boojh kar rakha — founder bole to hatao. Installer: `docs/cursor-work/server/e30-dashboard-install.mjs` (generator `e30-build-installer.py`, anchor-gated, backup + `restore.sh`). DONE tab jab founder ke server par output green aur Mail rail browser mein dikhe (Rule 5).
- **U7. TODO (naya, Rule 14 — pehle list mein). "Assigned to me" folder khali.** `mail_thread_assign` (E14) sirf `assignee` set karta hai; rail ka Assigned folder `folder='assigned'` dikhata hai jo koi action set nahi karta. Dashboard ka "Assigned to me" ab `assignee` se ginta hai, lekin tile par click karne se folder list us se mel nahi khayegi. Founder decide: list `assignee` se bane ya assign `folder` bhi set kare.

### Founder's own follow-ups after code lands
- 9: screenshot of Mail cinema — done.
- 21: press Work Done.
- 22: send the promise-wording mail, then open Promises.
- 31–33: CRM pages per plan, Basic checklist, undo send, Cmd+K, gates.
- 36: founder host scope — founder to say.
- 37: spreadsheet — yes or no.
- 40: Chat Phase 32+ text.

---

## 25 Sep 2026 — repo copy of what is already on the server

Claude ne yeh server pe likha. Repo ab usi file ko rakhta hai. Password is record mein nahi.

- `server/routes/storage.ts` lines 135–158 (`storage_reserve` result, `storage_commit`, `storage_release`) GitHub se match. Dated 25 Sep 2026.
- `server/mail-worker.ts` — Claude ka worker. Har 5s `mail_scheduled` `status=queued`. Storage: `chat_ensure_workspace`, `storage_reserve`, `storage_commit`, `storage_release`. Send: `sendMail`. Brain `index.ts` `startMailWorker()` call karta hai. `deploy-brain.sh` file ko `/opt/anexomail/src/mail-worker.ts` copy karta hai.
- Live proof 25 Sep 2026: `POST /api/mail/schedule` → `{"id":"2f6a82a4-317b-4535-b5e0-d84a833bc716","status":"holding"}`. 35s baad log: `[mail-worker] sent id=2f6a82a4-317b-4535-b5e0-d84a833bc716 to=naumankhansherwani@gmail.com`.
- `deploy-brain.sh` ne `GREEN anexomail-leo :3100` print kiya. Website pull is entry ke liye nahi.

### 25 Sep 2026 — Step 5 shared-inbox assign

- Supabase function `mail_thread_assign` applied (create, revoke, grant). Repo copy: `docs/cursor-work/sql/E14_mail_thread_assign.sql`. Dubara run nahi.
- `POST /api/mail/thread/:id/assign` live `mail.ts` mein. Pro+ gate `hasFeature(plan, "sharedInbox")`. Basic ko 403. Brain deploy usi waqt `GREEN anexomail-leo :3100`.
- UI chip pehle se tha. Is paste mein assign button ka frontend save nahi aaya.
- `server/lib/plan.ts` is paste mein nahi tha. Server par hai, yahan naya nahi likha.
- 25 Sep 2026 later: GoTrue `users?email=` filter ignore karta hai. Assign email ko client-side match karta hai (`per_page=1000`). Live: thread `fadd90c3-054f-4455-8f9a-ecb0b8a0c6f1` assignee `3e3a60ea-1580-4443-94f6-b758de732dce`, plan `business`, `ok: true`. Step 5 API complete.
- 25 Sep 2026 frontend: `src/lib/mail.ts` `useThreadAction` kind `assign` → `POST /api/mail/thread/:id/assign`. Build `web: 200`. `ThreadHeaderActions` ka source is paste mein nahi tha — GitHub header file rewrite nahi hui.
- 26 Sep 2026: name lookup + UUID check. "Masood Sherwani" → assignee `670351c7-b377-4371-a3fe-41ce66b1bc8a`, plan `business`, `ok: true`. Empty assignee → `assignee: null`, `ok: true`. Thread `fadd90c3-054f-4455-8f9a-ecb0b8a0c6f1`. Unknown name → `400 assignee_not_found`. Step 5 API complete. Do not redo.
