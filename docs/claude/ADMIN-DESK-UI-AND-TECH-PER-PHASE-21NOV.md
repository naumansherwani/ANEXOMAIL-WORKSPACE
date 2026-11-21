# ADMIN DESK: HOW THE UI WILL LOOK + ADVANCE TECHNOLOGY PER PHASE (FRONTEND + BACKEND ENGINE) 21 Nov 2026 07:50 PKT, FOR DISCUSSION (his 07:27 order), blueprint holds the phase list

Rules that hold for every line below: Rule 52 (every call signed + kernel-verified in the Rust WASM kernel, no raw fetch after sign-in), ONE build for 390 / 820 / 1200+, founder look (cinematic, same logo, same login look), a technology listed here that is missing in code = OPEN GAP never GREEN, no mock data (empty states say so).

## 1. THE PAGES (what he will see)
- admindesk.anexomail.com (landing): top band "ADMIN DESK" (one hue, never confusable with the founder tab), brand mark, one headline, one line "Where company mail is heard and solved. For ANEXOMAIL staff only.", one Sign in button.
- /adminlogin: the founder sign-in look (AuthCinema panel from 1024 px, same fields), words "Admin Desk / Welcome to the Desk". Email + password; passkey OPTIONAL (arrives R6; a lost/old key = he takes the key back and issues a new one).
- /dashboard (after sign-in): the founder shell (glass sidebar, cinematic header) with the band. Sidebar: Dashboard, Inbox, Managed Move-In, Priority Support, System reports, Automations, Ledger (and later Staff, owner only). Dashboard cards (real numbers only): open issues per mailbox, unassigned backlog, SLA clock (due soon / overdue, one hue), median first response, auto-mail today (welcome sent / skipped by gate), Managed Move-In deals in progress, Priority Support reviews due, ledger verify chip (ok:true + entry count), mail posture chip (SPF DKIM DMARC MTA-STS).
- Inbox (three panes on laptop, stacked on phone): list | thread | side panel. Folders: resolved@ (main), hello@, moveyourbusiness@ (labels Managed Move-In, Priority Support), System reports (postmaster/abuse/dmarc), leo@. Every mail wears its address label; Unassigned view = daily backlog. Side panel = issue status, owner (one name), SLA clock, internal notes, canned replies, collision lock "Aisha is replying". Awam customer facts appear ONLY inside an issue and only while it is assigned to you.
- Reply box: Send-from (founder, hello@, moveyourbusiness@, resolved@), undo window, same editor as founder mail, no passkey touch.
- Managed Move-In board: stages Enquiry > Sample (2-4 mailboxes) > Bulk copy > MX cutover > Proof report > Closed; DNS green check card; runbook checklist; rollback points; proof report viewer. Price ladder 568 / 1,670 / 2,210 / 3,350 (closed).
- Priority Support: customers (GBP 790/month), named contact, 2-business-day response clock, quarterly review calendar.
- Ledger: verify screen (hash chain, Merkle seal, time anchors), per-mailbox and per-person views.
Phone 390: one column, bottom tab bar, 44 px targets; tablet 820: two panes; laptop 1200+: three panes. Keyboard single-letter keys, ariaNotify announcements, forced-colors and contrast layers from QC8 are inherited.

