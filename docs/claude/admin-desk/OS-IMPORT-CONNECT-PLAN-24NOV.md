# HOW THE COMMAND CENTER OS CONNECTS TO THE AWAM "IMPORT MAIL" FEATURE (24 Nov 2026 09:4x PKT, his 09:41 order: "business test account yeh real hai, live Chrome mein jao, match kero ke humara OS user ki kya help kar sakta hai")
Written from my OWN LIVE LOOK at https://anexomail.com/app/import (his Chrome, business test account, read only: I opened the page, started NO copy, typed NO password) plus the repo (src/components/app/migrate/ImportMailPage.tsx, E35 mig_sessions / mig_items / mig_chain, MOVEIN-PRICE-CLOSED-21NOV.md, BILLIONAIRE BL-27).

## WHAT THE LIVE PAGE SHOWS (facts, 09:4x PKT)
- Signed in as the business test account; the copy goes INTO business.test@anexomail.com.
- Six old-provider choices: Gmail / Google Workspace, Outlook.com / Hotmail, Yahoo Mail, iCloud Mail, Zoho Mail, Another IMAP server. Gmail needs 2-Step Verification + a 16-letter App Password.
- Promises written on the page (WEBSITE PROMISES law: a line on a page is a promise he delivers): old mailbox is only READ, never moved / marked read / deleted; a sealed receipt you can check when the copy ends; mail already here is skipped (running twice never doubles); read and starred state kept, folders kept; App Password kept in memory only while the copy runs, never on disk, database or logs.
- HONEST GAP the page itself states: attachment files are NOT copied yet (mails that had attachments are marked). Trash and Spam are off by default.
- The page showed no earlier copies for this account (no list rows), console 0 errors.

## WHAT THE OS (DESK) CAN DO FOR IT, in his locked order (Dashboard first)
1. B7 "Move-in board" card (BL-27, was blocked): per company, import state (running, stopped, finished, failed), counts of items copied / skipped / marked-attachment, start and end time, from E35 mig_sessions via the Control Plane signed read-only door (same path as Plans / Deliverability). NEVER mail content, subject, address or the old provider password. Honest zeros: no sessions = 0 shown.
2. Receipt check field: staff pastes the receipt id, the Desk asks the Control Plane to verify the mig_chain seal and shows 'genuine / not genuine' + counts, no mail content (Rule 52 signed answer).
3. Stuck-import case (needs B13 T3/T4 binding first because the company is known from the session tenant UUID, not guessed from mail): an import stopped or running > 24 h opens a case in the movein queue with the session id.
4. Attachments gap = a Desk runbook line 'attachments are not copied yet, here is what to tell the customer' (words to say, no promise of a date) and a counter on the board of mails marked as having attachments.
5. Package split: self-serve import is for Basic, Pro, Business, Business Pro (the page comment says so); Premium, Max and anyone who cannot self-serve use MANAGED MOVE-IN (his closed price GBP 568 / 1,670 / 2,210 / 3,350 by mailbox count): the same migrator engine run by staff from the Desk (Folder 8, phase P, Rust async IMAP), same receipt, any content access only through B13 consent.
6. After the copy: Deliverability card (SPF/DKIM/DMARC/MX, already GREEN) plus a runbook 'switch the domain' for the company; storage pool meter (AWL-3) so a big import never hits the quota silently.

## WHAT STAYS FROZEN (his order): Managed Move-In and the Rust mail door wait for Folder 8 and Folder 2. B7 comes in the card order AFTER B13, B11, B12 (his locked order); I do not reorder it unless he says so.
## WHAT I MUST NOT DO: start a copy, type or store an old-provider password (prohibited), change anything on the business test account.
