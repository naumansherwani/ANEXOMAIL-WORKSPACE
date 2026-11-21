> ## >>> TOP PRIORITY LIST, AWAM (HIS WORD 22 Nov 2026 03:34 PKT, ANYTHING HE DICTATES GOES HERE FIRST) <<<
> ## >>> AW0 PACKAGES AND CAPS = FINAL: BUSINESS PREMIUM 21,000 POUNDS / 7,000 USERS / 70 TB / 100 MB / 4 GB CHAT FILE. BUSINESS MAX 125,000 POUNDS (HIS 03:38 WORD: FULL AND FINAL 125,000), CARD SAYS UNLIMITED, STRICT 125,000-USER CAP IN BACKEND AND SQL, ALERT 90 / 95 PERCENT, NO BLOCK. BUSINESS PRO ATTACHMENT 60 MB. POOL ALERTS 70 / 85 PERCENT, AT 100 PERCENT BIG TRANSFERS SLOWED, EMAIL KEEPS WORKING. <<<
> ## >>> CODE STILL OLD (MUST BE FIXED WHEN AWAM OPENS): PHASE61 SQL PREMIUM 21,000 USERS CAP, NO MAX ROW; PRICING-V6 AND PACKAGES README SAY PREMIUM UNLIMITED; MAIN.RS HAS NO 10 GB MAX TIER; NO MAX CAP / ALERT / POOL THROTTLE CODE. FULL LIST: docs/awam/PACKAGES-CAPS-AUDIT-22NOV.md <<<
# PENDING AWAM WORK (audit 17 Nov 2026 05:2x PKT). Every open awam item, with the file it comes from. Order of doing = docs/claude/AWAM-BLUEPRINT-CLEAN-17NOV.md (AW0..AW6). Awam starts only after the founder blueprint.

