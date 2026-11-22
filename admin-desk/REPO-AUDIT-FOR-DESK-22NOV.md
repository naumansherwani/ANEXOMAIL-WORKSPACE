# REPO AUDIT FOR THE ADMIN DESK (his word 22 Nov 2026 09:46 PKT: "full repo ka ek ek folder, kuch bhi nahi chodo")
Written 22 Nov 2026 09:49 PKT. Why: the Desk was planned inside the founder app, now it is its OWN product (own host, own Rust binary, own role, own tables). So the Desk blueprint must hold every point the repo already knows about the awam's problems, and must NOT hold founder-only phases. Method: every top-level and second-level folder of `git ls-files` (4,126 files) was searched for Desk words (mail desk, support, SLA, move-in, escalation, deliverability, ClamAV, Storage Box, staff, case, CRM, quota, glitch) and the hits were read. `lovable-gold/` is frozen (Rule 73): read only, never edited.
Rules kept: Desk isolation law (no founder code, doors, keys, tables); no money / webhook / Polar data on the Desk (his 09:15 word: finance stays with him); no phase name anywhere an employee can see (rule 14); HTTP/3 primary, Rule 52 kernel-verified answers; Desk files never say h1 / h2.

## A. FOLDER BY FOLDER (every folder has a row, also the ones with nothing)
| Folder | Files | What it holds that the Desk needs | Desk point (id) |
|---|---|---|---|
| docs/claude | 381 | Old Mail Desk method (FOUNDER-ADMIN-MAIL-DESK-03NOV.md), mailbox phase order, Managed Move-In price closed, packages caps audit, vendor ban, isolation law | AU1, AU2, AU3, AU10, AU11 |
| docs/claude/admin-desk | 97 | The Desk's own plans (already canonical) | none, this is home |
| docs/cursor-work | 882 | CRM-STACK, MAIL-OUTLOOK-MAP, server scripts (backup, ClamAV alerts), founder-commands (his verbatim orders), MASTER-GAP-LEDGER | AU4, AU12 |
| docs/packages | 38 | Package truth per tier (basic, pro, business, business_pro, enterprise, crm), features.tsv 232 rows with status MATCHES-CODE / GATE-TO-BUILD / PROPOSED | AU5 |
| docs/wire | 32 | Wire steps: account recovery (25), storage box (16), CRM hosts (18), final addresses (20), mail queue fix (22) | AU6, AU7 |
| docs/awam | 7 | PENDING-AWAM, PACKAGES-CAPS-AUDIT-22NOV (the caps the Desk must show) | AU5 |
| src (awam site) | 664 | What the customer can do: app.admin.* (members, audit, health, diagnostics, export, migrate, monitoring, addresses), org routes (blast radius, revoke, roles, privilege radar), support drafts | AU8 |
| server (awam Bun + Rust + routes) | 358 | Customer-side doors the employee must understand (support, glitch, movein, org, storage, crm), Rust mail core (deliver_bin, inbound_attach, evidence), storage mount scripts, gates | AU4, AU7, AU8 |
| founder-web | 461 | Desk source lives in src/desk (own domain); the rest is founder UI: not for the Desk | AU10 |
| admin-desk | 96 | Synced copy of the canonical Desk folder | none |
| sql | 60 | Awam SQL: phase37/38/39 Move-In state machine, phase47 glitch + noise rules, phase48 logical storage quota, phase52 mail truth tables, phase56 final address list | AU4, AU7, AU9 |
| ai-product | 62 | Awam AI and founder AI; AI drafting for the Desk is dropped until July 2027 (his word) | AU13 |
| anexochat | 41 | Chat to email bridge (phase30), file limits quota (phase61 old numbers) | AU5 |
| web-wasm | 38 | Rule 52 Rust WASM kernel + mailparse.rs; the Desk has its OWN kernel build in admin-desk/kernel | AU1 |
| backups | 17 | Desk backups with MANIFEST (restore points) | AU12 |
| .cursor | 14 | plan-match-lock rule (plan and code must match) | AU12 |
| lanes | 11 | Lane files: founder / awam / shared / lovable / docs; a new Desk file must be run through lane-sync | AU12 |
| public | 10 | Static public files: nothing for the Desk | none |
| .lovable | 6 | Old Lovable plan notes: frozen history | none |
| scripts | 5 | Generic scripts: nothing Desk specific | none |
| banned-countries | 4 | Country wall list (geoblock) | AU11 |
| anexomail inboxes to build | 3 | THE address list: hello, moveyourbusiness, support alias, billing, noreply, trials, abuse, postmaster, dmarc, resolved, founder, leo, industry agents | AU2 |
| portal | 1 | Portal stub: nothing | none |
| .claude | 1 | Claude settings: nothing | none |
| lovable-gold | 901 | Frozen original Lovable code: the Mail Desk, support replies, Move-In cockpit as first written; migrate by the recipe "preserve, advance technology, fix loopholes, polish" | AU1, AU3, AU4 |
| (root) | 18 | CLAUDE.md, AGENTS.md rules 1..73 | AU12 |

