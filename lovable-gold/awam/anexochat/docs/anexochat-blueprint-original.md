# ANEXOChat™ Blueprint — The World's Super-Advanced Business Chat

> ## TECHNOLOGY FOR ANEXOChat — founder order 1 Nov 2026 ("beast level, WhatsApp aur Telegram ko challenge")
> Added at the top by founder's written order; the original blueprint below is unchanged. Applies to BOTH awam ANEXOChat and the founder-side chat (same engine, founder gates on top). Facts verified 1 Nov 2026.
>
> | Layer | Technology | Why for chat | Status |
> |---|---|---|---|
> | Realtime push | WebTransport over QUIC (Rust `wtransport`, UDP 3443) | messages, typing, presence without TCP head-of-line blocking | awam LIVE (0.1.14, old); upgrade to 0.7.x later |
> | Channels / live rooms / broadcast (one-to-many) | MoQ (Media over QUIC), `draft-ietf-moq-transport-22`, pinned to ONE draft, behind a flag | fan-out to thousands (Telegram-channel style, live rooms) | PLANNED; OUR OWN Rust relay (founder 1 Nov: no Cloudflare), still a draft, no RFC, so fallback = WebTransport/WebSocket |
> | 1:1 and group calls | WebRTC + TURN (`anexovideochat-turn.md`) | MoQ is not the right fit for 2-way calling | unchanged |
> | Attachments | A1-A4 common file engine (resumable chunks, A3 over WebTransport) | WhatsApp-class big files | PLANNED, master order 11b/11c |
> | Verification in browser | Rule-52 WASM kernel (Ed25519, HMAC, Merkle `merkle@1`) | tamper-proof message/audit proofs | founder GREEN; awam pin 0.6.0 pending pull |
> | Sessions | DBSC (Chrome 146 Windows) + passkeys | stolen-cookie protection | PLANNED step 7 / 7b |
> | Transport crypto | TLS 1.3 now; hybrid post-quantum only after a check | honest claims only | check pending |
> | Hardening | RLS on Supabase, signed writes, audit hash chain + Merkle | founder gates | GREEN on founder |
>
> Not claimed: "production-ready MoQ", "Meta relay", "256-bit TLS". Details: `docs/claude/TECH-CHART-01NOV.md`.

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

> **UPDATE 3 Nov 2026 13:09 PKT (founder, verbatim in `docs/cursor-work/founder/founder-commands.md`): THE AWAM GETS NO AI IN ANEXOCHAT.** Phase 57 (the AI assistant layer) is **FOUNDER-ONLY and only on demand ("jab mujhe zarurat hogi")**. The three AI plans are no longer a way into ANEXOChat AI. ANEXOChat is for **Business, Business Pro and Business Premium** only. The AI plan lines in this section are kept for history and are SUPERSEDED. File limits and monthly quota: **Phase 61**.

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
Includes: Up to 570 users, Unlimited messages, Monthly chat transfer quota 150 GB per user (fair-use, throttled never blocked; Phase 61), 1TB pooled workspace storage, maximum individual file per package (Business 500MB, Business Pro 1.5GB, Business Premium 4GB; Phase 61), ANEXOMAIL Business, Advanced administration, Device Trust, Audit Ledger, Access revocation, Export, Privacy controls, Priority support

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

Individual file max: Business 500MB, Business Pro 1.5GB, Business Premium 4GB; transfer = monthly bandwidth quota per user (Phase 61, throttle never block); Storage 1TB pooled workspace

Transfer and storage are separate concepts.

---

## PHASE 14 — RUST LARGE-FILE ENGINE

```
Browser → WebTransport → QUIC → Rust Transfer Engine → Storage
```

Support: chunking, streaming, integrity checks, resumable transfers, concurrent transfer management, backpressure, progress reporting

---

## PHASE 15 — RESUMABLE TRANSFER (per-package max file 500MB / 1.5GB / 4GB, Phase 61)

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

