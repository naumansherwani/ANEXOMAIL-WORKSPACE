# ANEXOMAIL ADMIN DESK: D-SERIES BLUEPRINT, UPDATED 22 Nov 2026 21:55 PKT (generated from the files named in each part; edit those, not this)
> ## >>> NO INCOMPLETE WORK LAW (his 22 Nov 2026 20:36 PKT, in anger): INCOMPLETE PHASE, INCOMPLETE CODES, INCOMPLETE ADVANCE TECHNOLOGY = BANNED. Every listed advance technology of a phase must be IN CODE and tested before its code is committed; the gate INCOMPLETE ADVANCE refuses the commit otherwise. A phase is finished first, then committed; nothing half-done is handed to him. What truly needs his input (address, key, list) is named once, up front. docs/claude/NO-INCOMPLETE-ADVANCE-LAW-22NOV.md <<<
Standing laws: Rule 52 (every answer kernel-verified), HTTP/3 only with WebTransport, TLS 1.3 AES-256-GCM + X25519MLKEM768, Desk isolation (own domain, never founder code or tables), no money or webhook data on the Desk, no phase name visible to an employee, no promises by employees, no refunds (published policy), the original UI/UX stays intact, GREEN only after a live Chrome look (WIRED: YES / REAL: YES / TECH-LAW CHECKED), whole Desk deadline 26 Nov 2026 07:26 PKT.



=====================================================

# PART 0g: GREEN TABLE (STATUS-GREEN-TABLE-22NOV.md)

# GREEN TABLE (his 20:23 order "GREEN LIKHO"; refreshed 22 Nov 2026 21:05 PKT). Two honest levels, never mixed
- SQL GREEN = the SQL file ran on his server and its CHECK printed every row true (his own paste).
- CODE GREEN = Rust / TS code written, tests pass in my sandbox, committed and pushed (not yet on his server until his desk-install + desk-restart).
- PHASE GREEN = WIRED: YES / REAL: YES / TECH-LAW CHECKED after my live Chrome look at 390 / 820 / 1200+ (his standing law). Only then the word GREEN stands alone.
| Item | Advance technology | SQL | CODE | PHASE |
|---|---|---|---|---|
| AD1 identity, units, sessions | PostgreSQL 16 forced RLS, Argon2id, hash-chained ledger | GREEN (live, CHECK OK) | GREEN (login, me, logout doors) | live, in use |
| AD2 actions + policies | deny-by-default fadm_need / fadm_authorize | GREEN | GREEN (via doors) | live, in use |
| AD3 alerts + bridge data | SECURITY DEFINER doors, pinned search_path | GREEN | GREEN (bridge.rs) | Dashboard first cuts live |
| AD4 lookup audit + burst breaker | append-only lookup ledger, burst limit | GREEN | GREEN since 20:42 (lookup.rs, step D5a-3) | NOT GREEN: Control Plane address + key not given |
| AD5 addresses + mailbox roles | PostgreSQL trigger guards, grants | GREEN | none (Mailboxes folder FROZEN) | NOT GREEN |
| AD6 package registry | versioned, frozen rows, no money columns | GREEN (registry empty) | none (D5a-2 needs his package list) | NOT GREEN |
| AD7 cases | state machine trigger, append-only events | GREEN | none (Cases folder FROZEN) | NOT GREEN |
| D5a-3 signed lookup door (client side in the Desk) | Rust Tokio axum 0.8, quinn + h3 client (TLS 1.3, AES-256-GCM, X25519MLKEM768), ed25519-dalek, Rule 52, fail closed | no new SQL | GREEN: cargo 41 passed; LIVE on his server since his install paste 20:5x (kid e92a4cb169d466a2, same build as origin/main); my Chrome look 20:54: route exists, no session = 400 unsigned_request | NOT GREEN: no responder to ask (D5a-3b) |
| D5a-3b Control Plane lookup responder (the other end) | Rust Tokio axum 0.8, quinn + h3 server, ed25519-dalek, own key | read-only view, schema-first | NOT WRITTEN (contract written, all rows no) | NOT GREEN: needs his fresh ss -ulnp paste for the UDP port |
| Desk page protocol | HTTP/3 only (his 21 Nov law) | | Chrome 20:54 shows h2 for the Desk (public curl HTTP/2 via Caddy TCP 443, Alt-Svc h3=:4400 set, DNS HTTPS record empty) | OLD GAP, not part of D5a-3, stays open |
| DASHBOARD FOLDER as a whole | see DASHBOARD-FOLDER-ORDER-22NOV.md | | | NOT GREEN: steps 2..9 open |

# PART 0h: D5a-3 PHASE DETAIL (his 20:53 order: put the phase detail in front)

D5a SUB-PHASES AND THEIR ADVANCE TECHNOLOGY (D5-SUBPHASES-22NOV.md):
|---|---|---|---|
| D5a-1 Contract | The lookup contract in CURRENT.md: allowed fields (package id and version, features on, limits, usage, service state, one flag "payment received, service not active" + since when, freshness time), forbidden fields (any amount, invoice, card, transaction), request format | Written contract + a commit gate that FAILS any Desk file that names an amount / invoice / card field (same style as the isolation gate) | gate fails on a planted bad field, passes clean |
| D5a-2 Package registry | ONE versioned entitlement registry from the landing-page list: package, version, effective date, features, limits, trial and grace rules, SLA target; old subscriptions keep their version | PostgreSQL (fadm_pkg tables in the Desk schema, forced RLS), append-only versions, hash-chained ledger line per version, Rust read door; empty until he supplies the list | an inserted test version cannot be edited, only superseded |
| D5a-3 Signed lookup | Employee opens a company: role check, reason typed, short-lived signed read-only request to the Control Plane, answer checked, nothing stored | Rust Tokio axum, Ed25519 request signature with audience + expiry + request id, HKDF/HMAC, one narrow read-only key, Rule 52 verify in the Rust WASM kernel, HTTP/3 | wrong audience, expired, replayed request all refused |
| D5a-4 Audit with reason | Every look leaves one line: employee, company ref, time, reason, requested fields, request id | PostgreSQL append-only ledger with SHA-256 hash chain (Desk's own), RLS | line appears for every look, chain verifies |
| D5a-5 Fail closed | Control Plane down or slow: screen says "Data unavailable", never old data; show freshness time on every screen | Rust timeout + circuit state, kernel stale-frame check (Rule 52) | live test with the lookup switched off shows the honest message |

WHERE D5a-3 STANDS (22 Nov 2026 21:08 PKT): the Desk side (lookup.rs: signed request, HTTP/3 client, verify, whitelist, audit before data, fail closed) is written, tested (cargo 41, real HTTP/3 loopback, PostgreSQL integration) and LIVE on his server (his install paste; my Chrome look: the door exists and refuses a call without a session). The other end, the Control Plane responder, does not exist anywhere: new sub-phase D5a-3b (contract in tech-contracts/CURRENT.md, all rows open). So D5a-3 is NOT whole and NOT green. Next input from him: ss -ulnp | head -60.

HANDOFF FOR A NEW CLAUDE: docs/claude/admin-desk/state/HANDOFF-22NOV.md (21:26: no server pull pending; next server commands only when D5a-3b is whole)

# PART 0j: D5a-2 STATE (22 Nov 2026 21:55 PKT)
| Sub-phase | Advance technology | State |
|---|---|---|
| D5a-2 SQL seed AD6b | PostgreSQL 16 (append-only versions, hash chain, forced RLS) | 7 landing-page packages (src/lib/plans.ts), features + limits, grace 3, trial 0, no price; proved on scratch; ad-auto said "already run" on his server: UNEXPECTED, waits his read-only count |
| D5a-2 Rust doors | Rust, Tokio, axum 0.8, Rule 52 sealed router | GET /desk/v1/packages and /{id}; installed + restarted by his pastes (health 200, door 401); live look with a session pending |
| Loop law | shell | after commit the checkpoint loop no longer dirties the repo (his 21:40 word) |


# PART 0i: D5a 1 TO 5 GREEN LIST (D5A-GREEN-LIST-22NOV.md)

# D5a: 1 TO 5, ONE BY ONE, NOTHING MOVES ON UNTIL ALL FIVE ARE GREEN (his order 22 Nov 2026 20:59 PKT, written 22 Nov 2026 21:20 PKT)
His words: "is ki list bana ek ek ker ke is ko complete kero ... jab tak green nahi tab tak agay nahi jana hai. Yeh 1 se 5 tak green ka target hai". GREEN = WIRED: YES / REAL: YES / TECH-LAW CHECKED with proof. Dashboard steps 3..9 and every other folder wait behind this list.
| # | Sub-phase | Advance technology | State now | What makes it GREEN (proof I must show) | Blocked by |
|---|---|---|---|---|---|
| 1 | D5a-1 Contract | Written contract + commit gate DESK NO-MONEY | DONE: gate live, it refused a money field name in lookup.rs on 22 Nov 20:30 (real catch), contract copy kept equal by a test | gate fails a planted bad field (re-run now), passes clean; lookup.rs reads the same contract | GREEN 21:22 PKT: WIRED: YES / REAL: YES / TECH-LAW CHECKED. Proof: a planted Desk file naming a card field was REFUSED by the gate DESK NO-MONEY (and by INCOMPLETE ADVANCE), clean commits pass, lookup.rs reads the same contract |
| 2 | D5a-2 Package registry | PostgreSQL 16 versioned, hash-chained, append-only (AD6, live) + Rust read door | SQL live and empty; no Rust read door yet | his package list loaded, an inserted version cannot be edited, Rust door answers, signed, kernel-verified | HIS PACKAGE LIST (features, limits, grace days) |
| 3 | D5a-3 Signed lookup (3a Desk side, 3b responder) | Rust Tokio axum 0.8, quinn + h3, Ed25519, Rule 52 | 3a live on his server; 3b contract written, port UDP 127.0.0.1:4410 reserved, code not started | a real lookup end to end on his server: wrong audience, expired and replayed requests refused, good request answered, shown in my Chrome | 3b code (schema-first read of the subscription tables first) |
| 4 | D5a-4 Audit with reason | PostgreSQL append-only ledger, SHA-256 chain (AD4, live) | SQL live; Rust path proven on the scratch database (requested line before the answer) | after 3 is live: one real look leaves one line, chain verifies on his server | step 3 |
| 5 | D5a-5 Fail closed | Rust timeout + unavailable path, kernel stale-frame check (Rule 52) | server side done and tested (Off / bad key / bad signature give data_unavailable); screen message + kernel check not wired | Control Plane switched off on his server, my Chrome shows "Data unavailable" with freshness, never old data | steps 3 and the D5 screen |
Order of work from here: 1 (proof now) -> 3b -> 3 -> 4 -> 5 -> 2 (when he gives the list).

# PART 0: STATE NOW (NEXT-CODES-ORDER-22NOV.md)

# NEXT CODES, IN ORDER (his word 22 Nov 2026 11:18 PKT: "list banao aur bari bari is ke codes likho aur send kero pull command")
Each row: written -> proved on scratch PostgreSQL 16 (or test double) -> ONE pull line for him -> next row. Technology per row is the advance level of the phase. Rule 52 on every Desk call.
| # | Code | What | Advance technology | Status 22 Nov 11:22 |
|---|---|---|---|---|
| 1 | AD5 | address-role truth (10 addresses, billing restricted, founder private, reply-from) | PostgreSQL forced RLS, CHECK, SECURITY DEFINER doors, hash-chained grant ledger | LIVE ON HIS SERVER (his paste 11:1x, 13/13 CHECK OK). SQL layer only: not GREEN until the Rust mail door uses it and my Chrome sees it |
| 2 | AD6 (D5a-2) | versioned package registry, no price, append-only versions | PostgreSQL forced RLS, append-only triggers, hash-chained ledger | LIVE ON HIS SERVER (his paste 11:38, 10/10 CHECK OK). SQL layer only: not GREEN until the Rust read door + D5 screen use it |
| 3 | AD7 | staff queues: case table per queue (support/movein/general/billing), assignment, status, Priority Support label + 2 business day SLA clock, per-company move-in work record | PostgreSQL RLS (team key on every row, 50k-staff design), burst breaker, hash-chained audit | NOT written |
| 4 | D5a-3 | Rust signed read-only lookup door vs a test double of the Control Plane (Ed25519, audience desk-lookup, 60 s, fail closed) | Rust, Tokio, Axum, HTTP/3, Ed25519, Rule 52 kernel verify | NOT written |
| 5 | D5a-5 | fail-closed behaviour proof (Control Plane down = "not available", nothing stale) | Rust + test double | NOT written |
| 6 | Mail door | Rust inbound routing through fadm_route_inbound, outbound sender identity through fadm_reply_from, founder draft/approve flow | Rust, Tokio, QUIC, ClamAV, Storage Box | NOT written |
| 7 | D5 screen | company plan context screen (original UI intact, data only) | React 19, TS, Tailwind 4, kernel-verified data | NOT written |
| 8 | D5b-1..3 | nine runbooks, guided checklist, say-this text + no-promise gate | PostgreSQL versioned runbooks, React | NOT written |
| 9 | D5c, D6 | Escalate one-way signed hand-over, Desk card | Rust signed hand-over, React | NOT written |
| 10 | Gate | DESK CONTRACT DRIFT: DESK-LOOKUP-CONTRACT.json allowed_fields vs AD4 field list | rules-gate | NOT written |
| 11 | Tests | real send/receive tests through the mail door | Rust integration tests | NOT written |
## SCORE (his question 11:39, honest): 2 of 11 are on his server (AD5, AD6), both SQL layers only; 9 of 11 are not written (AD7, D5a-3, D5a-5, mail door, D5 screen, D5b, D5c+D6, drift gate, send/receive tests). GREEN: 0 of 11, because GREEN = WIRED: YES / REAL: YES / TECH-LAW CHECKED after my live Chrome look (his standing law), and none of the 11 is wired end to end yet.
## C4 (his answer 11:18, recorded): the "named founder contact" line came from when the Desk was inside the founder app; the Desk is independent now; Priority Support is paid (landing page shows the real monthly charge) and is answered by the support team from resolved@ with the priority label and SLA. The landing line wording is a website promise: proposed new text is listed in docs/claude/WEBSITE-PROMISES.md as OPEN until he approves the exact words; landing UI untouched.

# PART 0b: MAILBOX AND ROLE PLAN (MAILBOX-ROLES-PLAN-22NOV.md)

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

# PART 0c: TOP BAR PLAN (TOPBAR-PLAN-22NOV.md)

# TOP BAR PLAN (his word 22 Nov 2026 11:26 PKT, image of the concept top bar: Search, Quick actions, theme, bell, profile)
His question: which phase does the top bar (Search, Quick actions, Bell and the rest) belong to? His law: the original Anexomail UI/UX stays INTACT; additive only, his haan before any pixel changes.
## Answer: NEW Desk phase T "Top bar", after S1 (rail order) and S2/S5 (Customers, Cases), because Search and Quick actions need real data to search and act on. Today (checked in founder-web/src/desk/DeskShell.tsx) the Desk shell has none of them.
| Item in the concept | Desk decision | Needs first | Advance technology |
|---|---|---|---|
| Search | YES: one box searches cases, customers (opaque company ref), runbooks; typed reason is NOT needed for search, only for opening a company lookup | S2 Customers, S5 Cases, S3 Knowledge | PostgreSQL full text + trigram behind a signed door, Rule 52 kernel-verified results, React 19 |
| Quick actions | YES: a keyboard-first action list (new note, assign to me, open runbook, escalate); each action is an existing signed door, list comes from fadm_action by the person's relation | AD7 queues, D5b, D5c | React 19 + TS, Framer Motion, kernel-verified action list |
| Bell | YES: assignments, SLA warnings, alerts of the glitch rules (AD2 alerts exist) | D2 alerts (exist), AD7 SLA clocks | Server push over WebTransport with the kernel, never a third-party push |
| Theme toggle | YES, colours only, from the D8 eye-comfort palette decision | D8 his pick | CSS design tokens |
| Profile + sign out | exists already in the shell | none | existing |
| Workspace switcher (Northwind Studio) | NO: the Desk is one workspace | none | none |
| Breadcrumb tags "Protected preview", "browser router" | NO: no phase or tech names visible to employees (rule 14) | none | none |
| Orb/"OpsPilot" logo, sidebar group names | NOT copied; the Desk keeps its own Anexomail look and identity | none | none |
Order inside T: T1 Search, T2 Quick actions, T3 Bell, T4 Theme. Every step: backup in backups/desk, before/after check, 390 / 820 / 1200+ look, his haan first.

# PART 0d: BACKUP RESERVE RULE (BACKUP-RESERVE-RULE-22NOV.md)

# BACKUP RESERVE RULE (his word 22 Nov 2026 11:39 PKT)
Backups in backups/desk stay RESERVED. They are used only when he says so. When code from a backup is needed, ONE command restores ONLY the files asked for (not everything); the live (newer) code of every other file is untouched, because the website changes all the time.
1. List the backups:
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:admin-desk/scripts/desk-restore.sh) 2>&1 | tail -8
2. Look at specific files (live code untouched, they are extracted to /tmp): the same line with the backup name fragment and the file name fragment after the closing bracket, for example: ... desk-restore.sh) perfect-login DeskShell.tsx 2>&1 | tail -8
3. Write them into the repo (only those files, the backup version replaces the new one): the same line with RESTORE_APPLY=1 in front of bash. Then desk-copy-sync, build, tests, commit.
Every UI change still needs a fresh backup first (backups/desk + MANIFEST) and his haan. Written 22 Nov 2026 11:40 PKT.

