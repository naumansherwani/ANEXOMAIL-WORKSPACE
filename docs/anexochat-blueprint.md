# ANEXOChat™ Blueprint — The World's Super-Advanced Business Chat
Status: SOURCE OF TRUTH (locked 14 Aug 2026). Build reads from this file. Founder ne kaha: "kuch add kerwana hai" — additions isi file mein aayengi.

Host: anexochat.anexomail.com (Caddy + Namecheap DNS already done).

Complete All Phases. Core intelligence, realtime, file transfer, safety and business logic run through Supabase4 + PostgreSQL + Rust + tRPC + WebTransport/QUIC + Caddy HTTP/3. Bun must be included as a fallback/secondary. Lovable builds simultaneously for Founder + Business + Business Pro + ANEXOMAIL AI Pro + AI Business + AI Executive.

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
- ANEXOMAIL AI (AI Pro / AI Business / AI Executive) starts from → Phase 57
- Basic and Pro must have no ANEXOChat access.

CORE RULE: ANEXOChat is an API-FREE architecture. No third-party AI API, weather API, file-transfer API, chat API, or external SaaS API is required for the core product. External providers are not part of the runtime dependency chain.

## PART 0 — NON-NEGOTIABLE ARCHITECTURE RULES

Technology principle:

```text
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

Supporting realtime synchronization may use Supabase Realtime.

- No external chat provider.
- No external file-transfer service.
- No external weather service.
- No external AI API.
- No DeepInfra dependency.
- No OpenWeatherMap dependency.
- No Open-Meteo dependency.
- No third-party "chat API".
- No third-party "AI moderation API".

## PHASE 1 — ANEXOCHAT FOUNDATION

Product identity: ANEXOChat™ — "Instant conversation. Business-grade ownership."
Parent: ANEXOMAIL™
Purpose: private human-to-human communication inside a verified business workspace.
Core philosophy: Mail when it matters. Chat when it's instant. Work when it's done.

Business Pro — £2,850/month per company. Includes:

- Unlimited legitimate internal users
- Unlimited messages
- Unlimited chat transfer
- 1TB pooled workspace storage
- 5GB maximum individual file
- ANEXOMAIL Business
- Advanced administration
- Device Trust
- Audit Ledger
- Access revocation
- Export
- Privacy controls
- Priority support

## PHASE 2 — DUAL REALTIME TECHNOLOGY

ANEXOChat will not depend on a single realtime mechanism.

Primary transport: WebTransport + HTTP/3 + QUIC, Rust-based realtime/transfer engine.
Existing Caddy routing: `/wt/*` → port 3200.

Supporting synchronization: Supabase Realtime — used where appropriate for presence, lightweight state synchronization, notifications, workspace events.

The architecture must allow transport components to evolve independently.

Important technical rule: do NOT describe QUIC as "zero packet loss." Correct principle: reliable QUIC streams provide reliable ordered delivery with retransmission; WebTransport can also use datagrams where loss-tolerant delivery is appropriate. For business messages and files: durability and correctness come first.

## PHASE 3 — POSTGRESQL MESSAGE ENGINE

PostgreSQL is the durable source of truth for: conversations, participants, messages, message states, reactions, edits, deletions, read receipts, delivery receipts, attachments, tasks, promises, decisions, conversation state.

Message lifecycle:

```text
Client → Transport → Validation → Durable database write → Delivery event → Recipient → Read confirmation
```

A message is never considered permanently sent merely because the UI animation completed.

## PHASE 4 — SUPABASE / SB4 DATA FOUNDATION

SB4 remains the protected ANEXOChat data environment. Data domains: Workspace, Users, Memberships, Conversations, Messages, Files, Devices, Trust, Safety, Audit, Business objects. Workspace isolation is mandatory.

## PHASE 5 — RLS WORKSPACE PRIVACY

Every workspace object must enforce workspace membership. User A in Workspace A cannot access Workspace B even if they know an object identifier. RLS is not optional. Security must exist at the database boundary, not only in the frontend.

## PHASE 6 — ANEXOMAIL INTEGRATION

ANEXOMAIL sidebar: Mail · People · Calendar · Work · ANEXOChat

`💬 ANEXOChat  4`

Click → new browser tab. Same authenticated session, workspace, user identity, permissions, membership, notification state, unread state.

## PHASE 7 — CORE UI

Claude-style conversational simplicity.

```text
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

Rules: minimal sidebar · full conversation focus · no Slack maze · no unnecessary channels · no 50 buttons · keyboard shortcuts · responsive · dark mode mandatory.

## PHASE 8 — MESSENGER PARITY

1-to-1 chat, group chat, emoji, reactions, reply, forward, copy, edit, delete, search, pin, mute, archive, unread counter, links, media, documents, voice messages, notifications, typing, presence, read receipts.

Goal: if someone already knows WhatsApp, they immediately understand ANEXOChat.

## PHASE 9 — MESSAGE STATES

`Sending → Sent → Delivered → Read`. Never merge these into one fake "success" state.

Typing: `Sarah is typing...`
Presence: `● Online` · `○ Away` · `Offline`

## PHASE 10 — MESSAGE EDIT / DELETE

Edit: 5-minute window. After that: Edit unavailable. Edited message marked `edited`.
Delete for me: removes from user's view.
Delete for everyone: 1-hour initial window.
Business/audit rules must remain consistent with the published retention policy.

### PHASE 10 — NEW ADDED (shipped 15 Aug 2026) — ANEXOVIDEOCHAT 10A + 10B

Yeh Phase 10 ke ANDAR ka hissa hai (naya phase nahi). Business Pro + founder only.

**10A — ultra-low-latency call engine** (`src/lib/chat-call.ts`, `src/lib/chat-signal.ts`, `sql/anexochat_phase10a_call_engine.sql`)
- Unified Plan · Trickle ICE · perfect negotiation · `restartIce()` watchdog (WiFi→4G par black screen nahi).
- P2P preferred + coturn TURN fallback (host `anexovideocall.anexomail.com`, ephemeral HMAC creds; `TURN_SECRET` browser par kabhi nahi). TURN na ho to UI sach bolta hai: "P2P only".
- Signaling: Supabase Realtime broadcast `call:<id>` (persistent) + durable rows catch-up. Polling primary kabhi nahi.
- Telemetry 3 layers: sab ko badge (🟢/🟡/🔴 + resolution + Connected/Reconnecting) · Business Pro tap-to-expand (RTT/jitter/loss/P2P-TURN/bitrate/FPS/res) · founder god-view `/app/founder/calls` (p50/p95 setup, relay %, reconnect rate).

**10B — adaptive 8K pipeline, "no fake 8K"** (`src/lib/chat-video-quality.ts`, `sql/anexochat_phase10b_8k_video.sql`)
- Ladder: 8K (7680×4320, cap 60 Mbps) → 4K → 1440p → 1080p → 720p → 480p, default AUTO.
- Codec order AV1 → VP9 → H.264 (VP8 last resort), `RTCRtpSender.getCapabilities('video')` se detect — assume kuch nahi.
- Label sirf asli measured track/encode/decode reading se: 7680×4320 na mile to "8K" kabhi nahi likha jata; upscale se 8K banana mamnu.
- CPU/bandwidth/encoder limit par khud neeche, halaat theek hone par khud upar; 8K na milne par call kabhi drop nahi hoti.
- DB truth: `chat_call_sessions.capture_native_8k` / `max_encoded_*` / `max_decoded_*` / `top_rung` + view `chat_call_resolution_truth` (native_8k_capture · encoded_8k · decoded_8k · av1_calls). SQL self-healing hai — 10A tables missing ho to khud bana leti hai.
- Multi-party simulcast/SVC SFU-ready shape mein bheja jata hai; TURN ko SFU kehna mamnu (asli group SFU = baad ka phase).

## PHASE 11 — OFFLINE-FIRST OUTBOX

```text
Message → Pending → Local outbox → Connection restored → Server reconciliation → Sent
```

Never show "Sent" while the message is only sitting locally. User sees: `Waiting to send`.

### PHASE 11 — NEW ADDED (shipped 15 Aug 2026) — MESSAGE ENRICHMENT + MULTITASKING

1. **Image / screenshot attachments** — `src/lib/chat-attachments.ts` + `sql/anexochat_phase11_attachments.sql` + `server/routes/chat.ts` (`/api/chat/attachments/ticket|commit|attach|:messageId`).
   - Drag-drop + Ctrl/Cmd+V paste, max 25 MB, PNG/JPEG/WebP/AVIF (GIF → PNG).
   - EXIF/GPS strip client par (canvas re-encode) + client-side thumbnail (320px WebP).
   - Private bucket `chat-media`, signed URLs only; service key browser par kabhi nahi.
   - Progress asli XHR reading se — fake 100% kabhi nahi; row commit ke baad hi attachment dikhta hai (`state: pending → ready`).
2. **Per-conversation drafts** — `src/lib/chat-drafts.ts`: conversation switch par draft zinda, local-only, draft kabhi server par nahi jata aur kabhi "Sent" nahi dikhta.
3. **Multitasking** — `src/lib/chat-multitask.ts`: split view (do asli conversations, dono live, apni apni draft, `ax.chat.split`) + pop-out window (`/app/chat?c=<id>&pane=1`, pane mode mein list/nav chhupti hai). Panel kabhi nahi chhutta.
4. **Lottie + GSAP tick states** — `src/components/app/chat/Ticks.tsx`: waiting/sending = inline Lottie pulse, sent/delivered/read = GSAP stroke-draw check(s), failed = `!` badge. Label + `sr-only` text saath (a11y); state sirf `messageState()` se aati hai — invent kabhi nahi.
5. **Avatars** — `chat_members.avatar_path` + `chat_avatar_set()` RPC + `/api/chat/profile/avatar/ticket|commit` (512px WebP, wahi honest pipeline).



## PHASE 12 — CROSS-DEVICE CONTINUITY

Same account across desktop, laptop, tablet, PWA/mobile. Synchronize messages, read state, unread state, drafts, attachments, conversation state, relevant position. User changes device: work continues.

## PHASE 13 — FILE ENGINE

Business Pro: unlimited transfer volume. Individual file: maximum 5GB. Storage: 1TB pooled workspace.

`ABC Ltd — 684GB / 1TB`

Transfer and storage are separate concepts.

## PHASE 14 — RUST LARGE-FILE ENGINE

```text
Browser → WebTransport → QUIC → Rust Transfer Engine → Storage
```

Support: chunking, streaming, integrity checks, resumable transfers, concurrent transfer management, backpressure, progress reporting.

## PHASE 15 — RESUMABLE 5GB TRANSFER

`project.mp4 4.7GB — Uploading 94%`. Connection disappears: "Transfer paused." Connection returns: "Connection restored. Resuming from 94%." No unnecessary restart from zero.

## PHASE 16 — FILE TRUTH

`Selected → Uploading → Uploaded → Scanning → Verified → Available → Downloaded`

The UI must never claim "Delivered" when only the browser upload finished.

## PHASE 17 — FILE SECURITY WITHOUT EXTERNAL API

No DeepInfra. No external moderation API. Safety layer runs through self-hosted/local inference or deterministic security tooling.

```text
Upload → File type validation → Malware/dangerous-file scanning → Content safety classification where applicable → Integrity verification → Storage → Available
```

Models/tools can run inside infrastructure controlled by ANEXOMAIL. No external AI API dependency.

## PHASE 18 — CONTENT SAFETY

`Upload → Safety classification → Policy decision`

If clearly prohibited: Block → record safety event → notify appropriate review system → account enforcement according to policy.

Normal human conversations are not sent to an AI API.

## PHASE 19 — DEVICE SAFETY VAULT

At account/device registration: `Device signals → Normalized identifier → Cryptographic hash → Encrypted vault`.

Used for abuse prevention, banned-device detection, suspicious registration detection. Not biometric fingerprinting. Implementation must minimize collected signals and document retention/legal basis.

## PHASE 20 — DEVICE TRUST

User/admin can see: `Chrome · Windows — Trusted`, `Safari · iPhone — Trusted`, `Unknown Device — Suspicious`. Action: Revoke Access, one click.

## PHASE 21 — SAFETY REPORTING

Users can report a message, person, file, conversation. Founder/admin review queue: New → Under Review → Action → Resolved. Do not expose private message content unnecessarily to reviewers.

## PHASE 22 — BUSINESS SUPERPOWER: MESSAGE → TASK

Message: "Sarah, send the invoice tomorrow." → Create Task → Task: Send invoice · Owner: Sarah · Deadline: Tomorrow · Source: ANEXOChat.

## PHASE 23 — PROMISE ENGINE

"I'll send the proposal tomorrow." becomes PROMISE — Owner: Sarah · Action: Send proposal · Due: Tomorrow · Status: Pending.

States: Pending · Due · Overdue · Kept · Cancelled.

## PHASE 24 — DECISION LEDGER

"Migration Friday at 02:00." → Mark as Decision → DECISION: Migration · Friday · 02:00 · Made by Sarah · Timestamp 13:42 UTC · Source ANEXOChat.

## PHASE 25 — CONVERSATION TIMELINE

Conversation becomes structured: Messages, Files, Tasks, Promises, Decisions, Important.

```text
09:12 Request
09:17 File received
10:03 Decision
11:22 Task
14:40 Promise
16:12 Completed
```

## PHASE 26 — CONVERSATION HEALTH

🟢 Healthy · 🟡 Waiting · 🔴 Blocked · ✓ Completed

Example: `ABC Contract — 🟡 Waiting · Owner: Sarah · Due: Today`.

## PHASE 27 — MESSAGE PROVENANCE

Sent by john@company.com · Workspace ABC Ltd · Timestamp 14:32:11 UTC · Delivery Confirmed · Integrity Verified.

## PHASE 28 — BUSINESS CONVERSATION RECEIPTS

Message: ✓ Sent ✓ Delivered ✓ Read. Attachment: ✓ Uploaded ✓ Scanned ✓ Verified ✓ Available.

Core principle: don't just say it happened. Show what happened.

## PHASE 29 — EMAIL → CHAT

From ANEXOMAIL: "Discuss in ANEXOChat" opens relevant conversation. Email remains the formal record. Chat remains the instant communication layer.

## PHASE 30 — CHAT → EMAIL

ANEXOChat → Create formal email → Recipients → Subject → Attachments → Send. No accidental replacement of email.

## PHASE 31 — FILE CONTEXT

`File → Uploader → Conversation → Related Work → Related Email → Decision / Promise`

Example: Contract.pdf — Shared by John · Conversation: ABC Renewal · Related: Contract Approval · Status: Pending.

## PHASE 32 — PERMANENT BUSINESS SEARCH

Search "ABC invoice" returns Messages, Files, People, Tasks, Promises, Decisions, Emails. Filters: person, date, conversation, file, task, decision, promise. One business search surface.

## PHASE 33 — CONVERSATION EXPORT

Export messages, timestamps, participants, files, delivery states, decisions, promises, relevant work records. This preserves: no lock-in.

## PHASE 34 — CONVERSATION COST

Optional business analytics: Participants 8 · Active attention 46 minutes · Estimated attention cost £18.40. Calculation must be explainable. No hidden AI scoring.

## PHASE 35 — ATTENTION LEAKS

Workspace-level analytics: Sales coordination 18% · Support 31% · Internal coordination 27% · Other 24%.

Purpose: find communication overhead. Not: secretly monitor employees. Privacy boundaries remain explicit.

## PHASE 36 — CALM MODE

Weather effects OFF · Particles OFF · Sound OFF · Unnecessary motion OFF · Notification pressure reduced. Chat remains fully functional.

## PHASE 37 — CINEMATIC WEATHER WITHOUT EXTERNAL WEATHER API

No Open-Meteo. No OpenWeatherMap. No weather API.

- Layer 1 — Device clock (always available): Dawn → orange/pink · Day → bright · Dusk → warm · Night → deep navy/stars.
- Layer 2 — Optional device location, used locally only if permission granted. No mandatory external weather service.
- Layer 3 — Device sensors (Ambient Light Sensor / W3C capabilities) can influence brightness, contrast, atmospheric intensity. If unavailable: graceful fallback.

## PHASE 38 — CINEMATIC WEATHER STATES

Dawn (orange/pink gradient) · Sunny (bright sky) · Cloudy (muted grey) · Rain (dark clouds + rain particles) · Storm (lightning-style effect + heavier particles) · Snow (snow particles + white atmosphere) · Night (deep navy + stars).

Important: if real weather data is not available without an external service, ANEXOChat must not falsely claim it is showing the user's actual weather. The visual system may use time/device/environment context without fabricating weather facts.

## PHASE 39 — MESSAGE SEND CINEMATIC EFFECT

`Message → Gradient sweep → 300ms → Fade`. Direction left → right. Brand gradient: Blue → Purple → Teal. Calm Mode: no animation. Motion budget: 300ms.

## PHASE 40 — CINEMATIC PERFORMANCE

Priority: Message correctness → Realtime → Input responsiveness → File transfer → Visual effects.

If device performance falls: Full effects → Reduced effects → Static atmosphere → Calm Mode.

## PHASE 41 — GROUP CHAT

Groups included, but ANEXOChat remains simple: Sales Team, Support Team, Accounts, Project Alpha. No huge Slack-style hierarchy.

Group features: messages, files, reactions, replies, pinned messages, tasks, promises, decisions, search, notifications.

## PHASE 42 — BUSINESS GROUP INTELLIGENCE

Group conversation can show: 3 active promises · 2 pending tasks · 1 decision · 4 files. No AI required for the core functionality.

## PHASE 43 — 1TB STORAGE GOVERNANCE

Business Pro: 1TB pooled workspace storage. 80%: "Workspace storage is 80% full." 90%: "almost full." 100%: new persistent file uploads are paused; existing files remain available; messaging continues; export continues. No silent deletion.

## PHASE 44 — FOUNDER / ADMIN ANEXOCHAT

Founder side contains the same ANEXOChat product surface/control environment: ANEXOChat access, workspace overview, conversations/workspace state where authorized, reports, safety queue, storage, device trust, audit, system health, transfer health, abuse events, operational alerts.

Critical privacy rule: admin visibility must follow the defined privacy model. Admin access does not automatically mean unrestricted reading of private employee conversations. If founder/admin messaging with internal users is enabled, it must be an explicit workspace policy rather than an accidental backdoor.

## PHASE 45 — FOUNDER GOD-VIEW

Founder cockpit: Companies, Active users, Online users, Messages, Files, Storage, Transfer health, Safety alerts, Device alerts, Reports, System health.

Example: ABC Ltd — Users 247 · Online 83 · Storage 684GB / 1TB · Messages today 12,842 · Files today 418 · Safety alerts 0 · Device alerts 2.

No fake numbers.

## PHASE 46 — REALTIME RESILIENCE

`WebTransport → Unavailable → Approved fallback transport → State reconciliation`

No message loss. No duplicate message creation. No phantom delivery. Every state reconciles against durable storage.

## PHASE 47 — SECURITY & PRIVACY ARCHITECTURE

Authentication → Workspace membership → RLS → Authorization → Device Trust → Transport security → File scanning → Audit → Export/delete controls.

No single security feature is treated as the entire security model.

## PHASE 48 — NO MOCK DATA

Lovable must not create fake users, messages, files, storage, presence, audit events, weather, delivery receipts or transfer progress. If backend state doesn't exist: "No conversations yet" — not fake Sarah/John conversations.

## PHASE 49 — API-FREE ENFORCEMENT

Must NOT introduce: OpenAI API, Anthropic API, DeepInfra API, OpenWeather API, Open-Meteo API, Pusher, Ably, Sendbird, Stream Chat, Firebase Chat, third-party file-transfer API.

If a capability requires an external service, first look for: browser-native capability → Rust implementation → self-hosted service → PostgreSQL/Supabase capability → local/self-hosted model.

## PHASE 50 — PERFORMANCE OBSERVABILITY

Measure: message p50/p95/p99, delivery latency, read latency, typing latency, presence latency, reconnect time, file throughput, upload resume time, UI interaction latency. Founder sees actual numbers — evidence, not "blazing fast."

## PHASE 51 — ACCESSIBILITY

Keyboard navigation, screen readers, reduced motion, high contrast, focus states, accessible composer, accessible notifications, accessible file status. Weather/cinematic effects must never interfere with communication.

## PHASE 52 — RESPONSIVE DESIGN

Desktop: People | Conversation. Tablet: adaptive two-panel. Mobile: People → Conversation. No broken sidebar. No hidden composer. No inaccessible send button.

## PHASE 53 — RELEASE GATE

Before production every item must have a real verification result: Authentication, Workspace isolation, Messaging, Delivery, Read receipts, Typing, Presence, Offline, Reconnect, Files, 5GB enforcement, Scanning, Resume, Storage, 1TB enforcement, Export, Device Trust, Revocation, Audit, Notifications, Groups, Search, Email bridge, Calm Mode, Cinematic UI, Performance, Accessibility.

## PHASE 54 — FINAL PRODUCT STACK

```text
                         ANEXOChat™
                              │
               ┌──────────────┼──────────────┐
               │              │              │
          MESSENGER       BUSINESS       CINEMATIC
          EXPERIENCE      SUPERPOWERS     EXPERIENCE
               │              │              │
          Messages          Tasks          Atmosphere
          Groups            Promises       Dawn
          Reactions         Decisions      Day
          Presence          Receipts        Dusk
          Typing            Provenance      Night
          Files             Search          Rain-style
          Notifications     Attention       Snow-style
                              │              │
                              └──────┬───────┘
                                     │
                                TRUST LAYER
                                     │
                         Device Trust / Safety
                         RLS / Audit / Export
                                     │
                                  ANEXOMAIL
                                     │
                             Mail / People / Work
                                     │
                              ANEXOMAIL AI
```

## PHASE 55 — FINAL COMMERCIAL LOCK

Business: £97/user/month — ANEXOMAIL Business. Defined ANEXOChat limits apply.

Business Pro: £2,850/month per company. Not per user. Not per mailbox. Not per employee. Included: unlimited legitimate internal users · unlimited ANEXOChat messages · unlimited ANEXOChat transfer volume · 1TB pooled storage · 5GB maximum individual file · groups · read receipts · typing · presence · resumable transfers · business work layer · promise tracking · decision ledger · conversation health · message provenance · business receipts · permanent search · Email ↔ Chat bridge · Device Trust · Audit Ledger · access revocation · export · safety system · cinematic experience · Calm Mode · priority support.

## PHASE 56 — FINAL ANEXOCHAT PHILOSOPHY

WhatsApp/Messenger gives people easy communication. ANEXOChat gives businesses easy communication + ownership + work context + proof + control.

The user should feel: "WhatsApp jaisa simple." Then: "Lekin business ke liye bana hua." Then: "Is mein meri conversation actual work ban sakti hai." And finally: "Mujhe pata hai kya hua, kis ne kiya, aur system ne kya actually verify kiya."

## FINAL LOVABLE MASTER INSTRUCTION (Phases 1–56)

Build ANEXOChat™ as a native human-to-human private communication system inside ANEXOMAIL. Architecture must be API-FREE from the beginning. Do not introduce third-party chat APIs, AI APIs, weather APIs, file-transfer APIs, moderation APIs or external communication SaaS dependencies. Use the existing Supabase/PostgreSQL/SB4 infrastructure, Supabase Realtime where appropriate, and the Rust/WebTransport/HTTP3/QUIC architecture for realtime and large-file transport.

ANEXOChat is HUMAN-TO-HUMAN. Normal chat must not use AI. Business Pro is £2,850/month per company with unlimited legitimate internal users, unlimited messages, unlimited transfer volume, 1TB pooled storage and 5GB maximum individual file size. Do not implement unlimited storage. Do not implement a monthly transfer cap for Business Pro.

Implement the complete Messenger/WhatsApp familiarity layer first, then the business superpower layer, then safety/trust, then cinematic experience, then advanced realtime/transfer and observability.

No fake data. No fabricated weather. Never claim an external weather source is used. Never claim QUIC has zero packet loss. Never add an external API merely because it is easier. Where advanced intelligence is required, prefer browser-native technology, Rust, self-hosted infrastructure, deterministic processing, or self-hosted/local models.

Preserve workspace RLS, privacy, auditability, exportability and the ANEXOMAIL principle: Your communication. Your data. Your choice.

The final experience should feel as familiar as Messenger/WhatsApp, as clean and fluid as modern conversational interfaces, and substantially deeper for business communication — without becoming a Slack clone.

## PHASE 57 — ADVANCED HUMAN-CHAT AI ASSISTANT LAYER
Founder Lock — ANEXOChat + Leo Intelligence. Phases 1–56 unchanged. Phase 57 is only for ANEXOMAIL AI users.

**1. CORE PRINCIPLE** — ANEXOChat remains Human → Human. Phase 57 adds Human → AI Helper → Human Work. AI is not a hidden participant: it does not silently read messages, auto-reply, auto-send, auto-create tasks or auto-make decisions. The user explicitly invokes AI.

**2. LEO — CHAT ASSISTANT** — Optional "Ask Leo" inside a conversation's context. Example: "Leo, mujhe batao is conversation mein kya decide hua?" Leo modes: Ask · Explain · Summarize · Draft · Translate · Find · Extract · Organize · Compare · Prepare · Analyze.

**3. CONVERSATION SUMMARY** — Summarize produces key points, decisions, promises, tasks, pending items, files, people involved.

**4. ASK QUESTIONS ABOUT THE CHAT** — "What did Sarah promise?" / "What are we waiting for?" answered from the conversation.

**5. PROMISE INTELLIGENCE** — Phase 23 remains non-AI capable; Phase 57 adds deeper interpretation. "I'll send the proposal once I get the numbers from accounts." → Potential Promise (Owner Sarah · Action Send proposal · Dependency Accounts numbers · Status Waiting) with a "Create Promise" button. AI doesn't silently create it.

**6. TASK EXTRACTION** — "John, can you send the invoice to ABC tomorrow?" → Potential task detected (Task, Owner, Due) with Create Task / Dismiss.

**7. DECISION EXTRACTION** — "Okay, Friday 02:00 UTC is confirmed." → Potential decision → Save Decision.

**8. AI DRAFTING** — Draft ≠ Send. AI Draft → Review → Edit → Send. No autonomous sending.

**9. CHAT → EMAIL AI** — "Turn this conversation into a formal customer email." Leo generates subject, greeting, concise summary, relevant commitments, attachments, closing → Review & Create Email.

**10. EMAIL → CHAT AI** — "Discuss with Leo" on an email; Leo explains it and helps prepare a chat response.

**11. AI TRANSLATION** — Any language, both directions. No requirement that ANEXOChat itself have one fixed language.

**12. MULTILINGUAL CONVERSATION ASSISTANCE** — Mixed-language conversations: Leo can explain/translate selected content. AI translation is optional and credit-metered; human chat remains free.

**13. AI FILE UNDERSTANDING** — Authorized files: PDF, DOCX, XLSX, PPTX, images, supported business documents. Answers must distinguish source-backed answer vs uncertainty.

**14. CITATION-ONLY ANSWERS** — For document/workspace questions: no source = no confident answer. Answer + Source (file, page, section).

**15. FILE COMPARISON** — "Compare these two contracts." Differences shown with sources.

**16. CONVERSATION SEARCH WITH AI** — Natural language search returning conversation, participants, date, relevant message, source.

**17. PEOPLE INTELLIGENCE** — "Who is handling the ABC migration?" answered from authorized workspace records with source.

**18. WORK INTELLIGENCE** — Combines authorized conversations, tasks, promises, decisions, files, emails into an outstanding-items view.

**19. CONVERSATION HEALTH EXPLANATION** — "Why is this conversation yellow?" explained with the blocking item.

**20. FOLLOW-THROUGH ASSISTANT** — "What promises are overdue?" → list with owners and due dates.

**21. MEETING / CALENDAR CONTEXT** — Where authorized, connects chat context with calendar/work information.

**22. AI ACTION PREPARATION** — Multi-step preparation (e.g. migration checklist) but never executes sensitive actions automatically.

**23. AI WORKFLOW BUILDER** — Leo proposes a workflow; only after "Approve workflow" does automation become active.

**24. AI SMART REPLY** — Suggestions the user chooses/edits/sends. Every AI generation consumes credits per the defined usage model.

**25. AI TONE CONTROL** — Professional · Concise · Friendly · Direct · Formal · Diplomatic. AI does not automatically alter the original message.

**26. AI REWRITE** — simplify · shorten · clarify · professionalize · expand · translate.

**27. AI GRAMMAR** — Proposed version only; no automatic modification.

**28. AI EMAIL COMPOSER** — Subject, body, timeline, relevant context → Review → Send.

**29. AI INBOX INTELLIGENCE** — "What needs my attention today?" → structured attention list.

**30. AI ATTENTION BRIEF** — "Give me my 5-minute briefing." → needs action, waiting on others, important decisions, upcoming deadlines, potential risks.

**31. AI RISK DETECTION** — Reported as "Potential risk", never as established fact.

**32. AI CONVERSATION PRIORITIZATION** — Ranked with a reason shown for each recommendation.

**33. AI BUSINESS SEARCH** — Natural-language authorized search; remains auditable.

**34. AI KNOWLEDGE LAYER** — Sources: emails, ANEXOChat, files, work, calendar, people, decisions, promises. Permissions inherited — Leo cannot see what the user cannot see.

**35. AI PERMISSION WALL** — User permission → Workspace permission → Object permission → AI retrieval. The AI never becomes an admin backdoor.

**36. AI CREDIT SYSTEM** — Locked AI credit model: AI Pro £400/month → 1,200 credits · AI Business £1,000/month → 5,000 credits · AI Executive £2,000/month → 10,000 credits. Top-ups unchanged. (NOTE: reconcile against locked PRICING v4 before build.)

**37. PRE-FLIGHT CREDIT ESTIMATE** — Mandatory before every AI operation: "This will use ~8 credits. You have 1,192 remaining." → Approve → execute. No surprise deductions.

**38. POST-ACTION RECEIPT** — Action, model, credits, time, source — stored in AI usage history.

**39. DYNAMIC CREDIT CONSUMPTION** — Cost depends on context length, model cost, processing complexity, workflow complexity, file size, number of documents, operation type.

**40. AI MODEL ROUTING** — Leo → AI provider layer → model selection → execution → credit accounting. Provider changes must not change credit accounting.

**41. AI FALLBACK** — Primary model → unavailable → approved fallback → retry. Never report "Success" when AI actually failed.

**42. AI FAILURE TRUTH** — "Leo couldn't complete this request. No credits were charged." Partial success must be reflected honestly in the receipt.

**43. ZERO-CREDIT STATE** — Human ANEXOChat continues normally; AI pauses: "AI credits finished. Your chat and workspace remain fully available." Then: renew plan · purchase top-up · wait for complimentary credits.

**44. COMPLIMENTARY CREDITS** — Day 1: 5 credits · Day 2: 5 credits · total 10 per billing cycle. Then AI pauses again. Human chat unaffected.

**45. AI USAGE DASHBOARD** — Balance plus breakdown: chat assistance, document analysis, drafting, search, translation, other.

**46. CREDIT WALLET** — Always visible in the AI interface; shows balance, consumption, complimentary credits, renew date, top-ups, receipts.

**47. AI HISTORY** — Every AI interaction reviewable with time, action, credits.

**48. AI FAVORITES** — Save useful AI outputs/prompts (customer reply template, migration briefing, contract analysis, daily briefing).

**49. AI PROMPT LIBRARY** — Prebuilt actions: summarize conversation, find commitments, prepare reply, translate, explain document, find risks, prepare meeting brief, create task, extract decisions. User doesn't need to learn prompting.

**50. AI STUDIO** — Structured AI operations over authorized workspace data with pre-flight estimate, approve, run, receipt.

**51. AI AUTOMATION** — Prepare summaries, identify potential promises, prepare drafts, classify conversations, prepare reports, extract work, generate briefings. Sensitive external actions remain approval-gated.

**52. AI WORKFLOW BUILDER (visual)** — Trigger → retrieve authorized context → AI analysis → human approval → action → receipt. Every AI step shows estimated credits before execution.

**53. AI MEETING EXTRACTION** — From authorized notes/transcripts: decisions, tasks, owners, deadlines, promises → Review → Create.

**54. AI TASK EXTRACTION** — Potential task → owner → deadline → source. Human confirmation required.

**55. AI KNOWLEDGE SEARCH** — Natural-language search across authorized sources; answer + sources; no unsupported answer.

**56. AI PERSONAL WORK ASSISTANT** — "What should I deal with before I finish today?" → prioritized list from authorized context.

**57. AI EXECUTIVE BRIEFING** — Revenue-related communication, customer commitments, overdue promises, pending decisions, migrations, important unread communication, risks, today's deadlines. All claims must have sources.

**58. AI PRIVACY BOUNDARY** — Human chat stays private human communication. AI only processes content when the user explicitly requests an AI operation or has explicitly enabled a documented AI workflow. No hidden indexing, no secret AI reading, no advertising use, no selling communication data.

**59. AI ACTION PERMISSION MODEL** — Level 1 Read (answer questions) · Level 2 Prepare (draft/prepare) · Level 3 Execute (only when explicitly authorized). Sensitive actions require approval by default.

**60. FINAL PHASE 57 POSITION** — Human messages → unlimited/included → ANEXOChat. AI assistance → credit-metered → AI Pro / Business / Executive → top-ups when needed. Every time: Estimate → Approve → Execute → Receipt. No hidden AI consumption, no hidden AI activity, no AI pretending to be human.

Killer principle: the more value Leo creates, the more AI credits the customer chooses to use.

## FINAL LOVABLE LOCK

Build the entire ANEXOChat project from Phase 1 through Phase 57.

- Basic £23 and Pro £46 are completely excluded — do not display ANEXOChat access, features or navigation to Basic or Pro users.
- Business receives Phases 1–56.
- Business Pro receives Phases 1–56 with the full £2,850/company limits and features.
- ANEXOMAIL AI (AI Pro, AI Business, AI Executive) receives from Phase 57 — the AI layer.
- Do not duplicate or rebuild Phases 1–56 for AI plans. AI plans inherit the exact same foundation and add Phase 57.
- ANEXOChat itself remains human-to-human. Phase 57 adds Leo as an explicit AI assistant.
- The core architecture is API-FREE. Use the existing Supabase/PostgreSQL/SB4 + tRPC + Rust + WebTransport + Caddy HTTP/3 infrastructure with Bun as fallback, plus controlled/self-hosted AI infrastructure.
- No mock data. No fake users. No fake messages. No fake weather. No fake delivery states. No hidden AI activity. No hidden AI credit deductions.
- Preserve all existing ANEXOMAIL architecture, pricing, security, privacy, Phase 29 UX principles and founder-lock decisions.
- Build phase-by-phase. Do not skip phases. Do not merge phases. Do not invent a new architecture. Do not change pricing. Do not expose Phase 57 AI functionality to Business/Business Pro unless the account has an ANEXOMAIL AI plan.

ANEXOChat = human communication.

Mail when it matters. Chat when it's instant. Work when it's done.

---

# ADDITIONS v2 — locked 14 Aug 2026 (founder: Muhammad Nauman Sherwani)

Yeh additions existing phases ke ANDAR add hote hain — naya phase nahi banta, tarteeb nahi badalti. Har item apne phase ka hissa hai. Build se pehle founder se discuss lazmi.

## A. Per-phase addition index (sirf yahan add hoga)

| Existing Phase | Sirf yahan add hoga |
| --- | --- |
| Phase 3 | Message identity + idempotency + duplicate-send protection + ordering |
| Phase 4 | Identity, membership, roles and account lifecycle |
| Phase 5 | Authorization boundary + RLS enforcement model |
| Phase 9 | Durable event/state ledger for message lifecycle → **SHIPPED: Lottie/GSAP tick states (Phase 11 NEW ADDED §4)** |
| Phase 10 | Edit/delete windows + **SHIPPED: ANEXOVideoChat 10A call engine + 10B adaptive 8K "no fake 8K"** |
| Phase 11 | Offline outbox reconciliation + retry correctness → **SHIPPED: attachments (EXIF-strip, signed URLs), per-conversation drafts, split view + pop-out, avatars** |
| Phase 12 | Cross-device state reconciliation + session continuity |
| Phase 13 | File versioning + storage/transfer distinction |
| Phase 14 | Chunk integrity + checksum/hash verification |
| Phase 15 | Resumable-transfer identity + corrupted/missing chunk recovery |
| Phase 16 | File truth/evidence state machine |
| Phase 19 | Device identity lifecycle + privacy/retention rules |
| Phase 20 | Device/session revocation + trust lifecycle |
| Phase 21 | Complete report/safety enforcement workflow |
| Phase 22 | Deterministic task lifecycle + source/evidence relationship → **WORK EXECUTION CHAIN** |
| Phase 23 | Follow-through engine + promise completion evidence → **PROMISE RECOVERY ENGINE** |
| Phase 24 | Decision immutability + decision history → **DECISION IMPACT MAP** |
| Phase 25 | Immutable conversation snapshots + business timeline → **CONVERSATION-TO-OUTCOME TIMELINE** |
| Phase 26 | Commitment Collision detection + deadline collision map → **COMMITMENT COLLISION PREVENTION** |
| Phase 27 | Message integrity / tamper evidence |
| Phase 28 | Business Receipt Pack / proof evidence → **ZERO-LOSS HANDOVER PACK** |
| Phase 29 | Email ↔ Chat object relationship / continuity |
| Phase 30 | Chat → Email provenance preservation |
| Phase 31 | Business object graph → **BUSINESS RELATIONSHIP GRAPH** |
| Phase 32 | Universal business search → **⌘K UNIVERSAL BUSINESS COMMAND SURFACE** |
| Phase 33 | Complete immutable export + no-lock-in evidence structure |
| Phase 34 | Attention Budget + explainable cost ledger → **COMMUNICATION ROI LEDGER** |
| Phase 35 | Attention leaks + deadline/commitment pressure map → **ATTENTION DEBT MAP** |
| Phase 36 | Quiet Hours / Focus protection |
| Phase 37 | Weather-atmosphere truth boundary + graceful fallback |
| Phase 38 | Cinematic state fallback hierarchy |
| Phase 39 | Send-animation identity tied to canonical message send |
| Phase 40 | Adaptive performance degradation / effect kill-switch |
| Phase 41 | Group membership lifecycle + group continuity |
| Phase 42 | Deterministic group work-state summary |
| Phase 43 | Retention policy + storage governance + deletion behavior → **BUSINESS MEMORY CONTINUITY** + large-conversation capacity |
| Phase 44 | Admin boundaries + employee departure/handover → **EMPLOYEE HANDOVER CONTINUITY** |
| Phase 45 | Founder operational recovery/backup visibility — without private-chat backdoor |
| Phase 46 | Full event reconciliation + fallback transport duplicate prevention |
| Phase 47 | Backup, restore, disaster recovery + security architecture |
| Phase 48 | Data-integrity rule: no fabricated recovery/demo state |
| Phase 49 | Dependency governance / external-service kill-switch policy |
| Phase 50 | Observability for all critical reliability paths |
| Phase 51 | Accessibility for new controls / evidence states |
| Phase 52 | Responsive behavior for business command / evidence surfaces |
| Phase 53 | Real release-gate probes: idempotency, ordering, recovery, restore, RLS, transfer integrity |
| Phase 54 | Final architecture: Proof Mode / business continuity layer |
| Phase 55 | Exact Business vs Business Pro commercial boundary |
| Phase 56 | Final differentiation: **PROOF MODE** + Zero-Loss Handover + Commitment Collision |
| Phase 57 | AI permission wall + citation enforcement + approval + credit receipt + failure truth |

## B. PHASE 22 — ADD THIS: WORK EXECUTION CHAIN

ANEXOChat must connect communication to actual business execution without turning normal chat into a task-management maze.

When a message creates a business obligation:

```text
Message → Task / Promise / Decision → Owner → Dependency → Deadline → Completion → Evidence
```

The original message remains the source context. The resulting work object must retain: source message ID, conversation ID, creator, owner, created timestamp, deadline, current state, completion evidence.

A task must never become detached from the conversation that created it. If the source message is later deleted from the user's normal view, the business object's provenance must follow the published retention and audit policy.

## C. PHASE 23 — ADD THIS: PROMISE RECOVERY ENGINE

The Promise Engine must not stop at detecting whether a promise is overdue. For every overdue promise, determine the available recovery state:

```text
Promise → Due → Overdue → Recovery
```

Example: 🔴 Promise overdue · Owner Sarah · Promise "Send revised proposal" · Due Friday · Downstream impact "ABC customer quote".

Available actions: Remind owner · Reassign · Update deadline · Mark kept · Mark cancelled. No action is taken automatically unless explicitly authorized.

The system must preserve: original promise, original deadline, subsequent changes, who changed the deadline, reason for change, completion evidence. This creates a follow-through history, not merely a reminder.

## D. PHASE 24 — ADD THIS: DECISION IMPACT MAP

Every important business decision may have downstream relationships.

```text
DECISION Migration Friday 02:00 UTC
  ↓ affects Task: DNS verification
  ↓ affects Promise: Customer confirmation
  ↓ affects Cutover: Friday 02:00 UTC
```

Authorized users can see the objects affected by a decision. If a decision changes, show potentially affected tasks, promises, deadlines, conversations, files, related work. The system must never silently rewrite historical decisions — a changed decision creates a new decision state/history entry.

## E. PHASE 25 — ADD THIS: CONVERSATION-TO-OUTCOME TIMELINE

The timeline must show not only what was said, but what resulted.

```text
09:12 Customer requested migration
09:17 Contract received
10:03 Migration date decided
10:20 Task created
11:22 Promise made
14:40 DNS completed
16:12 Customer confirmation received
18:00 Migration completed
```

The system distinguishes Communication from Business outcome, so a user can reconstruct the complete history of an important matter without searching hundreds of messages.

## F. PHASE 26 — ADD THIS: COMMITMENT COLLISION PREVENTION

Identify conflicting or dependent business commitments.

Example: Sarah promise "Send proposal Friday"; John task "Send final customer quote Friday" with dependency on Sarah's proposal →

```text
⚠ Commitment Collision
John's deadline depends on Sarah's overdue/pending commitment.
Potential downstream delay: Customer quote
```

The system must show the relationship and evidence behind the warning. It must not invent dependencies. Actions: Resolve dependency · Change deadline · Reassign · Dismiss · View source. This is a business coordination layer, not a generic notification.

## G. PHASE 28 — ADD THIS: ZERO-LOSS HANDOVER PACK

Authorized Handover Pack for business continuity when a user leaves a project, department, workspace or company.

Contents: active conversations · open tasks · pending promises · overdue commitments · important decisions · relevant files · outstanding dependencies · upcoming deadlines · known risks.

Every item retains source/provenance. The handover must distinguish: Confirmed fact · Pending item · Overdue item · Historical decision · Open dependency. Never fabricate missing context. Supports review, recipient assignment, export, audit record, completion confirmation.

## H. PHASE 31 — ADD THIS: BUSINESS RELATIONSHIP GRAPH

```text
ABC Ltd
 ├── Sarah
 ├── Conversation
 │     ├── Contract.pdf
 │     ├── Task
 │     ├── Promise
 │     └── Decision
 ├── Email
 └── Migration
       ├── DNS
       ├── Deadline
       └── Payment
```

Objects linked through durable IDs, not copied text. Navigation: Message → Conversation → Customer → File → Task → Promise → Decision → Email. Permissions apply to every relationship — a user must never gain access to a protected object merely because it is linked from another object.

## I. PHASE 32 — ADD THIS: ⌘K UNIVERSAL BUSINESS COMMAND SURFACE

Single keyboard-first command surface (Cmd+K / Ctrl+K) that searches and navigates authorized people, conversations, messages, files, tasks, promises, decisions, emails, customers, work objects.

Examples: "ABC migration" · "overdue promises" · "Sarah" · "contract.pdf".

The command surface must not bypass permissions. It is a unified business navigation layer, not a second database.

## J. PHASE 34 — ADD THIS: COMMUNICATION ROI LEDGER

Communication cost optionally connected to measurable outcomes.

```text
ABC Renewal — 46 minutes · estimated attention cost £18.40
Outcome: ✓ 2 decisions ✓ 3 tasks ✓ 1 customer issue resolved

Internal discussion — 18 minutes · estimated cost £7.20
Outcome: No recorded decision · No task · No completed work
```

Calculation must remain explainable. Never claim communication was "unproductive" merely because no task or decision was recorded — show measured cost and recorded outcomes; the business interprets.

## K. PHASE 35 — ADD THIS: ATTENTION DEBT MAP

```text
ATTENTION DEBT
12 unanswered important conversations
7 overdue promises
4 pending decisions
3 customer replies waiting
2 deadlines approaching
```

Groupable by person, customer, project, department, deadline, urgency. Purpose: reveal unresolved communication pressure — not secretly monitor employees.

## L. PHASE 43 — ADD THIS: BUSINESS MEMORY CONTINUITY + LARGE CONVERSATION CAPACITY

Historical business communication must remain usable across the workspace lifetime, subject to the published retention policy. A years-old conversation must remain reconstructable when retained: messages, files, decisions, promises, tasks, receipts, provenance, conversation relationships. No artificial "recent messages only" architecture.

Large conversation capacity: a single conversation may contain up to 500,000 words of message content, subject to system resource limits and published technical limits. UI must use efficient pagination/virtualization; the system must not load the entire conversation into the browser.

## M. PHASE 44 — ADD THIS: EMPLOYEE HANDOVER CONTINUITY

```text
Outgoing user → active business responsibilities → open conversations → tasks → promises → decisions → files → dependencies → Incoming owner
```

Transfer business continuity without transferring unnecessary private access. Access transfer must be explicit and auditable. Never hand over credentials or unrestricted private account access.

## N. PHASE 56 — ADD THIS: PROOF MODE

Optional Proof Mode turns a normal business event into a structured evidence view.

```text
PROOF MODE — Contract.pdf
Source: ANEXOChat conversation
Uploaded by: john@abc.com
Uploaded: 14:32:11 UTC
Delivery: Confirmed
File integrity: Verified
Related decision: Contract approved
Related task: Legal review
Related promise: Customer confirmation
Evidence: ✓ Message ✓ Delivery ✓ File ✓ Integrity ✓ Decision
```

Proof Mode must never invent evidence. If a state was not actually recorded, show `Not recorded`.

Principle: don't just trust what the conversation says happened — show what the system actually recorded.

## O. WOW-FACTOR UI DIRECTIVE (locked)

- Entry point: ANEXOMAIL sidebar mein Mail ke NEECHE `ANEXOChat` — click par NAYA TAB khulta hai (anexochat.anexomail.com) jahan wow factor hai.
- Target: duniya ki sab se advance chat UI — latest technology par, 100% original. Founder ne jo screenshots diye woh sirf manzar samjhane ke liye reference hain: NO COPY, NO DUPLICATE, koi visual/code copy nahi.
- Cinematic atmosphere states: ☀️ Sunny (bright sky) · 🌧 Rain (particles + dark clouds) · ⛈ Storm (lightning flash + heavy rain) · ❄️ Snow (falling snowflakes) · 🌙 Night (stars + dark) · 🌅 Dawn (orange/pink gradient).
- Glass-morphism bubbles, message send = gradient light sweep (300ms, blue → purple → teal), atmosphere-matched send effect (e.g. raindrop sweep in rain state).
- Calm Mode = koi effect nahi, chat fully functional.
- Cinematic atmosphere = Business Pro exclusive experience layer.

### OPEN CONFLICT — founder decision pending (do not build until resolved)

Founder's wow-factor brief mentions a real weather source (OpenWeatherMap / "Real weather API check kare", location-based Lahore/Dubai/London). This conflicts with the locked API-FREE rule (Phase 37/38/49: no OpenWeatherMap, no Open-Meteo, no external weather API, and never falsely claim real weather).

Two allowed resolutions — founder chooses one:

1. **API-FREE (current lock):** atmosphere device clock + optional device location + optional ambient-light sensor se banta hai; badge honest rehta hai (e.g. "Dusk · Karachi" ya "Atmosphere: Rain (manual)"), asli weather ka dawa nahi. Sunny/Rain/Storm/Snow/Night/Dawn sab available, user/workspace theme ya self-hosted derivation se.
2. **Self-hosted weather truth:** weather data self-hosted service (apna Rust worker + open dataset) se aata hai, phir badge "Clear · 32°C" jaisa asli claim kar sakta hai. Yeh Phase 49 exception hai aur founder ki likhi approval chahiye.

Third-party weather API (OpenWeatherMap) core runtime mein tab hi jaayega jab founder explicit likh kar API-FREE lock ko is ek jagah exempt karay. Default = option 1.
