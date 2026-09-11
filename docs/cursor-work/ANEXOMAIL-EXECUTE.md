# ANEXOMAIL.COM — EXECUTE BLUEPRINT
# Yeh file implement hogi. Original + Claude merge. Protected files no-touch.

**Original catalog (no-touch):** `docs/anexomail-blueprint.md`  
**Claude order:** F1 → F9 (mail only) — teesri kitab nahi, **yahi tarteeb**  
**Lovable:** files rakhna, mix rail/AI/Chat dump **gate**  
**Lovable PRESERVE (locked):** existing `src/` `server/` `sql/` phenko mat. Mix (AI/Chat/CRM/Speed/naam-chip mail pe) **gate/alag**. Phir **usi** code ko theek karke implement — naya clone / shuru se rewrite nahi.

**Inbox:** pehle se bani — **shuru se rewrite nahi** (tootegi)

**Founder rule:** yeh file TODO board nahi. Product TODO se nahi chalti. Har E: wire + live test, ya abhi start nahi. Blank UI nahi.

## GATE (locked — PARTIAL se agla nahi)

Har E sirf **not live** ya **DONE**.  
**DONE** = wire + founder/live test (browser + API + DB).  
DONE se pehle **agli E start nahi.**  
PARTIAL / “almost” / “local only” = **not live**.

**NO TOUCH:** `plans.ts` · Polar · landing · `BrandMark` SVG · ANEXOChat original blueprints

**Teen execute (mix nahi):**
1. Yeh file — mail `anexomail.com`
2. `docs/cursor-work/AI-EXECUTE.md` — baad, same UX + AI add
3. `docs/cursor-work/FOUNDER-EXECUTE.md` — end

**Packages (locked cards — implement existing, prices no-touch):**
| Plan | Price | Rail on anexomail.com |
|---|---|---|
| Basic | £23 / user / month | Dashboard, Mail, People, Calendar |
| Pro | £46 / user / month | + Work + **CRM** (leads, own pipeline) |
| Business | £97 / user / month | + Org + ANEXOChat + CRM shared work |
| Business Pro | £2,850 / company / month | + Org + ANEXOChat + CRM ledger (activity) |
Workspace cards = **LEO zero**. AI grant includes platform (AI Exec → Biz Pro UX) but Leo only on `ai.anexomail.com`.

---

## Technology (Claude — locked, naya nahi)

| Layer | Technology |
|---|---|
| Host | Hetzner only |
| Edge | Caddy — HTTPS + HTTP/3 |
| Frontend | React 19.2 · TanStack Start v1 · Router 1.17.0 · Vite 8.2 · Tailwind v4.2 · Radix + shadcn/ui · Framer Motion · GSAP · Three.js |
| SSR | Bun · Nitro bun preset · PM2 interpreter bun · :3000 |
| Backend PRIMARY | Rust :3200 — Tokio async, WebTransport, tRPC, PostgreSQL |
| Backend FALLBACK | Bun :3100–3300 |
| Emergency | Node 22 only |
| Database | Supabase / PostgreSQL |
| Mail | Postfix / Dovecot / OpenDKIM |
| Payments | Polar — Rust webhook (no-touch) |

Har E isi stack pe. Naya architecture nahi. **Backend kis E pe** = neeche wali table (Claude F-map, E-series tarteeb). Alag “Rust phase” **nahi**.

### Backend per E (Claude → E — locked)

