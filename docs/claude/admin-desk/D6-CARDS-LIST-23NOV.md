# 1m D6 CARDS B1..B13, POINT LIST (23 Nov 2026 05:2x PKT). Written BEFORE code, from web research (Front customer-service dashboard guide, Zendesk real-time ticket progress dashboard + SLA/backlog dashboards, Geckoboard SLA + Zendesk backlog examples, Metabase SLA breach rate; plus the repo's own DASHBOARD-LIVE-COMMAND-22NOV.md section B).
Order lock unchanged: 1l GREEN (his word 05:13: its 390/820 look and the live double-press go to the END of the Dashboard folder), 1m NOW, then 1n E+F, 1o DASHBOARD FINAL. Card order (DASHBOARD-FOLDER-ORDER step 8): B4, B5 (already live data), B1, B2, B3, B8, B9, B6, B7, B10..B13. ONE card (or pair) per sub-phase; each ends with SQL CHECK, cargo + bun tests, his two commands, my Chrome look.
SUB-PHASE 1m-1 = B1 Queue pressure + B2 SLA at risk (this block). The rest follow in the order above, each with its own ADVANCE-RESEARCH line added BEFORE its code.

| # | Point (1m-1: B1 + B2) | From | Advance technology next to it |
|---|---|---|---|
| C1 | Queue pressure = open work per QUEUE (general, support, move-in, billing): new, open, waiting, oldest age. The fixed queue order never changes. | Front/Zendesk backlog + queue views | PostgreSQL SECURITY DEFINER read door fadm_queue_pressure (AD11), SQL CHECK |
| C2 | SLA at risk = Priority clock ends in under 15 minutes or has passed AND nobody has answered; shown as a short list (max 20), most urgent first, with minutes left or minutes past. | Zendesk SLA at risk / Geckoboard SLA | fadm_sla_risk (AD11), partial index fadm_case_due (AD07) |
| C3 | The 15 minutes are a WARNING WINDOW for the team, never a promise to a customer (words say so on screen and in code). | his no-promise law | WINDOW_NOTE + test |
| C4 | Permission per case: a person sees only what fadm_case_can lets them read (billing only the granted, restricted labels only leads). A queue they may not read shows 0, never a leak. | AD07 who-sees-what | fadm_case_can inside the door, selftest with 3 roles |
| C5 | METADATA ONLY: counts and case references. No subject, no address, no company, no thread, no money. | Proton zero-access spirit, B13 | selftest regex + Rust shape check |
| C6 | Fail-closed: a wrong answer shape is "Data unavailable", never half a number. | Rule 52 | pressure_shape_ok / risk_shape_ok (Rust) + parsePressure / parseRisk (TS) |
| C7 | Rule 52: both answers are signed by the Desk and verified inside the browser kernel (deskCall). | Rule 52 | Rust Ed25519 sealed router + WASM kernel |
| C8 | Refresh every 30 s while the screen is open; no polling when it is closed; no WebSocket. | live dashboards | React 19 effect cleanup, HTTP/3 only |
| C9 | The cards Queue pressure and Live SLA clock flip from "Not connected yet" to real data (honestly "No cases are waiting" while there are none). | his rule: nothing invented | desk_cards.ts wired flags + card tests |
| C10 | Tablet/phone: counts in a flexing grid, 44 px targets, no sideways scroll; the 390/820 live look is done at the END of the Dashboard folder (his 05:13 word). | Rule 34 + 19 | CSS minmax grid |
SOURCES: https://front.com/blog/customer-service-dashboard ; https://support.zendesk.com/hc/en-us/articles/9757103543194 ; https://www.geckoboard.com/dashboard-examples/itsm/zendesk-sla-backlog-dashboard/ ; https://www.metabase.com/metrics/sla-breach-rate
NAME NOTE: the blueprint reserved AD11 for "SLA clocks for all queues, automations, 7-day auto-mail gate"; the two thin read doors of 1m-1 take AD11 now (schema-first: AD07 and AD03 read first, nothing changed), the bigger SLA/automation SQL moves to AD12.
