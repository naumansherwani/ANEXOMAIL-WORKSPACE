# ANEXOMAIL MOVE-IN SYSTEM PLAN: SAVED VERBATIM (24 Nov 2026 10:0x PKT, his 10:01 order: "yeh ek ek line likh ki Admin Desk ke phase ke agay, gates ko bhi batao, yehi follow hoga, saath mein web search ke checkpoints add hongay")
# Text between BEGIN VERBATIM and END VERBATIM is exactly as he pasted it. Everything after END VERBATIM is Claude's notes. Kept in docs/claude/ (not in the Desk folder) because it names money amounts and the Desk files keep money out (DESK NO-MONEY gate).
# BEGIN VERBATIM
ANEXOMAIL Move-In System — Plan
Maqsad: customer ke email move ko request se lekar verified handover tak staff ke liye trackable aur customer ke liye saaf banana. Yeh sirf design plan hai; code ya files nahi badli hain.

1. Request lena — `moveyourbusiness@` Customer company/domain, purane email provider, mailboxes ki tadaad, andazati data size, zaroori data (mail, contacts, calendars), aur preferred move date bataye. Mailbox count mein actual login inboxes gine jayen; aliases aur groups alag record hon.
2. Scope aur one-off quote
   * 1–5 mailboxes: £568
   * 6–15 mailboxes: £1,670
   * 16–29 mailboxes: £2,210
   * 30+ mailboxes: £3,350
Customer ko quote approve karne se pehle included work, exclusions, data size aur cutover plan saaf dikhaya jaye. Yeh prices live billing se verify nahi kiye gaye.
3. Kaam ki stages `Nayi request → Scope check → Quote bheja → Customer approval → Move ki tayari → Pilot → Migration → Verification → Cutover scheduled → Handover → Closed`
Har stage par zimmedar staff member, agla qadam, tareekh, aur customer ko bheja gaya update record ho. Approval se pehle migration shuru na ho.
4. Pilot, phir poora move Pehle customer ke saath chhote pilot group ko test karein. Mailbox access, mail folders, bhejna/receive karna, aur agreed data check hone ke baad hi baqi mailboxes aur cutover schedule hon. Purana provider foran band na kiya jaye.
5. Customer aur staff ke views
   * Customer: request, agreed scope, current stage, scheduled cutover, verification result, handover.
   * Admin Desk staff: request queue, assigned owner, checklist, customer updates, evidence, deadlines aur escalation.
   * Founder: progress aur approval/reporting; founder ke login details staff ke saath share na hon.
6. Security aur proof Email mein passwords na mangwayein. Customer ko secure tareeqe se access dene aur baad mein revoke karne ka raasta ho. Har important action—approval, mailbox count, pilot result, cutover aur verification—waqt aur zimmedar ke saath audit record bane. Asli proof ke baghair “complete” na dikhaya jaye.
7. Priority Support alag rahe £790/month Priority Support, Move-In quote se alag service ho. Wada 2 business days mein pehla jawab hai—fix ya migration complete hone ka waqt nahi. Quarterly service/security review bhi isi alag plan ka hissa hai.

Abhi tay karne wali policy: quote mein data-size limits, kaun sa data migrate hoga, failed/incomplete migration ka tareeqa, aur cutover ke baad support duration. Inke baghair customer ko final scope approve nahi karwana chahiye.
Technology report: koi file ya code nahi badla; yeh sirf design plan hai, phase abhi assign nahi. Abhi code mein NAHI.
# END VERBATIM

## CLAUDE NOTES (after the verbatim text; he reviews)
1. WHERE IT LIVES IN THE PHASES: the whole Move-In pipeline (11 stages, quote, pilot, cutover, handover) = Folder 8 "Admin Desk group", phase P Managed Move-In (R4-11), with the Rust async IMAP migrator. NOT before Folder 1 is whole. The Dashboard card `movein` (B7) stays the one-glance board of it. Order unchanged.
2. SAME ENGINE (his 10:01: "yehi mera business backbone hai, accurate banao"): Managed Move-In and the self-serve import page use ONE migrator and ONE sealed receipt (mig_chain). Accuracy first: AWL-MI1 (attachments not copied) is the HIGHEST awam loophole; the Move-In promise is half until attachments, contacts and calendars are copied and counted on the receipt.
3. A MOVE-IN REQUESTER IS OFTEN NOT A TENANT YET (mail to moveyourbusiness@ comes from a prospect). So the case is a PROSPECT case: it must NOT be bound to a tenant UUID (B13 T2 binding) and must never start a consent request; B13 T3 returns 'unknown' for such a sender and that is correct. The 11 stages belong to a Move-In record of their own (own table, Folder 8), tied to a tenant UUID only AFTER the company has an account. Loophole closed on paper here.
4. PLAN POINTS THAT NEED POLICY BEFORE CODE (his own last paragraph): data-size limits per quote, which data classes move (mail, contacts, calendars), failed/incomplete migration handling, support duration after cutover. They are OPEN POLICY ITEMS: no customer is shown a final scope until they exist.
5. PASSWORDS: no password by email; secure access that can be revoked; every approval, mailbox count, pilot result, cutover and verification = audit line (hash-chained ledger) with time and owner; 'complete' is shown only with real proof (receipt).
6. PRICES: the plan says 'not verified against live billing'; MOVEIN-PRICE-CLOSED-21NOV.md (his word) says they equal the landing page and Polar; a live billing check stays on the list.
7. PRIORITY SUPPORT (his 10:01): 'a named founder contact' is REMOVED from every landing text BEFORE LAUNCH; Priority Support is answered from resolved@ by staff (MAILBOX-ROLES-PLAN-22NOV.md C4). THE GATE NOW HOLDS THIS: TECH-LAW-GATE.json checks C4-priority-* fail from 9 Jan 2027 (one week before the seminar launch 16 Jan 2027) if any landing file still says 'named founder contact'. Awam files are frozen: the text change itself needs his haan, the gate only reminds.
8. WEB SEARCH CHECKPOINTS (his 10:01: they must be added): every Move-In phase begins with a dated web-research point list (RESEARCH IN BLUEPRINT law), recorded in the phase row. Checkpoints to run, in order, when phase P starts: [W1] IMAP migration tooling and resumable-batch design (imap-codec, imapsync-style flag/UID mapping); [W2] attachment, contact (CardDAV) and calendar (CalDAV) migration accuracy and receipts; [W3] cutover practice (MX TTL lowering, dual delivery, SPF/DKIM/DMARC staging, rollback); [W4] quote and scope templates of managed migration services; [W5] provider rate limits and app-password / OAuth rules of Google, Microsoft, Yahoo, iCloud, Zoho; [W6] data-protection duties (nFADP, UK GDPR) for a processor reading a customer's old mailbox. Each result goes into the blueprint BEFORE code.
