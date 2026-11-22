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