## A. Packages (AW0): Basic, Business, Business Pro, Business Premium, Business Max (Pro is 100% GREEN, not redone)
Source: docs/packages/features.tsv (26 GATE-TO-BUILD, 12 PROPOSED, 1 LATER, 5 OUT-OF-PACKAGE), docs/packages/*/NOT-BUILT.md, AWAM-PACKAGES-PROPOSAL-07NOV.md.
- GATE-TO-BUILD: I1-16 meeting rooms, I1-61 people list, I2-12 decision ledger, I2-18 email-to-chat bridge, I2-25..32 calls (1:1, SFU group, quality ladder, pre-warmed ICE, ring truth, audio-only, connect report, telemetry), I2-34 call business record, I2-66 team report, I2-72 rooms/resources, I2-75..80 forecast / attention leaks / promise SLA / team analytics / report figures, I3-08 live org graph, I3-09 org security, I3-10 teams, I3-17 ownership proof (DKIM/SPF/DMARC/TLS), I3-28 sealed report evidence, I3-29 enforcement history + device ban list.
- PROPOSED (needs his word): N-CRM-04..11 (lead scoring, workflow, quotes, approvals, cadences, forecast, territory, dashboards), N-DOC-01 CRDT docs, N-RET-01/02 legal hold + retention + eDiscovery, N-OFC-01 shared files hub. LATER: I2-35 screen share/recording/captions.
- Card values: Premium 7,000 users, Premium 70 TB, 100 MB attachments; Business Max unlimited-users card with the strict 125,000 cap (backend + SQL, 90 % / 95 % alerts, no block); Business Pro 60 MB; trial 48 h = only free entry; import from Google/Microsoft/Proton in every package; price lock 2 years; Pass + Calendar in every package; pool meter 70/85 %. Premium and Max cards are NOT built (CLOSE-THE-GAPS-07NOV 22:45).
- Personal plans retired: SQL retire step in PERSONAL-PLANS-REMOVAL-PLAN-02NOV.md (check if all steps ran).
- Payment provider: Polar STAYS (his word 17 Nov 05:2x; not a vendor-ban conflict; added to the allowed list in VENDOR-BAN-LIST.json).
- Hetzner capacity: 1 Gbit tops ~324 TB/month; 350-500 TB needs 10 Gbit or more servers; written in the proposal.

## B. Migration of the 822 frozen Lovable files (AW1)
Source: AWAM-LOVABLE-MIGRATION-15NOV.md, lovable-gold/awam/ENDPOINTS-awam.csv (475 endpoints, RUST-FIRST vs BUN-ONLY). Per file: Rust twin, parity test, loophole pass, 390/820/1200 look. AI files are excluded (now in ai-product/). Also: the 41 old founder pages inside awam src (MESS-REPORT) leave when the founder lane owns them.

## C. Transport and promises (AW2)
- K5a is LIVE: 23 awam hosts AES-256-GCM only through server/awam-edge (AES-128 refused, h2 + http/1.1). Proof 9 Nov 17:28.
- HIS CORRECTION 17 Nov: awam is HTTP/3 with h2 + HTTP/1.1 fallback on his server (Caddy h3 on UDP 18443). K5b OPEN: the h3 side itself under our own Rust, AES-256 on its own UDP port (Caddy keeps h3 on UDP 18443 until then). X25519MLKEM768 on the awam listeners not proven.
- WEBSITE-PROMISES P2 OPEN: the awam login + footer TLS line is written only after his openssl proof (TLS 1.3 only, AES-128 refused).
- 9 hosts return 502 (CLOSE-THE-GAPS 9 Nov 17:24); pm2 anexomail-web restarts = 500 (read-only look not done).
- Kernel pin: awam pull needed after the kernel moved to 0.14.0 (CLOSE-THE-GAPS 9 Nov 19:55); check it is done.
- Awam site still runs Bun/Node under pm2: leaves with AW1 (his ban on Bun/Node in runtimes).

## D. Sign-in (AW3)
Passkey only, no 2FA at all, device-bound sessions. Sources: AWAM-PASSKEY-ONLY-PLAN-10NOV, AWAM-PASSKEY-AUDIT-10NOV (loopholes list), AWAM-PASSKEY-PRESERVE-10NOV, AWAM-NO-2FA-10NOV, G35 PasskeyGate (compulsory with grace), password stays until March 2027. Mobile login + country requirement: AWAM-MOBILE-LOGIN-COUNTRY-REQUIREMENT-01NOV (still to verify on the phone). Syria wall (geoblock apply) waits his go; banned-countries data exists.

## E. Mailbox, calendar, CRM, chat (AW4, AW5)
- Mailbox UI = founder mailbox moulded (AWAM-MAILBOX-UI-INHERIT-LAW-16NOV): mailbox_pure.ts, mailbox_icons.tsx, mailbox.css, MailBox.tsx, mail_pure.ts, MailCompose.tsx are preserved with SHA-256 in AWAM-INHERIT-MANIFEST.json. Business Premium and Max use the same UI. Premium/Max mailboxes on the company's own domain.
- Emoji: compose offers every emoji (founder QC1e first, then inherited).
- AnexoChat: 141 endpoints, blueprint anexochat/docs, SQL anexochat/sql (27 files). CRM: docs/packages/crm/CRM-PHASES.md. Tablet 820 look of K5a still unseen.
- PX7c, PX8, AX9b, GEO1, MB1 and AX0..AX13 rows: table in AWAM-ENGINE-BLUEPRINT-02NOV.md (top block).
- Old open lists (21 Oct, stale but unreconciled): docs/cursor-work/GREEN-BOARD/NOT-GREEN/01..06. They must be reconciled against features.tsv once, then marked superseded.

## F. Later products
AnexoSuite (AX-P11, last, 2-month target): AX-P11-ANEXOSUITE-TECH-PLAN-07NOV. "Beyond Proton" footer + phase order: AWAM-PROTON-PLUS-PLAN-07NOV. AI product: ai-product/ (separate, not in awam). Enterprise contract form for Premium/Max sits near the founder billing phase O.

## G. Deadlines (his words)
Founder complete 25 Nov 2026; whole awam website 100 % with tests and AnexoChat by 16 Dec 2026; seminar launch 16 Jan 2027.

## H. AI product (his word 17 Nov 05:2x)
AI codes are kept (ai-product/ copy + live originals) and used in the AI product = same website with AI features added where they belong, product build starts JULY 2027. Until then: awam landing must NOT open ai.anexomail.com, awam users must not see it, the landing shows only "Coming soon". OPEN: audit landing + nav + footer for ai links and the 3 AI hosts (ai, aicrm, aiemail) so they show nothing to the public.
