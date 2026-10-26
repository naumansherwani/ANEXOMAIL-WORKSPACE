# PACKAGE + FEATURE FORMULA — Agent Personal Memory

# PRICING v6 (FOUNDER LOCKED 25 Oct 2026 21:30 UTC) — flat per-month, per-user khatam

# Asli sach ab: docs/cursor-work/founder/packages-pricing-v6-2026-10-25.md

# | Basic Flat £40 (5 users, 3 mailboxes, 15GB shared, 25MB) | Pro £105 (20, 300GB, 35MB) | Business £360 (60, 1.5TB, 45MB) | Business Pro £2,850 (570, 10TB, 100MB) | Enterprise £18,000 (UNLIMITED, 15TB, 100MB) |

# Neeche wali v5 ladder/purani table HISTORY hai — pricing ke faislay mein v6 jeetta hai. Naya dimension RULE 4A: file transfer limit 25/35/45/100/100 MB.

# Source: docs/ai-packages.md + docs/package-feature-map.md (Lovable originals — DO NOT DELETE)

# Rule: packages touch NAHI kerne — sirf yeh file dekh ke feature gate decide karo

# Surface unmix (teen hosts, Chat vs LEO, do Admin): docs/cursor-work/IMPLEMENTATION-MASTER.md §0

# ═══ UPDATE 26 Oct 2026 03:42 PKT — FOUNDER GATE DECISIONS (neeche ke purane 7-column tables HISTORY; yeh jeetta hai) ═══
# ANEXOChat: Business ladder -> Business 2GB / Business Pro 5GB / Enterprise 7GB (Basic, Pro = NAHI). Personal ladder -> PRO+ 2GB / Premium 4GB (Personal Basic = NAHI).
# Email attachment: 25/35/45/60/100 MB. Storage (shared pool): Basic 15GB (3 mailboxes) / 300GB/1.5TB/10TB/15TB. CRDT docs: Business+. Enterprise = Business Pro ke saare features + upar.
# Bandwidth overage (hidden, bill-only): Business 10TB @ £12/TB, Business Pro 30TB @ £11/TB, Enterprise 50TB @ £10/TB (CEO decision, founder veto).
# AI (ai.anexomail.com, alag product): AI Pro £2,000 / AI Business £5,000 / AI Executive £25,000 per month. Workspace plans = AI ZERO.
# Detail: docs/claude/PRICING-POSITIONING-26OCT.md section 9.

# ═══ PRO v6 GATE (26 Oct 2026 06:40 PKT, Rule 53 — DRAFT, founder approve baqi) — poori detail: docs/packages/pro/ ═══
# PRO = £105/month flat, yearly £1,155 (x11), UP TO 20 USERS, 10 mailboxes, 300GB shared, 35MB attachment, 3 company domains,
#   3 booking links, 4 trusted devices, support 48h. Shared inbox/collision guard, snooze, schedule send, templates, boards/notes/tasks,
#   thread analytics = Pro+ (server-side REAL). SQL: E88_pro_v6.sql (+CHECK_E88). Har package ka alag folder: docs/packages/<pkg>/.
# BOOKING LINKS: Basic 1 / Pro 3 / Business 20 / Business Pro + Enterprise unlimited (chat_phase_entitlements 'booking_links' + trigger booking_pages_cap).

