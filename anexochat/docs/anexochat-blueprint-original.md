# ANEXOChat™ Blueprint — The World's Super-Advanced Business Chat
# FOUNDER ORIGINAL — DO NOT MODIFY

> Save kiya: Sep 9 2026. Yeh founder ka original blueprint hai.
> Koi code nahi likhna jab tak founder phase number bole.

---

## LOVABLE — READ THIS FIRST

This is the complete ANEXOChat project specification.

Basic and Pro plans are EXCLUDED from ANEXOChat.

ANEXOChat is available to:
- Business
- Business Pro
- ANEXOMAIL AI — AI Pro
- ANEXOMAIL AI — AI Business
- ANEXOMAIL AI — AI Executive

Phases 1–56 are the common human-to-human ANEXOChat foundation.
Phase 57 adds the AI assistance layer.

Therefore:
- Business + Business Pro → Phases 1–56
- ANEXOMAIL AI AI Pro / AI Business / AI Executive → Phases 1–57

Basic and Pro must have no ANEXOChat access.

**CORE RULE:** ANEXOChat is an API-FREE architecture. No third-party AI API, weather API, file-transfer API, chat API, or external SaaS API is required for the core product.

---

## PART 0 — NON-NEGOTIABLE ARCHITECTURE RULES

```
ANEXOChat Client
      ↓
WebTransport / HTTP/3 / QUIC
      ↓
Rust Realtime + Transfer Engine
      ↓
PostgreSQL / Supabase
      ↓
SB4 Data Layer
```

Supporting realtime synchronization may use: Supabase Realtime

**BANNED:**
- No external chat provider
- No external file-transfer service
- No external weather service
- No external AI API
- No DeepInfra dependency
- No OpenWeatherMap dependency
- No Open-Meteo dependency
- No third-party "chat API"
- No third-party "AI moderation API"

---

## PHASE 1 — ANEXOCHAT FOUNDATION

**Product Identity:** ANEXOChat™ — Instant conversation. Business-grade ownership.
**Parent:** ANEXOMAIL™
**Purpose:** Private human-to-human communication inside a verified business workspace.
**Core philosophy:** Mail when it matters. Chat when it's instant. Work when it's done.

**Business Pro:** £250/month per company
Includes: Unlimited legitimate internal users, Unlimited messages, Unlimited chat transfer, 1TB pooled workspace storage, 5GB maximum individual file, ANEXOMAIL Business, Advanced administration, Device Trust, Audit Ledger, Access revocation, Export, Privacy controls, Priority support

---

## PHASE 2 — DUAL REALTIME TECHNOLOGY

ANEXOChat will not depend on a single realtime mechanism.

**Primary transport:** WebTransport + HTTP/3 + QUIC — Rust-based realtime/transfer engine
- Existing Caddy routing: `/wt/*`
- Port: 3200

**Supporting synchronization:** Supabase Realtime
Used for: presence, lightweight state synchronization, notifications, workspace events

**Important technical rule:** Do not describe QUIC as "zero packet loss."
Correct principle: Reliable QUIC streams provide reliable ordered delivery with retransmission; WebTransport can also use datagrams where loss-tolerant delivery is appropriate.

---

## PHASE 3 — POSTGRESQL MESSAGE ENGINE

PostgreSQL becomes the durable source of truth for: conversations, participants, messages, message states, reactions, edits, deletions, read receipts, delivery receipts, attachments, tasks, promises, decisions, conversation state

**Message lifecycle:**
```
Client → Transport → Validation → Durable database write → Delivery event → Recipient → Read confirmation
```

A message is never considered permanently sent merely because the UI animation completed.

---

## PHASE 4 — SUPABASE / SB4 DATA FOUNDATION

Data domains: Workspace, Users, Memberships, Conversations, Messages, Files, Devices, Trust, Safety, Audit, Business objects

Workspace isolation is mandatory.

---

## PHASE 5 — RLS WORKSPACE PRIVACY

Every workspace object must enforce workspace membership. RLS is not optional. Security must exist at the database boundary, not only in the frontend.

---

## PHASE 6 — ANEXOMAIL INTEGRATION

ANEXOMAIL sidebar: Mail, People, Calendar, Work, ANEXOChat

ANEXOChat: 💬 ANEXOChat 4 → Click → new browser tab
Same: authenticated session, workspace, user identity, permissions, membership, notification state, unread state

---

## PHASE 7 — CORE UI

Claude-style conversational simplicity

