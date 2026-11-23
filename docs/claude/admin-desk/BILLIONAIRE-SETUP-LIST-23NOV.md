# BILLIONAIRE SETUP LIST FOR THE ANEXOMAIL ADMIN DESK (his order 23 Nov 2026 09:11 PKT)
His words: copy the setup of the billionaire companies (Zendesk, Salesforce and the rest) that Anexomail needs, ADD an advance level the rest of them do not have, tell the gate, and keep all of it ON the Anexomail Admin Desk. This is the master list. Every row has an id (BL-xx). A phase that builds a row names its id in its contract block; the gate "BILLIONAIRE LIST" refuses Desk code whose newest contract block names no BL id.
Sources used (web research, 23 Nov 2026): Zendesk Support / Explore metrics and admin docs, Salesforce Service Cloud (Omni-Channel, Entitlements and Milestones, Knowledge, Shield, Setup Audit Trail, Sharing Model), Front, Intercom, Freshdesk, ServiceNow, Google Workspace Admin (Security Center, Alert Center, Access Approval), Microsoft 365 Admin (Secure Score, Service Health), Proton (zero access). Law: FUTURE-PROOF (built ONCE for when the business is big), SQL WORLD-CLASS, Rule 52 (every number signed and kernel-verified), HTTP/3 only, no third-party vendor.
Status words: GREEN = live and seen in Chrome. SQL = database part live, screen open. OPEN = planned, not built. NOT YET = needs a product that does not exist yet (said honestly, never faked).

## A. Case desk (Zendesk Support, Salesforce Service Cloud, Front)
| id | What they have | Anexomail Desk today | ADVANCE beyond them | Where |
|---|---|---|---|---|
| BL-01 | Shared inboxes per address, assignment, status flow | GREEN (AD5, AD7: addresses, cases, legal status moves) | status moves decided INSIDE the database, a case is never deleted, identity fixed | Cases |
| BL-02 | Views, queues, queue pressure, backlog | GREEN (B1 AD11) | 1-minute hash-chained queue series, honest gaps, team signal calm/busy/strained/overloaded | B1 |
| BL-03 | SLA policies and clocks, breach warnings | GREEN (B2) | clock exists exactly when the Priority label does (database CHECK), alert raised once | B2 |
| BL-04 | Reports: created, solved, backlog, first reply, resolution, reopens | SQL (AD16, this phase) | medians and p90 (never averages), backlog rebuilt from the append-only event history, only queues the reader may read | B10 |
| BL-05 | CSAT surveys | NOT YET (no survey table exists; nothing invented) | survey result signed and verified like every other number | B10b |
| BL-06 | Macros / canned replies, runbooks | GREEN (9 runbooks, versions, checklist, words to say) | versioned runbooks with change log, staff acknowledge each version | Runbooks |
| BL-07 | Triggers and automations | OPEN | every automation run is a ledger line; dry-run before enable | Automations |
| BL-08 | Skills-based and omni-channel routing | OPEN | routing decision written to the ledger with the reason | Routing |
| BL-09 | Escalation to a specialist / tier 2 | GREEN (D5c, real case number) | escalation is a real case with its own SLA, owner sees status | Escalations |
| BL-10 | Collision detection (two agents on one case) | OPEN | lock shown with who and since when, expires on its own | Cases |
| BL-11 | Merge / split / side conversations | OPEN | merge is reversible for 24 h and chained into the ledger | Cases |
| BL-12 | Light agents / read-only collaborators | OPEN | read-only seat is a database right, not a UI hide | People |
| BL-13 | Shifts, schedules, who is online | GREEN (B8) | gap = on shift and not online, never a guess for people without hours | B8 |
## B. Customer 360 (Salesforce Customer 360, Zendesk Sell, HubSpot)
| id | What they have | Anexomail Desk today | ADVANCE beyond them | Where |
|---|---|---|---|---|
| BL-20 | Account view: plan, usage, state | GREEN (D5 plan lookup) | one signed read-only request, audit line written FIRST, fields from a closed contract | Plans |
| BL-21 | Portfolio dashboard: customers per plan and state, growth, renewals | GREEN (B9) | all numbers from the real tables, small-group rule, zero is data | B9 |
| BL-22 | Health score and churn risk | OPEN | score is explained row by row from real signals (seats, storage, payment), never a black box | CRM |
| BL-23 | Renewal and expansion forecast | OPEN | forecast from real billing intents, shown as a range with its inputs | CRM |
| BL-24 | Contact and company timeline | OPEN | timeline is built from the append-only ledger, nothing editable | CRM |
| BL-25 | Domain and deliverability posture per customer | GREEN (B6 step 1) | SPF, DKIM, DMARC, MX from the real checks, sums verified before display | B6 |
| BL-26 | Bounce and complaint rates, TLS reporting, DANE | OPEN (B6b) | own-domain MTA-STS, TLS-RPT and DANE by our own Rust DNS probe | B6b |
| BL-27 | Migration / onboarding board | NOT YET (needs phase P, the Rust IMAP migrator) | batches and retries signed like every other number | B7 |
## C. Security and governance (Salesforce Shield, Google Security Center, Microsoft Secure Score, Okta)
| id | What they have | Anexomail Desk today | ADVANCE beyond them | Where |
|---|---|---|---|---|
| BL-40 | MFA / SSO for staff | GREEN (device-bound passkeys only) | enforced IN the database, two keys per person, no password fallback | Security |
| BL-41 | Security health score | GREEN (B3) | score from real tables, each point explained | B3 |
| BL-42 | Setup Audit Trail / admin audit log | GREEN (hash-chained ledger) | chain checked by the database AND by an outside signed copy on the Storage Box | Ledger |
| BL-43 | Temporary elevation, privileged access approval | GREEN (elevations with countdown, break-glass with two keys) | countdown shown to everyone, break-glass raises a high alert at once | B8 |
| BL-44 | Event monitoring / alert center | GREEN (B4 alerts, B5 services) | alerts kernel-verified in the browser, burst freeze | Alerts |
| BL-45 | Field-level security / sharing model | GREEN (queue and case rights per unit, restricted queues) | restricted cases never appear in any series or count, so a trend cannot leak | Queues |
| BL-46 | Customer data access approval (Google Access Approval, Proton zero access) | OPEN (B13) | staff see metadata only, customer data opens only with consent and a timer | B13 |
| BL-47 | Encryption in transit | GREEN (TLS 1.3, AES-256-GCM) | X25519MLKEM768 post-quantum key exchange, HTTP/3 only, no HTTP/1 or HTTP/2 | Edge |
| BL-48 | Key transparency | OPEN (B12) | company key directory checked and signed (Web Key Directory) | B12 |
| BL-49 | Spoof and link guard on inbound | OPEN (B11) | link shows its full address, tracking pixel blocked, verdict in the ledger | B11 |
| BL-50 | Data subject requests, retention, deletion | OPEN (rail: Data requests) | deletion proof is a ledger line with a hash | Data requests |
## D. Platform and operations (ServiceNow, Salesforce Platform, status pages)
| id | What they have | Anexomail Desk today | ADVANCE beyond them | Where |
|---|---|---|---|---|
| BL-60 | Service health / status | GREEN (B5, Systems) | probes every 12 s, plain words for every employee, what to tell customers | Systems |
| BL-61 | Incident management and post-mortems | OPEN (rail: Incidents) | post-mortem is a runbook with an owner and a deadline | Incidents |
| BL-62 | Command palette and keyboard-first admin | GREEN (Ctrl+K, Alt+Shift keys, help sheet) | the same keys on Desk, founder and awam | Keys |
| BL-63 | Sandbox / dry run | OPEN | every Desk SQL runs a rolled-back selftest on the live database before it counts | SQL |
| BL-64 | Release management | GREEN (ad-auto, desk-install) | every install ends with PROOF lines: binary, page and kernel are the repo build | Install |
| BL-65 | Rate limits and abuse protection | GREEN (breaker, burst freeze) | circuit breaker per door, fail closed with one honest shape | Doors |
| BL-66 | Knowledge base | OPEN (rail: Knowledge) | each article versioned, linked to the runbook that uses it | Knowledge |
| BL-67 | Quality assurance / conversation review | OPEN (rail: Quality) | review scores chained in the ledger | Quality |