# ═══ PP1 — FEATURE GATE MATRIX (CEO proposal 26 Oct 04:40 PKT; FOUNDER approve baqi) — ab se REPO ka rule (AGENTS Rule 53) ═══
# PRICE AXES (founder 04:27 PKT, FINAL): BUSINESS = v6 flat per-month: Basic £40 / Pro £105 / Business £360 / Business Pro £2,850 / Enterprise £18,000.
#   PERSONAL (alag Polar SKUs, per person): Personal Basic £17 / Personal Pro+ £83 / Personal Premium £1,850. "£23/£46/£97" PURANI hain -- kahin istemal na hon.
#   plan-surface.ts ka polarToPersonalTier mapping + comments PURANE hain (P5 mein theek honge).
# Personal = ek insaan: shared inbox/thread ownership/company address/Org/Domains NAHI. Personal Pro+ aur Premium = Business Pro POWER.
#
# | Feature | Basic | Pro | Business | Biz Pro | Enterprise | P.Basic | P.Pro+ | P.Premium |
# | Mail/People/Calendar/Search/Import/Move-In/Billing/Devices/Settings | Y | Y | Y | Y | Y | Y | Y | Y |
# | Work (boards, notes, tasks, thread analytics) | - | Y | Y | Y | Y | Y | Y | Y |
# | Pro mail tools (snooze/schedule), multiple identities, video 1:1 | - | Y | Y | Y | Y | - | Y | Y |
# | CRM base (accounts/leads/pipeline/tasks) | - | Y | Y | Y | Y | People only | Y | Y |
# | CRM collab + risk + business ledgers | - | - | Y | Y | Y | - | Y | Y |
# | CRM activity ledger + graph | - | - | - | Y | Y | - | Y | Y |
# | ANEXOChat + ANEXOVideoCall (file send) | - | - | Y 2GB | Y 5GB | Y 7GB | - | Y 2GB | Y 4GB |
# | CRDT collaborative docs | - | - | Y | Y | Y | - | (founder faisla) | (founder faisla) |
# | Org centre (members/roles/departments/policies/audit/compliance) | - | - | Y | Y | Y | never | never | never |
# | Company domains + addresses | Y(biz kind) | Y | Y | Y | Y | never | never | never |
# | Safety centre (review queue, sealed evidence, appeals) | - | - | - | Y | Y | - | Y | Y |
# | Priority Support | add-on £790 | add-on | add-on | add-on | INCLUDED | - | - | - |
# | Email attachment | 25MB | 35MB | 45MB | 60MB | 100MB | (founder) | (founder) | (founder) |
# | Storage (shared pool) | 15GB (3 mailboxes) | 300GB | 1.5TB | 10TB | 15TB | 5GB | 10GB | 1TB pooled |
# | Users cap | 5 | 20 | 60 | 570 | unlimited | 1 | 1 | 1 |
# | Bandwidth overage (hidden, bill-only) | fair-use | fair-use | 10TB@£12 | 30TB@£11 | 50TB@£10 | - | - | - |
# | Video group size | - | 4? | 8 | 40 | 60 | - | 8 | 40 |
# | Device vault slots | 2 | 4 | 10 | 50 | 100 | 2 | 10 | 50 |
# | LEO AI | NO (sirf ai.anexomail.com, COMING SOON July 2027; Enterprise AI nahi) |
# Analytics routes (/app/analytics*): koi plan gate NAHI mila -- decide: Pro+ (Work ke saath). | Founder/Admin/Perf: founder host only.

---

## RULE 1 — NEVER TOUCH (locked forever)

```
src/lib/plans.ts          ← workspace plans pricing (FOUNDER LOCKED)
src/lib/ai-packages.ts    ← AI plans pricing (FOUNDER LOCKED)
server/routes/polar.ts    ← payment webhook (FOUNDER FIXED)
docs/polar-products.md    ← Polar product IDs
docs/ai-packages.md       ← master package doc (original)
docs/package-feature-map.md ← phase feature gating (original)
```

Agent ka kaam: feature gate decide karna. Pricing change karna nahi.

---

## RULE 2 — PACKAGE LOGIC FORMULA (Lovable ka formula — locked)

```
AI Pro (£400)      INCLUDES:  Business platform + AI workspace + 1,200 credits
AI Business (£1,500) INCLUDES: Business platform + more AI + 5,000 credits
AI Executive (£4,000) INCLUDES: Business PRO platform + full AI + 10,000 credits

Formula:
  AI Pro     > Business      (£400 > £97  — better deal: workspace + AI both)
  AI Executive > Business Pro (£4000 > £2850 — Business Pro included + AI on top)
```

**Ladder (jaan boojh kar aisa hai):**

```
Basic (£23) → Pro (£46) → Business (£97) → Business Pro (£2850/co)
                                                ↕
                         AI Pro (£400) → AI Business (£1500) → AI Executive (£4000)
```

