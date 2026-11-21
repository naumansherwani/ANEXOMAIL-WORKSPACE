# SIDEBAR SECTIONS + BILLION-DOLLAR LOOPHOLES, HIS TEXT VERBATIM (his 22 Nov 2026 03:01 PKT, saved 22 Nov 2026 03:02 PKT)
His order: add this line by line to the repo, Admin Desk blueprint phases (in order), ledger and compact save. Text below is HIS attachment, unchanged.

```

 Sidebar Mein Kya Naye Folders / Sections Add Karein? (Tarteeb Se)

Abhi aapke left sidebar mein 5 items hain (Dashboard, Inboxes, Cases, Managed Move-In, Team, Audit). Dunya ke top enterprise consoles ko match karne ke liye isay 4 saaf groups mein is tarteeb se mukammal karein:
1. COMMAND & LIVE PULSE (Upar Top Par):
	• Dashboard (Mojood hai — is mein live metrics aur alerts aayenge)
	• Live Pulse & SLA (Naya — customer tickets ka response time, live queue pressure, aur server/mail health)
2. SUPPORT & OPERATIONS (Awam Ki Madad):
	• Inboxes (Mojood hai — support@, priority@, billing@ shared queues)
	• Cases (Mojood hai — open, urgent P1, aur resolved tickets)
	• Managed Move-In (Mojood hai — "Move Your Business" G30 migration tracker)
	• Domains & DNS Health (Naya — customers ke MX, SPF, DKIM, DMARC aur MTA-STS status check/fix karne ke liye)
3. ORGANIZATION & GOVERNANCE (Company Control):
	• Customers & Plans (Naya — Basic, Pro, Business Pro, aur Enterprise £20,500 accounts ki status aur limits)
	• Team & Access (Mojood Team ko upgrade karein — 10-minute enrollment codes, 2-device passkeys, aur shift locks)
	• Security & Policies (Naya — IP geofencing, AAGUID hardware key rules, aur bulk-export circuit breakers)
4. VERIFICATION & ESCALATION (Zero-Trust Saboot):
	• Audit Ledger (Mojood Audit — SHA-256 hash-chained immutable logs)
	• Chairman Escalations (Naya — woh critical P1/Enterprise cases jo seedha aapke Founder Vault ko bheje jayein)

2. Billion-Dollar Companies Kya Karti Hain (Jo Aapke Dashboard Par Hoga)

Google Admin, Microsoft 365 Defender, aur Zoho Admin Console ke standard features jo aapke dashboard cards mein live aayenge:
• Live Queue & SLA Radar: Kitne tickets open hain, Enterprise/Business Pro ke kitne P1 tickets hain, aur average resolution time (jaise 1m 45s) kya chal raha hai.
• Migration Command Center (Managed Move-In): Customers ki purani Gmail/Outlook/Zoho se aane wali emails ke live progress bars, failed batch retry buttons, aur domain verification status.
• Domain & Mail Deliverability Inspector: Customer ka domain dalte hi SPF, DKIM, DMARC, aur TLS status ek click mein verify aur troubleshoot karna.
• Delegated Role & Shift Management: Support agents, migration specialists, aur team leads ke alag-alag permissions aur active sessions ki live list.

3. Billion-Dollar Companies Ke 6 Bade Loopholes — Jo Anexomail Fix Karega!

Google, Microsoft, aur Zoho ke admin panels mein 6 aise security loopholes hain jin ki wajah se badi companies hack hoti hain. Anexomail in sab ko jadh se khatam karega:

#	Billion-Dollar Companies Ka Loophole (Ghalti)	Anexomail Admin Desk Ka Fix (Dunya Se Advance)
1	Super-Admin God Mode (Blind Trust): Google/Zoho ka support ya super-admin kisi bhi user ki emails aur files parh sakta hai.	Zero-Knowledge Vault Isolation: Aapka koi bhi employee (yahan tak ke Owner bhi) kisi customer ki sealed email body ya Founder Vault (fmail_*) kabhi nahi parh sakta—sirf metadata aur DNS/migration tools dikhenge.
2	Session Hijacking & Cookie Theft: Admin ka browser cookie chori ho jaye to hacker apne laptop se admin console khol leta hai.	Hardware DBSC + Network Flap Kill: Token laptop ki TPM chip se bandha hai; agar doosre IP/machine se use ho to session milliseconds mein auto-nuke ho jata hai.
3	Help-Desk Social Engineering: Hackers support ko call kar ke password ya MFA reset karwa lete hain (jaise MGM aur Twilio hacks mein hua).	Zero-Password + 2-Supervisor Cooling Lock: Password hai hi nahi; account recovery ke liye 2 supervisors ki passkey aur 24-ghante ka cooling period lazmi hai.
4	Editable / Deletable Audit Logs: Compromised admin purane logs delete ya hide kar sakta hai.	SHA-256 Append-Only Merkle Ledger: Database triggers har delete/update ko block karte hain—koi ek row bhi mita de to poori chain toot kar alert de deti hai.
5	Insider Bulk Data Scraping: Ek naraz employee ek hi raat mein hazaron customer tickets aur emails download kar ke le jata hai.	Anti-Scraping Circuit Breaker: Tezi se bulk tickets kholne ya export karne par Rust backend session freeze kar ke seedha Founder Bridge par red alert bhejta hai.
6	24/7 Unrestricted Admin Access: Employee ghar baith kar raat 3 baje bhi office system khol sakta hai.	Office Geo-Fence & Shift-Hours Gate: Employee ka access sirf office IP aur un ki duty timing mein hi khulega; off-hours mein darwaza band rahega.
```

