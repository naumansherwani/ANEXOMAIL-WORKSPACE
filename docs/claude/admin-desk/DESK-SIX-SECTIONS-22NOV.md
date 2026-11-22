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