- Sab se mehnga non-AI = Business Pro
- Sab se mehnga overall = AI Executive
- AI Pro sirf AI features ke liye nahi — Business POORA included hai

---

## RULE 3 — SURFACE SEPARATION (locked)

| Surface      | Host                             | Plans shown                        |
| ------------ | -------------------------------- | ---------------------------------- |
| Workspace    | `anexomail.com`                  | Basic, Pro, Business, Business Pro |
| AI workspace | `ai.anexomail.com`               | AI Pro, AI Business, AI Executive  |
| Founder      | `founderworkspace.anexomail.com` | All features, no plan gate         |

`ai.anexomail.com` SAME codebase — sirf host-aware gate.
ANEXOChat + ANEXOVideoCall = `ai.anexomail.com` ke ANDAR, alag subdomain NAHI.

---

## RULE 4 — WHEN ADDING NEW FEATURE: WHICH PLAN GETS IT?

```
New feature decide karne ka formula:

1. Kya yeh basic mail/contacts/calendar hai?
   → ALL plans (Basic+)

2. Kya yeh collaboration (shared inbox, teams, audit)?
   → Pro+ (Pro, Business, Business Pro, all AI)

3. Kya yeh ANEXOChat feature hai?
   → Personal Pro+ (same power as Business Pro) OR Business / Business Pro Polar SKU
   → Personal Basic ko Chat wall
   → Polar pe alag Personal Chat product NAHI

4. Kya yeh large file transfer (>2GB) / 1TB storage?
   → Business Pro + AI Business + AI Executive ONLY

5. Kya yeh LEO AI feature hai?
   → AI plans ONLY (AI Pro, AI Business, AI Executive)
   → Workspace plans ko ZERO AI

6. Kya yeh admin / device trust / safety review?
   → Business Pro + AI Executive (top tiers only)

7. Kya yeh founder-only feature hai?
   → is_founder = true (DB flag) — no plan check needed
```

---

## FEATURE GATES PER PLAN (DB-backed, source: package-feature-map.md)

### Core Mail + Workspace

| Feature                        | Basic | Pro | Business | Biz Pro | AI Pro | AI Biz | AI Exec |
| ------------------------------ | ----- | --- | -------- | ------- | ------ | ------ | ------- |
| Mail send/receive              | ✓     | ✓   | ✓        | ✓       | ✓      | ✓      | ✓       |
| Contacts + Calendar            | ✓     | ✓   | ✓        | ✓       | ✓      | ✓      | ✓       |
| Thread ownership               | ✓     | ✓   | ✓        | ✓       | ✓      | ✓      | ✓       |
| Undo send 30s                  | ✓     | ✓   | ✓        | ✓       | ✓      | ✓      | ✓       |
| Snooze / schedule send         | —     | ✓   | ✓        | ✓       | ✓      | ✓      | ✓       |
| Shared inbox (collision guard) | —     | ✓   | ✓        | ✓       | ✓      | ✓      | ✓       |
| Tasks + thread analytics       | —     | ✓   | ✓        | ✓       | ✓      | ✓      | ✓       |

### Storage

| Plan         | Per mailbox / pool |
| ------------ | ------------------ |
| Basic        | 5 GB/mailbox       |
| Pro          | 10 GB/mailbox      |
| Business     | 25 GB/mailbox      |
| Business Pro | 1 TB pooled        |
| AI Pro       | 256 GB pooled      |
| AI Business  | 1 TB pooled        |
| AI Executive | 2 TB pooled        |

### ANEXOChat

| Feature             | Basic | Pro | Business | Biz Pro   | AI Pro   | AI Biz    | AI Exec   |
| ------------------- | ----- | --- | -------- | --------- | -------- | --------- | --------- |
| 1-to-1 + group chat | ❌    | ❌  | ✓ Ph1-56 | ✓ Ph1-56  | ✓ Ph1-57 | ✓ Ph1-57  | ✓ Ph1-57  |
| Max file in chat    | —     | —   | 2 GB     | 5 GB      | 2 GB     | 5 GB      | 5 GB      |
| Monthly transfer    | —     | —   | 5 TB     | unlimited | 5 TB     | unlimited | unlimited |
| Resumable transfer  | —     | —   | ✓        | ✓         | ✓        | ✓         | ✓         |

