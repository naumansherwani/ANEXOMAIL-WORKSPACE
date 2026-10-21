# 01 — GREEN (live saboot ke saath)

21 Oct 2026, asli ghadi ~06:50 PKT · repo HEAD b18c4b9+ · source: MASTER-BUILD-PLAN.md, MASTER-GAP-LEDGER.md, loophole-ledger.md, blueprint G-table, DONE-DO-NOT-REPEAT.md, PROMISES.md, TECH-MAP.md + repo grep (src/, server/).

## A. Plan (P1–P9) mein se green
| Phase | Item | Darja | Saboot |
|---|---|---|---|
| P1 | Login cinema split (auth page) | 🟢 GREEN (live dekha/proof) | Plan status board: 'LIVE — screenshot liya'; login live (B1/B2 proofs) |
| P1 | Inline error states, no generic message | 🟢 GREEN (server par aaya + wire; live click-test baqi) | auth.tsx + auth-harden (login-loop fix, probe 72 calls 200); live retest of every error text nahi hua |
| P1 | Password strength indicator (signup) | 🟢 GREEN (server par aaya + wire; live click-test baqi) | src/routes/auth.tsx mein hai |
| P1 | Forgot password flow (real email) | 🟢 GREEN (server par aaya + wire; live click-test baqi) | auth.tsx + E19 password-reset hardening (docs/cursor-work/server/e19-...) |
| P1 | Email confirmation state UI | 🟢 GREEN (server par aaya + wire; live click-test baqi) | auth.tsx |
| P1 | Session persist (refresh pe logout nahi) | 🟢 GREEN (live dekha/proof) | B1 GREEN 21 Oct 04:55: refresh asli, logout 26 s baad token 401 (revocation) |
| P2 | Activity feed (last 10) | 🟢 GREEN (server par aaya + wire; live click-test baqi) | Panels.tsx |
| P2 | Quick Actions bar | 🟢 GREEN (server par aaya + wire; live click-test baqi) | Panels.tsx |
| P2 | Upcoming panel (today's events) | 🟢 GREEN (server par aaya + wire; live click-test baqi) | Panels.tsx/Greeting.tsx; calendar events live (E51) |
| P2 | AI usage panel (AI plan users) | 🟢 GREEN (server par aaya + wire; live click-test baqi) | Panels.tsx |
| P2 | Founder version: Founder View stats | 🟢 GREEN (server par aaya + wire; live click-test baqi) | app.founder.tsx + server/routes/founder.ts |
| P3 | Email snooze | 🟢 GREEN (server par aaya + wire; live click-test baqi) | lib/mail.ts snooze + UI action row 'Snooze' (820 par dikha) |
| P3 | Scheduled send | 🟢 GREEN (live dekha/proof) | B3: mail.schedule/hold Rust worker, proof SAB PASS (asli Postfix), Compose 'Held for 30s' live |
| P3 | Undo send | 🟢 GREEN (live dekha/proof) | G-UNDO GREEN 21 Oct 01:20 (cancel 200, mail nahi aayi) + B3 undo/409 proofs. NOTE: plan 10 s likhta hai, product 30 s |
| P4 | Attachment drag-drop | 🟢 GREEN (server par aaya + wire; live click-test baqi) | ComposeStudio.tsx onDrop; G38 server side GREEN, live Compose attach SEND test baqi (C3) |
| P4 | CC/BCC toggle | 🟢 GREEN (server par aaya + wire; live click-test baqi) | ComposeStudio.tsx |
| P4 | Scheduled send UI | 🟢 GREEN (live dekha/proof) | Compose live: 'Sending… Held for 30s' toast |
| P4 | Undo send countdown toast | 🟢 GREEN (live dekha/proof) | G-UNDO GREEN (30 s, Undo button) — plan '10 s' purana |
| P4 | Draft auto-save every 30 s | 🟢 GREEN (server par aaya + wire; live click-test baqi) | ComposeStudio.tsx draft |
| P4 | LEO compose assist (grammar/professional/translate) | 🟢 GREEN (server par aaya + wire; live click-test baqi) | ComposeStudio.tsx LEO calls; AI plan par live test nahi |
| P5 | Conversation view (replies grouped) | 🟢 GREEN (live dekha/proof) | Thread live dekha 390/820 (Basic) |
| P5 | Inline reply | 🟢 GREEN (server par aaya + wire; live click-test baqi) | InlineReply.tsx; live reply bhejna test nahi (mail bhejne ke liye founder haan) |
| P5 | Quote original toggle | 🟢 GREEN (server par aaya + wire; live click-test baqi) | InlineReply.tsx |
| P5 | Discuss in ANEXOChat button | 🟢 GREEN (server par aaya + wire; live click-test baqi) | DiscussInChat.tsx + QuoteInChat.tsx |
| P5 | Email → Task | 🟢 GREEN (server par aaya + wire; live click-test baqi) | EmailBridge.tsx (work) + app.work.tsx |
| P6 | Contact list with search | 🟢 GREEN (server par aaya + wire; live click-test baqi) | app.people.tsx; people_core/people_glue Rust LIVE (G23, 182 procs) |
| P6 | Contact profile (history/stats/last contact) | 🟢 GREEN (server par aaya + wire; live click-test baqi) | ContactProfile.tsx |
| P6 | Company profile (domain ke sab contacts) | 🟢 GREEN (server par aaya + wire; live click-test baqi) | CompanyProfile.tsx |
| P6 | Contact timeline | 🟢 GREEN (server par aaya + wire; live click-test baqi) | Timeline.tsx |
| P6 | Import vCard/CSV | 🟢 GREEN (server par aaya + wire; live click-test baqi) | ContactsImport.tsx + contacts-import.ts + people_import Rust (L75) |
| P7 | Week view (primary) | 🟢 GREEN (live dekha/proof) | Calendar desktop week = TimeGrid live: create, drag move+resize LIVE VERIFIED (21 Oct 04:25) |
| P7 | Create/edit/delete event | 🟢 GREEN (live dekha/proof) | calendar.create GREEN after E51 (21 Oct 00:50), calendar.update drag persisted; delete live saboot nahi |
| P7 | Timezone support | 🟢 GREEN (server par aaya + wire; live click-test baqi) | calendar.ts + FindTime |
| P7 | Focus windows (deep work block) | 🟢 GREEN (server par aaya + wire; live click-test baqi) | Availability.tsx/calendar.ts |
| P8 | Live system health (Rust/Bun/Postfix/Caddy) | 🟢 GREEN (server par aaya + wire; live click-test baqi) | app.admin.health.tsx + app.founder_.* ; real ports ka founder-login live saboot nahi |
| P8 | All workspaces founder view | 🟢 GREEN (server par aaya + wire; live click-test baqi) | app.founder_.org.tsx / founder.ts |
| P8 | Revenue dashboard (MRR/ARR/churn) | 🟢 GREEN (server par aaya + wire; live click-test baqi) | app.founder_.revenue.tsx + server/routes/revenue.ts (Polar webhook data) |
| P8 | Safety queue (privacy-preserving) | 🟢 GREEN (server par aaya + wire; live click-test baqi) | app.founder_.safety.tsx |
| P8 | AI usage across users | 🟢 GREEN (server par aaya + wire; live click-test baqi) | app.founder_.ai*.tsx |
| P8 | Launch checklist (real checks) | 🟢 GREEN (server par aaya + wire; live click-test baqi) | app.founder_.launch.* |
| P8 | SiteLock control | 🟢 GREEN (server par aaya + wire; live click-test baqi) | SiteLock.tsx + site-lock.ts |
| P8 | Move-in manager | 🟢 GREEN (server par aaya + wire; live click-test baqi) | app.founder_.movein.tsx + server/routes/movein.ts |
| P8 | Founder single inbox (phase55) | 🟢 GREEN (server par aaya + wire; live click-test baqi) | docs/wire/19 (status READY); founder-plan.ts |
| P9 | LEO chat always-visible sidebar | 🟢 GREEN (server par aaya + wire; live click-test baqi) | AiBits.tsx / leo.ts; ai.anexomail.com live test nahi |
| P9 | AI Studio | 🟢 GREEN (server par aaya + wire; live click-test baqi) | ai_.studio.tsx + ai-studio.ts |
| P9 | Knowledge base (upload docs, ask) | 🟢 GREEN (server par aaya + wire; live click-test baqi) | ai_.knowledge.tsx |
| P9 | AI Automation (workflow builder) | 🟢 GREEN (server par aaya + wire; live click-test baqi) | ai_.automation.tsx + ai-automation.ts |
| P9 | Credit wallet (balance visible) | 🟢 GREEN (server par aaya + wire; live click-test baqi) | AiCreditMeter.tsx + ai-credits.ts |
| P9 | Usage history + receipts | 🟢 GREEN (server par aaya + wire; live click-test baqi) | app.founder_.ai.receipts.tsx |

## B. G-series green
| G | Kaam | Darja | Saboot |
|---|---|---|---|
| G3 | Rust latest (edition 2024, axum 0.8.9, wtransport 0.7.2) | 🟢 GREEN (live dekha/proof) | tokio 1.53.3/axum 0.8.9/wtransport 0.7.2/rustc 1.99.1 live |
| G10 | Passkey flow verify | 🟢 GREEN (live dekha/proof) | B2 GREEN: passkey proof SAB PASS (20 checks) + B2b |
| G17 | Admin Members/Teams/Invitations | 🟢 GREEN (live dekha/proof) | ledger B: G17/L76 team invites live |
| G23 | People import Rust port | 🟢 GREEN (live dekha/proof) | people_core/people_glue; live 182 procs ✔ |
| G28 | Rust cal glue asli compile server par | 🟢 GREEN (live dekha/proof) | calendar.create/update live (E51 + drag) |
| G29 | Revoked member guard (mail_identity) | 🟢 GREEN (live dekha/proof) | live 06:16 |
| G31 | Team seat/audit chain/work address (E34) | 🟢 GREEN (live dekha/proof) | live 06:06 |
| G32 | manager rank | 🟢 GREEN (live dekha/proof) | live 06:16 |
| G36 | 72 h export → delete (countdown + email) | 🟢 GREEN (server par aaya + wire; live click-test baqi) | E44/E45/E46 live; UI/email countdown ka live dekhna (C7) |
| G37 | 24h me 3 account suspicious/review + warn→block→ban | 🟢 GREEN (server par aaya + wire; live click-test baqi) | review queue UI live dekhna (C7) |
| G38b | Aane wali mail ke attachment bytes | 🟢 GREEN (live dekha/proof) | inbound hello.txt download 200 (01:15); PROMISES #12 EICAR FOUND |
| G42 | Passkey/recovery login Rust par | 🟢 GREEN (live dekha/proof) | B2 GREEN 05:50 |

## C. Technology green
| Technology | Darja | Saboot |
|---|---|---|
| Tokio async 1.53.3 | 🟢 GREEN (live dekha/proof) | live |
| axum 0.8.9 | 🟢 GREEN (live dekha/proof) | live |
| QUIC wtransport 0.7.2 (quinn) | 🟢 GREEN (live dekha/proof) | live; ufw 3443/udp open item D11 |
| tRPC-style /rpc/* | 🟢 GREEN (live dekha/proof) | live |
| B1 Rust JWT local verify + refresh | 🟢 GREEN (live dekha/proof) | 21 Oct 04:55 |
| B2 passkey/recovery Rust (G42) | 🟢 GREEN (live dekha/proof) | 05:50 |
| B2b Bun hardening + passkey list/delete | 🟢 GREEN (live dekha/proof) | 05:50 |
| B3 mail.send/undo/queue worker/org.mailboxes (R1) | 🟢 GREEN (live dekha/proof) | 06:00 |
| B4 event-driven push (R5) | 🟢 GREEN (live dekha/proof) | 21 Oct 06:50 founder output: proof SAB PASS (UDP 3443, /internal/event, family 3/3) |

## D. Ledger section B (live green, dobara mat chhuo)
- tokio 1.53.3 / axum 0.8.9 / wtransport 0.7.2 / rustc 1.99.1 + edition 2024 — live 20 Oct.
- L1/L2 mail TLS cert + expiry watch — live.
- E37 (anjaan pata quarantine), E38 (thread count), R1a Rust inbound pipe — live.
- G29 revoked guard, G31 seat/audit/work address (E34), G32 manager rank, G17/L76 team invites — live.
- E41–E47 + CHECK_E42_E47 (family real buyer, device hash HMAC, passkey/recovery tables, export, purge, notices/appeal, revoke sessions) — founder 20:21.
- G38 SQL E48/E49/E50 + CHECKs; Rust `attach`; attach-gc timer; Caddy `/files/*` band; attach-check — founder 23:50.
- E51 calendar fix, calendar create/drag, E53 session alive, E54 mail queue claim — live.
- Basic account Chrome: 21-page sweep (0 empty/0 error), 39 loads (13 routes × 390/820/1200), billing -> Polar checkout opens (Pro £46/mo, not paid).
- Basic = GREEN (founder haan, 21 Oct 04:30; saboot `BASIC-AUDIT-DONE.md`).
- A1 repo-vs-server audit + A2 live-snapshot (af24025) — GREEN.
- Brain: auth-harden, CRM tenant isolation, passkey-harden, mail (claim/cancel), refresh — installed, health 200.
- Rust deliver (anexopipe -> Rust) 21 Oct 06:40: 35 tests, asli Postfix -> Rust -> DB OK.
- Web pull 21 Oct 06:35: server==repo src 490/491 (sirf routeTree.gen.ts generated diff).