```
┌──────────────┬───────────────────────────────────┐
│ People       │ Sarah                             │
│              │                                   │
│ Search       │ Hey, did you get the contract?    │
│              │                                   │
│ Sarah        │ Yes, received it.                 │
│ John         │                                   │
│ Accounts     │ Great 👍                           │
│ Sales        │                                   │
│ Support      │                                   │
│              │                                   │
│              │ +  Message...              Send   │
└──────────────┴───────────────────────────────────┘
```

Rules: Minimal sidebar, Full conversation focus, No Slack maze, No unnecessary channels, No 50 buttons, Keyboard shortcuts, Responsive, Dark mode mandatory

---

## PHASE 8 — MESSENGER PARITY

1-to-1 chat, Group chat, Emoji, Reactions, Reply, Forward, Copy, Edit, Delete, Search, Pin, Mute, Archive, Unread counter, Links, Media, Documents, Voice messages, Notifications, Typing, Presence, Read receipts

Goal: If someone already knows WhatsApp, they immediately understand ANEXOChat.

---

## PHASE 9 — MESSAGE STATES

```
Sending → Sent → Delivered → Read
```

Never merge these into one fake "success" state.
Typing: "Sarah is typing..." | Presence: ● Online / ○ Away / Offline

---

## PHASE 10 — MESSAGE EDIT / DELETE

**Edit:** 5-minute window. After that: Edit unavailable. Edited message shows "edited".
**Delete for me:** Removes from user's view.
**Delete for everyone:** 1-hour initial window. Business/audit rules must remain consistent with the published retention policy.

---

## PHASE 11 — OFFLINE-FIRST OUTBOX

```
Message → Pending → Local outbox → Connection restored → Server reconciliation → Sent
```

Never show "Sent" while the message is only sitting locally. User sees: "Waiting to send"

---

## PHASE 12 — CROSS-DEVICE CONTINUITY

Same account across: desktop, laptop, tablet, PWA/mobile
Synchronize: messages, read state, unread state, drafts, attachments, conversation state, relevant position

---

## PHASE 13 — FILE ENGINE

Business Pro: Unlimited transfer volume, Individual file max 5GB, Storage 1TB pooled workspace

Transfer and storage are separate concepts.

---

## PHASE 14 — RUST LARGE-FILE ENGINE

```
Browser → WebTransport → QUIC → Rust Transfer Engine → Storage
```

Support: chunking, streaming, integrity checks, resumable transfers, concurrent transfer management, backpressure, progress reporting

---

## PHASE 15 — RESUMABLE 5GB TRANSFER

Connection disappears → Transfer paused. Connection returns → Resuming from last position. No unnecessary restart from zero.

---

## PHASE 16 — FILE TRUTH

```
Selected → Uploading → Uploaded → Scanning → Verified → Available → Downloaded
```

The UI must never claim "Delivered" when only the browser upload finished.

---

## PHASE 17 — FILE SECURITY WITHOUT EXTERNAL API

No DeepInfra. No external moderation API.

```
Upload → File type validation → Malware/dangerous-file scanning → Content safety classification → Integrity verification → Storage → Available
```

Models/tools run inside infrastructure controlled by ANEXOMAIL. No external AI API dependency.

---

## PHASE 18 — CONTENT SAFETY

Explicit prohibited content → Block → Record safety event → Notify appropriate review system → Account enforcement

Normal human conversations are not sent to an AI API.

---

## PHASE 19 — DEVICE SAFETY VAULT

Device signals → Normalized identifier → Cryptographic hash → Encrypted vault

Used for: abuse prevention, banned-device detection, suspicious registration detection. Not biometric fingerprinting.

---

## PHASE 20 — DEVICE TRUST

User/admin can see devices and trust status. Action: Revoke Access — One click.

---

## PHASE 21 — SAFETY REPORTING

Users can report: message, person, file, conversation

Founder/admin review queue: New → Under Review → Action → Resolved

Do not expose private message content unnecessarily to reviewers.

---

## PHASE 22 — BUSINESS SUPERPOWER: MESSAGE → TASK

Message: "Sarah, send the invoice tomorrow." → Action: Create Task
Task: Send invoice | Owner: Sarah | Deadline: Tomorrow | Source: ANEXOChat

---

## PHASE 23 — PROMISE ENGINE

```
Promise → PROMISE (Owner, Action, Due, Status)
States: Pending → Due → Overdue → Kept → Cancelled
```

---

## PHASE 24 — DECISION LEDGER

Important message: "Migration Friday at 02:00." → Mark as Decision
DECISION: Migration, Friday · 02:00, Made by: Sarah, Timestamp: 13:42 UTC, Source: ANEXOChat

---

## PHASE 25 — CONVERSATION TIMELINE