| E | Claude | Browser REST (Bun :3100) | Rust :3200 PRIMARY | Rust? |
|---|---|---|---|---|
| **E1** | F1.2 shell | — (frontend rail) | — | nahi |
| **E1A** | F12 CRM + locales | `/api/crm/*` `/api/locale/*` FALLBACK | `/rpc/crm.*` pehle (`rpcOrRest`) | **HAAN** — Bun jab Rust route na ho |
| **E2** | F1 auth | login / signup / session / passkey | ❌ | **kabhi nahi** — session Bun |
| **E3** | F3 inbox | `/api/mail/*` FALLBACK | `/rpc/mail.*` + `/wt/mail` | **HAAN — PRIMARY** |
| **E4** | F4 GATE | `POST /api/mail/send` → Postfix | delivery push sent→delivered→read | **HAAN** — status; SMTP Postfix |
| **E5** | F5 thread | `GET /api/mail/thread/:id` | inline reply push | Partial |
| **E6** | F6 people | `/api/contacts` | ❌ | nahi |
| **E7** | F7 calendar | `/api/calendar/load` | 5min reminder push | **HAAN** — push |
| **E8** | F8 work | `/api/work/*` | ❌ | nahi |
| Chat (E-list nahi) | F10 | ❌ | `/wt/chat` poora | **FULLY RUST** |
| Polar | — | — | webhook (PM2, no-touch) | **pehle se** |
| Founder (end) | F9 | `/api/founder/*` | `/wt/founder` live | **HAAN** — live metrics |
| LEO | F11 | `/api/ai/ask` — **AI host baad** | ❌ | nahi is execute pe |

Payments Polar Rust **phase wait nahi** — pehle se. Mail SMTP = Postfix, Rust inbox/push.

---

## Root (sensible)

Ek codebase. Ab sirf **anexomail.com** user complete.  
`ai.anexomail.com` = baad mein **wahi UX** + AI phases add. Naya clone nahi.  
Founder deck = end. Founder **guard** (family Admin/Speed nahi) ab.

**ANEXOChat is execute list mein nahi.** Code repo mein rehti hai; Basic/Pro pe dikhe nahi. Business+ pe rail + existing `/app/chat`. Is blueprint ka kaam mail hai — Chat 1–57 rebuild nahi.

Wire = har E-step: UI dikhe + API + DB. Mock nahi. DONE = live proof.

```
E1 package rail → E1A CRM + 28 locales → E2 auth/session → E3 inbox KEEP → E4 SEND/RECEIVE GATE
→ E5 thread → E6 people → E7 calendar → E8 work
→ [STOP mail complete]
→ AI host add (original 8, 17…)
→ founder
```

---

## Execute order (Claude) = original phase = Lovable file

| E | Claude | Original | Lovable (keep, wire) | Mix hatao | Status |
|---|---|---|---|---|---|
| **E1** | F1.2 | Ph 1 shell | `AppShell.tsx` `host.ts` `plan-surface.ts` `PlanSurfaceGate.tsx` | Package rail = cards. Naam chip **sirf** right avatar. CRM/Speed/AI dump. Landing / `plans.ts` no-touch | **READY** — repo. **DONE** after pull + live: Basic vs Pro vs Business rail, no Leo on anexomail.com |
| **E1A** | — | CRM + 28 locales | `app.crm*` `i18n` `server/routes/crm.ts` `server/routes/locale.ts` SQL phase64 | Alag CRM product, Argos widget, Leo agent, dummy strings | **READY** — GitHub. **DONE nahi** until pull + Humza/Pro live: 5-item CRM nav, suggested leads from mail, New-deal drawer, slim KPI, no auth language chip |
| **E2** | F1 | Ph 5A auth | `auth.tsx` `server/routes/auth.ts` | `workspace_plan` sach. Sessions = Chrome·Windows, Bun dump nahi | **not live** — login hai, plan/sessions live test nahi |
| **E3** | F3 | Ph 2 + **7** mail | `ia.ts` `app.mail.*` `MailRail` | Folders pane. Inbox zero honest. Rewrite nahi | list live; DONE tab E3 verify + E1 live close |
| **E4** | **F4 GATE** | Ph 9 + 52–58 | `ComposeStudio` `sendmail.ts` Postfix | Leo compose se **nikaal** (mail host). Send+receive | **not live** — E1–E3 DONE ke baad |
| **E5** | F5 | thread | `$threadId.tsx` | — | wait E4 DONE |
| **E6** | F6 | Ph 10 | `people` SQL62 | — | wait E4 DONE |
| **E7** | F7 | Ph 11 | `calendar` SQL61 | — | wait E4 DONE |
| **E8** | F8 | work | `app.work.tsx` | — | wait E4 DONE |

