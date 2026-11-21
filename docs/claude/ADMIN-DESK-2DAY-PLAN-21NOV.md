# ADMIN > MAIL DESK (letter R3), 2-DAY BUILD PLAN FOR DISCUSSION (his word 21 Nov 2026 05:51 PKT: "admin desk ka plan samne leke aao, detail main discuss kero, 2 din main complete")
STATUS: PLAN ONLY, NOTHING BUILT. Source plan: docs/claude/FOUNDER-ADMIN-MAIL-DESK-03NOV.md (his 3 Nov 12:37 order). Today = Sat 21 Nov; target = Mon 23 Nov 06:00 PKT. Every step closes only with live Chrome proof (AUTOFIX law); 390 / 820 / 1200+ (Rule 34); Rule 52 (kernel-verified signed calls, zero raw fetch); founder and awam never mixed.

## What the Desk is (one paragraph)
A SECOND mailbox system, own folder, for the COMPANY mailboxes (support@, billing@, abuse@, appeals@, glitch/inbox@): the awam problems arrive as mail, the founder (or staff he assigns) hears and solves them with an issue view: 24 h SLA clock, assign, escalate, resolve, canned replies, deliverability panel, hash-chained ledger of everything done. It reads company mailboxes only, never the awam database (separation law).

## Technology per layer (2026 latest, his law)
| Layer | Technology |
|---|---|
| Backend | Rust, Tokio, axum, ONE HTTP/3 UDP 443 endpoint, kernel rpc over WebTransport, signed writes, Ed25519 + ML-DSA hybrid (existing) |
| Data | PostgreSQL RLS forced, tables fadm_mail_*, own SHA-256 hash-chained append-only ledger, advisory locks, selftests + CHECK files |
| Mail cores reused (shared only) | fmail_core / fmail_seal / fmail_mime / fmail_out / fmail_auth, attach_core, kernel sha256, PQM content seal. NOT the founder Mail pages or tables |
| UI | React 19, TS, TanStack Router (#/admin/mail-desk/...), Radix/shadcn, Framer Motion (reduced-motion safe), folder founder-web/src/admin/maildesk/ |
| Accessibility | the QC8 layers apply at once: ariaNotify announcements, focus return, semantics, forced-colors CSS, single-letter keys switch + "?" sheet (new files only) |
| Live | SSE/WebTransport push of new issues (no WebSocket), signed envelopes verified by the WASM kernel |

## Day 1 (Sat 21 Nov, by 23:59)
| # | Subphase | Technology | Output | Proof |
|---|---|---|---|---|
| R3a | Design note + contract in CURRENT.md + tech chart, register tech in TECH-LAW-GATE | docs | contract written BEFORE code | rules-gate passes |
| R3b | SQL E201: fadm_mail_boxes, fadm_mail_issues (state open/assigned/escalated/resolved, sla_due_at, priority), fadm_mail_issue_events (hash-chained, append-only), fadm_mail_assignees, RLS forced, guard triggers | SQL | E201 + CHECK_E201 + selftest | his sql-run paste, local PG 16 first |
| R3c | SQL E202: SLA engine (due/overdue/escalate functions, pure workday window like E196), canned replies table, stats door | SQL | E202 + CHECK_E202 | his sql-run paste |
| R3d | Rust fadm_mail.rs: signed doors /founder/v1/admin/maildesk/{inbox,issue,assign,escalate,resolve,reply,stats,verify}; passkey touch for send-as-company | Rust | cargo tests | cargo + his install |
| R3e | UI skeleton: sidebar child "Mail Desk" under Admin, routes, folder, empty states, KeyLayer + a11y layers mounted | React/TS | page opens | my Chrome look |

## Day 2 (Sun 22 Nov, by 23:59) and morning of Mon 23 Nov
| # | Subphase | Technology | Output | Proof |
|---|---|---|---|---|
| R3f | Issue inbox list + issue view + SLA clock chip + assign / escalate / resolve | React/TS | working desk | live Chrome, real company mail |
| R3g | Reply (send as company, passkey touch, undo window) through the shared send core | React/TS + Rust | one real reply sent to my own test address | live Chrome + header proof |
| R3h | Deliverability panel (SPF/DKIM/DMARC/MTA-STS/TLS-RPT facts for the company domain) reusing fmail_tls / fmail_qtls | Rust + React | panel | live Chrome |
| R3i | Ledger verify screen + stats (SLA met %, open by age) | SQL + React | verify ok:true | live Chrome |
| R3j | 390 / 820 / 1200+ pass, High Contrast CSS, final check, blueprint + ledger GREEN with open gaps listed | all | GREEN lines | phone screenshots by him |

## UPDATE 21 Nov 06:35 PKT: HIS ORDER OVERRIDES THESE DEFAULTS (see ADMIN-DESK-R3-FOUNDER-ORDER-21NOV.md): support@ is BANNED -> resolved@; mailboxes = hello@, moveyourbusiness@ (own full mailbox), resolved@, billing@ (restricted), leo@, noreply@ send-only; reply = NO passkey.

## What I need decided (defaults I will use if you say "default")
1. Which company mailboxes exist today? Default: support@, billing@, abuse@, appeals@, inbox@ on anexomail.com as the company mailboxes (E1xx mail tables already hold boxes).
2. Reply "from" identity: default = the company address of the issue's box, never the founder personal address, send needs a passkey touch.
3. Staff: default = founder only today; assignee table exists so staff can be added later (no staff login built in these 2 days).
4. Composer: the founder compose window is a founder Mail page, the separation law forbids reusing the page. Default = a small Desk reply box that uses the same send core and pure helpers (mail_pure), not the page.
5. Old Lovable endpoints (lovable-gold/founder: mailboxes, ai-mail, provision, approve, billing-support): migrate only mailbox list + support replies; AI mail stays out (AI = founder-only letter V, dropped until July 2027).

## Honest risks for the 2-day target
- Two days is tight for SQL x2 + Rust + UI + real sends. The plan keeps each step small and proof-first; if R3g (real company send) or R3h slips, they go on the open list, never green by words.
- Real company mailboxes must already receive mail (QC intake is live for the founder box; company boxes need the same intake rows).
- Phone 390 / 820 screenshots need his hands (one step at a time).
- The awam packages (3 packages with ANEXOChat, due 1 Jan 2027) are a SEPARATE awam-lane plan (docs/claude/AWAM-PACKAGES-PROPOSAL-07NOV.md). It is not started here; scheduling it after R3 keeps 1 Jan realistic.