Conversation becomes structured: Messages, Files, Tasks, Promises, Decisions, Important
Timeline: 09:12 Request → 09:17 File received → 10:03 Decision → 11:22 Task → 14:40 Promise → 16:12 Completed

---

## PHASE 26 — CONVERSATION HEALTH

🟢 Healthy | 🟡 Waiting | 🔴 Blocked | ✓ Completed

---

## PHASE 27 — MESSAGE PROVENANCE

Sent by: john@company.com | Workspace: ABC Ltd | Timestamp: 14:32:11 UTC | Delivery: Confirmed | Integrity: Verified

---

## PHASE 28 — BUSINESS CONVERSATION RECEIPTS

Message: ✓ Sent ✓ Delivered ✓ Read
Attachment: ✓ Uploaded ✓ Scanned ✓ Verified ✓ Available

Core principle: Don't just say it happened. Show what happened.

---

## PHASE 29 — EMAIL → CHAT

From ANEXOMAIL: "Discuss in ANEXOChat" → Opens relevant conversation.

---

## PHASE 30 — CHAT → EMAIL

Conversation → Create formal email → Recipients → Subject → Attachments → Send

---

## PHASE 31 — FILE CONTEXT

File → Uploader → Conversation → Related Work → Related Email → Decision / Promise

---

## PHASE 32 — PERMANENT BUSINESS SEARCH

Search returns: Messages, Files, People, Tasks, Promises, Decisions, Emails
Filters: person, date, conversation, file, task, decision, promise

---

## PHASE 33 — CONVERSATION EXPORT

Export: messages, timestamps, participants, files, delivery states, decisions, promises, relevant work records

---

## PHASE 34 — CONVERSATION COST

Optional analytics: Participants, Active attention time, Estimated attention cost. Calculation must be explainable. No hidden AI scoring.

---

## PHASE 35 — ATTENTION LEAKS

Workspace-level analytics: Communication overhead by category.
Purpose: Find communication overhead. Not: secretly monitor employees.

---

## PHASE 36 — CALM MODE

Weather effects OFF, Particles OFF, Sound OFF, Unnecessary motion OFF, Notification pressure reduced. Chat remains fully functional.

---

## PHASE 37 — CINEMATIC WEATHER WITHOUT EXTERNAL WEATHER API

No Open-Meteo. No OpenWeatherMap. No weather API.

Layer 1 — Device Clock: Dawn/Day/Dusk/Night automatic atmosphere
Layer 2 — Optional Device Location: Local calculations only, no external service
Layer 3 — Device Sensors: Ambient Light Sensor if supported, graceful fallback

---

## PHASE 38 — CINEMATIC WEATHER STATES

Dawn, Sunny, Cloudy, Rain, Storm, Snow, Night

Important: If real weather data is not available without an external service, ANEXOChat must not falsely claim it is showing the user's actual weather.

---

## PHASE 39 — MESSAGE SEND CINEMATIC EFFECT

On send: Message → Gradient sweep → 300ms → Fade
Direction: Left → Right | Brand gradient: Blue → Purple → Teal
Calm Mode: No animation. Motion budget: 300ms

---

## PHASE 40 — CINEMATIC PERFORMANCE

Priority: Message correctness → Realtime → Input responsiveness → File transfer → Visual effects

If device performance falls: Full effects → Reduced effects → Static atmosphere → Calm Mode

---

## PHASE 41 — GROUP CHAT

Groups included. But ANEXOChat remains simple. No huge Slack-style hierarchy.

Group features: messages, files, reactions, replies, pinned messages, tasks, promises, decisions, search, notifications

---

## PHASE 42 — BUSINESS GROUP INTELLIGENCE

Group conversation can show: 3 active promises, 2 pending tasks, 1 decision, 4 files

No AI required for the core functionality.

---

## PHASE 43 — 1TB STORAGE GOVERNANCE

80%: Warning | 90%: Almost full | 100%: New uploads paused

Existing files remain available. Messaging continues. Export continues. No silent deletion.

---

## PHASE 44 — FOUNDER / ADMIN ANEXOCHAT

Founder/admin interface includes: ANEXOChat access, workspace overview, reports, safety queue, storage, device trust, audit, system health, transfer health, abuse events, operational alerts

Critical privacy rule: Admin access does not automatically mean unrestricted reading of private employee conversations.

---

## PHASE 45 — FOUNDER GOD-VIEW

Founder cockpit: Companies, Active users, Online users, Messages, Files, Storage, Transfer health, Safety alerts, Device alerts, Reports, System health

No fake numbers.

---

