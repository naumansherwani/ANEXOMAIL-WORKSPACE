# ANEXOMAIL Workspace — CINEMATIC UI MASTER DESIGN

**Founder paste: 11 Sep 2026.** Yeh spec CRM cinematic UI ka master hai. Agent isi se match karta hai.
Status words: DONE / READY / TODO.

---

## 1. Overall screen geometry

Desktop primary target: **1440 × 900**. Larger: 1600 × 1000, 1920 × 1080.
Fixed pixel layout nahi — responsive grid.

```
┌──────────────────────────────────────────────────────────────┐
│ TOP BAR                                                64px │
├───────┬──────────────────────┬───────────────────────────────┤
│       │                      │                               │
│       │    CRM CONTENT       │                               │
│ 72px  │                      │                               │
│ RAIL  │                      │                               │
└───────┴──────────────────────┴───────────────────────────────┘
```

Global dimensions:
- Global rail: **72px**
- Secondary CRM nav: **220–240px**
- Top header: **64px**
- Main content padding: **32px**
- Section gap: **24px**
- Card radius: **16–20px**
- Input height: **44–48px**
- Button height: **44–48px**

## 2. Left global rail

Vertical icon rail retain. Width **72px**. Background `#07101D → #0B1220`.
Icons 20–22px. Active item 48×48px, radius 14px, subtle outer glow + 1px border + soft backdrop. Neon arcade glow nahi.

Hierarchy: ANEXOMAIL → Mail → Chat → People → CRM (active) → Calendar → Work → AI → Settings

## 3. CRM secondary navigation

Width **236px**. Background slightly lighter than global rail: `#0C1624`.
Top: **CRM**. Main tabs: Dashboard, Relationships, Leads, Accounts, Deals, Activities, Tasks, Reports.
Har item: height 40–42px, padding-left 14px, radius 10px.
Active: soft background + left indicator 3px.

## 4. THE LOOP

CRM ka signature element:

```
Capture
Memory
Timeline
Promises
Health
Risk
Evidence
Graph
Next
```

Visual treatment:
- Heading: THE LOOP — 11–12px, letter-spacing 0.16em, uppercase
- Steps: CR1 Capture · CR2 Memory ● · CR3 Timeline ● · CR4 Promises ● · CR5 Health · CR6 Risk ● · CR7 Evidence · CR8 Graph ● · CR9 Next ●
- Step indicator: round badge 24×24px
- Count bubble: 28×28px
- Hover: subtle horizontal light sweep + text brighten + 180ms
- Active step: soft blue/indigo halo

## 5. Top bar

Height 64px. Left: CRM. Center/left: Dashboard / Relationships…
Right: Search, Notifications, AI, Profile.
Search field 320–380px, height 42px, radius 12px.
Placeholder: "Search people, companies, deals, mail, chat..."
Existing global search hai — CRM mein duplicate giant search bar nahi.

## 6. Main dashboard

Main content width: `calc(100vw - 72px - 236px)`. Padding 32px.

Header:
- CRM
- **Relationship intelligence** — 32–38px, weight 650–700
- Subtitle 14–16px: "Every relationship leaves a trail. Turn the trail into action."

## 7. KPI row

6 cards. Desktop grid `repeat(6, 1fr)`, gap 16px.
Card: min-height 118px, padding 20px, radius 18px.
Metrics: **Revenue · Pipeline · Open Deals · At-Risk · Promises Due · Conversion**
Big number 28–32px. Small label 11–12px uppercase.
Example: PIPELINE £184,200 +14.8% compared with last period.

## 8. Main cinematic dashboard area

Empty dark space nahi — hero-style data canvas.
Split: **Left 65% / Right 35%**.
Left: Relationship Flow — revenue / pipeline trend.
Right: AI Next Actions panel (320–360px):

```
AI NEXT
──────────────
3 accounts need attention
2 promises at risk
1 deal stalled
```

## 9. Cinematic background

Main background `#060D17`.
- Layer 1: very subtle radial blue glow, top-right
- Layer 2: indigo glow, bottom-left
- Layer 3: extremely subtle grain/noise 2–4% opacity
- Layer 4: tiny star-like particles

But: NO giant moving stars · NO distracting animation · NO constant particle movement.

Formula: dark depth + soft atmospheric gradients + glass surfaces + fine borders + subtle light movement + high typography contrast = premium cinematic.
Not: neon everywhere + blur everywhere + 100 animations.

## 10. Cards

- background `rgba(14, 24, 38, .72)`
- border 1px `rgba(255,255,255,.08)`
- shadow `0 12px 40px rgba(...)`
- backdrop-blur 16–24px
- radius 18px
- hover translateY(-2px) 180ms
- No oversized cards.