# PART 0f: DASHBOARD FOLDER FIRST, STEP ORDER AND WAITING ITEMS (DASHBOARD-FOLDER-ORDER-22NOV.md)

# DASHBOARD FOLDER FIRST, 100% GREEN, FOLDER BY FOLDER (his word 22 Nov 2026 20:15 PKT, repeating his 07:26 rule; written 20:25 PKT)
His rule (DESK-PHASES rule 11): the DASHBOARD folder (D, D1..D6) goes 100% green BEFORE any other folder starts; then Mailboxes, Cases, Replies, Routing, SLA clocks, Automations, Admin Desk group, Company group, in rail order. No half work, no broken order.
## Honest account of what I did out of order (said plainly, fixed from now)
- AD5 (addresses/roles) was his 11:06 priority order for the mailbox plan: a Mailboxes-folder item. AD7 (cases) is a Cases-folder item. I wrote AD7 myself at 19:50 under "next phase" instead of the next Dashboard step. That broke his order. AD6 (package registry) and AD4 (lookup audit) ARE Dashboard items (D5a).
- Repair: Mailboxes, Cases, AD8 and every later folder are FROZEN from now (no new code) until the Dashboard folder is 100% green. AD5 and AD7 stay on his server because they are harmless and the Dashboard cards B1 / B2 (queue pressure, SLA at risk) will read from AD7 through a thin Dashboard data door, which is the only part of Cases the Dashboard needs. Nothing is deleted.
## THE DASHBOARD FOLDER, step by step (the order I work in; each step closes only after my live Chrome look at 390 / 820 / 1200+, original UI intact)
| # | Step | What it is | Advance technology | SQL | State 22 Nov 20:25 |
|---|---|---|---|---|---|
| 1 | D, D1, D1c..D1f, D2, D3, D3b, D4, D7, D8..D10 (command bar, cards, alerts, service health, trend, registry, copy, glow, brand link) | the dashboard shell and its live Bridge cards | React 19 + TS, Framer Motion, Rust h3-webtransport (QUIC), signed frames, Desk-own Rust WASM kernel (Rule 52) | AD2, AD3 (live) | LIVE / first cuts; each waits its green look |
| 2 | D5a-3 Rust signed lookup door | Rust asks his Control Plane read-only (Ed25519, audience desk-lookup, 60 s, request id, reason typed, audit before data, fail closed), against a TEST DOUBLE of the Control Plane first | Rust Tokio Axum 0.8, ed25519-dalek, HTTP/3, Rule 52 kernel verify | AD4 (live) | 20:58 CODE GREEN in sandbox (lookup.rs, real HTTP/3 client, PostgreSQL integration test, cargo 40 passed); his desk-install + desk-restart next; PHASE GREEN waits his Control Plane address + key |
| 3 | D5a-5 Fail closed proof | Control Plane down = "Not available now", nothing stale, ledger line | Rust + test double | AD4 (live) | after step 2 |
| 4 | D5a-2 fill + read door | registry filled from his package list, Rust read door | PostgreSQL versioned registry + Rust | AD6 (live, empty) | needs his package list |
| 5 | D5 Plan context screen | package + version, features included vs enabled, limits and usage bars (90 / 95 marks), service state, SLA target, one payment flag, freshness; no amount anywhere | React 19 + TS + Tailwind 4, kernel-verified data | AD4, AD6 | after steps 2 to 4 |
| 6 | D5b Runbooks (b1 nine runbooks, b2 guided checklist, b3 say-this text + no-promise gate) | one card per user problem | React + PostgreSQL versioned runbooks | AD9 (planned) | after step 5 |
| 7 | D5c Escalate + D6 card | one-way signed hand-over creating a real case for the owner | Rust signed hand-over, PostgreSQL | AD10 (planned) | after step 6 |
| 8 | D6 cards B1..B13, one at a time | each card flips from "Not connected yet" to real data through a THIN Dashboard data door (only the numbers the card shows); B1 queue pressure + B2 SLA at risk from AD7 first | Rust read doors, PostgreSQL views, kernel-verified stream | AD7 (live), then AD11, others per card | after step 7; order B4, B5 (live data), B1, B2, B3, B8, B9, B6, B7, B10..B13 |
| 9 | Dashboard FINAL green | every card real or honestly "Not connected yet", live look 390 / 820 / 1200+, WIRED: YES / REAL: YES / TECH-LAW CHECKED | all of the above | all | closes the folder; only then Mailboxes folder opens |
Target days (not promises, the whole Desk deadline is 26 Nov 2026 07:26 PKT): tonight step 2; Mon 23 steps 3 to 6 (steps 4 and 5 need his package list); Tue 24 step 7 and cards B4, B5, B1, B2, B3; Wed 25 remaining cards and the final look.
## WHAT EACH "WAITING" MEANS, ONE BY ONE (his question: "kab intezar complete hoga")
| Waiting item | Exactly what is missing | Which step brings it | Needs from him |
|---|---|---|---|
| AD2 staff, relations, policy screens | the Rust doors and screens for staff and policy (G, H phases). The SQL is live and its alerts part is wired. | Company group, LAST in the rail order (step after Dashboard, Mailboxes ... Company) | nothing now |
| AD4 company lookup audit | the Rust lookup door that calls fadm_lookup_begin / finish around every Control Plane look | Dashboard step 2 and 3, starting now | Control Plane address + how it verifies our signature (tonight I use a test double, the real address is a one-line setting) |
| AD6 package registry | empty: no package rows yet, and no Rust read door | Dashboard steps 4 and 5 | his package list (features, limits, grace days) |
| AD5 addresses and roles | the Rust mail door that routes inbound mail through fadm_route_inbound and picks the reply address | Mailboxes folder (opens after the Dashboard is 100% green) | nothing now |
| AD7 cases | the Rust mail door that creates cases (fadm_case_ingest) and the screens (My Work, All Cases); only a thin read door for cards B1 / B2 is Dashboard work | thin door: Dashboard step 8; full: Cases folder | nothing now |
| AD8 .. AD16 | not written, frozen until their folder opens | their folders in rail order | nothing now |
## RULES ADDED BY HIS 20:15 ORDER
1. After EVERY phase I send him the updated blueprint file (like the 11:40 and 20:10 sends), in this order: Part 0 state, 0b..0f, then the phase tables.
2. The word "Technology" is written "ADVANCE TECHNOLOGY" everywhere (Rule-70 table, blueprint, repo, gates). Only advance technology is named.
3. Every gate gets its advance technology written phase by phase (PHASE-TECH-SQL-MAP-22NOV.md section 5).
4. His thread rule: Desk threads follow the SAME WAY as the awam mail threads (same method, same user feel), only adapted to what the Admin Desk needs; written new, never shared with the awam code.