### LEO AI (credit-metered)

| Feature               | Basic | Pro | Business | Biz Pro | AI Pro | AI Biz | AI Exec |
| --------------------- | ----- | --- | -------- | ------- | ------ | ------ | ------- |
| Smart reply / rewrite | ❌    | ❌  | ❌       | ❌      | ✓      | ✓      | ✓       |
| Thread summary        | ❌    | ❌  | ❌       | ❌      | ✓      | ✓      | ✓       |
| Live translate        | ❌    | ❌  | ❌       | ❌      | —      | ✓      | ✓       |
| AI workflow builder   | ❌    | ❌  | ❌       | ❌      | —      | ✓      | ✓       |
| AI Executive Briefing | ❌    | ❌  | ❌       | ❌      | —      | —      | ✓       |
| Credits per month     | 0     | 0   | 0        | 0       | 1,200  | 5,000  | 10,000  |

### ANEXOVideoCall

| Feature             | Basic | Pro | Business | Biz Pro | AI Pro | AI Biz | AI Exec |
| ------------------- | ----- | --- | -------- | ------- | ------ | ------ | ------- |
| 1:1 video call      | —     | —   | ✓        | ✓       | ✓      | ✓      | ✓       |
| Group participants  | —     | —   | 8        | 40      | 8      | 40     | 60      |
| Screen share        | —     | —   | ✓        | ✓       | ✓      | ✓      | ✓       |
| Live captions (AI)  | —     | —   | —        | —       | ✓      | ✓      | ✓       |
| Post-call LEO notes | —     | —   | —        | —       | —      | ✓      | ✓       |
| Recording + search  | —     | —   | —        | ✓       | —      | ✓      | ✓       |

### Device Trust + Security

| Feature                | Basic | Pro | Business | Biz Pro | AI Pro | AI Biz | AI Exec |
| ---------------------- | ----- | --- | -------- | ------- | ------ | ------ | ------- |
| Device vault (sealed)  | ✓ 2   | ✓ 4 | ✓ 10     | ✓ 50    | ✓ 10   | ✓ 50   | ✓ 100   |
| One-click session kill | ✓     | ✓   | ✓        | ✓       | ✓      | ✓      | ✓       |
| Safety review queue    | —     | —   | —        | ✓       | —      | —      | ✓       |
| Enforcement history    | —     | —   | —        | ✓       | —      | —      | ✓       |

---

## RULE 5 — DB AUTHORITY (feature gate check kaise hota hai)

```
Server pe feature check:
  1. GET /api/trial/state → account.plan
  2. Check plan against DB function: chat_feature_allowed(org_id, feature_name)
  3. Server returns 403 if not allowed — frontend sirf honest state dikhata hai

Frontend pe UI gate:
  const account = useAccountState()
  if (!account.data?.ai_enabled) return <UpgradeBanner />
  if (account.data?.plan !== 'business') return <UpgradeBanner />
```

**LOCK:** Client-side gate = sirf UI. Real gate = server + DB (RLS + function).
Client ko tamper karke feature nahi milta.

---

## AI CREDITS — Pre-flight formula

```
Har AI action se pehle:
  1. Estimate: "This will use ~8 credits. You have 1,192 remaining." → User: Approve
  2. Execute
  3. Receipt: Action + Model + Credits used + Time + Source

Zero-credit state: human workspace chalti rehti hai, AI pauses.
Complimentary: 5/day first 2 days = 10 total per billing cycle.
```

---

## TOP-UP PRICES (locked — source: docs/ai-packages.md)

| Amount | Credits               |
| ------ | --------------------- |
| £15    | 40                    |
| £30    | 75                    |
| £60    | 170                   |
| £120   | 360                   |
| £250   | 800                   |
| £500   | 1,800                 |
| £1,000 | 4,000                 |
| £2,000 | 9,000                 |
| £5,000 | 21,000 (founder-only) |