## 11. Relationships screen

CRM ka most important screen.
Top filters: **All · Healthy · At Risk · New · High Value · Silent**
Table columns: Name · Company · Health · Last contact · Open deal · Revenue · Risk · Next action
Row height 68–76px. Click → right detail panel **420–480px**.

## 12. Customer profile = cinematic command panel

```
ACME CORPORATION
Enterprise

Health        82
Risk          Medium
Revenue       £48,000
Deal          £30,000

TIMELINE
─────────────
Email · Meeting · Chat · File · Task · Payment · Promise

AI RELATIONSHIP BRIEF
Customer is positive, but has not responded to the revised proposal.

NEXT BEST ACTION
[ Schedule follow-up ]
```

## 13. Promise engine

Promises normal task list nahi:

```
PROMISE AT RISK
"We'll send the revised proposal by Friday."
Owner: Nauman
Due: Tomorrow
Risk: HIGH
[ Resolve ] [ Open thread ]
```

## 14. Health

Visual. RELATIONSHIP HEALTH 82 Healthy.
Breakdown (thin bars, giant charts nahi):
Engagement 91 · Responsiveness 78 · Sentiment 88 · Momentum 72 · Commitments 81

## 15. Risk

RISK RADAR:
- Deal stalled 8 days
- Customer silent
- Promise overdue
- Decision maker missing

Click → evidence. No AI hallucinated warning. Every risk needs: reason · source · timestamp · evidence.

## 16. Evidence

Visually distinctive:

```
EVIDENCE
Why is this account at risk?
──────────────
Email · Sep 10 — "Need revised pricing..."
Meeting · Sep 08 — Decision postponed
Task · Sep 09 — Proposal still pending
```

AI output explainable.

## 17. Graph

Cinematic network:

```
            Company
               │
       ┌───────┼────────┐
       ↓       ↓        ↓
     Person   Deal     Account
       │       │         │
      Mail    Files     Chat
       │       │         │
      Chat    Tasks    Meetings
```

Dark canvas `#050A12`. Nodes 72–120px. Connections 1px, subtle animated flow.

## 18. Next

AI action center:

```
NEXT BEST ACTIONS
1. Follow up with Sarah — Why: no response for 6 days
2. Review ACME proposal — Why: promise due tomorrow
3. Schedule decision-maker meeting — Why: deal stalled
```

Each: Why · Evidence · Action. Buttons: Review · Approve · Dismiss.

## 19. Typography

- Page title 32–38px
- Section title 18–22px
- Card title 14–16px
- Normal text 13–15px
- Metadata 11–12px
- KPI number 28–32px
- Weights 400/500/600/700 — bold everywhere nahi.

## 20. Animation system

Expensive feel, busy nahi:
- Standard 150–200ms
- Modal 220–280ms
- Page transition 240–320ms
- Graph: slow 1.5–3s ambient
- Background: 10–20s
- No looping 200ms animation.

## 21. Cinematic color system

Existing dark system maintain:
- Base `#07101D` `#0B1220`
- Primary `#2563EB` · Indigo `#4F46E5` · Teal `#06B6D4`
- Success `#22C55E` · Warning `#F59E0B` · Danger `#EF4444`
- Text `#F8FAFC` · Muted `#94A3B8`

Primary colors accents ke liye, backgrounds paint karne ke liye nahi.

## 22. 8K cinematic feel ka actual formula

1. Pixel-perfect spacing
2. Huge contrast
3. Deep layered background
4. Beautiful typography
5. Glass depth
6. Fine 1px borders
7. Micro-animation
8. Excellent charts
9. Beautiful empty-state composition
10. Consistent iconography
11. Very clean responsive layout
12. No visual clutter

## 23. Mobile

- Global rail → bottom nav / drawer
- CRM secondary nav → horizontal scroll
- KPI cards → 2 columns
- Main content → 1 column
- AI Next panel → bottom section
- Main padding 16px, card radius 16px

## 24. Tablet (1024–1200px)

- Secondary nav 200px
- KPI 3 × 2
- Main 60/40

## 25. Final visual identity

```
         ANEXOMAIL CRM

   calm      intelligent      cinematic
      \           |             /
        ── relationship OS ──

  DATA → MEMORY → TIMELINE → PROMISES → HEALTH → RISK → EVIDENCE → GRAPH → NEXT ACTION
```

---

## Match rules (locked)

- Har feature real — recorded rows se. Dummy / hallucinated number banned.
- Mail host pe Leo zero — "AI NEXT" panel rules-based hai; AI memory/agent/brief = AI host.
- Existing dashboard / mail / shell duplicate nahi — CRM compliment karta hai.
- 28 locales: har label `t()`.