## PHASE 46 — REALTIME RESILIENCE

Transport failure → Approved fallback transport → State reconciliation

No message loss. No duplicate message creation. No phantom delivery.

---

## PHASE 47 — SECURITY & PRIVACY ARCHITECTURE

Layers: Authentication → Workspace membership → RLS → Authorization → Device Trust → Transport security → File scanning → Audit → Export/delete controls

---

## PHASE 48 — NO MOCK DATA

Do not create fake: users, messages, files, storage, presence, audit events, weather, delivery receipts, transfer progress.

If backend state doesn't exist: "No conversations yet" — not fake Sarah/John conversations.

---

## PHASE 49 — API-FREE ENFORCEMENT

BANNED: ❌ OpenAI API ❌ Anthropic API ❌ DeepInfra API ❌ OpenWeather API ❌ Open-Meteo API ❌ Pusher ❌ Ably ❌ Sendbird ❌ Stream Chat ❌ Firebase Chat ❌ third-party file-transfer API

Where advanced intelligence is required, prefer: browser-native capability → Rust implementation → self-hosted service → PostgreSQL/Supabase capability → local/self-hosted model

---

## PHASE 50 — PERFORMANCE OBSERVABILITY

Measure: message p50/p95/p99, delivery latency, read latency, typing latency, presence latency, reconnect time, file throughput, upload resume time, UI interaction latency

Founder can see actual numbers. Not "Blazing fast." Evidence instead.

---

## PHASE 51 — ACCESSIBILITY

Support: keyboard navigation, screen readers, reduced motion, high contrast, focus states, accessible composer, accessible notifications, accessible file status

---

## PHASE 52 — RESPONSIVE DESIGN

Desktop: People | Conversation
Tablet: Adaptive two-panel
Mobile: People → Conversation

No broken sidebar. No hidden composer. No inaccessible send button.

---

## PHASE 53 — RELEASE GATE

Before production verify all: Authentication, Workspace isolation, Messaging, Delivery, Read receipts, Typing, Presence, Offline, Reconnect, Files, 5GB enforcement, Scanning, Resume, Storage, 1TB enforcement, Export, Device Trust, Revocation, Audit, Notifications, Groups, Search, Email bridge, Calm Mode, Cinematic UI, Performance, Accessibility

---

## PHASE 54 — FINAL PRODUCT STACK

```
                     ANEXOChat™
                          │
           ┌──────────────┼──────────────┐
           │              │              │
      MESSENGER       BUSINESS       CINEMATIC
      EXPERIENCE      SUPERPOWERS     EXPERIENCE
           │              │              │
      Messages          Tasks          Atmosphere
      Groups            Promises       Dawn/Day/Dusk/Night
      Reactions         Decisions      Rain/Snow style
      Presence          Receipts
      Typing            Provenance
      Files             Search
      Notifications     Attention
                             │
                        TRUST LAYER
                        Device Trust / Safety / RLS / Audit / Export
                             │
                          ANEXOMAIL → Mail / People / Work → ANEXOMAIL AI
```

---

## PHASE 55 — FINAL COMMERCIAL LOCK

**Business:** £85/user/month — ANEXOMAIL Business

**Business Pro:** £250/month per company (NOT per user / NOT per mailbox / NOT per employee)

Included in Business Pro:
✅ Unlimited legitimate internal users
✅ Unlimited ANEXOChat messages
✅ Unlimited ANEXOChat transfer volume
✅ 1TB pooled storage
✅ 5GB maximum individual file
✅ Groups, Read receipts, Typing, Presence, Resumable transfers
✅ Business work layer, Promise tracking, Decision ledger, Conversation health
✅ Message provenance, Business receipts, Permanent search, Email ↔ Chat bridge
✅ Device Trust, Audit Ledger, Access revocation, Export, Safety system
✅ Cinematic experience, Calm Mode, Priority support

---

## PHASE 56 — FINAL ANEXOCHAT PHILOSOPHY

**WhatsApp/Messenger gives people:** Easy communication.

**ANEXOChat gives businesses:** Easy communication + ownership + work context + proof + control.

The user should feel:
1. "WhatsApp jaisa simple."
2. "Lekin business ke liye bana hua."
3. "Is mein meri conversation actual work ban sakti hai."
4. "Mujhe pata hai kya hua, kis ne kiya, aur system ne kya actually verify kiya."

---

## PHASE 57 — ADVANCED HUMAN-CHAT AI ASSISTANT LAYER (ANEXOMAIL AI plans only)

### CORE PRINCIPLE

ANEXOChat remains: Human → Human
Phase 57 adds: Human → AI Helper → Human Work