## E. ADVANCE LEVEL: what none of them have (already built or in the blueprint)
E1 Every number carries a verified tick: signed by the Desk key and verified inside the browser by the Rust WASM kernel (Rule 52); a number that cannot be verified is not shown ("Data unavailable"). E2 Staff keys are device-bound passkeys only, enforced in the database. E3 Append-only hash-chained ledger with a signed outside copy and a check that needs no database. E4 The Desk is its OWN security domain (no founder or awam code, keys, doors or tables mixed in). E5 HTTP/3 over QUIC only, post-quantum hybrid key exchange on every listener. E6 No third-party vendor, ever. E7 Every new SQL ships a rolled-back selftest and a CHECK file, forced RLS, REVOKE PUBLIC, statement and lock timeouts. E8 Zero is data: no card says "not measured". E9 The Control Plane (the only thing that reads the customer database) is read-only, counts-only, signed both ways, replay-proof, with its own audience per question.

## ORDER OF WORK from this list (does not break the blueprint order)
Now: BL-04 Reports (B10, AD16). Next: BL-26 (B6b), BL-46 (B13), BL-49 (B11), BL-48 (B12), then BL-07/08/10/11/12 (automations, routing, collision, merge, light agents), BL-22/23/24 (CRM health and forecast), BL-61, BL-66, BL-67, BL-50. BL-27 (B7) waits for phase P. Each row is built as ONE phase: web research -> this list -> ADVANCE-RESEARCH -> contract (names the BL id) -> world-class SQL and technology -> his install -> my Chrome look -> GREEN.
