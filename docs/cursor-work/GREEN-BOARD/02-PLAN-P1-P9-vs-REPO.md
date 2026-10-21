# 02 — MASTER-BUILD-PLAN (docs/MASTER-BUILD-PLAN.md) har item vs repo

21 Oct 2026, asli ghadi ~06:50 PKT · repo HEAD b18c4b9+ · source: MASTER-BUILD-PLAN.md, MASTER-GAP-LEDGER.md, loophole-ledger.md, blueprint G-table, DONE-DO-NOT-REPEAT.md, PROMISES.md, TECH-MAP.md + repo grep (src/, server/).

**Zubaan (sach, jhoot nahi):**
- 🟢 **GREEN** = live saboot (founder ka server output ya Chrome mein dekha) — dobara mat chhuo.
- 🟡 **CODE** = repo mein bana (file maujood), live par chalne/dekhne ka saboot nahi.
- 🟠 **PARTIAL** = kuch hissa green/maujood, kuch baqi.
- 🔴 **TODO** = repo mein bana hi nahi (ya server par nahi chala).
- 🔵 **FOUNDER** = founder ka faisla/haan/login/DNS chahiye.
- ⚪ **PARKED** = founder ne rok rakha.
**Dhyaan:** P1–P9 ke "CODE" ka matlab sirf itna ki file maujood hai (grep se mila) — chalta hai ya nahi, wo live test se hi tay hoga. Isse zyada main daawa nahi karta.


## P1
| Item | Status | Evidence | Agla qadam |
|---|---|---|---|
| Login cinema split (auth page) | 🟢 GREEN | Plan status board: 'LIVE — screenshot liya'; login live (B1/B2 proofs) |  |
| Inline error states, no generic message | 🟡 CODE (bana, live saboot baqi) | auth.tsx + auth-harden (login-loop fix, probe 72 calls 200); live retest of every error text nahi hua | founder login par error screens ek dafa dekhna |
| Password strength indicator (signup) | 🟡 CODE (bana, live saboot baqi) | src/routes/auth.tsx mein hai | live signup par dekhna |
| Forgot password flow (real email) | 🟡 CODE (bana, live saboot baqi) | auth.tsx + E19 password-reset hardening (docs/cursor-work/server/e19-...) | live reset email test |
| Email confirmation state UI | 🟡 CODE (bana, live saboot baqi) | auth.tsx | live signup test |
| Session persist (refresh pe logout nahi) | 🟢 GREEN | B1 GREEN 21 Oct 04:55: refresh asli, logout 26 s baad token 401 (revocation) |  |

