# ADMIN DESK D5 + D6 REVISED: "WHICH PACKAGE IS THIS CUSTOMER ON" + RUNBOOKS (his 22 Nov 2026 09:23 PKT; written 09:35 PKT)

## HIS WORD (Chairman, 09:15 + 09:23)
- Webhook, Polar and FINANCE stay on the founder side (his own Rust control plane); he looks at them personally. The Desk builds NO webhook door, NO Polar code, NO payment data, NO invoices, NO card details.
- BUT the employee must know which package a user is on, what that package includes (the features and limits he fixed on the landing page, NOT the conflicting numbers in old repo docs), and what is wrong with the account, so the problem is solved ON THE SPOT.
- Example he gave: "money was cut but the service did not become active". He will give the employees the instructions; the Desk shows the employee what is needed to resolve it there and then.
- Every user problem that can be solved on the Desk is written down clearly (runbooks), so that even a critical situation in the future is handled easily by any employee.
- NO phase names, NO "P1" anywhere an employee can see (rule 14).

## WEB RESEARCH (22 Nov 2026, in order; sources at the bottom)
1. Supportbench (entitlements for support): show the plan's included features and limits NEXT TO the account's active entitlements so a difference is visible at a glance; show add-ons, contract overrides with start and end dates; show usage against limits; show the SLA of the plan; plain-language labels, never raw config; ONE central record, not notes or spreadsheets.
2. Same source, "paid but not active": confirm payment status first; check the payment-failure grace period; compare the billing record with the entitlement record (sync gap, missed upgrade event, expired trial, wrong dates, a deal signed but never pushed); fix or re-sync the record, never grant access through a side channel; if unclear, escalate with the entitlement history; temporary access only as an OVERRIDE WITH AN END DATE; keep the customer informed and apply the SLA the paid tier entitles them to; log the root cause; review overrides regularly.
3. dev.to "Stripe says active, Postgres says false": failure modes = event never arrives, handler answers 2xx without writing, events out of order, duplicates, wrong user row, slow handler timeouts, trusting the success page. Remedy = nightly reconciliation of billing versus access rows with an alert on any mismatch, treat billing as the source of truth and the database as a cache, store processed event ids, refetch before trusting an event. (This is the FOUNDER side's job; the Desk only SHOWS the result of that check.)
4. Zendesk developer guide (single view of the customer): the agent sees the customer's tier and history in a sidebar inside the ticket, so no switching between tools or asking colleagues; faster, personal answers.
5. Google Workspace Access Approvals (zero-access spirit): staff open customer data only with a reason, time-boxed, logged; metadata first, content only with consent.

## DESIGN (decision needed from him in section "QUESTIONS")
### D5 Customer plan context (replaces the old D5 plan table + SLA doors)
The employee opens a company (by domain or id) and sees, in plain words:
- Package name and its features and limits (from the Desk-own package catalogue, values copied ONCE by him from the landing page, owner-edited only, append-only history; NO price column).
- Service state: Active / Not active yet / Grace period / Suspended / Setting up. Plus "since when".
- The ONE finance-safe flag: "Payment received, service not active" (a yes or no and the time it began; no amount, no card, no invoice).
- Usage against limits (seats, storage) with the near-cap marks (90 percent yellow, 95 percent high, no block).
- The SLA target of that package (first answer time) so the clock and the tone are right.
Data comes from his control plane through ONE read-only, signed, metadata-only lookup that the Desk asks on demand when an employee opens a company; nothing is stored on the Desk except an audit line (who looked, when, why). The Desk never reads founder tables directly (isolation law), the lookup is a narrow door he owns and can close.

### D5b Runbooks (written once, shown on the Desk next to the problem)
One card per user problem, each with: what the employee sees, what they MAY do, what they must NOT do, who to escalate to and how, what to tell the customer (plain script), and which SLA applies.
1. Payment received, service not active (his example): check the flag and the time; do NOT grant access any other way; press "Escalate to founder desk" with the prefilled summary (company, package, since when); tell the customer "we have your payment and are fixing it, expected time"; temporary access only if the founder sets an override with an end date.
2. Service active but features missing (wrong package features): compare package list with what the account shows; escalate with the difference.
3. Plan limit reached (storage, seats, outbound pool): show usage and the near-cap marks; explain the next package or a capacity pack; no free extension by staff.
4. Account suspended or in grace period: show the reason class (not the money detail); script for the customer; escalate.
5. Cannot sign in, mail not arriving, attachment blocked, virus-scan hold: each linked to the Systems status, Deliverability and ClamAV rows already live.
6. Critical situation (many customers affected): the Systems banner "What to tell customers" plus the Urgent alerts list.

### D6 Dashboard list, re-aligned
Cards the employee can act on, filled as data arrives: "Customers needing you now" (payment received but not active, grace period, near cap, suspended) with counts and a link to the runbook; Queue pressure and SLA at risk (cases), Security health and Staff online (staff accounts), Deliverability, Move-In, Reports. Each card flips from "Not connected yet" to real numbers one by one, each GREEN after a live look.

## QUESTIONS FOR HIM (answer and Claude starts)
1. Lookup: OK that the Desk asks his control plane on demand through one read-only signed metadata door (recommended), instead of any copy of customer data on the Desk?
2. Package catalogue: he types or pastes the FINAL landing-page package features and limits once (the repo docs conflict and are not trusted); no prices on the Desk.
3. Escalation: where does "Escalate to founder desk" go (a Desk case assigned to the owner, recommended)?

## SOURCES
- https://www.supportbench.com/?p=24762
- https://dev.to/mattbaconz/stripe-says-active-postgres-says-false-nobody-alerts-you-32d4
- https://developer.zendesk.com/documentation/apps/build-an-app/prompt-and-personalized-service-with-a-single-view-for-your-customer/
- https://support.google.com/a/answer/12410469
