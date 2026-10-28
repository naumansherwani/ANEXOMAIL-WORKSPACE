# BRIDGE vs DASHBOARD — a CEO's split (founder 28 Oct 2026, 13:01: "tum CEO ho, kya karoge?")
Rule: **Bridge = verbs and "now" (what needs ME).** **Dashboard = nouns and "trend" (how is the COMPANY).** A tile lives in exactly one of them; the other links to it. Technology and gates as in FOUNDER-KILLER-FEATURES-28OCT.md (Rust + Postgres + WASM verify + React 19.2). Nothing mocked: a tile with no source says "Not connected / Not measured".

## What I check as CEO, in this order every morning
1. Is anything on fire? 2. Is money coming in? 3. Who is waiting for my decision? 4. Did anyone touch something they shouldn't? 5. Are customers OK? 6. What is live / risky?

## BRIDGE (founder only, across all tenants, every row has an action)
| # | Block | Source / step | Action (gate) |
|---|---|---|---|
| B1 | **Needs you** — one queue: approvals, appeals, comp/extend requests, sealed agreements waiting for my countersign, insider holds to review, release waiting | Decide (N) step 8; K1 11a; K4 10b; F3/F4 | Approve / reject (G2, G3 for money) |
| B2 | **Money now** — MRR, failed payments, who is about to churn | Polar (F3-a done, F3-b step 9) | Send reminder / extend grace (G2) |
| B3 | **Fire alarm** — anything failing right now + the kill switches | Systems probes (12), Control (13) | Open incident / kill switch (G3) |
| B4 | **Release** — what is live, one-click deploy + rollback | Release deck (9), executor (13) | Deploy / rollback (G3) |
| B5 | **Customers waiting** — new leads, SLA breaches, abuse review queue | Mail Desk (11), People (10) | Reply / assign (G2) |
| B6 | **Live Pulse** — real vs test accounts, signups today | step 8 | none (read) |
| B7 | **Poison Pill** — devices I can shred | K3 (13a) | Shred (G3 + passkey) |
| B8 | **Mesh fleet** — office LAN nodes online (only when K2 exists) | K2 (12a) | none |
| B9 | **My desk** — founder mail summary, my tasks/calendar | Founder desk (15) | open |
Bridge stays short: max ~6 blocks visible, each with its count; everything else one click away in the decks (Rule 65: clean screen, nothing lost).

## DASHBOARD (company health, read-only G1; first for ANEXOMAIL itself, later the same component per business account — FC22)
| # | Block | Source / step |
|---|---|---|
| D1 | **Ledger Integrity Gauge** (founder's #1) | F2c Merkle — 5a |
| D2 | **Active Work Chain Dependencies** (founder's #2) | Promise engine + `depends_on` — 10a |
| D3 | **Device Trust Map** (founder's #3) | founder_devices + device vault — 8a |
| D4 | **Uptime and speed** — probes history, p95, error rate | Systems — 12 |
| D5 | **Growth** — MRR trend, signups, activation, churn curve | F3 — 9 |
| D6 | **Mail health** — deliverability, bounces, queue age | Mail Desk — 11 |
| D7 | **Capacity** — disk, mailboxes, storage per plan | Systems — 12 |
| D8 | **Support clock** — SLA, response time trend | Mail Desk — 11 |
| D9 | **Audit activity** — writes per day, time machine / drift | F2c, S2 — 5, 6 |
Navigation order (founder 13:06): **Dashboard, then Bridge**, then the decks. "Dashboard" appears above Bridge when D1 ships (5a); no empty page before that. The sidebar group label "Command center" is no longer printed above Bridge; it is the first part of the breadcrumb (Command center / Bridge).

## What I (CEO) would build first
1. Make money real (Polar token, F3-b) — a company that cannot see its money is flying blind.
2. Needs-you queue (Decide) — it turns the Bridge from a report into a tool.
3. Ledger Integrity Gauge — the one number that proves everything else can be trusted.
Then People/Mail Desk, then the killer features in FOUNDER-KILLER-FEATURES order.