## B. THE POINTS (each one goes into the Desk blueprint top, in this order)
AU1. OLD MAIL DESK = the Desk's mailbox source. The founder's old plan "Admin > Mail Desk" (R3) said: a separate advanced mailbox for the awam's problems, `fadm_mail_*` tables with its own hash-chained ledger, ClamAV + Hetzner Storage Box for attachments, passkey touch for any send on behalf of the company. Lovable endpoints (founder.ts mailboxes, ai-mail, provision, approve, billing-support.ts support replies) are preserved in lovable-gold/founder and are migrated with the recipe, never copied raw. Desk phase: I, K, N.
AU2. THE ADDRESS LIST (anexomail inboxes to build + sql phase56, final): real mailboxes are hello@, moveyourbusiness@, resolved@, billing@ (restricted), leo@; support@ is an ALIAS to hello@ (his Desk order: support@ banned as a separate mailbox); noreply@ is send-only, inbound closed; trials@, abuse@, dmarc@ real; postmaster@ alias to abuse@. resolved@ is the silent internal BCC of every resolved reply (the Desk's proof of "solved"). Desk phase: I.
AU3. SUPPORT REPLY RULES from the Lovable gold: a public SLA number exists (`sla_public`, 30 days) and the landing page shows it; drafts can be discarded; every resolved reply is BCC-logged. The Desk keeps the same truth: SLA clock = real minutes from first message, stops at first human reply. Desk phase: K.
AU4. MANAGED MOVE-IN = a state machine decided by the database (phase37): LEAD to ... legal transitions in `movein_transitions`, capacity per month (`movein_capacity_state`: slots booked / free, waitlist), source / destination / DNS / verification state per deal, deposit and final legs, a sweep job, a customer view of their own deal. PRICE: 568 / 1,670 / 2,210 / 3,350 by mailbox count 1-5 / 6-15 / 16-29 / 30+ (the Lovable ladder 500/1,500/2,000/3,000 is OLD). Money legs and revenue stay founder side: the Desk shows ONLY state, slot, DNS and mailbox checks. Desk phase: P.
AU5. PACKAGE TRUTH for D5 (employee sees package + features + limits): Basic, Business, Business Pro, Business Premium, Business Max. Caps decided: Premium 7,000 users / 70 TB / 100 MB attachment / 4 GB chat file; Max strict 125,000-user cap in backend + SQL with near-cap alert 90 / 95 percent, no block; Business Pro attachment 60 MB; pool alerts 70 / 85 percent, at 100 percent big transfers are slowed and email keeps working. OLD numbers still in code (phase61 SQL 21,000, pricing v6 "unlimited", README, main.rs no Max tier): the Desk must read the final list the founder supplies (his answer 2 of 3), never these old files. The Desk shows NO price. Desk phase: D5.
AU6. ACCOUNT RECOVERY (wire 25) is the path an employee hears most ("I cannot sign in"): the employee must see only that recovery is pending / done, never a secret or code. Runbook card: "cannot sign in". Desk phase: D5b, H.
AU7. STORAGE / QUOTA (phase48 + wire 16): quota is LOGICAL (quota_bytes, used_bytes, remaining_bytes; no disk reserved), Business Pro is a pooled 1 TB, storage volumes are abstract (local, object, Storage Box) and the frontend never knows where data sits. Employee view: used / remaining, near-full alert, never the volume path. Mail queue fix (wire 22) and inbound raw proof (`mail_inbound_raw`) are the evidence for "my mail did not arrive". Desk phase: D5b, I.
AU8. WHAT THE CUSTOMER CAN DO (so the employee does not guess): company admin screens (members, audit, health, diagnostics, export, migrate, monitoring, addresses), org actions (revoke member with a blast-radius preview, roles, privilege radar, departments, policies). Runbooks for "member removed by mistake", "export", "address not working" are built from these. The Desk never performs a customer admin action silently: the customer's own admin does it; the employee guides or escalates. Desk phase: D5b.
AU9. GLITCH TRUTH (phase47): customer errors are logged with a fingerprint (same fingerprint = one alert, count grows), noise rules (browser noise, extension errors, chunk reload) are ignored, rate cap 12 alerts per hour then muted (log stays), rage click alert only when 3 or more different sessions hit one button. The Desk copies these RULES for its own alerts (dedupe key already in `fadm_alert_raise`), with NO third-party replay tool and NO outside chat alert (vendor ban); alert push to the founder phone goes only through his own Rust. Desk phase: D2 (rules), K.
AU10. FOUNDER-ONLY PHASES TAKEN OUT of the Desk blueprint (his word: the Desk is independent): Finance, Polar read, Release, Control (kill switches, flags), founder Devices and sessions, Settings, Profile, Trust, keys, founder ledger, orb, Palette, founder Mail and Calendar, founder AI. From the old founder letter series the Desk keeps only what it needs as its own code: Rule 52 kernel (own build), WebTransport, passkey touch (own), hash-chained ledger (own), Merkle log (own). The old letters K-series, L, M, N..V of the founder are NOT Desk phases; the Desk letters are A..Q in DESK-PHASES-22NOV.md.
AU11. SECURITY INHERITED AS LAW (not code): banned vendor list (docs/claude/VENDOR-BAN-LIST.json; only Caddy, Namecheap by his hands, Hetzner, his own Rust), country wall list (banned-countries, geoblock applies when he says go), no WebSocket, no Bun or Node in a server runtime, X25519MLKEM768 + AES-256-GCM only. Desk gate keeps checking these.
AU12. PROCESS FACTS the Desk follows: backups before any UI change (backups/desk/MANIFEST), plan must match code (.cursor plan-match-lock), lane-sync after adding files, canonical folder docs/claude/admin-desk then desk-copy-sync, every green line "WIRED: YES / REAL: YES / TECH-LAW CHECKED", live Chrome look before green, 26 Nov 2026 07:26 PKT is the whole-Desk deadline.
AU13. AI: leo@ (LEO) and the AI drafting for replies are dropped from the Desk until July 2027 (his word); awam-ai and founder-ai folders are NOT Desk code.

## C. WHAT THIS CHANGES IN THE DESK PLAN
1. Phase I (Mailboxes) now has its exact address list (AU2) and its source (AU1).
2. Phase K (Cases + SLA) takes the SLA rule and resolved@ BCC proof (AU3) and the alert rules (AU9).
3. Phase P (Managed Move-In) takes the state machine, capacity, checks, new price (AU4); money stays with him.
4. D5 / D5b take caps (AU5), recovery (AU6), storage (AU7), customer-admin facts (AU8) as the runbook base.
5. Founder-only items are listed once (AU10) and are not on any Desk phase.

## D. STILL OPEN (honest)
- The final landing-page package list from him (answer 2 of 3).
- Whether the Desk may do a read-only signed metadata lookup on his control plane (answer 1) and the escalation case (answer 3).
- Folder content below second level inside docs/cursor-work (882 files) was searched by keyword, not read line by line; anything new he points at is added here the same hour.
