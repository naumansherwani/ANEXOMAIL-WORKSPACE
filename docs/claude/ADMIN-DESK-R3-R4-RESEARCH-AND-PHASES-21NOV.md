# R3 DESK + R4 MANAGED MOVE-IN: WEB RESEARCH + PROPOSED PHASE ORDER (21 Nov 2026 06:55 PKT) FOR DISCUSSION, NOT FINAL, NOTHING BUILT

His word 06:43: web research for the world's advanced points, then FINAL DISCUSSION of phase order, which feature and which advance technology in which phase; blueprint/ledger phase lines only after he finalises.

## New phase named (his 06:43 order): R4 = MANAGED MOVE-IN + PRIORITY SUPPORT (own mailbox moveyourbusiness@, comes AFTER R3)
- Built by extracting from LOVABLE GOLD (frozen, never edited): lovable-gold/awam/sql/phase37_movein_ops.sql (900 lines: movein_deals, bands, audit, transitions, mailboxes, capacity, waitlist, DNS checks, exceptions, runbook, rollback points, payments, health, evidence bundle, customer view, cockpit), phase38_movein_hardening.sql, phase39_movein_fixes.sql, server/routes/movein.ts (426), src/lib/movein.ts (317), billing-products.ts (POLAR_PRODUCT_PRIORITY_SUPPORT). Rebuilt in RUST + new SQL (E-numbers, schema-first), never copied as Bun.
- FINDING FOR HIM: Lovable gold price ladder = GBP 500 / 1,500 / 2,000 / 3,000, his landing page = 568 / 1,670 / 2,210 / 3,350. Not one fixed ratio. Which is the truth for the build? (WEBSITE-PROMISES: the landing line is the promise.) Also not yet in WEBSITE-PROMISES.md: Managed Move-In and Priority Support lines, to be added.
- Priority Support GBP 790/month: named founder contact, first response within 2 business days (not a fix promise), quarterly service + security review; support hours, emergency coverage and included company/users to be written before launch; migration NOT included. Own mailbox/folder inside the move-in area.
- His 5-step method (enquiry data without passwords, billable mailbox = own login + storage not aliases/groups, sample migration on 2-4 mailboxes first, MX cutover at low traffic with old system kept, proof report) becomes the R4 runbook; "zero downtime" is never promised unless proven.

## Research points (sources: RFC 3834, Missive shared-mailbox guide, imapsync guide, all fetched 21 Nov 2026)
Auto-reply safety (RFC 3834), for hello@ welcome + billing@ receipt + LEO:
- Header Auto-Submitted: auto-replied on replies, auto-generated on system mail (receipt); never on manual mail.
- Never auto-reply to: Auto-Submitted other than no, null return path, list/automated senders (owner-*, *-request, MAILER-DAEMON), List-* headers, Precedence bulk/junk/list, spam, mail where our address is not in To/Cc.
- Rate limit: one auto-reply per sender per period (RFC suggests 7 days), at most one recipient, brief plain text, envelope sender that cannot loop; reply to Return-Path, never Reply-To.
- Our design: ledger table of auto-replies sent (hash-chained) + per-sender 7-day gate, so hello@ cannot loop or be abused as a spam cannon.
Shared inbox (Missive):
- Every conversation has ONE named owner; unassigned view = daily backlog; assign by work type (billing, technical, move-in); internal notes inside the thread with @mention; individual logins, remove on leave; SLA clock stops only on a human reply or resolve (auto-acks do NOT stop it); test rules on real mail; strict conditions on outgoing rules to avoid loops.
Migration (imapsync):
- justlogin check, dry run, copy with automap, rerun = only missing mail, delta pass shortens final cutover to minutes; lower MX TTL to 300 s before cutover; first pass while users still work, switch MX, final pass, keep old server several days, repeat; --useheader Message-Id against duplicates; never --delete2 on a mailbox already receiving; per-mailbox logs and counts = the proof report; app passwords/OAuth needed on Google/Microsoft sources (OAuth not covered by that guide).
- WARNING for our law: imapsync/Node/Bun tooling is not allowed on the website runtime; migration engine must be RUST (async-imap or own IMAP client) on his server, or the tool runs only as an operator tool by me/him, decided in discussion. Also NEVER ask customers for passwords by email.

## Advance technology candidates per phase (to discuss, each must be real, in CAPITALS when accepted)
- R3 DESK: RUST TOKIO AXUM SIGNED DOORS, HTTP/3, KERNEL RPC (RULE 52), POSTGRESQL RLS + HASH-CHAINED LEDGER, REACT 19 same founder UI; QC8 accessibility; MIME/DMARC checks reuse fmail cores; Auto-Submitted + 7-day gate.
- R3 deliverability: SPF, DKIM, DMARC, MTA-STS, TLS-RPT, DANE already in founder cores; BIMI optional later (needs VMC, vendor cost: ask him).
- R4 MOVE-IN: RUST IMAP migrator, per-mailbox checksum proof report, DNS green check (existing movein_dns_checks idea), rollback points, evidence bundle PDF/JSON signed with the Ed25519 audit key.

## PROPOSED PHASE ORDER (to finalise with him)
R3a contract + SQL E201/E202 (his answers A-E first) / R3b company inboxes + labels (hello, moveyourbusiness, resolved, restricted billing, System reports) / R3c auto mail (hello welcome, welcome on board, billing receipt on Polar success, noreply) with RFC 3834 gate / R3d same founder UI as Desk (kernel RPC) / R3e reply send-from list, no passkey / R3f SLA 24 h assign escalate resolve + ledger verify / R3g 390-820-1200+ and final / R4a move-in extraction map from Lovable gold + price truth / R4b SQL + Rust deals, runbook, DNS checks / R4c IMAP migrator + proof report / R4d Priority Support mailbox + 790 plan terms / R4e UI + live proof / R5 LEO (Claude via Chrome, his yes per send).