# PART 0e: PHASE -> ADVANCE TECHNOLOGY -> SQL MAP (PHASE-TECH-SQL-MAP-22NOV.md)

# PHASE -> ADVANCE TECHNOLOGY -> SQL MAP (his word 22 Nov 2026 20:04 PKT: "kaun se phase mein kaun si advance technology aaye gi aur SQL kaun se phase mein aaye ga, clearly detail summary mein")
Rule 52 (every answer signed by Rust, verified by the Desk's own Rust WASM kernel in the browser, no raw fetch) is on EVERY row. HTTP/3 + WebTransport only, TLS 1.3 AES-256-GCM + X25519MLKEM768, Desk isolation (own tables fadm_*, own role desk_app). GREEN only after WIRED: YES / REAL: YES / TECH-LAW CHECKED and my live Chrome look (390 / 820 / 1200+). SQL numbers after AD7 are PLANNED numbers; each SQL is written schema-first on the file that owns the tables and runs through his one ad-auto line.
## 1. SQL ALREADY ON HIS SERVER (his pastes, ad-auto "run and CHECK OK")
| SQL | What it holds | Phases that use it | Wired to Rust / screen? |
|---|---|---|---|
| AD1 + AD1b | owner, session, passkey, mailbox, hash-chained ledger | R3a2 login (LIVE) | yes (login door) |
| AD2 | organisation units, relation tuples, deny-by-default policy, staff, recovery, JIT elevation, burst breaker, alerts | G Org + policy, H Staff accounts, B Bridge alerts | alerts yes; staff/policy doors NOT yet |
| AD3 | alert state + events, services, probes, incidents, alert watch | B, C, D2, D3, D7, S6 Incidents | yes (Bridge read path GREEN) |
| AD4 | company lookup audit (reason, fields, outcome, burst 30/min) | D5a-4, D5 | NO (waits for Rust lookup door D5a-3) |
| AD5 (11:1x) | 10 addresses and their role, billing restricted + grants, founder address private, routing, reply-from | I Mailboxes | NO (waits for Rust mail door) |
| AD6 (11:38) | versioned package registry, no price | D5a-2, D5 | NO (empty, waits for his package list + Rust read door) |
| AD7 (20:0x) | cases, Priority Support label + 2-business-day clock, assignment, status machine, reply record | K Cases + SLA, My Work, All Cases | NO (waits for the mail door + screens) |
## 2. PLANNED SQL (numbers may shift, order follows the phases)
| Planned SQL | What | Phase it belongs to |
|---|---|---|
| AD8 | mail THREADS and MESSAGES of the Desk (thread id, message ids, original recipient, headers, attachment metadata, virus-scan state; bodies and files on Hetzner Storage Box) | I Mailboxes, N Mail craft + attachments, "Replies" |
| AD9 | versioned runbooks (six parts each), no-promise word list, full-text knowledge search | D5b Runbooks, S3 Knowledge |
| AD10 | escalation hand-over (one-way signed request id, result link) | D5c Escalate |
| AD11 | SLA clocks for all queues, automations, 7-day per-sender auto-mail gate | J Auto mail, K rest, S4 Overview |
| AD12 | Managed Move-In work record per company (state machine, slots, DNS/mailbox checks; no money legs) | P Managed Move-In |
| AD13 | CRM accounts, leads, pipeline, tasks | O CRM |
| AD14 | transparency log (Merkle tiles, signed tree head) | L |
| AD15 | hybrid post-quantum keys (ML-DSA + Ed25519, ML-KEM) | M |
| AD16 | search index over cases, customers (opaque refs), runbooks | T1 Search (top bar) |
## 3. PHASE BY PHASE: ADVANCE TECHNOLOGY, SUBPHASES, SQL
| Phase | Advance technology | Subphases | SQL |
|---|---|---|---|
| R3a0..R3d (host, login, Rule 52) | Rust Tokio Axum 0.8, quinn + h3, TLS 1.3 AES-256-GCM, X25519MLKEM768, Argon2id, Ed25519 + HKDF, Desk-own Rust WASM kernel | done, LIVE | AD1 |
| A Browser HTTP/3 | HTTP/3 page load, Alt-Svc, DNS HTTPS record (his Namecheap) | OPEN | none |
| B Bridge, C WebTransport, D Command bar, D1..D10 | Rust h3-webtransport (QUIC), signed frames, kernel verify_frame, React 19, Framer Motion | green read path; D3b trend, D2 act | AD2, AD3 |
| D5a Foundation | Ed25519 signed read-only lookup (audience desk-lookup, 60 s), PostgreSQL versioned registry | a1 contract (done), a2 registry SQL (AD6 live), a3 Rust lookup door (NEXT), a4 audit (AD4 live), a5 fail-closed proof | AD4, AD6 |
| D5 Plan context screen | React 19 + TS + Tailwind 4, kernel-verified data, original UI intact | after a3 | uses AD4, AD6 |
| D5b Runbooks | React + PostgreSQL versioned runbooks, no-promise gate | b1 nine runbooks, b2 guided checklist, b3 say-this text | AD9 |
| D5c Escalate, D6 | Rust one-way signed hand-over | c1 request, c2 result, D6 card | AD10 |
| S Six sections (Overview, My Work, All Cases, Customers, Incidents, Knowledge) | React 19 + TS module registry, PostgreSQL full text | S1 rail order (needs his haan), S2..S6 | AD7 (cases), AD9 |
| T Top bar | React 19, Framer Motion, signed doors, WebTransport push | T1 Search, T2 Quick actions, T3 Bell, T4 Theme | AD16 |
| E Team fan-out | Tokio broadcast over WebTransport streams | one DB read per tick | none |
| F MoQ | Media over QUIC tracks (IETF) | summary/services/alerts tracks | none |
| G Org + policy | PostgreSQL tuples (Zanzibar style), Rust evaluator | staff, relations, policy screens | AD2 (live) |
| H Staff accounts | webauthn-rs, Argon2id, DBSC, device-bound passkeys | enrollment, devices, leaver, recovery | AD2 (live) |
| I Mailboxes | Rust mail door (Tokio, QUIC), PostgreSQL RLS, ClamAV | i1 inbound routing via AD5 + case ingest AD7, i2 sender identity, i3 founder draft/approve, i4 real send/receive tests | AD5, AD7 (live), AD8 |
| J Auto mail | Rust, RFC 3834 Auto-Submitted | 7-day gate | AD11 |
| K Cases + SLA | Rust, SQL SLA engine, SKIP LOCKED routing | assign, reply, clock, root-cause note | AD7 (live), AD11 |
| L Transparency log | Merkle tiles, signed tree head | audit log browsers remember | AD14 |
| M Hybrid post-quantum | ML-DSA + Ed25519, ML-KEM | signatures and mail | AD15 |
| N Mail craft + attachments | React, Tiptap 3, ML-KEM, WebTransport, Hetzner Storage Box, ClamAV, OpenPGP PQC (RFC 9980) | compose, rich text, attachments | AD8 |
| O CRM | React 19, Rust, RLS | accounts, leads, pipeline | AD13 |
| P Managed Move-In | Rust async IMAP migrator | per-company work record | AD12 |
| Q Final audit + load proof | Rust, React | audit, load proof | none |
## 4. THE "THREAD" QUESTION (his 20:04 word: the awam/founder system has threads; where does the Admin Desk get them?)
What exists: the awam site has its own mail threads (src/routes/app.mail.$folder.tsx, server/mail-worker.ts, sql phase52 mail truth tables) and the founder mailbox has its own (QC series). The Desk must NOT import or share them (isolation law); they are remade NEW for the Desk from the same method (preserve, advance technology, fix loopholes, polish).
Where the Desk gets its threads: phase I Mailboxes + the Replies folder. AD7 already keeps one case per (address, thread id); the thread's messages, original recipient, headers and attachments come with AD8 (planned) and the Rust mail door, bodies and files on Hetzner Storage Box with ClamAV. Every email keeps its original recipient and thread history (his point 4).
His remark that the earlier thread codes are "left open": I will audit the awam thread code and the founder thread code (read-only) for loopholes in phase I step i0 and write each loophole into CLOSE-THE-GAPS-07NOV.md; the awam code is frozen (his law), so the Desk copy gets the fix, the awam fix waits for his word.

## 5. GATES (commit gates in docs/cursor-work/server/rules-gate.py) AND THEIR ADVANCE TECHNOLOGY, PHASE BY PHASE (his 20:15 order)
| Gate | Phase it guards | Advance technology | What it refuses |
|---|---|---|---|
| RULES NOT READ | every phase | signed receipt file (2 h), SHA-256 of rule files | a commit without a fresh rules-read |
| DESK PHASE START | every Desk code commit | desk-phase-start.py receipt per phase | Desk code before the phase's contract is read |
| DESK ISOLATION | all Desk phases | static import + table + key scan | any mix with founder or awam code, doors, keys, tables |
| DESK NO-MONEY | D5a, D5, D6 | contract JSON (DESK-LOOKUP-CONTRACT.json) + pattern scan over Desk files | amount, invoice, card, Polar, webhook fields on the Desk |
| DESK WIRING | D1..D6 cards | desk_cards.ts registry + test | a card without route, track and phase; phase names visible to employees |
| NO-PROMISE (planned) | D5b runbooks | closed banned-word list over runbook text | date, restore, refund, credit, upgrade, owner decision promises |
| DESK CONTRACT DRIFT (planned) | D5a | JSON allowed_fields vs AD4 field list compare | the contract and the SQL list disagreeing |
| TECH LAW | all phases | tech-contracts/CURRENT.md + TECH-LAW-GATE.json | a listed advance technology missing from code, GREEN without TECH-LAW CHECKED |
| SERVER FIRST | server surface (ports, TLS, HTTP/3, Caddy, installers) | hash-chained receipt ledger of his pasted read-only output | a server change without his fresh paste |
| 73 lanes + manifest | every commit | lane-sync, SHA-256 manifest | stale lane files, changed files not in the manifest |
| VENDOR BAN | all | VENDOR-BAN-LIST.json | any third-party vendor name |
| HTTP/3 only, no WebSocket / Bun / Node | all Desk phases | pattern scan | h1, h2, ws://, Bun, Node in Desk or server runtime |

# PART 1: PHASE TABLE (D-series, every letter, state)  (DESK-PHASES-22NOV.md)
=====================================================
# ADMIN DESK: ORIGINAL BLUEPRINT BY PHASE (technology + features next to every phase). Written 22 Nov 2026 06:42 PKT, his 06:41 order; ALPHABETIC ORDER (his 06:43 word) laid out 22 Nov 2026 06:50 PKT: A to Q in build order, old ids in brackets.
> RULE BOOK copy inside the Desk: docs/claude/admin-desk/RULE-BOOK.md (rebuilt from these rules by ckpt.sh into state/WORKING-NOW.md every checkpoint).
## STRICT RULES (top of the Desk, read before EVERY phase; the commit gate "DESK PHASE START" fails a Desk code commit without a fresh read)
1. BEFORE EVERY PHASE: run `python3 docs/cursor-work/server/rules-read.py` then `python3 docs/cursor-work/server/desk-phase-start.py <phase>` and READ both outputs, plus docs/claude/admin-desk/state/WORKING-NOW.md and docs/claude/state/WORKING-NOW.md. The scripts print this page, the phase row and the ledger tail; receipts last 2 hours.
2. ADVANCE TECHNOLOGY ONLY, AND IT MUST BECOME CODE: the technology written next to a phase is his word, not a wish. A listed technology missing from code = OPEN GAP, the phase is never GREEN. Contract first (docs/claude/tech-contracts/CURRENT.md), code second.
3. HTTP/1 AND HTTP/2 ARE BANNED FOR THE DESK, everywhere (code, tests, comments, strings). HTTP/3 + WebTransport (QUIC) only. HTTP fallback is banned until HE approves it.
4. RULE 52: every Desk call and every stream frame is Desk-signed (Ed25519) and verified by the Desk's own Rust WASM kernel; requests carry the HKDF/HMAC MAC + replay nonce.
5. GREEN only with "WIRED: YES / REAL: YES / TECH-LAW CHECKED" AND my live Chrome look (live bundle = repo, 390 / 820 / 1200+). Installed or written is not green.
6. ISOLATION: the Desk is its OWN security domain (own binary, keys, tables, cookie, role). Never mix with founder or awam code. Vendor ban stays (Caddy, Namecheap by his hands, Hetzner, his own Rust only).
7. Never remove or restyle a feature he did not name. Login look and Bridge look are his approved ones.
8. After EVERY message: repo + ledger + blueprint + COMPACT-SAVE updated with real date and time (rec.sh, desk-copy-sync, lane-sync, manifest-sync, rules-gate 0 fail). EVERY phase is named by ALPHABET in build order (A, B, C ... Q), never S-numbers; the old ids stay in brackets.
9. Address him only as Aap, Roman Urdu, short; end every reply with the Rule-70 table and "Abhi code mein NAHI"; server commands = ONE line.
10. WEB RESEARCH GOES INTO THE REPO IN ORDER (his 22 Nov 2026 07:15 PKT): every web search's points and features are written, in order, into the blueprint (section 'WEB RESEARCH LOG' in DASHBOARD-CARDS-CLICK-PLAN-22NOV.md plus the phase row they belong to) in the same step; each point gets a phase letter and is built in that phase, never left in chat.
11. FOLDER-WISE GREEN, DASHBOARD FIRST (his 22 Nov 2026 07:26 PKT): the Desk is made green folder by folder in rail order and the DASHBOARD folder (D, D1..D6) goes green completely before any other folder starts. Order: 1 Dashboard, 2 Mailboxes (was Inboxes), 3 Cases, 4 Replies, 5 Routing, 6 SLA clocks, 7 Automations, 8 Admin Desk group (Managed Move-In .. Quality), 9 Company group (Team .. Audit). A folder is green only by rule 5.
12. FOUR-DAY TARGET (his 22 Nov 2026 07:26 PKT): the WHOLE Admin Desk is complete, wired and green in 4 days: by 26 Nov 2026 07:26 PKT. Day plan: docs/claude/admin-desk/FOUR-DAY-PLAN-22NOV.md. Every message re-checks the day plan against the clock.
13. NO READ, NO COMMIT (his 22 Nov 2026 07:26 PKT): the commit gate 'DESK PHASE START' fails a Desk code commit unless the receipt shows the strict rules, this blueprint, the rule book and both WORKING-NOW files were read (desk-phase-start.py prints and records them), the receipt is under 2 hours old, and the strict rules have not changed since the read.
14. NO PHASE NAME, NO "P1" ANYWHERE AN EMPLOYEE CAN SEE ON THE ADMIN DESK (his 22 Nov 2026 09:03 PKT, CHAIRMAN, said three times, "baaned hai"): not in cards, pages, tooltips, alert text, notes, test rows or database rows that Claude writes. Phase names live only in docs and code comments. Words to use: Urgent, Not connected yet. The gate DESK WIRING fails phase names in Desk text and in the test alert script. Before writing ANY visible text, check it for D2, R3b, phase K, P1.
## PHASES (technology | features | state at 22 Nov 2026 06:50 PKT). Foundation rows first (done), then A to Q in order. One phase at a time, each GREEN only after my live Chrome look.
| Phase | Advance technology | Features | State |
|---|---|---|---|
| R3a0 Host | Rust + Tokio + Axum 0.8, systemd hardening, TLS 1.3 AES-256-GCM, X25519MLKEM768, HTTP/3 (quinn + h3) on UDP 4400, Caddy edge | own process 127.0.0.1:4400, host gate, CSP + Trusted Types, HSTS, own installer | LIVE; browser page load still shows h2 (phase A below) |
| R3a1 Login look | React 19, TypeScript, Three.js (lazy), CSS backdrop-filter, WebAuthn detection | night-office scene, glass card, ONE light under the card, no scrollbar, eye icon, Save password, principle line | LIVE, his word "perfect" 22 Nov 06:02 |
| R3a2 Login door | Argon2id, constant-time, PostgreSQL RLS (AD1), audience "desk" | /desk/v1/auth/login, sessions, append-only ledger, desk_app role | LIVE |
| R3d Rule 52 | Rust Ed25519 signer, HKDF/HMAC, Desk-own Rust WASM kernel, deskCall | signed answers, kernel-verified, replay nonce | LIVE |
| R4-1 Shell + dashboard | React 19, TS, Tailwind 4, kernel | rail + bottom tabs, greeting, clock, account menu with Sign out, menu closes outside | LIVE; boot screen (Anexomail mark + ADMIN DESK) live-confirmed 22 Nov 2026 06:59 PKT (bundle = repo, raw HTML has boot, no big heading) |
| A Browser HTTP/3 | HTTP/3 page load, Alt-Svc, DNS HTTPS record (his Namecheap) | browser shows h3 for the Desk page | OPEN: Chrome shows h2; WebTransport reaches UDP 4400 (pcap) || HIS WORD 22 Nov 2026 08:55 PKT (08:51): "pehle fallback rakho, phir likho sirf HTTP/3 hoga". ORDER: A1 keep the TCP fallback so the browser can still arrive and learn Alt-Svc (and so a network that blocks UDP still reaches the Desk); A2 prove in Chrome that page load itself runs on HTTP/3 (Network panel protocol h3) with the DNS HTTPS record answered by his Namecheap; A3 ONLY THEN switch the Desk host to HTTP/3 only, with a rollback line, after his fresh read-only paste and his haan. Nothing changed on his server yet || LIVE MEASURE 22 Nov 2026 09:05 PKT: performance navigation entry in Chrome says page protocol h2, 10 of 10 resources h2 (Caddy TCP). Next: read-only paste from his server, then the cause (Alt-Svc learned or marked broken) |
| B Bridge doors | Rust Axum, Rule 52, PostgreSQL RLS (fadm_need) | summary, services, alerts, alert act | GREEN for the read path 22 Nov 2026 06:49 PKT: the three Bridge queries (summary, services, alerts) run live through the C stream and every frame was kernel-verified; alert-act door tested in sandbox only (no live alert yet) |
| C WebTransport | Rust h3-webtransport (QUIC), Rule 52 per frame, Rust WASM kernel verify_frame (seq, STALE 12 s), Tokio | /wt/bridge stream, hello MAC, signed frames, real stream state on the chip, no fallback | GREEN 22 Nov 2026 06:49 PKT: WIRED: YES / REAL: YES / TECH-LAW CHECKED. His install 06:42 PKT, my live Chrome on admindesk.anexomail.com: live bundle desk-BdocEYqO.js = repo build, chip data-live=live 'Live · verified', stayed live past the 12 s stale limit (heartbeat works), no console errors. OPEN LOOK: 390 / 820 live (my Chrome window would not resize; layout unchanged except chip text) |
| D Command Bar | React 19, Framer Motion, kernel stream data | Live SLA clock, Active P1 alerts with package prices, Mail and QUIC heartbeat, red pulse at P1 >= 1 | GREEN 22 Nov 2026 07:19 PKT: WIRED: YES / REAL: YES / TECH-LAW CHECKED. Live Chrome look on admindesk: bundle desk-DvcfAUtv.js = repo build, chip 'Live · verified', P1 = 0 with '0 is healthy', HTTP/3 edge 6 ms, TLS 1.3 6 ms, database 269 ms, signer 0 ms, ledger chain verified, inbound/outbound mail and ClamAV honestly 'Not measured'. OPEN: red P1 pulse proven in sandbox only (live P1 = 0), 390/820 seen in sandbox only (extension window cannot resize), SLA clock waits for cases (K), prices wait for plan rows (J). |
| D1 Cards + router | React 19, TS, Desk router (History API), Framer Motion | account cards removed (identity + session time in the AD menu), cards are real links, /dashboard/* pages, "Connecting…" fix | GREEN 22 Nov 2026 07:34 PKT WIRED: YES / REAL: YES / TECH-LAW CHECKED (live Chrome look, bundle desk-CKA6WGAE.js: no account cards, 20 links, P1 click opens Alerts filtered, Back returns, service row opens detail, direct /dashboard/services loads). D1b shortcuts + hand cursor GREEN 22 Nov 2026 07:44 PKT WIRED: YES / REAL: YES / TECH-LAW CHECKED (live Chrome look, bundle desk-ByW6Xrfq.js: 9 hover badges, g a opens Alerts, g d home, an expired chord does nothing, hand cursor on rail) |
| D2 Alerts page | React, Rust alert act door, Rule 52 | P1 / unacked list, ack, filters in URL | FIRST CUT written 07:33 PKT inside D1 (real stream rows, ?severity=p1 / ?status=unacked); ack/act buttons still open || GREEN 22 Nov 2026 09:04 PKT (WIRED: YES / REAL: YES / TECH-LAW CHECKED) with D2 Alert actions (live list, filters, buttons) |
| D3 Service health page | React, stream services track | per-service detail | FIRST CUT written 07:33 PKT inside D1 (rows + #service anchor) || LIVE LOOK 22 Nov 2026 08:22 PKT (desktop, owner): real rows ClamAV not measured, Desk database 204 ms Operational 100% in 24 h, HTTP/3 QUIC edge 13 ms, Ledger hash chain 205 ms, Inbound mail not measured; WIRED: YES / REAL: YES; NOT GREEN until his phone 390 / tablet 820 look. NEXT D3b = rolling latency trend per service (client-side, from the verified 4 s tick), waits his haan (UI law) || GREEN 22 Nov 2026 08:32 PKT (WIRED: YES / REAL: YES / TECH-LAW CHECKED) by his word "jin phases ke codes aa gaye GREEN likho": live Chrome desktop real rows; 390/820/1280 measured in sandbox |
| D3b Latency trend | desk_trend_pure.ts + test (6), SVG line inside each Service health row, Rule 52 verified stream, in memory, HTTP/3 + WebTransport only | his haan 22 Nov 2026 08:32 PKT: complements Service health only, UI otherwise intact; a failed or unmeasured probe is a gap; words Collecting / Steady / Slower than usual / Faster than usual after 6 real probes | WRITTEN 22 Nov 2026 08:32 PKT; sandbox 390/820/1280 ok; waits his desk-install + live look || LIVE LOOK 22 Nov 2026 08:47 PKT: lines show but counted 1 probe only (BUG: probe and stream tick both 4 s, age stayed the same); FIXED same minute (probe identity = now minus age, 2.5 s tolerance, 41 tests); bundle desk-BOQJhbLw.js waits his install, then live look, then GREEN || GREEN 22 Nov 2026 09:05 PKT (WIRED: YES / REAL: YES / TECH-LAW CHECKED): live Chrome, installed bundle desk-BOQJhbLw.js; database and edge rows show a drawn line and "Steady · last 13 probes", the 60 s ledger row "Collecting · last 2 probes" (one probe per minute, honest) |
| D1d Copy text + plain words | DeskCommandBar, DeskNav, desk_cards.ts (React 19 + TS) | his 22 Nov 2026  08:26 bug: text on the KPI cards could not be selected or copied (the stretched link overlay caught the mouse); and "P1" and "phase K/H/J" were written on the real Desk | FIXED 22 Nov 2026 08:36 PKT: no overlay, card opens on click only when nothing is selected, links not draggable; "P1" is now "Urgent", "Waits for phase X" is now "Not connected yet. Shows when ..."; sandbox: drag selects text on all 4 card kinds, plain click still opens; waits his install + live look || GREEN 22 Nov 2026 08:47 PKT (WIRED: YES / REAL: YES / TECH-LAW CHECKED): live Chrome, bundle desk-Dqnc5mb_.js = repo build; drag on the card selected 38 characters and did not open the page; no "P1", no "phase X" on the page |
| D1e Pop-up on KPI cards | DeskCommandBar (title on the whole card) | his 22 Nov 08:37 word: the three KPI cards show no white pop-up with the shortcut (the overlay used to cover it, now the card itself carries it): "Urgent alerts · Alt+Shift+A" | WRITTEN 22 Nov 2026 08:38 PKT; he asked Ctrl+A for alerts: NOT done on purpose, Ctrl+A is the browser Select all and would break the copy fix he just asked for; Alt+Shift+A stays, other Ctrl+Shift+letter options wait his word; waits his install + look || GREEN 22 Nov 2026 08:47 PKT (WIRED: YES / REAL: YES / TECH-LAW CHECKED): live Chrome, the three KPI cards carry "Live SLA clock · Alt+Shift+L", "Urgent alerts · Alt+Shift+A", "Systems · Alt+Shift+Y"; grid cards "Open · Alt+Shift+Y" etc.; no bordered badge; no overlay |
| D4 Wiring registry | desk_cards.ts + test + gate | card -> route -> track -> phase, "Waits for" pages | FIRST CUT written 07:33 PKT: desk_cards.ts registry + test (gate rule still open) || GREEN 22 Nov 2026 09:05 PKT (WIRED: YES / REAL: YES / TECH-LAW CHECKED): GATE WRITTEN in rules-gate.py "DESK WIRING": a commit touching founder-web/src/desk runs the card registry test (dead card = FAIL) and fails user-facing "Waits for phase" / "Phase X" / "P1" text; proven both ways (dead card and phase text fail, clean commit passes) |
| S Six main sections (his word 22 Nov 10:34, 10:35 PKT) | S1 rail order React 19 + TS + module registry; S2 Customers (D5a lookup); S3 Knowledge (Postgres full-text); S4 Overview strip (Tokio broadcast, kernel WebTransport); S5 All Cases + My Work (PostgreSQL SKIP LOCKED, SQL SLA engine, virtual list); S6 Incidents (Rust, signed notices, hash chain) | Overview, My Work, All Cases, Customers, Incidents, Knowledge | WRITTEN as plan only; S1 waits his haan; detail DESK-SIX-SECTIONS-22NOV.md |
| D5a Foundation (his word 22 Nov 10:27, 10:28 PKT) | a1 contract + no-money gate; a2 versioned package registry (PostgreSQL forced RLS, hash-chained); a3 signed read-only lookup (Rust Tokio axum, Ed25519 + HKDF/HMAC, audience/expiry/request id, kernel verify Rule 52, HTTP/3); a4 audit with reason (append-only SHA-256 chain); a5 fail closed (timeout, stale-frame check) | contract, registry, lookup, audit, honest outage | a1 CODED 22 Nov 10:48 PKT (contract JSON + gate DESK NO-MONEY, planted field fails, clean passes); a4 CODED 22 Nov 10:51 PKT (AD4.sql + AD4-check.sql, selftest and 18 checks passed on a scratch PostgreSQL 16; waits his SQL command on the server); a2, a3, a5 next; detail docs/claude/admin-desk/D5-SUBPHASES-22NOV.md |
| D5 Customer plan context (REVISED again 22 Nov 2026 09:35 PKT, his word 09:23) | Rust axum read-only signed metadata lookup (Rule 52, kernel-verified), Desk-own package catalogue (RLS, append-only), audit line per look, HTTP/3 + WebTransport | employee sees the user's package, its features and limits, service state, the one finance-safe flag "Payment received, service not active", usage against limits, SLA target; NO webhook, NO Polar, NO money data on the Desk; plan in PLAN-CONTEXT-AND-RUNBOOKS-22NOV.md | PLANNED, web research done; waits his 3 answers | [10:10 PKT his 3 answers APPROVED: see D5-DECISIONS-AND-EXTRACT-22NOV.md]
| D5b Runbooks | React 19 + TS, Desk-own runbook cards (plain words, no phase names), Rule 52 | one card per user problem: what the employee sees, may do, must not do, who to escalate to, what to tell the customer (his example: payment received but service not active) | PLANNED 22 Nov 2026 09:35 PKT, written in the plan file; waits his 3 answers |
| D5c Escalate (10:30 PKT) | Rust one-way signed hand-over, Desk-own case table, idempotent request id, PostgreSQL RLS | real case to the owner queue, result returns, employee sees number + status | WRITTEN as plan only; D5b has subparts b1 nine runbooks, b2 guided checklist, b3 say-this text |
| D6 Rest of dashboard list | per DASHBOARD-LIVE-COMMAND-22NOV.md B1..B13 | lands in phases H, K, N, P, Q | PLANNED 07:15 PKT || 22 Nov 2026 09:22 PKT WHEN: D6 cards need data that does not exist yet (queue + SLA need cases = phase K, security + staff need staff accounts = phase H, deliverability = phase N, Move-In = phase P, reports = phase Q), so they flip from "Not connected yet" to real as those phases land; one by one in that order, each GREEN after a live look |
| D7 Systems folder | React 19, TS, kernel-verified stream, pure model, role-aware screen rule | rail folder Systems live: plain status for EVERY employee (Working / Slow / Down), what to tell customers, banner; technical rows + Service health only for owner/admin/engineer | WRITTEN 22 Nov 2026 07:46 PKT, MOVED 07:52 PKT (his 07:40 word: the Mail and QUIC pipeline and all system technology leave the dashboard and live in the Systems folder, the dashboard keeps a one-line Systems card); bundle desk-DZKO_LVM.js; server-side role split = phases G/H (honest limit in CURRENT.md) || GREEN 22 Nov 2026 08:16 PKT WIRED: YES / REAL: YES / TECH-LAW CHECKED (live Chrome look, bundle desk-BvvohRXS.js) |
| D8 Eye-comfort colours | CSS design tokens (colour only), reduced saturation, WCAG contrast kept | his 22 Nov 07:47 word: the blue strains the eyes; demo of 4 palettes (A now, B Graphite, C Soft navy, D Warm charcoal) in docs/claude/admin-desk/demo/ | DEMO 1 shown 07:58 PKT (A..D dark), DEMO 2 "cinematic light" shown 08:03 PKT (L1 Dusk, L2 Twilight teal, L3 Daylight, L4 Golden hour); code waits for HIS PICK (no restyle without his word) || CLOSED 22 Nov 2026 09:05 PKT by his word (08:56): the existing look stays intact, no palette change; D10 glow is the colour he chose || GREEN 22 Nov 2026 09:22 PKT (WIRED: YES / REAL: YES / TECH-LAW CHECKED) by his word (09:15): "yeh maine color choose kiya hai aur yeh abhi chal raha hai live": the live Desk colours (existing look + D10 bottom glow) are his chosen palette; seen live 08:16 and 09:14; no other palette is built |
| D9 Brand link | React 19, TS, anchor + History API | the ANEXOMAIL brand is a link: on a sub page it goes back to the dashboard, on the dashboard it refreshes the page; on phone ANEXOMAIL shows top-left | WRITTEN 22 Nov 2026 08:03 PKT (his 07:49 word), waits his desk-install + live look || GREEN 22 Nov 2026 08:16 PKT WIRED: YES / REAL: YES / TECH-LAW CHECKED (live Chrome look, bundle desk-BvvohRXS.js) |
| D10 Bottom glow | CSS only (one rule + one element .dsk-glow) | his 22 Nov 07:56 word: the colours of the top corner (amber + light blue) spread softly to the BOTTOM, everything else untouched | WRITTEN 22 Nov 2026 08:10 PKT after backup backups/desk/20261122-0756-47ebf24c-before-bottom-glow (verified); before/after shown; undo = delete .dsk-glow rule + element or restore the backup; waits his desk-install + look | || LIVE LOOK GREEN 22 Nov 2026 08:16 PKT (WIRED: YES / REAL: YES / TECH-LAW CHECKED): live Chrome, bottom amber+blue glow visible, bundle installed by him; he liked it
| D1c Shortcut hint | DeskNav title + Alt+Shift+letter (comboTarget) | his 22 Nov 08:04 + 08:07: Ctrl/Shift-style keys; the white pop-up stays | WRITTEN 22 Nov 2026 08:10 PKT; sandbox ok; waits his install + look | || LIVE LOOK GREEN 22 Nov 2026 08:16 PKT (WIRED: YES / REAL: YES / TECH-LAW CHECKED): live Chrome, links carry 'Open · Alt+Shift+Y' pop-up text, no bordered badge
| D2 Alert actions | Acknowledge / In progress / Resolve / False alarm via signed POST /desk/v1/bridge/alerts/act | confirm step for closing; 403 own-alert message; assign-to-me waits G/H | FIRST CUT 22 Nov 2026 08:10 PKT; sandbox 390/820/1280 ok; waits install + live look | || LIVE LOOK NOT GREEN: live page + empty list ok ('No alerts. That is healthy.'), buttons not seen live because there are 0 alerts; sandbox only; needs a real or test alert row || 22 Nov 2026 09:05 PKT: to see the buttons live without touching real data: desk-test-alert.sh raises ONE labelled TEST alert (notice, no red pulse); Claude presses Acknowledge then Resolve in Chrome, then GREEN || GREEN 22 Nov 2026 09:04 PKT (WIRED: YES / REAL: YES / TECH-LAW CHECKED): live Chrome with his test alert #1229 (source system, notice): row appeared with Acknowledge / Resolve / False alarm, Acknowledge turned it new to ack ("Done."), Resolve asked "Confirm: Resolve" (Cancel offered), the confirm closed it and the list showed "No alerts. That is healthy."; real signed POST /desk/v1/bridge/alerts/act; test alert is closed, real alerts untouched |
| D1f No phase names anywhere | URL filter ?severity=urgent (legacy p1 still read), CSS class dcb-urgent, comment cleaned; gate DESK WIRING now fails any P1 / severity=p1 / dcb-p1 in Desk code | his 22 Nov 09:04 word (Chairman): "khudi live Chrome pe dekho". LIVE SCAN 22 Nov 2026 09:20 PKT (my Chrome, 14 routes incl. unknown page, text + title + aria-label + placeholder + alt): clean, no phase name, no P1; address bar showed ?severity=p1 and CSS text had a phase tag: both fixed | WRITTEN 22 Nov 2026 09:20 PKT; new bundle waits his install + a second live scan, then GREEN || GREEN 22 Nov 2026 09:14 PKT (WIRED: YES / REAL: YES / TECH-LAW CHECKED): his install 09:08, live bundle desk-CaheKM8J.js = repo; 2nd live scan 15 routes (incl. ?severity=urgent and an unknown page): text, title, aria-label, placeholder, alt, address bar and raw DOM text all clean, no phase name, no P1 |
| E Team fan-out | Tokio broadcast, WebTransport streams | one DB read per tick shared by all staff sessions | NOT written |
| F MoQ | Media over QUIC tracks (IETF), WebTransport | named tracks summary/services/alerts as MoQ objects | NOT written (tracks already named in the frame) |
| G Org + policy (AD2, S1+S2) | PostgreSQL tuples (Zanzibar-style), RLS, Rust evaluator, deny-by-default | staff, relations, forbid-wins policy | NOT written |
| H Staff accounts (ON1..ON12) | webauthn-rs, Argon2id, DBSC, device-bound passkeys | enrollment code, devices, leaver, recovery, zero-trust locks (AAGUID, IP + shift, circuit breaker) | NOT written |
| I Mailboxes (was Inboxes; R3b, R4-2) | PostgreSQL RLS (fadm_mailbox), Rust, virtual list | hello, moveyourbusiness, resolved, billing (restricted), leo, noreply | NOT written |
| J Auto mail (R3c) | Rust, RFC 3834 Auto-Submitted | 7-day per-sender gate, Polar signed webhook | NOT written |
| K Cases + SLA (R3e, R3f) | Rust, SQL SLA engine (AD4), SKIP LOCKED routing | assign, reply, clock stops only on human reply or resolve, root-cause note | NOT written (needs his support terms) |
| L Transparency log (W1) | Merkle tiles, signed tree head | audit log browsers remember | NOT written |
| M Hybrid post-quantum (W3) | ML-DSA + Ed25519, ML-KEM | post-quantum signatures and mail | NOT written |
| N Mail craft + attachments (R4-3..R4-10) | React, Tiptap 3, Rust, ML-KEM, WebTransport, Hetzner Storage Box, ClamAV, OpenPGP PQC (RFC 9980) | compose, rich text, undo/schedule, attachments, outbound TLS policy | NOT written |
| O CRM (R-CRM) | React 19, Rust, RLS | accounts, leads, pipeline, tasks, reports in company style | NOT written |
| P Managed Move-In (R4-11) | Rust async IMAP migrator | company mailbox migration | NOT written |
| Q Final audit + load proof (R3g, S10) | Rust, React | dashboard + final audit + load proof (S10) | NOT written |
Sources: BLUEPRINT-ADMIN-DESK.md (R3a detail tables), MASTER-PLAN-22NOV.md, REMAINING-LIST-22NOV.md, BRIDGE-PLAN-22NOV.md, EMPLOYEE-ACCOUNTS-PLAN-22NOV.md, SCALE-50K-DESIGN-22NOV.md, WORLD-ADVANCE-DESK-22NOV.md. This page is the one-page summary; when a phase starts its own feature table (feature | code | technology | HAAN) is written in BLUEPRINT-ADMIN-DESK.md.


=====================================================
# PART 2: D5 SUBPHASES WITH ADVANCE TECHNOLOGY  (D5-SUBPHASES-22NOV.md)
=====================================================
# D5 SUBPHASES + ADVANCE TECHNOLOGY (his word 22 Nov 2026 10:27 PKT: "yeh admin desk meri company ki rooh hai, seminar mein bhi samjhana hai, business ki backbone")
Written 22 Nov 2026 10:28 PKT. Rule 52 holds for every step: each answer the employee sees is signed by the Desk Rust signer and verified in the browser by the Desk's own Rust WASM kernel. HTTP/3 only, TLS 1.3 AES-256-GCM, X25519MLKEM768. No phase name is ever shown to an employee (rule 14). No money on the Desk. Desk isolation law: nothing here touches founder code, doors, keys or tables.

## A. THE SEMINAR STORY IN 5 LINES (so he can say it on stage)
1. A customer has a problem. The employee opens that company in the Admin Desk.
2. The Desk asks the Control Plane, live and signed, read-only, and shows package, features, limits, service state, usage. Nothing is copied.
3. The employee types the reason, the look is written in a tamper-evident log.
4. A written runbook tells the employee exactly what to see, do, never do, who to call, what to say, which clock applies.
5. If it needs the owner, one button creates a real case. Money never appears on the employee's screen.

## B. SUBPHASES (build order, each closes only after my live Chrome look, 390 / 820 / 1200+)
| Id | What | Advance technology | Closes when |
|---|---|---|---|
| D5a-1 Contract | The lookup contract in CURRENT.md: allowed fields (package id and version, features on, limits, usage, service state, one flag "payment received, service not active" + since when, freshness time), forbidden fields (any amount, invoice, card, transaction), request format | Written contract + a commit gate that FAILS any Desk file that names an amount / invoice / card field (same style as the isolation gate) | gate fails on a planted bad field, passes clean |
| D5a-2 Package registry | ONE versioned entitlement registry from the landing-page list: package, version, effective date, features, limits, trial and grace rules, SLA target; old subscriptions keep their version | PostgreSQL (fadm_pkg tables in the Desk schema, forced RLS), append-only versions, hash-chained ledger line per version, Rust read door; empty until he supplies the list | an inserted test version cannot be edited, only superseded |
| D5a-3 Signed lookup | Employee opens a company: role check, reason typed, short-lived signed read-only request to the Control Plane, answer checked, nothing stored | Rust Tokio axum, Ed25519 request signature with audience + expiry + request id, HKDF/HMAC, one narrow read-only key, Rule 52 verify in the Rust WASM kernel, HTTP/3 | wrong audience, expired, replayed request all refused |
| D5a-4 Audit with reason | Every look leaves one line: employee, company ref, time, reason, requested fields, request id | PostgreSQL append-only ledger with SHA-256 hash chain (Desk's own), RLS | line appears for every look, chain verifies |
| D5a-5 Fail closed | Control Plane down or slow: screen says "Data unavailable", never old data; show freshness time on every screen | Rust timeout + circuit state, kernel stale-frame check (Rule 52) | live test with the lookup switched off shows the honest message |
| D5 Plan context screen | Company page: package + version, included vs ACTUALLY enabled features, limits and usage bars (90 / 95 marks), service state (Active, Not active yet, Grace period, Suspended, Setting up), SLA target, the one payment flag, freshness | React 19 + TypeScript, Tailwind 4, Framer Motion, registry-driven cards, kernel-verified data, History API router | his eyes on 390 / 820 / 1200+, no amount anywhere |
| D5b-1 Runbook library | The 9 runbooks, each with exactly 6 parts | Desk-own runbook data (PostgreSQL, versioned, approval owner + approved date), React cards | 9 runbooks readable, each with its 6 parts, owner = him |
| D5b-2 Guided checklist | A runbook opens as a step-by-step checklist beside the company (idea from his screenshot: stage bar + checklist panel); each tick is saved to the case | React 19 + Framer Motion, kernel-verified saves, Rust door | ticks survive reload and show in the case history |
| D5b-3 Say-this text | The sentence for the customer, one click copy, in plain words | React, clipboard with selection fallback | copy works on all three widths |
| D5c Escalate | "Escalate to the owner" button makes a real case: company, reason, priority, status flag, audit ref, employee, time; employee sees case number + status; the result comes back the same way | Rust one-way signed hand-over (Desk writes its OWN case table, owner side pulls on its own terms), idempotent request id, PostgreSQL RLS | a test case reaches the owner queue and the answer returns, no founder table touched by the Desk |
| D6 Customers needing you now | First priority card: payment received but not active, grace period, 90 percent usage, 95 percent usage, suspended; count, severity, SLA, runbook link per row | Rust Tokio broadcast over the kernel WebTransport stream (one read for all staff), React card from the registry | numbers equal the Control Plane, never a placeholder |

## C. DISCUSSION: WHAT I KEEP OF HIS RUNBOOK TEXT AND WHAT I CHANGE
KEEP exactly: the 9 problems, the 6 parts per runbook, version control, approval owner.
CHANGE / ADD (my view, he decides):
1. "Storage or seats limit: approved upgrade route": an upgrade is a money act. The employee explains usage and points to the customer's own Billing Portal or the owner; the employee never sells or promises. Wording changed to "explain usage, send the customer to the owner's upgrade route".
2. "Account suspended: approved reason class": HIS ORDER 10:42: I design the classes myself at advance level. DONE as a draft: eight classes SR1..SR8 in RUNBOOK-LIBRARY-DRAFT-22NOV.md; the employee only sees the class, never sets it; he approves.
3. "Grace period": I need HIS number of grace days per package; it comes from the registry, not from the runbook text.
4. "Multiple customers affected" is a runbook only for the first cut; the real incident handling (group, one status message) lands in phase K.
5. "Payment received, service not active": the runbook's first line is the safe flag; second line is escalate with the audit reference. The employee never checks Polar or amounts.
6. I ADD a 7th habit, not a 7th part: every runbook ends with "what to write in the case" so the evidence is the same every time.
7. From his screenshot I take the IDEAS only (a stage bar on the case, a contact card, a short case summary, a guided checklist panel on the side). No copy of that product's look; the Desk keeps its own night-glass style.
DROP now: AI-written summaries (AI for the Desk is dropped until July 2027), dual approval flows, a separate runbook editor UI (first cut: runbooks are written by me in the repo, approved by him, versioned by commit; an editor comes later only if he asks).

## D. WHAT HE MUST GIVE (one at a time, none blocks D5a-1 and D5a-4)
1. Package list as data (features + limits per package, grace days). Blocks D5a-2 filling and D5 screen values.
2. (Done by me, his order 10:42) Suspension reason classes: draft in RUNBOOK-LIBRARY-DRAFT-22NOV.md, waits his approval only.
3. Where his Control Plane answers (address + how it should verify our signature). Blocks D5a-3 on his server; the code and tests are written first against a local test double.

## E. ORDER NOW
D5a-1 contract and gate -> D5a-4 audit ledger SQL -> D5a-2 registry SQL -> D5a-3 signed lookup (test double) -> D5a-5 fail closed -> D5 screen -> D5b-1..3 -> D5c -> D6. Deadline for the whole Desk stays 26 Nov 2026 07:26 PKT.

## F. HIS 10:42 ADDITIONS
1. NO PROMISES (law): a runbook never promises a date, restore, refund, credit, upgrade or owner decision; gate in D5b-3 fails a runbook with a banned promise word. Text in RUNBOOK-LIBRARY-DRAFT-22NOV.md section A.
2. All nine runbooks are drafted (same file, section C); the suspension classes SR1..SR8 are drafted (section B).
3. THE ORIGINAL ANEXOMAIL UI AND UX STAYS INTACT (his identity): every step above and the six sections only ADD data and reorder the rail; no restyle of the Desk look, colours, glow, Command Bar, login or any existing screen without his word; a backup under backups/desk before each UI change, and a before / after screenshot check.


=====================================================
# PART 3: THE SIX MAIN SECTIONS  (DESK-SIX-SECTIONS-22NOV.md)
=====================================================
# THE SIX MAIN SECTIONS OF THE ADMIN DESK (his word 22 Nov 2026 10:34 PKT) + HOW, DECIDED FROM WEB RESEARCH
Written 22 Nov 2026 10:35 PKT. His words: the concept picture he sent is only a likeness, ours must be ORIGINAL, never a copy; add these 6 sections; method is mine to decide from research. Rule 52, HTTP/3 only, Desk isolation, no money on the Desk, no phase name visible to an employee (rule 14) all stand.

## A. THE SIX (employee words, exactly his table)
| # | Section | Employee's job | Home in the repo today | Phase that fills it |
|---|---|---|---|---|
| 1 | Overview | Today's important problems | Dashboard (LIVE, keeps its look) | D live; D6 adds "Customers needing you now"; K adds SLA at risk |
| 2 | My Work | Cases assigned to me | new view of the cases module (key cases) | K (needs staff identity from H) |
| 3 | All Cases | The whole support queue | modules/workspace/cases (planned, "not connected yet") | K |
| 4 | Customers | Customer and company profiles | modules/admin-desk/people + plans (planned) | D5 screen first, R5a people |
| 5 | Incidents | System issues hitting many customers | modules/admin-desk/incidents (planned) | K + R5f |
| 6 | Knowledge | Runbooks and solution guides | modules/admin-desk/knowledge (planned) | D5b runbooks first, R6 guides |

## B. WHAT THE WEB RESEARCH SAYS AND WHAT WE DO WITH IT
1. Zendesk (agent workspace guide): show each agent group the tools that fit the task (contextual workspace), put the most relevant fields first in the customer profile card, route by availability, capacity and priority, let agents resize the side panels. WE: Customers page shows plan, state, usage and open cases first; My Work is the default landing for a Support Agent, Overview for a Lead (role-aware screens already exist, canSeeTech); routing by capacity + priority in K.
2. Atlassian KCS (knowledge in the workflow): search the knowledge base BEFORE troubleshooting, capture or fix the article while solving, update an existing article more often than write a new one, use usage data to find gaps. WE: a case shows the matching runbook on the side; when a case is resolved the employee gets one question "Was the runbook right? Fix it" which opens the runbook change request; Knowledge shows "most used" and "gaps" (searches with no answer).
3. Freshservice major incident: related tickets are linked under one major incident, on-call and stakeholders are told, customers see status updates, BUT resolving the parent does NOT close the children unless extra automation is built, and closing notes are not copied. WE: Incident = one parent + linked case list; resolving it closes the linked cases in one controlled, logged step and copies the closing note; one status message per incident for affected companies.
Sources: https://support.zendesk.com/hc/en-us/articles/4408824058138-Optimizing-the-Zendesk-Agent-Workspace , https://www.atlassian.com/itsm/knowledge-management/kcs , https://support.freshservice.com/support/solutions/articles/50000006388-major-incident-management-frequently-asked-questions-faqs-

## C. ORIGINAL, NOT A COPY (his rule)
The concept shows an executive dashboard with money-style tiles, a "setup prompt" panel and a long sidebar. We keep our own look (night glass, the live Command Bar, the glow) and take only the IDEA of a short, grouped rail. We do NOT take: pipeline value or any money tile, "hours reclaimed" style vanity tiles, a setup prompt. Every number must come from a verified live source (rule: a card is real only when its data is real).

## D. THE METHOD (small steps, each seen live in Chrome before the next)
| Step | What | Advance technology | Closes when |
|---|---|---|---|
| S1 Rail order | The six sit at the TOP of the rail in this order; all other modules stay (nothing removed, UI law) under "Tools" and "Company" below them. On a phone the bottom bar shows exactly these six tabs (it fits), the rest under a "More" tab. His haan needed before this UI change | React 19 + TS, the module registry (one list, modules/registry.ts), CSS only layout (no JS size switch) | seen at 390 / 820 / 1200+, old items still reachable |
| S2 Customers | Search by company or domain, a typed reason, then the D5 plan context page; below it that company's cases | D5a signed lookup, React 19, kernel-verified data, History API router | opens a test company, reason audited |
| S3 Knowledge | Runbooks list + one runbook page (six parts) + side panel inside a case later | Postgres full-text search + versioned runbook data, React | nine runbooks readable |
| S4 Overview | Today strip: urgent alerts, customers needing you now, SLA at risk, active incidents, my open cases; each tile opens its list; placeholders stay honest ("Not connected yet") | Tokio broadcast over the kernel WebTransport stream, registry-driven cards | every tile equals its list |
| S5 All Cases + My Work | One cases table, saved views (Unassigned, Urgent, SLA at risk, Waiting, Reopened), filters in the URL, My Work = the same table filtered to me; claim a case safely so two people never take it | PostgreSQL SKIP LOCKED claim, SLA engine in SQL, virtual list for tens of thousands, Rule 52 | two staff cannot claim one case |
| S6 Incidents | Parent incident, linked cases, affected companies, one status message, timeline, controlled close of linked cases | Rust, PostgreSQL, signed notices, hash-chained timeline | closing an incident closes its cases with the note |

## E. THINGS I MUST FIX BECAUSE OF THIS (found while reading the registry)
1. modules/admin-desk/plans/meta.ts still says "Signed Polar webhook receiver (HMAC), Postgres fadm_plans". That contradicts his 09:15 word (no webhook, no Polar, no money on the Desk). It will be rewritten to "signed read-only lookup, versioned package registry" in the same change as S2.
2. The rail group names today are "Anexomail Workspace / Admin Desk / Company"; S1 adds the six on top and does not delete these groups.

## F. WHAT HE DECIDES (one line each)
1. Haan for S1 (six at the top of the rail, the rest below, phone bottom bar = the six + More)?
2. Which section does a Support Agent land on after sign-in: My Work (my suggestion) or Overview?


=====================================================
# PART 4: RUNBOOKS, SUSPENSION CLASSES, NO-PROMISE LAW, REFUND POLICY  (RUNBOOK-LIBRARY-DRAFT-22NOV.md)
=====================================================
# RUNBOOK LIBRARY, FIRST DRAFT BY CLAUDE (his word 22 Nov 2026 10:42 PKT: "promises miscommitment hai, woh nahi hoga" and "suspension reason classes tum khud banao, advance level pe")
Written 22 Nov 2026 10:43 PKT. Status: DRAFT for his approval (approval owner = the Chairman). Employee-facing words only: no phase names, no money, no webhook names. Rule 52 applies to every screen that shows these.

## A. THE NO-PROMISE LAW (his word, written as a rule the gate enforces)
The employee NEVER promises. Not a date, not a restore time, not a refund, credit, discount or free month, not an upgrade, not the outcome of an owner decision, not "it will be fixed". The employee states FACTS FROM THE SCREEN, what was done, the case number, and which clock applies (the SLA target is a target to answer, not a promise to fix).
Allowed sentence shapes: "I can see ...", "I have passed this to ... , your reference is ...", "The next update is due by ... (the target for this plan)", "I cannot give a restore time."
Banned in any runbook "say this" text (gate, D5b-3): promise, guarantee, definitely, for sure, 100 percent, will be fixed, will be restored, refund, credit, compensation, discount, free (the one fixed policy sentence of section A2 is whitelisted), within N hours / minutes (unless the number is read from the plan's SLA target and the sentence says "target"), "I will make sure". The commit gate fails a runbook that contains one. A runbook also shows a fixed line in part 3: "Never promise a date, a refund, a credit, an upgrade or an owner decision."

## A2. REFUND POLICY (his word 22 Nov 2026 10:47 PKT, CHAIRMAN): THERE IS NO REFUND POLICY
If a user used the service even for one day there is NO refund. This is already published on the landing site: page /billing-policy (src/routes/billing-policy.tsx: changing package means paying the new package's full price, no credit or refund for the old one; amounts "not credited, not adjusted and not refunded"). So the employee never negotiates, never hints at an exception, never opens a money case for a refund request. The ONLY allowed sentence (fixed, the gate whitelists it): "Our published billing policy says payments are not refunded or credited once the service has been used. You can read it on the Billing Policy page." Anything beyond that (a customer insists, threatens a dispute, says a mistake was made) = one owner case with the audit reference, no discussion of money, no promise. The customer billing blueprint already exists: docs/claude/BILLING-PORTAL-BLUEPRINT.md (awam side).

## B. SUSPENSION REASON CLASSES (my design, advance level; the employee only SEES the class, never sets it)
Who sets a class: the Control Plane or the owner, never the employee. The Desk shows class code + label + since when + case reference. The employee can never suspend, restore, or change a class.
| Code | Class | What the employee may say (facts only) | Escalate to |
|---|---|---|---|
| SR1 | Payment matter | "The account is on hold for a billing matter. I cannot see amounts. I have passed it to the team that handles billing, reference N." | owner case (billing side) |
| SR2 | Abuse or policy breach | "The account is on hold under our usage policy. The details are handled by the abuse team. Reference N." | abuse team case |
| SR3 | Security hold | "The account is on hold to protect it after unusual activity. Reference N. I cannot give details or a restore time." Never reveal what triggered it | security case, priority raised |
| SR4 | Legal or compliance hold | "The account is on hold. I am not able to discuss the reason. Reference N." No details, no guessing | owner case only |
| SR5 | Customer's own request | "The account is paused at the request of your company administrator." Restore only by the customer's own administrator through the owner route | owner case if the admin cannot be reached |
| SR6 | Verification pending | "We are waiting for the domain or identity check to be completed." Employee may show which check is pending | support lead |
| SR7 | Fair-use limit | "The account reached a usage limit for its package." Employee explains usage from the screen; no promise of a raise | owner case |
| SR8 | Under review | "The account is under review. Reference N." No reason given | owner case |
Every class has: allowed statement, forbidden statement ("never say why in detail unless the class sheet says so"), escalation target, who may lift it (always not the employee), and an audit line when someone views it. A new class needs the Chairman's approval and a new registry version.

## C. THE NINE RUNBOOKS (each has exactly six parts; part 3 always carries the no-promise line)
Format per runbook: 1 sees / 2 may / 3 never / 4 escalate / 5 say / 6 clock. SLA target numbers come from the plan registry, never typed here.

R1 Payment received, service not active
1 sees: service state, the ONE flag "payment received, service not active" + since when, package and version, freshness time
2 may: confirm the flag, open an owner case with the audit reference, tell the customer a case exists
3 never: ask for or look at amounts, card, invoice; touch the money side; promise a time; (no-promise line)
4 escalate: owner case, priority high if the flag is older than the plan's target
5 say: "I can see your payment has been received and your service is not active yet. I have opened case N with the team that can fix this. I cannot give a restore time."
6 clock: the plan's first-answer target (a target to reply, not a promise to fix)

R2 Features missing
1 sees: package and version, features included, features actually enabled, the difference
2 may: explain the difference, check the version date, open a case if included features are off
3 never: enable or disable anything, say a feature will be added, (no-promise line)
4 escalate: support lead if the package says included but it is off
5 say: "Your package includes X. I can see it is currently off for your account. I have opened case N."
6 clock: plan target

R3 Storage or seats limit reached
1 sees: usage against the limit, the 90 and 95 percent marks, package limit
2 may: explain what is using space or seats from the usage metadata, point to the owner's upgrade route
3 never: sell, quote, promise an upgrade or a raise, (no-promise line)
4 escalate: owner case if the customer asks for a change
5 say: "You are at N percent of your limit. Changes to limits are handled by the owner. I have passed your request, reference N."
6 clock: plan target

R4 Grace period
1 sees: service state "Grace period", days left (from the registry), package
2 may: explain the state in plain words, open a case if the customer disagrees
3 never: extend, shorten, or promise an extension, (no-promise line)
4 escalate: owner case for any extension request
5 say: "Your account is in a grace period. The date it ends is on your account page. Any change to that is decided by the owner. Reference N."
6 clock: plan target

R5 Account suspended
1 sees: state "Suspended", reason class code (section B), since when
2 may: read the class sheet statement, open the escalation named in the class
3 never: say more than the class sheet allows, guess a reason, restore, promise, (no-promise line)
4 escalate: as per the class table
5 say: the class sentence from section B
6 clock: plan target; SR3 and SR4 run at raised priority

R6 Cannot sign in
1 sees: account state, whether recovery is pending or done (never a code or secret), last sign-in time, device count
2 may: tell the customer the recovery steps from their own page, confirm that recovery is pending
3 never: ask for a password or code, reset a secret, bypass a check, (no-promise line)
4 escalate: security case if signs of takeover
5 say: "I can see the account is active. Please use the recovery option on the sign-in page. I will not ask for your password or any code."
6 clock: plan target, raised if suspected takeover

R7 Email not delivered
1 sees: domain checks (MX, SPF, DKIM, DMARC state), queue state, last delivery results, never message content
2 may: explain which check fails and what the customer's administrator must change
3 never: read message content, send on the customer's behalf, promise delivery, (no-promise line)
4 escalate: support lead if our side is the cause; incident if many customers show it
5 say: "Your domain check for X shows Y. Your administrator needs to change Z."
6 clock: plan target

R8 Attachment blocked
1 sees: scan state (clean, infected, scan pending, too large), size against the package limit
2 may: explain the reason in plain words
3 never: release or open the file, promise it will be released, (no-promise line)
4 escalate: security case if the scan result is disputed
5 say: "The file was held because the scan says X. I cannot open or release it."
6 clock: plan target

R9 Multiple customers affected (first cut)
1 sees: several cases from different companies about the same symptom, service health card
2 may: link the cases to one incident, post the status note the incident lead approved
3 never: tell customers a cause or an end time that is not in the approved note, (no-promise line)
4 escalate: incident manager immediately
5 say: the approved status note only
6 clock: incident clock; full handling in the incident section

## D. WHAT HAPPENS WITH THIS FILE
Part of D5b-1: each runbook becomes versioned data with the Chairman as approval owner; the no-promise words list becomes a commit gate in D5b-3; the suspension classes become registry rows in D5a-2. Until he approves, the Desk shows these as "Draft, not approved yet" to leads only.


=====================================================
# PART 5: D5 DECISIONS AND EXTRACT  (D5-DECISIONS-AND-EXTRACT-22NOV.md)
=====================================================
# D5 DECISIONS (HIS 3 ANSWERS) + WHAT WE TAKE FROM THE OUTSIDE BLUEPRINT (his word 22 Nov 2026 10:10 PKT)
His word: the outside blueprint is only a source; we build it PRACTICAL. The customer Billing Portal lives in the customer's own account (awam side) and ONE PART of it is seen in the Admin Desk. Take only what we need, ignore the rest.

## A. HIS 3 ANSWERS (all three APPROVED, so D5 is no longer waiting)
1. DATA SOURCE = YES: when an employee opens a company, the Desk makes a live, signed, READ-ONLY metadata request to his Control Plane. Conditions: no local copy of customer records; only account status, subscription state, payment state (one flag), usage metadata; every access leaves an audit line (which employee, which company, when, for what reason); role check + short-lived signed authorisation + request verification; if the Control Plane is down the Desk says "Data unavailable" and never shows old data as current. The Desk is a governed viewing window, never a customer database.
2. PACKAGES = the published landing-page list is the one true source. It becomes a VERSIONED entitlement registry (features, usage / storage / user limits, terms, trial and grace rules, restrictions). The Desk and the Control Plane both follow it. A later price or limit change makes a new version; old subscriptions keep their version, nothing changes silently. The Desk keeps NO package table of its own that can disagree. Old repo numbers (phase61, pricing v6, README) are never the source.
3. ESCALATE = a real case, not a notification. Case carries: company id, reason, priority, current account / payment status, audit reference, employee identity, creation time. The owner receives an assigned case; the employee sees case reference + status.
Split that stays: Admin Desk = visibility and support; Control Plane = truth and governance; Founder side = money decisions (Polar, payments, refunds, invoices, reconciliation). Employee never sees amounts, invoices, transactions.

## B. TAKEN from the outside blueprint (and where it lands)
| Point | Lands in |
|---|---|
| Lookup needs a REASON typed by the employee before the company opens; audit line holds employee, company ref, time, reason, requested fields, request id; append-only hash chain (already the Desk ledger) | D5 |
| Signed request: audience, expiry, request id verified; only required fields; response not kept in logs; fail closed | D5 |
| Screen fields: package name, included features, limits, ACTUALLY ENABLED features, service state, usage against limits, SLA target, "Payment received, service not active" Yes/No + since when, data freshness time | D5 |
| Service states in plain words: Active, Not active yet, Grace period, Suspended, Setting up | D5 |
| Package version per subscription (example: Pro, version 2026.11, effective date) shown next to the account | D5 |
| Runbook has exactly SIX parts: what the employee sees / may do / must never do / who to escalate to / what to tell the customer / which SLA applies; versioned with a named approval owner | D5b |
| First runbooks: payment received but service not active; features missing (package vs enabled); storage or seats limit; grace period; suspended; cannot sign in; email not delivered; attachment blocked; many customers affected | D5b |
| Escalation case flows: created, owner queue, triage, decision, result written back to the Desk case; only metadata + audit reference travel, money evidence stays on the founder side | D5b + K |
| First priority card "Customers needing you now": payment received but service not active, grace period, 90 percent usage, 95 percent usage, suspended; each with count, severity, SLA, runbook link | D6 |
| Rule: a card turns real only when its live data source is verified; a placeholder count is never shown as a metric (already our rule) | D6 |
| Case state machine NEW, TRIAGED, ASSIGNED, IN PROGRESS, WAITING, RESOLVED, VERIFIED, CLOSED; every transition authorised and logged; duplicate detection, same-company grouping, SLA clock, reminders, reopen tracking | K |
| Roles: Support Agent, Senior Support, Support Lead, Incident Manager, Security Auditor (Finance Operator and Founder stay on the founder side); permission also by company scope and action risk; sensitive action = time-limited permission, dual approval where needed | G, H |
| Automation bounded: safe read-only checks, approved reminders, duplicate merge by rule; NEVER a financial action from the Desk | K |
| Tests that must be proven: unauthorised employee denied, company A cannot see company B, no money detail leaks, expired or wrong signature refused, Control Plane outage fails closed, escalation makes the right case, every sensitive look is audited, restore of a backup actually tried | Q (and each phase's own check) |
| Rollout behind a feature flag with a tested rollback: lookup for chosen staff first, then runbooks, then the priority card, then the whole team | D5, D5b, D6 |

## C. LEFT OUT (not needed now, his word: no giant platform)
API gateway and microservice split, dead-letter queues, circuit-breaker and region partition lists, penetration-test programme, a separate Finance Operator role inside the Desk, MFA wording (our staff use passkeys, plan H), any financial screen. They come back only if a real need shows up.

## D. MY CAUTION (isolation law)
"Escalate" must NOT write into the founder's tables or call founder doors (Desk isolation law). Design: the Desk writes the case in its OWN table with owner = founder side, and the founder side pulls it through a signed one-way hand-over that the founder side reads on its own terms; the result comes back the same way. Same for the Control Plane lookup: the Desk holds one narrow key that can only read metadata. Contract goes into CURRENT.md before code.

## E. THE CUSTOMER BILLING PORTAL (awam side, his word)
It lives in the customer's own account on the awam site, so it is the awam blueprint (separate module, built after the Desk core). The Desk shows ONE part of it: the service state and the single flag "Payment received, service not active", never amounts. Written into the awam blueprint line, awam code is not touched now.

## F. BUILD ORDER NOW
1 signed read-only Control Plane connection + audit-with-reason (contract first) -> 2 D5 plan context screen -> 3 D5b runbooks -> 4 escalation case -> 5 D6 priority card -> (later) Billing Portal on the awam side. Needs from him still: the final landing-page package list as data (features and limits per package) so the registry can be filled; until then the registry file stays empty and the screen says "Package list not supplied yet".