## P2
| Item | Status | Evidence | Agla qadam |
|---|---|---|---|
| Real mail counters (unread/starred/today) | 🟠 PARTIAL | Panels.tsx/Greeting.tsx; Basic dashboard live dekha (20 Oct 22:00). 'starred/today' counters ka live saboot nahi | Pro/Business/Business Pro par dashboard numbers check (G41) |
| Activity feed (last 10) | 🟡 CODE (bana, live saboot baqi) | Panels.tsx | live check |
| Quick Actions bar | 🟡 CODE (bana, live saboot baqi) | Panels.tsx | live check |
| Upcoming panel (today's events) | 🟡 CODE (bana, live saboot baqi) | Panels.tsx/Greeting.tsx; calendar events live (E51) | live check |
| AI usage panel (AI plan users) | 🟡 CODE (bana, live saboot baqi) | Panels.tsx | AI plan account se check |
| Founder version: Founder View stats | 🟡 CODE (bana, live saboot baqi) | app.founder.tsx + server/routes/founder.ts | founder login par check |

## P3
| Item | Status | Evidence | Agla qadam |
|---|---|---|---|
| Email snooze | 🟡 CODE (bana, live saboot baqi) | lib/mail.ts snooze + UI action row 'Snooze' (820 par dikha) | snooze ke baad wapas aana live test |
| Scheduled send | 🟢 GREEN | B3: mail.schedule/hold Rust worker, proof SAB PASS (asli Postfix), Compose 'Held for 30s' live |  |
| Undo send | 🟢 GREEN | G-UNDO GREEN 21 Oct 01:20 (cancel 200, mail nahi aayi) + B3 undo/409 proofs. NOTE: plan 10 s likhta hai, product 30 s | plan doc ka '10 s' badal kar 30 s likhna |
| Read receipts (open tracking) | 🟠 PARTIAL | ThreadInsights.tsx (opens/response rate server se) maujood; per-message 'kab/kahan khola' receipt UI ka saboot nahi | scope tay karna + live test |
| Thread intelligence auto-labels | 🟠 PARTIAL | server/routes/mail-predict.ts (word prediction) hai; Receipt/Newsletter/Important auto-label ka alag code nahi mila | TODO decide |
| Split inbox (Priority vs Other) | 🔴 TODO (bana nahi) | repo mein split/priority inbox code nahi mila | build |
| Focus mode (ek thread, baqi fade) | 🔴 TODO (bana nahi) | repo mein 'focus mode' nahi mila | build |
| Keyboard-first (har action) | 🟠 PARTIAL | ⌘K CommandPalette + keydown handlers app.mail.$folder.tsx; single-key map (c r f e s # / g i g s g d ?) ka poora saboot nahi | map audit + live test |

## P4
| Item | Status | Evidence | Agla qadam |
|---|---|---|---|
| Rich text editor (bold/italic/lists/links) | 🟠 PARTIAL | ComposeStudio.tsx mein formatting hai (plain/HTML compose); full rich editor ka alag saboot nahi | live compose test |
| Attachment drag-drop | 🟡 CODE (bana, live saboot baqi) | ComposeStudio.tsx onDrop; G38 server side GREEN, live Compose attach SEND test baqi (C3) | Chrome: attach bhej kar test (founder 'haan' mail bhejne ke liye) |
| Inline image paste | 🔴 TODO (bana nahi) | compose mein onPaste nahi mila (sirf chat mein) | build |
| CC/BCC toggle | 🟡 CODE (bana, live saboot baqi) | ComposeStudio.tsx | live check |
| Scheduled send UI | 🟢 GREEN | Compose live: 'Sending… Held for 30s' toast |  |
| Undo send countdown toast | 🟢 GREEN | G-UNDO GREEN (30 s, Undo button) — plan '10 s' purana |  |
| Cinematic send animation (sweep) | 🟠 PARTIAL | blueprint ka sweep effect: MessageStream/WorkspaceLoader mein animations; Compose send sweep ka alag saboot nahi | live dekhna |
| Draft auto-save every 30 s | 🟡 CODE (bana, live saboot baqi) | ComposeStudio.tsx draft | live test |
| LEO compose assist (grammar/professional/translate) | 🟡 CODE (bana, live saboot baqi) | ComposeStudio.tsx LEO calls; AI plan par live test nahi | AI account se test |

## P5
| Item | Status | Evidence | Agla qadam |
|---|---|---|---|
| Conversation view (replies grouped) | 🟢 GREEN | Thread live dekha 390/820 (Basic) |  |
| Inline reply | 🟡 CODE (bana, live saboot baqi) | InlineReply.tsx; live reply bhejna test nahi (mail bhejne ke liye founder haan) | live test |
| Quote original toggle | 🟡 CODE (bana, live saboot baqi) | InlineReply.tsx | live test |
| Discuss in ANEXOChat button | 🟡 CODE (bana, live saboot baqi) | DiscussInChat.tsx + QuoteInChat.tsx | AnexoChat audit (D10) ke saath |
| Attachment preview inline (PDF/image) | 🟠 PARTIAL | SafeMailBody.tsx images; G38b download chip GREEN; inline PDF preview nahi mila | build/decide |
| Thread actions: star/archive/snooze/delete/print | 🟠 PARTIAL | ThreadHeaderActions.tsx (Done/Archive/Meeting/Snooze/Label HScroll live); print nahi mila; star/delete ka live saboot nahi | audit |
| Email → Task | 🟡 CODE (bana, live saboot baqi) | EmailBridge.tsx (work) + app.work.tsx | live test |
| Link preview cards | 🔴 TODO (bana nahi) | unfurl/link-preview code nahi mila | build |

## P6
| Item | Status | Evidence | Agla qadam |
|---|---|---|---|
| Contact list with search | 🟡 CODE (bana, live saboot baqi) | app.people.tsx; people_core/people_glue Rust LIVE (G23, 182 procs) | Basic/Pro live click-through |
| Contact profile (history/stats/last contact) | 🟡 CODE (bana, live saboot baqi) | ContactProfile.tsx | live check |
| Company profile (domain ke sab contacts) | 🟡 CODE (bana, live saboot baqi) | CompanyProfile.tsx | live check |
| Contact timeline | 🟡 CODE (bana, live saboot baqi) | Timeline.tsx | live check |
| Import vCard/CSV | 🟡 CODE (bana, live saboot baqi) | ContactsImport.tsx + contacts-import.ts + people_import Rust (L75) | live import test |
| Relationship intelligence ('30 din se baat nahi') | 🟠 PARTIAL | Profile/Timeline mein hai; 30-day nudge ka alag saboot nahi | decide + test |

## P7
| Item | Status | Evidence | Agla qadam |
|---|---|---|---|
| Week view (primary) | 🟢 GREEN | Calendar desktop week = TimeGrid live: create, drag move+resize LIVE VERIFIED (21 Oct 04:25) |  |
| Month view (toggle) | 🟠 PARTIAL | TimeGrid/WeekGrid mein month hits; live toggle saboot nahi | live check |
| Create/edit/delete event | 🟢 GREEN | calendar.create GREEN after E51 (21 Oct 00:50), calendar.update drag persisted; delete live saboot nahi | delete live test |
| Attendees + RSVP | 🟠 PARTIAL | Guests.tsx + /rsvp link; guest ka Gmail/Outlook 'Yes' reply (iMIP) = G26 TODO (B7) | B7 |
| Timezone support | 🟡 CODE (bana, live saboot baqi) | calendar.ts + FindTime | live check |
| Email → Calendar (meeting request detect) | 🟠 PARTIAL | IcsImport.tsx (.ics) hai; mail se meeting-request auto-detect ka saboot nahi | decide |
| Focus windows (deep work block) | 🟡 CODE (bana, live saboot baqi) | Availability.tsx/calendar.ts | live check |
| Availability sharing link / scheduling link | 🔴 TODO (bana nahi) | G27 TODO (B7) — scheduling link + recurrence + CalDAV | B7 |

## P8
| Item | Status | Evidence | Agla qadam |
|---|---|---|---|
| Live system health (Rust/Bun/Postfix/Caddy) | 🟡 CODE (bana, live saboot baqi) | app.admin.health.tsx + app.founder_.* ; real ports ka founder-login live saboot nahi | founder Chrome |
| All workspaces founder view | 🟡 CODE (bana, live saboot baqi) | app.founder_.org.tsx / founder.ts | founder Chrome |
| Revenue dashboard (MRR/ARR/churn) | 🟡 CODE (bana, live saboot baqi) | app.founder_.revenue.tsx + server/routes/revenue.ts (Polar webhook data) | founder Chrome (Polar NO-TOUCH) |
| Safety queue (privacy-preserving) | 🟡 CODE (bana, live saboot baqi) | app.founder_.safety.tsx | founder Chrome |
| AI usage across users | 🟡 CODE (bana, live saboot baqi) | app.founder_.ai*.tsx | founder Chrome |
| Launch checklist (real checks) | 🟡 CODE (bana, live saboot baqi) | app.founder_.launch.* | founder Chrome |
| SiteLock control | 🟡 CODE (bana, live saboot baqi) | SiteLock.tsx + site-lock.ts | founder Chrome |
| Move-in manager | 🟡 CODE (bana, live saboot baqi) | app.founder_.movein.tsx + server/routes/movein.ts | founder Chrome |
| Founder single inbox (phase55) | 🟡 CODE (bana, live saboot baqi) | docs/wire/19 (status READY); founder-plan.ts | founder Chrome |
| Founder routes Rust-only (Rule 22, G18/G40) | 🔴 TODO (bana nahi) | 181 Rust-pehle, 19 sirf Bun (B5) | B5 |

## P9
| Item | Status | Evidence | Agla qadam |
|---|---|---|---|
| LEO chat always-visible sidebar | 🟡 CODE (bana, live saboot baqi) | AiBits.tsx / leo.ts; ai.anexomail.com live test nahi | AI account |
| AI Studio | 🟡 CODE (bana, live saboot baqi) | ai_.studio.tsx + ai-studio.ts | AI account |
| Knowledge base (upload docs, ask) | 🟡 CODE (bana, live saboot baqi) | ai_.knowledge.tsx | AI account |
| AI Automation (workflow builder) | 🟡 CODE (bana, live saboot baqi) | ai_.automation.tsx + ai-automation.ts | AI account |
| Credit wallet (balance visible) | 🟡 CODE (bana, live saboot baqi) | AiCreditMeter.tsx + ai-credits.ts | AI account |
| Usage history + receipts | 🟡 CODE (bana, live saboot baqi) | app.founder_.ai.receipts.tsx | AI account |
| ANEXOChat live proof (status board 'P9') | 🔴 TODO (bana nahi) | Plan board: TODO; chat audit D10 (AnexoChat) founder order | D10 |
