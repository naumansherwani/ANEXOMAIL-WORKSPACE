# MAILBOX AND ROLE PLAN (his word, 22 Nov 2026 11:06 PKT, written line by line 11:12 PKT) - PRIORITY, phase I Mailboxes
Order he gave: Claude first updates this role plan; then verify address-role conflicts and the existing mail flow, then routing/permissions, staff queues, SLA, sender identity, and last real send/receive tests, in this order.
## His 8 points
1. resolved@ = Support queue: employees see customer problems, assign, answer and resolve.
2. moveyourbusiness@ = Managed Move-In queue: migration enquiries and a separate work record per company.
3. Priority Support = a priority/SLA label on the support queue, NOT a new mailbox; an eligible customer gets a first reply within 2 business days (as the landing page says).
4. hello@ = general enquiries; billing@ = authorized finance staff only. Every email keeps its original recipient and thread history.
5. Every employee signs in with own account; access follows the role; assignment, reply and status changes are audited.
6. A staff reply leaves from the address the customer wrote to: support from resolved@, move-in from moveyourbusiness@.
7. Founder may get owner view/copies, but staff never sign in to the founder mailbox. For a reply from the founder address the employee makes a DRAFT, the founder approves and sends. Delegated "send as Founder" only with his permission, approval and audit, never by sharing a password.
8. Order of work: conflicts + existing mail flow -> routing/permissions -> staff queues -> SLA -> sender identity -> real send/receive tests.
Sending rule: general -> hello@; migration -> moveyourbusiness@; support and Priority Support -> resolved@; billing -> billing@. Priority Support replies go from resolved@.
## His 10 addresses
| # | Address | Role |
|---|---|---|
| 1 | hello@anexomail.com | General questions and first enquiries |
| 2 | moveyourbusiness@anexomail.com | Managed Move-In: quote, schedule, company handover |
| 3 | resolved@anexomail.com | Customer support; Priority Support is in this same queue (first reply in 2 business days, as the landing page packages say) |
| 4 | billing@anexomail.com | Billing, invoices, payment questions; only authorized staff |
| 5 | leo@anexomail.com | LEO automatic replies/system work; not a staff support inbox |
| 6 | naumansherwani.founder@anexomail.com | His private founder account; employees never use its password |
| 7 | noreply@anexomail.com | Automatic system mail only; nothing received |
| 8 | postmaster@anexomail.com | Mail-server technical notices; forwarded to resolved@ with its own label |
| 9 | abuse@anexomail.com | Abuse/security reports; forwarded to resolved@ with a restricted security label |
| 10 | dmarc@anexomail.com | Domain mail security reports; auto-filtered in resolved@, never mixed with customer support |
## Step 1 result: conflicts found (11:12 PKT), each fixed or asked
| # | Conflict | Fix |
|---|---|---|
| C1 | AD1 made billing@ SEND-ONLY (live on his server); his rule: authorized finance staff READ billing@ | FIXED in AD5: only noreply@ stays send-only; billing@ restricted by explicit grant (ledgered) |
| C2 | Old docs: resolved@ = silent BCC log of resolved replies; new rule: resolved@ is the real support queue and the reply address | AD5 table says resolved@ = support queue; old BCC-proof idea must be re-planned in phase K (a flag on the case, not an address) |
| C3 | Old docs: postmaster@ alias to abuse@; support@ alias to hello@, trials@ real | AD5: postmaster/abuse/dmarc forward to resolved@ with labels; support@ and priority@ can never exist (constraint); trials@ not in his list, left out until he says |
| C4 | Landing Priority Support says "a named founder contact"; his plan answers from resolved@ by staff | OPEN, his decision: change the landing line or keep a founder contact (website lines are promises) |
| C5 | leo@ listed as system, but AI drafting is dropped until July 2027 | AD5 keeps leo@ as system row, no staff mailbox, no routing |
## Step status
- Step 1 conflicts: DONE (above). Step 2 routing + permissions SQL: AD5 CODED, proved on scratch PostgreSQL 16 (selftest all rules, 13/13 check), not yet on his server. Steps 3-6: NOT written.