AI normal conversation ka hidden participant nahi hoga.
- AI silently messages read nahi karega
- Automatically reply nahi karega
- Automatically send nahi karega
- Automatically create task nahi karega
- User explicitly AI ko invoke karega

### LEO — CHAT ASSISTANT

Leo modes: Ask, Explain, Summarize, Draft, Translate, Find, Extract, Organize, Compare, Prepare, Analyze

### KEY AI FEATURES (Phase 57)

1. **Conversation Summary** — Key points, Decisions, Promises, Tasks, Pending items, Files, People
2. **Ask questions about chat** — "What did Sarah promise?"
3. **Promise Intelligence** — Deeper interpretation, User creates (not AI silently)
4. **Task Extraction** — Human confirmation required
5. **Decision Extraction** — "Save Decision" (user action)
6. **AI Drafting** — Draft → Review → Edit → Send (no autonomous sending)
7. **Chat → Email AI** — Leo generates, user reviews
8. **Email → Chat AI** — Leo explains email
9. **AI Translation** — Any language, credit-metered
10. **Multilingual Assistance** — Mixed conversation support
11. **AI File Understanding** — PDF/DOCX/XLSX/PPTX analysis
12. **Citation-Only Answers** — No source = no confident answer
13. **File Comparison** — With sources shown
14. **AI Search** — Natural language, authorized conversations only
15. **People Intelligence** — From authorized workspace records
16. **Work Intelligence** — Combines conversations, tasks, promises, decisions, files, emails
17. **Conversation Health Explanation** — Why is this yellow/red?
18. **Follow-Through Assistant** — Overdue promises list
19. **Meeting/Calendar Context** — Where authorized
20. **AI Action Preparation** — Multi-step work prep (no auto-execute)
21. **AI Workflow Builder** — User approves before activation
22. **Smart Reply** — User chooses/edit/send
23. **Tone Control** — Professional/Concise/Friendly/Direct/Formal/Diplomatic
24. **AI Rewrite** — Simplify/shorten/clarify/professionalize/expand/translate
25. **AI Grammar** — Proposed version, no auto-modify
26. **AI Email Composer** — User reviews → sends
27. **AI Inbox Intelligence** — "What needs my attention today?"
28. **Attention Brief** — 5-minute briefing
29. **Risk Detection** — Potential risk signals (not established facts)
30. **Conversation Prioritization** — Ranked with reasons
31. **AI Business Search** — Auditable natural language search
32. **AI Knowledge Layer** — Sources: emails, chat, files, work, calendar, people
33. **AI Permission Wall** — User permission → Workspace permission → Object permission → AI retrieval (NOT: AI → Everything)
34. **AI Executive Briefing** — Revenue-related, customer commitments, overdue, pending decisions, risks

### AI CREDIT SYSTEM

| Plan | Price | Credits |
|---|---|---|
| AI Pro | £400/month | 1,200 credits |
| AI Business | £1,000/month | 5,000 credits |
| AI Executive | £2,000/month | 10,000 credits |

**Pre-flight estimate mandatory:** "This will use ~8 credits. You have 1,192 remaining." → User: Approve → Execute

**Post-action receipt:** Every AI operation generates: Action, Model, Credits used, Time, Source

**Zero-credit state:** Human ANEXOChat continues. AI pauses.
**Complimentary credits:** 5/day for first 2 days = 10 total per billing cycle

### AI PRIVACY BOUNDARY

AI only processes content when: user explicitly requests OR user has explicitly enabled a documented AI workflow.

- No hidden indexing for AI
- No secret AI reading
- No advertising use
- No selling communication data

### AI ACTION PERMISSION MODEL

- Level 1 — Read: AI can answer questions
- Level 2 — Prepare: AI can draft/prepare
- Level 3 — Execute: Only when user/workspace explicitly authorized

---

## FINAL MASTER LOCK

BUILD ANEXOChat™ PHASE 1 THROUGH PHASE 57.

- Basic (£20) + Pro (£40) → ZERO ANEXOChat access
- Business → Phases 1–56
- Business Pro → Phases 1–56 (full £250/company limits)
- AI Pro / AI Business / AI Executive → Phases 1–57

Do not duplicate Phases 1–56 for AI plans. AI plans inherit the exact same foundation + Phase 57.

**Architecture:** API-FREE from the beginning.
**No mock data. No fake users. No fake messages. No fake weather. No fake delivery states. No hidden AI activity. No hidden AI credit deductions.**

ANEXOChat = human communication.
**Mail when it matters. Chat when it's instant. Work when it's done.**