## CLAUDE'S CHECK AGAINST HIS OWN LAWS (honest, 22 Nov 03:0x): nothing is dropped, but 6 lines need his decision before code
| His line | Conflict | Proposed handling (his haan needed) |
|---|---|---|
| Inboxes "support@, priority@, billing@" | support@ is BANNED (AD1: resolved@ replaces it); billing@ is send-only | use hello, moveyourbusiness, resolved, priority (new), billing restricted |
| Anti-scraping "red alert to Founder Bridge" | DESK ISOLATION: the Desk cannot write to the Founder Bridge | alert goes to the Desk's OWN bridge (fadm_alert, AD2 built); a signed one-way notice to the founder is a separate door, only with his haan |
| "Chairman Escalations ... seedha Founder Vault" | same isolation law; fmail_* is founder-only | escalation stays INSIDE the Desk (owner-only case lane); no Desk write into the founder vault |
| "Enterprise £20,500" plan | not in AD1 plan list (Basic..Business Max) | keep as plan DATA row (fadm_plans) only after he confirms the term |
| "Merkle ledger" | built today = SHA-256 hash chain (AD1); Merkle is a later step | say hash chain now, Merkle at module 16 |
| "Session auto-nuke in milliseconds, TPM bound" | DBSC (ON3) is not built; no claim on a website until proven | planned ON3; nothing promised before his proof |
| "even the Owner cannot read sealed email / fmail_*" | consistent with isolation; Desk never reads founder tables | keep as a rule: staff see metadata only (module 06, 15) |
## HOW IT MAPS TO THE PHASES (order unchanged)
Rail group 1 COMMAND & LIVE PULSE: Dashboard (R4-1a LIVE), Live Pulse & SLA (R3f + R4-1b Desk Bridge). Group 2 SUPPORT & OPERATIONS: Inboxes (R4-2), Cases (R3b), Managed Move-In (R4-11), Domains & DNS Health (new, with R4-10 deliverability). Group 3 ORGANIZATION & GOVERNANCE: Customers & Plans (R3p / R5a), Team & Access (AD2 live; ON1-ON8 Rust door), Security & Policies (ON9-ON12, AD2 live). Group 4 VERIFICATION & ESCALATION: Audit Ledger (module 16), Chairman Escalations (new, inside Desk, owner-only). The rail names change to these four groups in step R4-1c, after his haan on the table above (current rail: Dashboard / Pinned / ANEXOMAIL WORKSPACE / ADMIN DESK / Company stays until then).
The 6 loopholes = the Desk's design promises: (1) metadata-only staff view, (2) DBSC session binding (ON3), (3) 2-supervisor recovery + 24 h cooling (AD2 LIVE), (4) append-only hash-chained ledger (AD1/AD2 LIVE), (5) anti-scraping breaker (AD2 LIVE, Rust side ON11), (6) office IP + shift gate (AD2 LIVE, Rust side ON10). Each is proof-gated: no website line until WIRED + REAL.

## HIS ANSWERS (22 Nov 2026 03:08 PKT, to the table above)
* Anti-scraping alert: Desk's OWN bridge (his "tum sahi ho"). Chairman Escalations: INSIDE the Desk, owner-only lane (his "yeh desk ke andar aye ga").
* "Enterprise 20,500 pounds" was WRONG as a plan: it is the Business Max package price he quoted; a separate Enterprise plan is a matter AFTER the Admin Desk (his word). No Enterprise row now.
* Merkle later, DBSC claim only after proof, owner cannot read sealed email: kept as written. support@ stays banned (resolved@).

## CORRECTION 03:19 PKT: I wrote that 20,500 was the Business Max price: WRONG. The awam packages file says Business Max = 125,000 pounds. He says 21,500; NOT found in any doc, so UNCONFIRMED. See DASHBOARD-LIVE-COMMAND-22NOV.md section D.

## CORRECTION2 22 Nov 2026 03:30 PKT: 21,500 was Premium 21,000 (7,000 users). Max price conflict 105,000 vs 125,000 open.
