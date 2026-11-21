# ADMIN DESK: PHASES IN ORDER + HOW AN EMPLOYEE IS SEPARATED FROM THE FOUNDER (21 Nov 2026 07:20 PKT) FOR HIS APPROVAL, NOTHING BUILT

His words 07:03: build the phases in order, blueprint only AFTER he approves; design so that LATER an EMPLOYEE gets the same Admin Desk (Managed Move-In, Priority Support, resolved@, hello@) and hears/solves awam problems WITHOUT ever touching the founder account; "founder se alag kaise?" think with web research, steps in order.

## A. DECISIONS CLOSED BY HIS WORD 07:03 (final)
1. Managed Move-In price CLOSED FOR EVER: GBP 568 / 1,670 / 2,210 / 3,350 (= landing page = Polar). Lovable gold's 500/1,500/2,000/3,000 is OLD. lovable-gold is FROZEN (never edited), so the date-stamped note lives in docs/claude/MOVEIN-PRICE-CLOSED-21NOV.md and the Lovable lane list, not inside gold files.
2. Founder workspace deck "Move-In" RENAMED "Managed Move-In" (founder-web/src/catalog.ts + Decks.tsx, bun tests 523 pass).
3. billing@ = SEND ONLY (receipts). Billing PROBLEMS are heard ONLY in resolved@ (resolved@ = the place where problems are heard and solved, massive volume). No billing inbox.
4. hello@ = engage the business: information about ANEXOMAIL, pre-sales questions (list of topics below). Only the welcome message is automatic.
5. hello@ welcome (with a smiley): Subject: We received your message / Hi [First Name], We got your message and we're on it. At ANEXOMAIL we don't use ticket numbers or queues. A real person will reply to you within 24 hours. Thank you for reaching out. ANEXOMAIL TEAM / anexomail.com. Gates (RFC 3834): skip lists/bulk/automated, null return path, our address not in To/Cc; one auto-reply per sender per 7 days.
6. R5 = LEO = Claude. When working with him, Claude mails users, or what Claude suggests, he approves (each real send his yes).
7. Migrator language (Rust or operator tool) and A (family accounts), D (3 awam packages), E (which addresses exist): STILL OPEN, defaults A=NO, migrator=RUST.

hello@ topic list (information he wants hello@ to carry; my first list, he edits): what ANEXOMAIL is; packages and prices; Managed Move-In; Priority Support; security (TLS 1.3, AES-256, post-quantum); data location; domain setup (SPF/DKIM/DMARC); partnerships and press; careers; demo/seminar 16 Jan 2027 questions.

## B. PHASES (proposed order; technology in CAPITALS)
R3 ADMIN DESK
- R3a CONTRACT + SQL: contract in CURRENT.md; SQL E201 fadm_* tables (mailboxes, threads, issues, assignments, notes, canned replies, auto-reply ledger) + E202 SLA engine; HASH-CHAINED APPEND-ONLY LEDGER, POSTGRESQL RLS, schema-first; staff-ready columns (actor_id, mailbox grants) from day 1.
- R3b INBOXES: resolved@ (main), hello@, moveyourbusiness@ (own mailbox, folders Managed Move-In + Priority Support), System reports (postmaster/abuse/dmarc), leo@; billing@ and noreply@ send only; RUST TOKIO AXUM intake on the shared fmail cores.
- R3c AUTO MAIL: hello@ welcome, welcome-on-board, billing@ receipt on Polar success, noreply@ system mail; AUTO-SUBMITTED HEADER + 7-DAY GATE (RFC 3834), DKIM/DMARC aligned, own ledger.
- R3d DESK UI: SAME FOUNDER REACT 19 UI via kernel RPC (RULE 52, no raw fetch), separate Vite entry so founder screens are not shipped to employees; QC8 accessibility layers; 390/820/1200+.
- R3e REPLY + SEND-FROM: founder, hello@, moveyourbusiness@, resolved@; NO PASSKEY touch for replies; undo window via shared send core; rate caps.
- R3f SLA + WORKFLOW: 24 h clock (stops only on a human reply/resolve), assign, escalate, resolve, internal notes in-thread, unassigned backlog, canned replies, collision lock.
- R3g VERIFY + FINAL: ledger verify screen, stats, phone/tablet/laptop, High Contrast, GREEN only with WIRED/REAL proof, gaps listed.
R4 MANAGED MOVE-IN + PRIORITY SUPPORT (after R3; extracted from Lovable gold movein code into RUST + new SQL)
- R4a extraction map + landing promise rows (done: P3, P4 in WEBSITE-PROMISES.md); R4b SQL + Rust deals/runbook/DNS green check/rollback points/evidence bundle; R4c RUST IMAP MIGRATOR (login check, dry run, delta passes, TTL 300 s, per-mailbox proof report signed by the audit key); R4d Priority Support mailbox + SLA 2 business days + quarterly review record; R4e UI + live proof.
R5 LEO: Claude as LEO from leo@, drafts for his yes, each real send approved; R6 EMPLOYEE ERA (below) when he hires.