## 2. ADVANCE TECHNOLOGY PER PHASE (FRONTEND | BACKEND ENGINE), all CAPITALS = must be real in code
R3a0 HOST
- FRONTEND: SEPARATE VITE 8 ENTRY (desk.html, own bundle dist-desk), __HOST- COOKIES, STRICT CSP + TRUSTED TYPES, COOP/CORP SAME-ORIGIN, FETCH-METADATA, ADMIN DESK BRAND BAND.
- BACKEND: RUST TOKIO AXUM SNI HOST ROUTER (founder doors only on founderworkspace, desk doors only on admindesk = host-confusion guard), HTTP/3 + WEBTRANSPORT OVER UDP 443 BY SNI, TLS 1.3 AES-256-GCM X25519MLKEM768, CERT REFRESH TIMER, DNS HTTPS RECORD alpn=h3 + CAA (Namecheap, his hands).
R3a1 LOGIN FACE (written, see section 4)
- FRONTEND: REACT 19 + TYPESCRIPT STRICT + TAILWIND 4.2 + RADIX/SHADCN + MOTION; three pages by path (/, /adminlogin, /dashboard); same BrandMark + AuthCinema (THREE.JS LAZY); VIEW TRANSITIONS between pages; prefers-reduced-motion respected.
- BACKEND: RUST /desk/v1/auth/login (ARGON2ID password hash, per-IP + per-account RATE CAP, constant-time compare, own TOKEN AUDIENCE "desk" signed under HKDF label desk-v1), DBSC DEVICE-BOUND SESSION (existing K7 tech), OPTIONAL PASSKEY (webauthn-rs, rp_id = admindesk.anexomail.com).
R3a2 CONTRACT + SQL (E201 fadm_* tables, E202 SLA)
- BACKEND: POSTGRESQL ROW-LEVEL SECURITY + desk_app ROLE (grants only on fadm_*), HASH-CHAINED APPEND-ONLY LEDGER + MERKLE SEAL + RFC 3161 TIME ANCHORS (reuse G5c), BUSINESS-HOURS SLA ENGINE IN SQL (pause/resume, holidays), ADVISORY LOCKS for collision, SQL SELFTEST + CHECK files, schema-first.
R3b INBOXES
- FRONTEND: TANSTACK VIRTUAL LIST (huge inbox stays 60 fps), container queries for the 3-pane/2-pane/1-pane layout, CSS anchor positioning for popovers, native popover + dialog, content-visibility:auto.
- BACKEND: RUST INTAKE on the shared fmail cores (MIME parse, FUZZED, size caps, CLAMAV SCAN), THREADING by Message-ID/References, ATTACHMENTS ON HETZNER STORAGE BOX SEALED AES-256-GCM WITH PER-MAILBOX KEYS (not the founder key), POSTGRES LISTEN/NOTIFY.
R3c AUTO MAIL
- BACKEND: RFC 3834 AUTO-SUBMITTED + 7-DAY PER-SENDER GATE in SQL, loop/list/bulk/null-return-path rules, Polar webhook (signature-verified) -> billing@ receipt (invoice id, plan, amount, next billing date), DKIM (Ed25519 + RSA) + DMARC ALIGNED + MTA-STS + TLS-RPT + DANE (existing), POSTGRES SKIP LOCKED JOB QUEUE with retries, every auto-mail in the ledger.
- FRONTEND: Automations page (what was sent, what the gate skipped and why).
R3d DASHBOARD + MAIL UI
- FRONTEND: THE FOUNDER REACT CODE REUSED (shared components, no founder screens in the Desk bundle), REACT 19 useOptimistic (instant assign/undo), useTransition, TANSTACK ROUTER, WASM KERNEL RPC OVER WEBTRANSPORT (RULE 52), SSE FALLBACK, SPECULATION RULES prefetch, QC8 a11y layers (ariaNotify, focus restore, forced colours).
- BACKEND: SIGNED DOORS /desk/v1/*, LIVE PUSH over WebTransport streams from LISTEN/NOTIFY.
R3e REPLY
- FRONTEND: send-from selector, undo bar (founder UndoBar tech), rich editor TIPTAP (existing). BACKEND: SHARED SEND CORE (fmail_out), per-mailbox rate caps, outbound ledger, NO passkey touch, attachment malware re-scan.
R3f SLA + WORKFLOW
- FRONTEND: SLA ring (one hue, no green/yellow arcs), notes with @mention, collision chip, canned replies with variables. BACKEND: SLA clock stops only on a human reply or resolve (auto-acks never stop it), assign/escalate/resolve state machine in SQL with transitions table, escalation timers via job queue.
R3g VERIFY + FINAL
- BACKEND: ledger verify door, SQL selftests, cargo tests, load test. FRONTEND: Playwright at 390/820/1280, forced-colors, a11y audit, bundle budget.
R4 MANAGED MOVE-IN + PRIORITY SUPPORT
- BACKEND: RUST ASYNC IMAP MIGRATOR (rustls, RESUMABLE CHECKPOINTS, Message-ID DEDUPE, login-check + dry-run + delta passes, TTL 300 s plan, NEVER ask for passwords by email: customer app-password/OAuth handed through a sealed one-time form), DNS GREEN CHECK (SPF/DKIM/DMARC/MX live query), ROLLBACK POINTS, PROOF REPORT SIGNED ED25519 + ML-DSA HYBRID, EVIDENCE BUNDLE.
- FRONTEND: stage board (keyboard-movable), runbook checklist, proof-report viewer, Priority Support clocks and quarterly review calendar.
R5 LEO
- BACKEND: staff identity "leo" with a draft-only role, every real send needs his approval token (one-time, bound to the exact message hash). FRONTEND: approval sheet showing the exact message + recipient before send.
R6 EMPLOYEE ERA
- BACKEND: fadm_staff, per-mailbox grants, issue-scoped awam data with auto-expiry, read-rate caps, no bulk export, anomaly alerts, take-back (revoke all, rotate desk key label + desk_app password), process split to own Rust binary. FRONTEND: Staff page (owner only), watermark with the employee's name, session list.

## 3. SUGGESTIONS I ADDED (he may refuse any)
Business-hours calendar for the 2-business-day promise; a customer-facing status page later; a "what changed" diff in the proof report; an access log customers can see (later); keep admindesk@ as owner label without an inbox.

## 4. WHAT IS ALREADY WRITTEN (design-first, NOT WIRED, not GREEN)
founder-web/src/desk/{desk_pure.ts, desk_pure.test.ts (3 pass), DeskSignIn.tsx, DeskPages.tsx, main.tsx}, desk.html, vite.desk.config.ts, package script build:desk (build ok, 411 kB js / 133 kB gzip). The login posts to /desk/v1/auth/login which does not exist yet, so the page says "Admin Desk sign-in is not connected on the server yet" (honest, no fake sign-in). Nothing is on his server; the host routing (R3a0) comes first.
