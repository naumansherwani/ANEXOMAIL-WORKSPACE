# INV-2 — Chat/Video, CRM/Work/Dashboard, Analytics feature inventory (read-only, 26 Oct 2026)
Status = what code shows; NOT live-tested. 'none' = no plan-surface gate found.

| # | Feature | What | Evidence | Status | Existing gate |
|---|---|---|---|---|---|
| | **A. ANEXOChat + ANEXOVideoCall** | | | | |
| 1 | Real-time 1:1 + group messaging | Send/receive chat with idempotent send, Sending/Sent states, offline "Waiting to send" | lib/chat.ts, routes/app.chat.tsx | code present | showChat (Business+, Personal Pro+/Premium) |
| 2 | Delivery ticks / honest message truth | Per-message truth badges, ticks, no fake "Sent" | components/app/chat/Ticks.tsx, MessageTruth.tsx | code present | showChat |
| 3 | Live push over WebTransport/QUIC | Live message stream, honest poll fallback | lib/chat-transport.ts, wt-url.ts, live-core.ts | code present | showChat (transport shared by all plans) |
| 4 | Image/screenshot attachments | Drag-drop + paste, EXIF strip, real XHR progress, thumbnails | lib/chat-attachments.ts | code present | showChat |
| 5 | Large file transfer (chunked, resumable) | Per-chunk sha256, resume identity, versions, backpressure, storage vs transfer pools | lib/chat-files.ts, components/app/chat/FileTransfers.tsx | code present | showChat + plan size caps (2/5/7GB decided; enforcement TBC) |
| 6 | File context + relationship graph | Link/unlink files with human reason, deterministic diff | lib/chat-file-context.ts, work/FileContextCard.tsx | code present | showWorkBusinessRecord (Business+) |
| 7 | Pop-out window + split view | Open a conversation in own window or two side-by-side | lib/chat-multitask.ts | code present | showChat |
| 8 | Cross-device continuity | Resume anywhere, server-authoritative drafts per device | lib/chat-continuity.ts | code present | showChat |
| 9 | Cinematic atmosphere (Dawn/Day/Dusk/Night) | API-free clock/sensor atmosphere, manual weather effect, Calm Mode | lib/chat-atmosphere.ts, chat-cinema.ts, components/chat/Atmosphere.tsx, CinemaStage.tsx | code present | showChat |
| 10 | Cinematic audio (rain/storm) | User-started Tone.js ambient sound | lib/chat-sound.ts | code present | showChat |
| 11 | Send-sweep animation | Visual send effect | components/app/chat/send-sweep.css | code present | showChat |
| 12 | Decision ledger | Decision from a real message, append-only versions, impact map | lib/chat-decisions.ts, work/DecisionLedger.tsx | code present | Pro+ (Work page section) |
| 13 | Conversation to outcome timeline | Events (message/file/work/decision) on one timeline | lib/chat-timeline.ts, work/ConversationTruth.tsx | code present | showWorkBusinessRecord (Business+) |
| 14 | Conversation health + commitment collision | Health from open work/overdue/blocked/awaiting reply | lib/chat-timeline.ts | code present | showChat |
| 15 | Message provenance | Who/when/hash per message | lib/chat-timeline.ts | code present | showChat |
| 16 | Business conversation receipts | Delivered/read/negative receipts, signed certificate (hashes only) | lib/chat-receipts.ts, work/ReceiptsPanel.tsx | code present | showWorkBusinessRecord (Business+) |
| 17 | Zero-loss handover pack | Handover bundle when someone leaves a conversation | lib/chat-receipts.ts | code present | showChat |
| 18 | Email to chat bridge | Link an email thread to a chat conversation, permanent link | lib/chat-email-bridge.ts, work/EmailBridge.tsx | code present | Pro+ (Work section), needs chat |
| 19 | Chat to email escalation | Formal email from chat with cited quotes + objection log | lib/chat-email-bridge.ts | code present | showChat |
| 20 | Work strip in chat | Message to work item to owner to deadline | components/app/chat/WorkStrip.tsx, lib/chat-safety.ts (Phase 22) | code present | showChat |
| 21 | Work execution chain | Message, work, owner, dependency, deadline, evidence | lib/chat-safety.ts, work/WorkChainBoard.tsx | code present | Pro+ (Work page) |
| 22 | Device safety vault (chat) | Minimised signals hashed to sealed vault | lib/chat-safety.ts (Phase 19) | code present | none found |
| 23 | Device trust / kill access | See devices, revoke in one click | lib/chat-safety.ts (Phase 20) | code present | none found |
| 24 | Safety reporting | new, under review, action, resolved | lib/chat-safety.ts (Phase 21) | code present | none found (Safety centre is showSafety) |
| 25 | 1:1 video call (WebRTC) | Unified Plan, Trickle ICE, ICE restart, TURN fallback (own coturn) | lib/chat-call.ts, components/chat/VideoCall.tsx | code present | DB chat_video_allowed() = founder + business_pro; UI showFullVideo = Pro+ (MISMATCH) |
| 26 | Group call via own SFU (3+) | Simulcast 3 layers, own SFU only | lib/chat-call.ts, chat-lightspeed.ts | code present | same as 25 |
| 27 | Adaptive quality ladder 8K to 480p | Auto step-down/up, honest labels, AV1/VP9/H.264 detection | lib/chat-video-quality.ts | code present | same as 25 |
| 28 | Pre-warmed ICE | Network path warmed before Call is pressed, 60s socket | lib/chat-prewarm.ts | code present | same as 25 |
| 29 | Ring truth + self-made ringtone | answered/declined/no_answer (45s), WebAudio chime, Calm Mode haptic | lib/chat-lightspeed.ts, chat-ringtone.ts | code present | same as 25 |
| 30 | Audio-only survival | Video drops to audio with reason, call stays up | lib/chat-lightspeed.ts | code present | same as 25 |
| 31 | Connect report | Measured connect marks (ICE, signal RTT, first frame) | components/app/chat/CallConnectReport.tsx | code present | same as 25 |
| 32 | Call telemetry (RTT/jitter/loss/bitrate) | Real getStats readings, "measuring" if absent | lib/chat-call.ts | code present | same as 25 |
| 33 | Signaling over WT/Realtime/durable rows | Zero-missed-offer signaling | lib/chat-signal.ts | code present | infrastructure |
| 34 | Call business record | Measured duration, join/leave events, in-call file evidence chain | lib/chat-call-record.ts, work/CallRecordPanel.tsx | code present | showWorkBusinessRecord (Business+) |
| 35 | Screen share, recording, live captions, group sizes | Listed in package docs (formula file, ai-packages.md) | not found in lib audit | UNVERIFIED in code | none |
| 36 | Public landings /anexochat, /anexovideocall | Marketing pages, redirect to /app/chat on founder host | routes/anexochat.tsx, anexovideocall.tsx | works (public) | none |
| 37 | Short paths /chat, /work, /analytics, /dashboard | Redirect to app surfaces | routes/chat.tsx etc | works | none |
| | **B. CRM + Work + Dashboard** | | | | |
| 38 | CRM overview/home | Pipeline summary, empty-book first steps | routes/app.crm.index.tsx, lib/crm.ts useCrmOverview | code present | showCrm (Pro+; Personal Pro+/Premium) |
| 39 | Relationships (people/contacts book) | Person table + side panel, per-person history | routes/app.crm.relationships.tsx | code present | showCrm |
| 40 | Leads | Create, suggestions, convert lead to person, bulk move imported contacts to People | routes/app.crm.leads.tsx, crm.ts | code present | showCrm |
| 41 | Deals pipeline (6 stages) | Advance, mark Lost, reopen | routes/app.crm.pipeline.tsx, crm.ts useMoveDeal | code present | showCrm |
| 42 | Deal to Work item | Turn a deal into a task | crm.ts useDealToWork | code present | showCrm |
| 43 | Attach email thread to deal | Link thread to deal | crm.ts useAttachDealThread | code present | showCrm |
| 44 | Accounts (companies) | Company list | routes/app.crm.accounts.tsx | code present | showCrm |
| 45 | CRM tasks | CRM task list | routes/app.crm.tasks.tsx | code present | showCrm |
| 46 | CRM reports | Open pipeline etc | routes/app.crm.reports.tsx | code present | showCrm |
| 47 | CRM memory + live + insights | Relationship memory, live feed, insights (no LEO on this host) | crm.ts useCrmMemory/useCrmLive/useCrmInsights | code present | showCrm |
| 48 | CRM health | Relationship health | CommandPalette/CrmStage, plan-surface | code present | showCrmHealth |
| 49 | Shared work / collab | Assignment, mentions, approvals, shared drafts | routes/app.crm.collab.tsx, crm.ts useSharedItems/useMentions/useApprovals/useAssignShared | code present | showCrmCollab (Business+) |
| 50 | Approvals | Decide approval requests | crm.ts useDecideApproval | code present | showCrmCollab |
| 51 | Team permissions | Who can see what in CRM | crm.ts useTeamPermissions | code present | showCrmCollab |
| 52 | CRM audit | Audit trail | crm.ts useCrmAudit | code present | showCrmCollab / Org |
| 53 | CRM risk | Risk view | plan-surface showCrmRisk | code present | showCrmRisk (Business+) |
| 54 | CRM activity timeline + evidence | Company timeline of every touch | routes/app.crm.activity.tsx, crm.ts useCrmActivities/useCrmEvidence | code present | showCrmLedger (Business Pro power) |
| 55 | CRM relationship graph | Graph view | components/app/crm/CrmGraph.tsx | code present | showCrmGraph (Business Pro power) |
| 56 | CRM capture | Capture from mail into CRM | components/app/crm/CrmCapture.tsx | code present | showCrm |
| 57 | CRM kill switch | Founder-level switch | crm.ts useCrmKillSwitch, useFounderCrmState | code present | founder |
| 58 | CRM translations (28 locales) | Localised chrome | lib/crm-i18n.ts | works | none |
| 59 | Work: Add task + TaskBoard | Personal tasks board | routes/app.work.tsx, work/TaskBoard.tsx | code present | page comment says Basic gets it; surfaceDenial for /app/work uses showWork = Pro+ (CONFLICT) |
| 60 | Work: Notes | Note document editor | work/NoteDoc.tsx | code present | showWork |
| 61 | Work: Promise inbox | Promises you made | work/PromiseInbox.tsx, lib/promise-engine.ts | code present | showProMailTools (Pro+) |
| 62 | Work: Follow-through table | Follow-up tracker | work/FollowThrough.tsx | code present | Pro+ |
| 63 | Work: Promise recovery | Recover broken promises | work/PromiseRecovery.tsx | code present | showWorkBusinessRecord (Business+) |
| 64 | Work: Locked Pro preview | Upsell preview for Basic | routes/app.work.tsx LockedProWorkPreview | works | Basic wall |
| 65 | Goals + deadlines | Goal/deadline logic | lib/goal.ts, lib/deadline.ts | code present | none found |
| 66 | Team report + team time | Team workload, team clock | lib/team-report.ts, lib/team.ts, dashboard/TeamTime.tsx | code present | none found |
| 67 | Dashboard home | Greeting, setup checklist, panels, install hint | routes/app.index.tsx, components/app/dashboard/* | works | showDashboard (all) |
| 68 | Expiry watch | Dashboard expiry reminders | dashboard/ExpiryWatch.tsx, lib/expiry.ts | code present | none |
| 69 | Install hint (PWA) | Add-to-home-screen hint | dashboard/InstallHint.tsx, lib/pwa.ts | works | none |
| 70 | Setup checklist | Onboarding checklist | dashboard/SetupChecklist.tsx | works | none |
| 71 | Live updates (mail/calendar/crm/work/people/org) | Shared WT connection, topic invalidation, poll fallback | lib/live-core.ts, live.ts | works | all plans, all kinds |
| 72 | Calendar rooms and resources | Bookable rooms/resources with conflict engine | lib/rooms.ts (calendar #8) | code present | none found (Org-managed) |
| | **C. Analytics** | | | | |
| 73 | Response debt (People waiting) | Waiting people/threads, GBP cost of delay, 7-day trend | routes/app.analytics.index.tsx, lib/analytics.ts | code present | NONE (no plan gate) |
| 74 | Deep work | Real work vs inbox, longest focus | routes/app.analytics.deep-work.tsx | code present | NONE |
| 75 | Forecast | Next-week incoming load | routes/app.analytics.forecast.tsx | code present | NONE |
| 76 | Attention leaks | What keeps interrupting | routes/app.analytics.leaks.tsx | code present | NONE |
| 77 | Promise SLA | Did you do what you said, at-risk today | routes/app.analytics.promises.tsx | code present | NONE |
| 78 | Team analytics | Who is drowning, who is free | routes/app.analytics.team.tsx | code present | NONE |
| 79 | Thread economics | What each conversation cost, most expensive threads | routes/app.analytics.threads.tsx | code present | NONE |
| 80 | Report figures | Shared figures helper | lib/report-figures.ts | code present | n/a |

## Surprises
1. Video: DB `chat_video_allowed()` = founder + business_pro only, but UI `showFullVideo` = Pro+ and chat = Business+ (three different rules).
2. Analytics: all 7 routes have NO plan gate anywhere.
3. Work page header says Basic gets TaskBoard, but `surfaceDenial` blocks /app/work below Pro (Business kind); also screen share/recording/captions in docs not found in code.