## C. HOW AN EMPLOYEE IS SEPARATED FROM THE FOUNDER (steps in order)
Research basis (fetched 21 Nov): WorkOS support-impersonation guide (delegation not shared logins, actor + subject both recorded, reason required, time limit, revoke, redaction), Lethain user-data access strategy (role + resource-level access granted only while a work item exists, automated rationale, user-visible access log, unused roles expire).
Principle: the Desk is its OWN SECURITY DOMAIN, not a role inside the founder account. The employee never gets a founder token, never shares a database role with founder code, never shares a key.
1. IDENTITY: new table fadm_staff (own ids). Staff tokens carry a different AUDIENCE ("desk") and are signed under a domain-separated key label (HKDF "desk-v1"); founder doors reject desk tokens and desk doors reject founder tokens. No shared login, ever; one person = one login.
2. DATABASE: a dedicated Postgres role desk_app with GRANTs ONLY on fadm_* views/functions; ZERO grants on founder tables (fmail_*, settings, keys, audit of founder). RLS on every fadm_* table keyed on staff id + mailbox grant. Even a bug in desk code cannot read the founder inbox.
3. MAILBOX GRANTS: per staff per mailbox capabilities (read, reply, assign, resolve, export none by default). Presets: Agent (resolved@ + hello@), Move-In operator (moveyourbusiness@ + Managed Move-In), Priority lead (Priority Support), Lead (assign/escalate). Founder personal inbox is NOT a Desk mailbox, so it cannot be granted at all.
4. ENCRYPTION KEYS: company mailbox attachments/bodies sealed under keys derived for "desk/<mailbox>", NOT the founder seal key. A compromised employee session cannot decrypt founder mail.
5. AWAM CUSTOMER DATA: seen only THROUGH AN ISSUE (resource-level, auto-granted while the issue is assigned to that employee, auto-revoked on resolve/reassign); automatic reason = issue id; redacted fields (no passwords/tokens/payment numbers); "view as customer" is NOT built (Desk reads, never impersonates); every view logged with actor + subject.
6. SESSIONS: staff login by passkey (awam rule = passkey only; his word on staff login needed), device-bound (DBSC already in the founder stack), short idle timeout, instant revoke. Reply needs NO touch (his word); high-risk actions (bulk export, MX cutover, rollback, role change) stay founder-only or need a second person.
7. PROCESS BOUNDARY: day one = Desk code in its own crate/module with its own DB role (no founder imports); at the first hire it is split into its own Rust binary on its own listener (needs his fresh ss paste, port red line). Awam is never inside the founder binary; the Desk is company ops, the founder binary never holds employee secrets beyond the grant table.
8. UI BOUNDARY: separate Vite entry/bundle for the Desk; capability-driven menus; founder screens (orb, settings, keys, ledger of founder) are not in that bundle. RULE 52: every call signed, kernel-verified.
9. AUDIT: Desk ledger = hash-chained, append-only, actor + role + mailbox + issue + action + reason; employee can view only their own actions; founder verify screen sees all; tamper = verify fails.
10. FOUNDER CONTROLS: Admin > Staff page: invite, assign preset, suspend, "revoke all" panic, 90-day unused role expiry, weekly sampled access review list.
11. OFFBOARDING: one click: sessions killed, grants removed, issues return to unassigned, signing key label rotated, ledger entry.
12. HONEST LIMIT: until the process split (step 7) the Desk runs next to founder code on the same server; the DB role, token audience and key separation already hold, the memory/process separation arrives at the split. Employee login itself is NOT built in the 2 days (his earlier default).

## D. TO FINALISE WITH HIM (answers)
Approve phase order B? / Employee login by passkey (C6)? / Split to own binary at first hire (C7) yes? / A family accounts (default NO) / D which 3 awam packages / E which addresses exist (read-only check) / migrator Rust (default).