**Skip ab (original mein hain, execute nahi):**  
Ph **8, 17–22, 31** = AI → `ai.anexomail.com` baad  
Ph **25, 27** Admin/Speed → founder end  
Ph **3** landing polish → no-touch  
Ph **32–51** Polar/trial → no-touch (spine)  
Ph 6 dashboard = **rakhna** (Greeting), Leo credits panel AI-only  
Ph 4 honest states = har E ke saath (`PlanSurfaceGate`)  
Ph 23 settings/account = E2 ke saath (profile right)

---

## Rail is track pe (anexomail.com)

**UI same** har package + `ai.anexomail.com`. Farq features hain. AI host pe LEO add. Naya layout nahi.

| Plan | Dikhe | Chat/AI/Founder |
|---|---|---|
| Basic | Dashboard Mail People Calendar | nahi |
| Pro | + Work + CRM (own book) | nahi |
| Business / Biz Pro | + Org + Chat + CRM (shared; Biz Pro + activity ledger) | AI nahi |
| AI Exec (Raana) | Biz Pro mail UX; Leo **baad** AI host | founder nahi |

URL se Chat/Work/Org/AI kholne par blank nahi — package wall (`PlanSurfaceGate`).

---

## E4 — agla asli kaam (inbox + E1 live ke baad)

1. Compose se mail bahar (Postfix)  
2. Bahar se aaye → list (E3 pehle se)  
3. `bash server/gates/mail-gate.sh` green + founder live dekhe  

Us ke baghair E5–E8 DONE nahi.

---

## CRM review (flagship vs ab kya hai)

ANEXOMAIL CRM **standalone Salesforce clone nahi** ho sakta — woh mix hai. Flagship = **live relationship object**: Person ke neeche mail, chat, meeting, call, file, task, deal, payment, promise, phir AI memory.

**Ker sakte ho — existing stack pe (naya host / naya CRM product nahi):**  
`people` + `mail_threads` + chat messages + calendar + work/promises + `crm_deals` + Polar later. Ek `customer_graph` / recorded links. AppShell pe CRM rail (Pro+). Humza = aam Business Pro.

**Abhi kya hai (bc11c07 — DONE nahi):** Pro own book (leads/pipeline/capture), Business shared work, Biz Pro activity list. Deal pe `thread_id` field. Overview par stale count. Leo insights band. Yeh **record system** hai, continuous memory nahi.

**Nahi (is host + workspace packages):** sentiment, “AI samjha”, autonomous agent, lifecycle prediction, executive brief written by Leo. Woh `AI-EXECUTE.md` + AI plan. Workspace cards = LEO zero.

**Mail-gate:** E4 ke baghair timeline/conversation→CRM khali hai. CR1+ E4 DONE ke baad. Capture forms E4 se pehle bhi chalte hain (manual book).

### Package (prices no-touch)

| | Pro | Business | Business Pro (Humza) | AI plans |
|---|---|---|---|---|
| Own leads / pipeline | ✅ | ✅ | ✅ | platform included |
| Team shared + collision | — | ✅ | ✅ | |
| Activity ledger / graph | — | — | ✅ | |
| Deterministic health / risk (counts, dates, overdue promises) | light | ✅ | ✅ | |
| Leo memory / agent / next-best-action prose | ❌ | ❌ | ❌ | `ai.anexomail.com` |

### Flagship → tarteeb (A–M aur 1–20)

Pehle **recorded / deterministic** (is file). Phir **AI retrieve + approve + evidence** (`AI-EXECUTE.md`).