Before production verify all: Authentication, Workspace isolation, Messaging, Delivery, Read receipts, Typing, Presence, Offline, Reconnect, Files, per-package file-size + monthly quota enforcement (Phase 61), Scanning, Resume, Storage, 1TB enforcement, Export, Device Trust, Revocation, Audit, Notifications, Groups, Search, Email bridge, Calm Mode, Cinematic UI, Performance, Accessibility

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
✅ ANEXOChat transfer within the monthly bandwidth quota (Phase 61: 150 GB per user per month, throttled never blocked)
✅ 1TB pooled storage
✅ 1.5GB maximum individual file (Phase 61)
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

## PHASE 57 — ADVANCED HUMAN-CHAT AI ASSISTANT LAYER (FOUNDER ONLY, ON DEMAND — awam AI REMOVED 3 Nov 2026 13:09; was: ANEXOMAIL AI plans only)

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

## PHASE 58 — 5G SLICE-ON-DEMAND FOR CALLS AND BIG FILES (CAMARA QoD) — founder 3 Nov 2026 11:24 PKT
- Wire protocol: CAMARA Quality on Demand (GSMA Open Gateway). Founder id: J7; awam id: AX11. Research and honest limits: `docs/claude/CELLULAR-CORE-J7-J9-RESEARCH-03NOV.md`.
- When a user STARTS an 8K-capable simulcast video call or forwards big files, the Rust backend may ask the user's operator (direct or via an aggregator) for a priority profile for that device and UDP flow, and ends the session when the call ends. The user sees "Priority network on" only after the operator confirms the session; if the operator says no or the network ends it (`NETWORK_TERMINATED`), the call continues normally and the UI says so.
- Not promised: "zero drop". Pakistan operators are unverified; without an operator/aggregator contract the feature shows "not available on your network". No mock status (Rule 69).
- Packages: Business Pro (which parts: founder decides) and Business Premium (whole website). The gate is written at the END of the AnexoChat build (Rule 72).

## PHASE 59 — T3 REMOTE ABORT / REMOTE WIPE THAT WORKS WITHOUT INTERNET (vault lease; NIDD only for IoT hardware) — founder 3 Nov 2026 11:24 PKT
- Founder id: J8; awam id: AX12. The founder asked for 3GPP Non-IP Data Delivery. Verified: NIDD (SCEF/NEF `3gpp-nidd/v1`) serves cellular-IoT devices, not smartphone apps. So this phase delivers the same outcome (a hijacked or cut-off device locks itself and its database) with: (1) a short server-signed device lease that the AnexoChat vault needs to open; a revoked device is not renewed and locks when the lease ends, even if the thief keeps it offline; (2) while online, the J6 Web Push and the WebTransport channel revoke at once; (3) company-wide "delete for everyone" and the strict security actions keep their own audit-chain entry and T2/T3 gate.
- NIDD adapter: only if an operator exposes SCEF/NEF access AND an IoT-class device (an Anexo hardware token) exists. Not claimed before it runs.
- Packages: Business Pro (which parts: founder decides) and Business Premium. Gate at the END (Rule 72).

## PHASE 60 — WORKSPACE DEVICE IDENTITY BOUND TO THE SIM (IoT SAFE / ARA-M, plus SIM-swap signals) — founder 3 Nov 2026 11:24 PKT
- Founder id: J9; awam id: AX13. IoT SAFE is a SIM-applet root of trust for cellular IoT devices; a normal user's eSIM belongs to the operator and cannot carry our applet, and iOS gives apps no SIM-applet access. So this phase delivers: (1) AnexoChat device-vault credentials bound to a hardware-backed passkey (J3: Secure Enclave / StrongBox, AAGUID allow-list, MDS) so a cloned app cannot sign as the user; (2) CAMARA SIM Swap / Device Swap signals feed the E139 risk engine as an extra reason (step-up or deny), never as a login factor; (3) an IoT SAFE adapter only for enterprises that supply their own IoT SAFE SIMs or a future Anexo hardware token.
- Not claimed: "mathematically 0% impersonation". Real claim: an attacker needs the device-bound key, which does not leave its hardware.
- Packages: Business Pro (which parts: founder decides) and Business Premium. Gate at the END (Rule 72).


