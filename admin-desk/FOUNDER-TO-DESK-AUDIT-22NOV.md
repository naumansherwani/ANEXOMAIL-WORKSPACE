# AUDIT: WHICH FOUNDER SCREENS ABOUT THE AWAM (USERS) MOVE TO THE ADMIN DESK (his 22 Nov 2026 02:43 PKT)
His word: everything in the founder app that is about the awam moves to the Admin Desk, "same to same", and is removed from the founder app afterwards; ONLY Finance and Polar stay in the founder app. The Desk's Bridge is the founder's Bridge pattern, but made for the Desk's own needs. Above the mailboxes sits ANEXOMAIL WORKSPACE, and the folder ADMIN DESK holds every user's problem. "Managed Move-In" (his "managed movie") moves too.
RULES THAT DO NOT BREAK: Desk isolation law (copy into founder-web/src/desk/, never import founder files; /desk/v1/*; fadm_* tables; Rule 52 kernel calls); UI LAW: a founder screen is REMOVED only after its Desk copy is live and seen by me in Chrome, and only as a "move", never as a gap; Finance + Polar are never touched. Source of the founder list: founder-web/src/catalog.ts DECK_META + lanes/FOUNDER-INDEX.md.
| Founder screen (catalog) | About the awam? | Decision | Desk home | Phase |
|---|---|---|---|---|
| Finance (F3) | revenue, billing, Polar | STAYS in founder (his word) | none | none |
| Polar read-only (E105/E106, polar.rs, Finance.tsx) | payments | STAYS in founder | the Desk only RECEIVES a signed plan event (R3p2), never reads Polar | none |
| People (F4): organisations, users, devices, permissions | YES | MOVE | Admin Desk folder, "People" (metadata only, never message content) | R5a |
| Managed Move-In (F3): slots, cut-overs, mailbox + DNS checks | YES | MOVE | Admin Desk folder, "Managed Move-In" (his folder name, rail item exists, not connected) | R4-11 |
| Mail > Mail Desk (company mailboxes, support replies, deliverability) | YES | MOVE | ANEXOMAIL WORKSPACE > Inboxes | R4-2 |
| Mail > his own inbox, folders, compose, outbox, Calendar | founder's own mail | STAYS (also built in the Desk for staff) | Inboxes (staff mail) | R4-3..R4-10 |
| Dashboard card "New customers" (leads, Glitch / Support / Company Mail) | YES | MOVE to the Desk dashboard (leads = CRM) | Desk dashboard + R-CRM | R4-1b |
| Bridge lanes about awam delivery (BridgeLanes, BridgeMailLedger, BridgeMailSpeed, Inbox 4d) | partly | COPY, then trim to the Desk's own needs (queues, SLA, mail lanes) | Desk Bridge | R4-1b |
| Systems (F6): health, capacity per tenant | tenant side YES | MOVE the per-tenant part; platform health STAYS | Desk "Systems" under Company | R5b |
| AI (F6) workflows for the awam product | partly | DECISION NEEDED from him (his haan) | later | R6 |
| Release (F3), Control (F8: kill switches, flags) | platform, not awam | STAYS in founder | none | none |
| Devices and sessions, Settings, Profile, Trust, keys, ledger/audit, Palette, orb | founder's own security | STAYS; the Desk has its OWN copy for staff | Desk top bar + profile menu | R4-1b |
## THE BIG ORDER OF HIS 2ND SCREENSHOT (founder look: top bar with Live + Trusted chips, profile menu with photo, Profile and photo, Settings, Devices and sessions, Sign out, cards) = R4-1b, DIRECTLY AFTER THIS STEP
1. R4-1a (done, on his server): rail, greeting, clock, session, honest cards. This step adds: pin/unpin, scrollbar, groups ANEXOMAIL WORKSPACE / ADMIN DESK / Company, the "Admin Desk" text removed under the logo.
2. R4-1b (NEXT, today): top bar with Live and Trusted chips (real: kernel-verified answer + device key state), profile menu (name, role chip, Profile and photo, Settings, Devices and sessions, Sign out), cards rebuilt from real Desk data, Desk Bridge copy. Tech: React 19, TanStack Router, kernel RPC (Rule 52), Tailwind 4, Framer Motion.
3. R4-2 inboxes (SQL fadm_mailbox on top of AD2 groups, Rust door, UI) = what sits under ANEXOMAIL WORKSPACE; hello / moveyourbusiness / resolved; billing restricted; noreply send-only; support@ banned.
4. AD2 Rust door (invite, enrol, passkey, recovery) so staff can exist; ON2/ON3.
5. R4-11 Managed Move-In move; R5a People move; R-CRM; then R4-3..R4-10 mail features; R3p plans; R3b-g SLA; R5b Systems.
After each MOVE: his haan to remove the founder screen, then one founder-install, then my Chrome look on both sites.
Mailbox count and rules are in docs/claude/admin-desk/BLUEPRINT-ADMIN-DESK.md and sql/AD1.sql (fadm_mailbox checks).