| CR | Flagship | A–M | Kab | Tech (repo) | Mix nahi |
|---|---|---|---|---|---|
| **CR0** | CRM rail + capture | — | E1 surface | `app.crm*` `server/routes/crm.ts` | AI CRM naam, Leo panel, alag crm. host |
| **CR1** | Unified Customer Memory | A, 1 | E4 + **E6** people | Person = hub. Email/chat/cal/work/deal **links**, copy nahi | dusri contacts DB |
| **CR2** | Unified Relationship Timeline | G, 2, 18 | CR1 | One timeline: mail · chat · meeting · file · deal · payment. Clock UTC | fake activity |
| **CR3** | Promise / Commitment Engine | C, 3 | **E8** work | Owner, due, evidence, status, at-risk by date. “I’ll send Friday” → work object | AI guess due date |
| **CR4** | Conversation → CRM (rules) | B, 6 | E4 + CR1 | Known contact + open deal + thread. Manual 8 fields nahi jab link pehle se ho | intent/priority from Leo yahan |
| **CR5** | CRM → Work conversion | K, 7 | CR3 + deal | Deal → workstream → tasks → owners → files → mail | dusra project app |
| **CR6** | Relationship Health | D, 4 | CR2+CR3 | Score from **recorded**: latency, unresolved, overdue promises, meeting gap, deal stall. No sentiment | “feelings” model |
| **CR7** | Revenue Risk Radar | E, 5, 14, 16 | CR6 + Biz Pro | Silent, overdue promise, unpaid (Polar later), stale deal. **Why** = which rows | competitor NLP yahan |
| **CR8** | Customer Intelligence Graph | H, 13 | Biz Pro card | Person ↔ company ↔ deal ↔ mail ↔ chat ↔ file ↔ work. **Recorded links only** | inferred AI edges |
| **CR9** | CRM → Calendar | L, 8 | E7 + CR1 | “No decision-maker meeting in 12 days” = date math. Suggest schedule, auto-book nahi | |
| **CR10** | CRM → Mail | M, 9 | E4 + CR2 | Open support thread → don’t pitch. Folder/state, not vibe | |
| **CR11** | Evidence-backed CRM | J, 11 | CR3–CR7 | Decision, why, source row, action, result. Activity log se zyada: append-only | |
| **CR12** | Next-best-action (deterministic) | 15 | CR6–CR10 | One next step from rules (overdue → remind; silent → meeting). Copy English/locale | Leo wording |
| — | AI Customer Memory | F, 10 | **AI-EXECUTE** | History retrieve + cite | anexomail.com Leo |
| — | Autonomous CRM Agent | I, 12 | **AI-EXECUTE** | Find → prepare → **approve** → execute → evidence | silent send |
| — | Lifecycle prediction | 19 | **AI-EXECUTE** | | |
| — | Executive Relationship Brief | 17 | **AI-EXECUTE** | | |
| — | Founder CRM command | 20 | **FOUNDER-EXECUTE** | Kill switch already; deck baad | Humza Admin nahi |

Architecture (locked — naya stack nahi):

```
PEOPLE · DEALS · ACCOUNTS
        → CUSTOMER GRAPH (recorded)
MAIL · CHAT · CALENDAR · WORK · FILES
        → TIMELINE + PROMISES
        → HEALTH / RISK (counts + dates)
        → NEXT ACTION (rules)
        → [AI MEMORY / AGENT  — ai host + plan]
        → APPROVAL / PROOF → EXECUTION
```

---

## Languages — 28 real locales (Hebrew + Swahili **nahi**)

**Lock:** translate widget / live Google/Argos **nahi**. User ek zubaan chune → `html lang` + `dir` + **usi locale ke JSON bundles**. Missing string = asli English, dummy nahi.

