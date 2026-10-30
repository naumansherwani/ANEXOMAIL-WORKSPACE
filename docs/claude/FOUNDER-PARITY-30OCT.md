# FOUNDER PARITY — which user-app features the founder gets (repo scan, 30 Oct 2026, 21:35 PKT)
Founder order (21:21, verbatim in founder-commands.md): user-side features founder ko bhi milen, ~80-90% same; "ab tumne repo se dekhna hai ke kaun se features abhi founder ko milna hai"; clean polished founder UI, tarteeb se, sirf us technology ke codes jo aaye gi.
Method: counted the real page files `src/routes/app.*.tsx` (125 files) and mapped each area to a founder deck from FOUNDER-MASTER-ORDER-28OCT.md. Rules: FC18/FC22 (same features, separate code, never edit user files), Rule 62 (technology first), Rule 66 (one phase, green in Chrome before the next).
How "same" is done: the founder gets the same feature list and behaviour on the latest technology (Rust endpoint on `anexomail-founder`, React-TS page in `founder-web`, kernel-verified answer). Pure logic is reused through `#[path]` includes or ported; the user's React files are never imported, user and founder never share a token, table or host.

| User area (route files) | Founder home | Same on founder | Founder-only change | Step | Technology |
|---|---|---|---|---|---|
| Dashboard `app` (1) | Dashboard | greeting, clock, tiles | company tiles, gates, API | done | UI + RUST |
| Settings (`settings` 9 files: root + workspace, appearance, notifications, privacy, ai, health, history, index) | Settings | all 8 tabs | Time machine, Drift, device approval | 2 done: Personal+Appearance; S2/S3/S4 | UI + RUST + SQL |
| Account, Devices, Security (`account`, `devices`, `security` 8 files: devices, encryption, history, index, proof, sessions, vault + root) | Profile + Settings + device approval | profile, sessions, device list, proof | passkey (F2d), break-glass | F2d (7) | RUST (webauthn-rs) + UI |
| Mail (`mail` 5: folders, outbox), Calendar (1), Search (1), Import (1), Domains (1) | Mail Desk | folders, outbox, calendar, search | Mail Desk adds company-wide view + K1 Sealed Agreements | F5 (11) | RUST + SQL + UI |
| People (1), Org (10 files: audit, compliance, departments, graph, index, members, policies, roles, security + root), CRM (11 files: accounts, activity, collab, index, leads, pipeline, relationships, reports, setup, tasks + root), Work (1) | People | all pages | Account 360, abuse and appeals, work chain dependencies | F4 (10) | RUST + SQL + UI |
| Analytics (8 files: deep-work, forecast, index, leaks, promises, team, threads + root), Perf/Speed (7 files: budgets, devices, index, prefetch, regressions, search + root), Safety (1), ANEXOChat (1), Storage (1), Integrations (1) | Systems | all pages | company-wide numbers across tenants | F6 (12) | RUST + SQL + UI |
| Admin (14 files: addresses, audit, diagnostics, export, health, logs, members, migrate, monitoring, reports, storage, teams) | Systems + Control | read parts | writes are G2/G3 with audit | F6, F8 (12, 13) | RUST + SQL + UI |
| AI (`ai` 2: credits; `ai-center` 1) | AI (inside Systems) | credits, centre | founder-only, read-first, no free-text SQL | F6 (12) | RUST + UI |
| Billing (2: state) | Finance | billing state | all tenants, Polar failed payments, churn | F3 (9) | RUST + SQL + UI |
| Move-In (1), Launch/Release (7 old pages) | Move-In, Release | all | go-live executor | F3 then F8 | RUST + UI |
| `founder` + `founder_.*` (35 old Lovable pages) | replaced | — | removed at cutover | F9 (14) | RUST + WEB |

Totals from the scan (`ls src/routes | grep ^app.`): 125 files = 33 old founder Lovable pages (replaced, removed at F9) + 92 user-app files. Of the 92, only the shell (`app.tsx`, `app.index.tsx`) has no founder deck; every other file maps to a deck above. That is the "80-90% same" the founder asked for.

## Sidebar clarity (fixed in code, 30 Oct)
The group "Workspace (user app)" lists links that open real user-app pages. Its first link used to read "Dashboard", the same as the founder Dashboard above it. It now reads "User dashboard". Each link disappears from that group when its founder version ships (step in the table).

## Which phase gives the founder the most next (honest)
1. F2c Merkle and Ledger Integrity Gauge (trust of everything below).
2. F2d + S2/S3/S4 (Settings tabs the user already has, same look).
3. F3 Finance (money is the first thing a chairman checks), then F4 People, F5 Mail Desk, F6 Systems. The founder may reorder; the order only changes with his "haan".
