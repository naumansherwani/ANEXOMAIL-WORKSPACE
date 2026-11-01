# FULL BLUEPRINT ORDER WITH STATUS (1 Nov 2026 05:40 PKT) - source: FOUNDER-MASTER-ORDER-28OCT.md + FOUNDER-SERVER-STATE-30OCT.md
GREEN = on server + CHECK + seen live in founder Chrome. One phase at a time (Rule 66).
| # | Step | Status |
|---|---|---|
| 1 | F1a device approval, F2a Ed25519 + signatures | GREEN |
| 2 | Settings S1 (E108): photo, name, home city, graphics, sidebar | GREEN |
| 3 | Polar token DONE; awam host guard enforce (L5) | OPEN: founder awam pull.sh, then hostguard enforce |
| 3a | T1 UI stack (TS, TanStack Router, Tailwind 4.2, shadcn) | GREEN |
| 3b | Loopholes L2 speed, L3, L7, Bridge/Dashboard split, L14-L22 | GREEN except L5 |
| 4 | F2b WASM kernel verify in browser (Trusted) | GREEN |
| 4b | Live data (founder 22:17): E109 SQL GREEN; Rust /live + SSE + Dashboard auto-update + pending_channels registry | NEXT (N2) |
| 5 | F2c audit v1 + Merkle (E107) | after 4b |
| 5a | I1 Ledger Integrity Gauge | after 5 |
| 6 | S2 Settings: Time machine, Drift and schedule | after 5a |
| 7 | F2d passkey (FOUNDER_PASSWORD removed) + S3 Privacy | after 6 |
| 8 | Decide (N) + Live Pulse + S4 Notifications | after 7 |
| 8a | I3 Device Trust Map | after 8 |
| 9 | F3 Finance: Polar failed payments/churn, Revenue, Billing, Release, Move-In | after 8 |
| 10 | F4 People: Org, CRM, permissions, Account 360, abuse, Work | after 9 |
| 10a | I2 Active Work Chain Dependencies | with 10 |
| 10b | K4 Insider Guard | after 10 |
| 11 | F5 Mail Desk (+ Mail, Calendar, notifications, undo-send) | after 10 |
| 11a | K1 Sealed Agreements | after 11 + F2c |
| 12 | F6 Systems + AI (10 pages) + Analytics, Speed, Admin, Safety, ANEXOChat | after 11 |
| 12a | K2 Mesh / air-gapped sync (research spike) | after 12 |
| 12b | Mail<->Chat Bridge, sub-steps 12b-1..6 | after 12 |
| 13 | F8 Control: kill switch, flags, one-click executor | after 12 |
| 13a | K3 Poison Pill | after 13 |
| 14 | F9 CUTOVER: remove Lovable founder routes + Bun-only endpoints after Rust == Bun proof | after 13 |
| 15 | Founder desk: Docs + Sheets (WOPI), calendar, tasks | last |
Awam ONE-ORDER is a separate lane, resumes after step 3 is green (FC21).