| # | Language | Tag (repo) | Dir |
|---|---|---|---|
| 1 | English | `en-GB` | ltr |
| 2 | हिन्दी | `hi-IN` | ltr |
| 3 | اردو | `ur-PK` | rtl |
| 4 | العربية | `ar-SA` | rtl |
| 5 | Español | `es-ES` | ltr |
| 6 | Français | `fr-FR` | ltr |
| 7 | Deutsch | `de-DE` | ltr |
| 8 | Schweizerdeutsch | `de-CH` | ltr |
| 9 | Português | `pt-BR` | ltr |
| 10 | 中文 | `zh-CN` | ltr |
| 11 | 日本語 | `ja-JP` | ltr |
| 12 | 한국어 | `ko-KR` | ltr |
| 13 | Türkçe | `tr-TR` | ltr |
| 14 | Italiano | `it-IT` | ltr |
| 15 | Română | `ro-RO` | ltr |
| 16 | Русский | `ru-RU` | ltr |
| 17 | Nederlands | `nl-NL` | ltr |
| 18 | Polski | `pl-PL` | ltr |
| 19 | Українська | `uk-UA` | ltr |
| 20 | Bahasa Indonesia | `id-ID` | ltr |
| 21 | Bahasa Melayu | `ms-MY` | ltr |
| 22 | Tiếng Việt | `vi-VN` | ltr |
| 23 | ไทย | `th-TH` | ltr |
| 24 | বাংলা | `bn-BD` | ltr |
| 25 | ਪੰਜਾਬੀ | `pa-IN` | ltr |
| 26 | فارسی | `fa-IR` | rtl |
| 27 | Ελληνικά | `el-GR` | ltr |
| 28 | Svenska | `sv-SE` | ltr |

**Repo pehle se:** `src/lib/locales.ts` `src/lib/i18n.ts` `src/i18n/*.json` `LanguagePicker`.  
**Abhi ghalat:** picker sirf `en-GB` filter — is liye site local nahi dikhti. Bundles ≈ public nav (11 strings). `/app` rail/mail/CRM `t()` use nahi karti. `translate.py` (Argos) = machine builder — **product copy ka source nahi**.

| L | Kya | DONE |
|---|---|---|
| **L0** | 28 list lock. `he-IL` `sw-KE` registry se nikal | picker mein 28, Hebrew/Swahili nahi |
| **L1** | Picker saari 28; `html lang/dir`; `ax.locale`; workspace header | Humza Urdu chune to RTL + nav local |
| **L2** | Public site strings — **human locale files**, Argos se overwrite nahi | landing/auth keys complete (landing layout no-touch, strings via `t()`) |
| **L3** | `/app` chrome: rail, Cmd+K, account menu | Humza workspace local |
| **L4** | Mail, CRM, work, chat chrome | surfaces local; mail **body** customer ki zubaan rehti hai |

L1 mail-gate ke baghair chal sakti hai (chrome). L4 E3+ ke saath.

---

## AI baad (same site, add only)

Jab E4 green + E5–E8 user-complete:  
`ai.anexomail.com` = same AppShell/mail. Add original **8 → 17 → 18 → …** tarteeb se. Duplicate mail app nahi.  
CRM AI (memory, agent, brief, prediction) = `AI-EXECUTE.md`, is E-list mein nahi.

---

## Green build kaunsi phase thi

Jo pull **toota** (`MISSING_EXPORT workspaceTourFromUrl`) = **E1** (Claude F1.2 / original **Phase 1 shell**) — `app.tsx` import, `founder-preview.ts` GitHub par export nahi tha.

Jo pull **nahi toota** (`bc11c07`) = wahi **E1** + CRM **CR0** surface (Pro/Business/Biz Pro rail). Yeh **E4 mail-gate nahi**, **E6 people graph nahi**, **CR1–CR12 nahi**.

---

## Execute shuru

Agent: **is file ke E-number se.** Original `docs/anexomail-blueprint.md` overwrite nahi.  
Ab: **E1 live** (package rail + CR0) → **L0/L1** locales → **E2 session** → **E4 mail-gate** → E5–E8 → **CR1+**.
