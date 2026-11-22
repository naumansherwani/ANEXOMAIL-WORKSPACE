# DESK DASHBOARD: CLICKABLE CARDS, WHERE EACH CARD GOES, AND WHAT COMES AFTER (his order 22 Nov 2026 07:11 PKT; written 07:15 PKT)

His words: remove "Signed in as / Role / Session" from the dashboard (identity stays in the AD menu); the dashboard shows what an employee needs to SEE live; every card is CLICKABLE and lands straight on that problem. Only code is written now; real problems arrive later and employees/founder see them (everything WIRED to its door by the gate).

## 1. Click map: card -> page it opens (Desk paths, own routes, no founder route reused)
| Card on the dashboard | Click opens | Lands on | Data door (Rule 52, kernel-verified) | State |
|---|---|---|---|---|
| Active P1 alerts (count) | /dashboard/alerts?severity=p1 | the P1 rows, oldest first, ack/act buttons | stream track alerts + POST /desk/v1/bridge/alerts/act | D2 |
| High / Unacknowledged chips | /dashboard/alerts?status=unacked | same list, filtered | alerts | D2 |
| Pipeline row (stream, h3_edge, tls, db, signer, ledger, mail_in, mail_out, clamav) | /dashboard/services#<service> | that service row opened: state, last probe, latency, uptime 24h | stream track services | D3 |
| Live SLA clock | /dashboard/sla | cases at risk list (breach under 15 min) | AD4 case events (phase K) | wired door now, rows in K |
| Package prices strip | /dashboard/plans | plan lanes, counts per plan | plan rows via signed Polar webhook (J/R3p) | wired door now, rows in J |
| Queue pressure (B1) | /dashboard/queue | team + plan lane, open / waiting / at risk | AD3 cases | K |
| Security health (B3) | /dashboard/security | passkey %, staff with 2 keys, expired reviews, open recoveries | AD1/AD2 | H |
| Staff online / shifts / elevations (B8) | /dashboard/staff | who is on, who holds an elevation (countdown) | fadm_session, fadm_rel | H |
| Deliverability (B6) | /dashboard/deliverability | bounces, complaints, SPF/DKIM/DMARC per company | DNS probes | N |
| Managed Move-In board (B7) | /dashboard/movein | batches, retries, domain verification | R4-11 tables | P |
| Reports (B10) | /dashboard/reports | volume, first response, resolution, backlog | AD3 views | Q |
| Ledger OK chip | /dashboard/audit | append-only ledger tail + chain check | summary.ledger_ok | L |

## 2. Rules for every card
1. A card is a real link (button role, keyboard Enter/Space, 44 px target, visible focus), same code on 390 / 820 / 1200+.
2. The number on the card and the rows on the page come from the SAME stream track, so they can never disagree; the page opens already filtered (drill-down keeps context: filter in the URL, Back returns to the dashboard with the same scroll).
3. A card whose data is not connected is STILL clickable and opens its page, which says plainly what it waits for ("Waits for phase K cases") and shows the wiring status. Nothing is invented.
4. Stale / offline stream: card shows "Stale · not answering", page too.
5. Wiring system (his "CONNECT KARNE KA SYSTEM"): ONE registry `desk_cards.ts` lists every card: id, label, route, track/door, phase, wired yes/no. A unit test fails when a card has no route, a route has no page, or a track is not in the stream; the commit gate reads the same registry. When phase K / J delivers rows, the card flips to wired by changing its one registry line.

## 3. Subphases (alphabetic, strict order; each GREEN only after live Chrome look at 390/820/1200+)
| Sub | Technology | Work |
|---|---|---|
| D1 Cards + router | React 19, TS, own Desk router (deskPage extended), Framer Motion (reduced motion respected) | remove the account cards; clickable cards from the registry; SPA fallback for /dashboard/* in Rust |
| D2 Alerts page | React, Rust door alerts/act, Rule 52 | list, filters from URL, ack/assign |
| D3 Service health page | React, stream services track | per-service detail, uptime 24h, probe age |
| D4 Wiring registry | TS registry + test + gate rule | card -> route -> track -> phase; "Waits for ..." pages |
| D5 Plans + SLA doors | Rust, Postgres (schema-first on AD1..AD3), Polar HMAC webhook | doors ready and empty-safe; fill when J / K land |
| D6 Rest of his list (B1..B13) | per row of DASHBOARD-LIVE-COMMAND-22NOV.md | each lands in the phase named in section 1 |

## 4. After clickable cards (web research 22 Nov 07:15 PKT: drill-down guidance from GoodData, Elastic Kibana, DevExpress, ServiceNow community)
Common pattern: KPI card -> filtered detail view that keeps the filter and returns with Back; one source for number and rows; no dead cards. Our next steps from that: (a) filter chips and URL state on every list, (b) keyboard shortcuts (g a = alerts, g s = services), (c) per-card "since last visit" change marker, (d) saved views per staff after phase H, (e) role-aware dashboard: card set decided in Postgres by fadm_need, never in the browser.
Sources: https://help.gooddata.com/classic/en/dashboards-and-insights/kpi-dashboards/drilling-in-kpi-dashboards/drill-to-insights-from-kpi-dashboards/ , https://www.elastic.co/kr/guide/en/kibana/current/drilldowns.html , https://docs.devexpress.com/eud/eud-for-bi-dashboard/dashboard-for-web/web-dashboard-viewer-mode/dashboard-items/cards/interactivity
