# COMMAND CENTER OS: WHAT WE DESIGN, THE DECISION IN ONE PLACE (24 Nov 2026 09:5x PKT, his 09:48 order: "final faisla kya hai, humne system kya design karna hai, awam side ke loophole blueprint mein phase ke aage detail likho, hum fix karenge")
SPLIT OF THIS FILE: A = what HE ALREADY LOCKED (his words, dated, never re-argued). B = what I recommend on top (becomes locked only when he says haan; until then nothing in B is built). C = loopholes of the AWAM side found, each with a phase tag written in the awam blueprint.

## A. LOCKED BY HIM (read, never re-ask)
1. The Command Center OS (admindesk.anexomail.com) is the staff side of the awam product: one shell, own security domain (Desk isolation law), Rust + HTTP/3 + Rule 52 kernel-verified, advance SQL only. Host stays admindesk.anexomail.com (his 24 Nov 03:28).
2. The OS sees a customer only through the Control Plane's signed, read-only, purpose-limited doors; customer data content only through B13 consent (Company Admin approves, 60/30/15 minute timers, no break-glass, no auto-approval, his 24 Nov 04:26).
3. Order never breaks: Dashboard folder first (1a..1o), then folders 2..9, then Q (ALL-PHASES-IN-ORDER-24NOV.md). B13 now, then B11, B12, B6c, B9c Y4/Y6, B7.
4. Packages and prices are the FINAL chart: Basic 40, Pro 105, Business 360, Business Pro 2,850, Premium 21,000, Max 125,000 (E201/E202 GREEN); Managed Move-In 568 / 1,670 / 2,210 / 3,350 one-off by mailbox count (MOVEIN-PRICE-CLOSED-21NOV.md). Polar is done by him, never ask.
5. The gate is the final authority (GATE-FINAL-AUTHORITY-LAW-24NOV.md).
6. Honest text on screens: 'Not measured yet' stays until a probe exists; staff-only wording for internal faults.

## B. MY RECOMMENDATION (needs his haan before any build; nothing built from B today)
1. ONE migrator engine, two doors: the awam self-serve page (/app/import, today) and Managed Move-In run by staff from the Desk (Folder 8, phase P, Rust async IMAP). Same receipt (mig_chain), same walled garden (E35).
2. The OS shows import state to staff as numbers and states only (B7 Move-in board), never mail content, never the old-provider password; receipt check by hash; a stuck import opens a case (company known from the session tenant UUID, so it needs B13 binding first).
3. The OS never starts a customer's import and never holds an old-provider password (prohibited for me, and by design for staff).
4. Order for this: B13 (T3..T6, Z4b-3, Z4c) -> B11 -> B12 -> B6c -> B9c -> B7 (Move-in board) -> 1n -> 1o -> phone/tablet test -> Folder 2 Mailboxes (mail ingest) -> Folder 8 Managed Move-In. No reorder.

## C. AWAM-SIDE LOOPHOLES (from my live look 24 Nov 09:4x + the repo; VERIFIED = seen on the page or in files; TO VERIFY = suspicion, not claimed as fact). Written with a phase tag in docs/claude/AWAM-BLUEPRINT-ALPHABETIC-20NOV.md (top block 'MOVE-IN LOOPHOLES')
| Tag | Loophole | State | Fix |
|---|---|---|---|
| AWL-MI1 | Attachment files are NOT copied (the page says so; mails are only marked). A customer who moves in loses attachments: the 'Move In' promise is half. | VERIFIED (page text) | Rust migrator copies attachments to the Hetzner Storage Box with ClamAV scan + size cap per plan; page text changes only after it is real and receipt counts them |
| AWL-MI2 | The page promise 'App Password kept in memory only, never disk, database or logs' has no proof line in WEBSITE-PROMISES.md. | VERIFIED (promises file has no import line) | add P-line; test that scans server logs and DB for the password after a test copy using a throwaway test mailbox of HIS; gate stays strict |
| AWL-MI3 | Import is not tied to the package storage pool (AWL-3 meter not built): a big copy may exceed the pool without warning. | TO VERIFY (migration code not read for pool checks) | read the migration code; if absent, pool check before and during copy with 70% / 85% alert |
| AWL-MI4 | The self-serve page names Basic, Pro, Business, Business Pro only (its own comment); what Premium and Max customers see is unknown. | TO VERIFY | look with a Premium test account or read the route gating; route them to Managed Move-In or open the page |
| AWL-MI5 | Staff cannot see a customer's import state (no Desk card), so 'my import is stuck' has no one-glance answer. | VERIFIED (card movein is wired:false) | Desk B7 as in B.2 |
| AWL-MI6 | No history of past copies was listed on the test account (empty list is fine) but a stuck session after a crash needs a visible state and a resume; resume behaviour unproven. | TO VERIFY | read mig_sessions state machine; test resume on a scratch database |