## PHASE 61 — FILE TRANSFER LIMITS + MONTHLY BANDWIDTH QUOTA (founder 3 Nov 2026 13:09 PKT, his own formula; supersedes every "5GB / unlimited transfer" line above)
**Per-file maximum:** Business **500 MB** · Business Pro **1.5 GB** · Business Premium **4 GB**. (Old gates 2 GB / 5 GB / 7 GB are REPLACED; Basic and Pro have no ANEXOChat.)
| Package | Per file | Monthly cap per user (= per-file x 100 sends) | Organisation pool |
|---|---|---|---|
| Business | 500 MB | 50 GB | 20 users x 50 GB = 1 TB |
| Business Pro | 1.5 GB | 150 GB | 570 users x 150 GB = 85.5 TB, fair-use |
| Business Premium | 4 GB | 400 GB | **21,000 users cap** (NOT unlimited; only the price page shows the word 'Unlimited') x 400 GB per user = 8.4 PB fair-use |
- **The dial:** the monthly quota is per-file x **100 sends** a month; "100" is his dial and can be raised or lowered.
- **Burst:** one hour of burst = per-file x 10 (token bucket). It does not eat the monthly quota; it only smooths the speed.
- **Warnings:** at 80% the user is warned; at 100% the transfer is **throttled (slowed), never blocked**; **inbound is never closed**; no billing shock.
- **Dedup:** the same file (sha256) sent again, to anyone, counts ONCE (offices send the same file often).
- **Free re-download:** a user who already took a file and fetches it again from the browser cache = 0 counted.
- **Resumable chunks** (Phase 14/15) stay; the **gate is enforced in Rust on the server**, the UI is only a mirror (Rule: server gate, never UI-only).
- **Honest cost (his numbers):** Hetzner bandwidth is about EUR 1 per TB; the most expensive case (Premium, 400 GB per user per month) is about EUR 0.40 per user per month, nothing against a GBP 21,000 per month plan. The cap exists to stop abuse, not to recover the Hetzner bill.
- **Transfer vs storage stay separate (Phase 13):** the 1 TB pooled storage (Phase 43) is not changed by this phase.
- **Code = the chart (3 Nov 13:17 'ab reality hai'):** `anexochat/sql/phase61_file_limits_quota.sql` (+ `CHECK_phase61.sql`) holds the chart in ONE function `file_chart()`, a trigger refuses any row that disagrees (an old 2/5/7 GB script now FAILS), per-user quota / burst / org pool are generated columns of the one dial, thresholds are a pure function, dedup is a database rule, selftest green in a scratch Postgres. `phase13_15_file_engine.sql` seed rows were edited to the same numbers. `src/lib/plans.ts` + landing text + `main.rs` ping updated. NOT yet on his server: the awam SQL runs with the awam migration (parked); the Rust byte-rate THROTTLE (`rate_mode='slow'`) is applied by the Rust transfer engine in the ANEXOChat build.

---

## FINAL MASTER LOCK

BUILD ANEXOChat™ PHASE 1 THROUGH PHASE 61. (3 Nov 13:09: AI Phase 57 is founder-only; awam AI plans have NO ANEXOChat AI. Packages = Business / Business Pro / Business Premium, split in `anexochat/packages/ANEXOCHAT-PACKAGES-PHASEWISE.md`.)

- Basic (£20) + Pro (£40) → ZERO ANEXOChat access
- Business → Phases 1–56
- Business Pro → Phases 1–56 (full £250/company limits)
- ~~AI Pro / AI Business / AI Executive → Phases 1–57~~ SUPERSEDED 3 Nov 13:09: no AI for the awam; Phase 57 founder-only on demand
- Business Premium → whole user side (Phases 1–56, 58–61), nothing founder-side

Do not duplicate Phases 1–56 for AI plans. AI plans inherit the exact same foundation + Phase 57.

**Architecture:** API-FREE from the beginning.
**No mock data. No fake users. No fake messages. No fake weather. No fake delivery states. No hidden AI activity. No hidden AI credit deductions.**

ANEXOChat = human communication.
**Mail when it matters. Chat when it's instant. Work when it's done.**
