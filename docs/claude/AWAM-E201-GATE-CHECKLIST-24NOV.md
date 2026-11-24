# AWAM E201 = AWL-3 (+ the SQL half of AWL-2): GATE POINTS FIRST (his 24 Nov 2026 07:25 order, "jo likho points banao sab gates ko pehle batao"), written 24 Nov 2026 08:0x PKT BEFORE the SQL
Fixes loopholes L1 (package caps old) and the SQL part of L3 (the six packages cannot be recorded). Awam lane, awam gate, awam pull. Never mixed with the founder or the Desk.

## GATES THAT WILL ASK, AND THE ANSWER IN THIS FILE
| Gate | Answer |
|---|---|
| SQL WORLD-CLASS | header SCHEMA-FIRST / ADVANCE-RESEARCH / CHECK-FILE, selftest that rolls back, forced RLS on every new table, fixed search_path on every SECURITY DEFINER, REVOKE FROM PUBLIC on every function, append-only ledger with SHA-256 chain |
| RESEARCH IN BLUEPRINT | line ADVANCE-RESEARCH [AWL-3] in the awam blueprint AND AWAM-LOOPHOLE-PHASES (written before commit) |
| SCHEMA-FIRST (20 Nov law) | READ: sql/phase21_billing_platform.sql (workspace_plans, workspace_subscriptions), sql/phase60_org_identity_repair.sql (org_members), anexochat/sql/phase61_file_limits_quota.sql (file_chart, _file_chart_guard), E100 plan_catalog, E193/E187 (plan names), CP4 (six packages), CP5/CP6 (chain pattern) |
| FUTURE-PROOF | no "not measured yet": the seat count is the real org_members count; the alert ledger is real rows; zero rows is data |
| NO TEST NO COMMIT | scratch PostgreSQL 16: selftest twice, CHECK file, an end-to-end run with real tables (trigger refuses at the cap, alerts at 90/95/100) |
| PHASE FILES / INCOMPLETE ADVANCE | CURRENT.md contract block lists only files that exist, every row IN CODE |
| lanes / manifest | lane-sync + manifest-sync before commit |

## WHAT THE SQL FIXES (each point has a CHECK row)
1. workspace_plans has ONLY basic, pro, business, business_pro (phase21), and workspace_subscriptions.plan is a FOREIGN KEY to it: a Business Premium or Business Max subscription CANNOT be stored today. E201 adds the two rows with active = false (sold by contract only, until Hetzner capacity is verified, proposal section G); price GBP 21,000 and 125,000 flat per company (his decisions, the 105,000 in his pasted chart stays an OPEN question).
2. Premium cap was 21,000 users in file_chart (phase61): now 7,000 (his A, final). Business 20 users in file_chart disagreed with the card (60 users, his 22 Nov chart, E100 plan_catalog): now 60.
3. ONE table public.package_seat_cap: the seat cap of every package (5 / 20 / 60 / 570 / 7,000 / 125,000), strict, alert levels 90 and 95.
4. Per-company raise (public.package_seat_cap_raise): only raises, reason of at least 20 characters, append-only history, service_role only (he raises it himself; this door is for the Rust founder side, never a customer).
5. Strict seat guard on org_members: a new active member over the cap is refused (check_violation), serialised by a transaction advisory lock so two simultaneous adds cannot both pass. A company with NO subscription is not capped (zero rows is data; the 48-hour trial rules stay as they are).
6. Alert ledger public.package_cap_alert (append-only, SHA-256 chain): yellow at 90 percent, high at 95 percent, full at 100 percent, one line per company per level per cap value; never blocks anything except the over-cap add; the founder dashboard card reads public.package_cap_alerts_open() (founder lane, later).
7. If phase61 is installed: file_chart + file_plan_limits rows follow the new numbers (guard stays on). If it is not installed: NOTICE only, nothing fails.

## WHAT THE SQL DOES NOT DO (honest)
- No billing rows are invented: workspace_subscriptions stays at 0 rows until real signups (AWL-2 Rust webhook).
- Business Max chat-file row (10 GB*, 250 TB*) waits for Hetzner verified values (the * rule); no number is written for it.
- The 10 GB Max tier in server/rust/main.rs and the founder dashboard card are Rust / React work (AWL-3 code half), not SQL.
- Pool alerts 70 / 85 / 100 percent of the outbound pool and the 50 GB per seat rule need the bandwidth ledger design (open question, written in AWAM-LOOPHOLE-PHASES).
- phase61 itself is frozen and is NOT edited: never run phase61 again after E201 (sql-run runs by number only).

## ORDER OF PROOF
scratch test -> commit -> his ONE sql-run line (E201) -> his paste -> E201 GREEN only then (WIRED: SQL yes / Rust no, so the phase AWL-3 stays OPEN until the Rust half).
