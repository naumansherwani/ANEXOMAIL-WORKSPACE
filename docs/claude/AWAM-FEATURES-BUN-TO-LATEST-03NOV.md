# Awam features: Bun (Lovable) -> latest technology, with frontend and backend (founder order 3 Nov 12:42 PKT)
Generated from `lovable-gold/awam/ENDPOINTS-awam.csv` (475 endpoints, counted by script, not by hand) + the awam route files. Docs only; nothing is moved or deleted (Rule 73). Awam stays PARKED until the founder account is 100% ready, then Basic, Business, Business Pro, Business Premium last.

**What 'Bun' means here.** The FRONTEND of the awam site is already React 19 + TypeScript + TanStack Start/Router + Tailwind 4 + shadcn (the latest line); Bun is the SERVER that renders and hosts it and answers the old `/api/*` endpoints. So the migration is: (1) backend: each Bun endpoint gets a Rust twin (axum 0.8 + tokio, `server/rust`), Rust-first with Bun fallback, the Bun one removed only at cutover T by his word; (2) frontend: pages move from TanStack Start on Bun to the same React-TS app served as static files by Rust, plus the founder technology (WASM kernel verify, WebTransport, passkeys) added per letter.

| Awam feature | Frontend (React-TS routes, kept) | Backend Bun file | Rust twins / total | Latest technology target | Founder letter that carries it |
|---|---|---|---|---|---|
| ANEXOChat | anexochat.tsx, app.chat.tsx, anexovideocall.tsx | `chat.ts` | 0/141 | Rust axum+tokio endpoint, signed answer, kernel verify where it shows data, React-TS UI; SQL with RLS per organisation | R (rebuilt from scratch, Phases 1-60) — 141 endpoints: the biggest block |
| Sign-up / sign-in | login, signup routes | `auth.ts` | 2/25 | Rust axum+tokio endpoint, signed answer, kernel verify where it shows data, React-TS UI; SQL with RLS per organisation | J (passkey, device) + awam migration A2 — host guard W5 runs with it |
| Organisation | app.admin.*, org pages | `org.ts` | 3/23 | Rust axum+tokio endpoint, signed answer, kernel verify where it shows data, React-TS UI; SQL with RLS per organisation | P (Org) |
| CRM | app.crm.* | `crm.ts` | 13/22 | Rust axum+tokio endpoint, signed answer, kernel verify where it shows data, React-TS UI; SQL with RLS per organisation | P (CRM) |
| AI | ai*.tsx, app.ai.* | `ai.ts` | 0/21 | Rust axum+tokio endpoint, signed answer, kernel verify where it shows data, React-TS UI; SQL with RLS per organisation | V (founder only) — awam gets NO AI (master order) |
| Calendar | app.calendar.tsx | `calendar.ts` | 17/17 | Rust axum+tokio endpoint, signed answer, kernel verify where it shows data, React-TS UI; SQL with RLS per organisation | Q1 — all 17 have a Rust twin |
| Mail compose | compose studio | `mail-compose.ts` | 17/17 | Rust axum+tokio endpoint, signed answer, kernel verify where it shows data, React-TS UI; SQL with RLS per organisation | Q1 (+ Q2 attachments) |
| AI automation | ai_.automation.tsx | `ai-automation.ts` | 0/14 | Rust axum+tokio endpoint, signed answer, kernel verify where it shows data, React-TS UI; SQL with RLS per organisation | V (founder only) — awam gets NO AI |
| Mail | app.mail.$folder.* | `mail.ts` | 13/14 | Rust axum+tokio endpoint, signed answer, kernel verify where it shows data, React-TS UI; SQL with RLS per organisation | Q1 |
| Billing state | app.billing*.tsx | `billing-sync.ts` | 7/12 | Rust axum+tokio endpoint, signed answer, kernel verify where it shows data, React-TS UI; SQL with RLS per organisation | O (Finance) — money: his word + server backup first |
| Integrations | app.integrations.tsx | `integrations.ts` | 10/12 | Rust axum+tokio endpoint, signed answer, kernel verify where it shows data, React-TS UI; SQL with RLS per organisation | R |
| Security | settings > security | `security.ts` | 10/12 | Rust axum+tokio endpoint, signed answer, kernel verify where it shows data, React-TS UI; SQL with RLS per organisation | J |
| Settings | app.settings.* | `settings.ts` | 6/12 | Rust axum+tokio endpoint, signed answer, kernel verify where it shows data, React-TS UI; SQL with RLS per organisation | B / H (founder GREEN) |
| Files / attachments | attachments | `files.ts` | 0/11 | Rust axum+tokio endpoint, signed answer, kernel verify where it shows data, React-TS UI; SQL with RLS per organisation | Q2 (+ Q3 WebTransport chunks) — 0 of 11 Rust |
| Admin | app.admin.* | `admin.ts` | 0/10 | Rust axum+tokio endpoint, signed answer, kernel verify where it shows data, React-TS UI; SQL with RLS per organisation | R (Admin, R3 Mail Desk) — 0 of 10 Rust |
| AI credits | ai_.credits.tsx | `ai-credits.ts` | 0/10 | Rust axum+tokio endpoint, signed answer, kernel verify where it shows data, React-TS UI; SQL with RLS per organisation | V / billing — awam gets NO AI |
| Contacts | contacts in mail/crm | `contacts.ts` | 10/10 | Rust axum+tokio endpoint, signed answer, kernel verify where it shows data, React-TS UI; SQL with RLS per organisation | P / Q |
| AI studio | ai_.studio.tsx | `ai-studio.ts` | 0/9 | Rust axum+tokio endpoint, signed answer, kernel verify where it shows data, React-TS UI; SQL with RLS per organisation | V (founder only) — awam gets NO AI |
| Passkey sign-in | login routes | `auth-passkey.ts` | 9/9 | Rust axum+tokio endpoint, signed answer, kernel verify where it shows data, React-TS UI; SQL with RLS per organisation | J — Rust-first already (PX8 GREEN) |
| Trial | signup | `trial.ts` | 7/9 | Rust axum+tokio endpoint, signed answer, kernel verify where it shows data, React-TS UI; SQL with RLS per organisation | O / A2 |
| Performance | analytics | `perf.ts` | 0/8 | Rust axum+tokio endpoint, signed answer, kernel verify where it shows data, React-TS UI; SQL with RLS per organisation | R (Speed) — AX9 latency core written |
| Storage | app.admin.storage.tsx | `storage.ts` | 6/8 | Rust axum+tokio endpoint, signed answer, kernel verify where it shows data, React-TS UI; SQL with RLS per organisation | R (Admin) |
| Polar (payments) | billing | `polar.ts` | 2/7 | Rust axum+tokio endpoint, signed answer, kernel verify where it shows data, React-TS UI; SQL with RLS per organisation | O — engine :3400 NO-TOUCH |
| Dashboard | app.index.tsx | `dashboard.ts` | 5/5 | Rust axum+tokio endpoint, signed answer, kernel verify where it shows data, React-TS UI; SQL with RLS per organisation | A-H (founder GREEN) — all 5 Rust-first |
| Handoff | app | `handoff.ts` | 5/5 | Rust axum+tokio endpoint, signed answer, kernel verify where it shows data, React-TS UI; SQL with RLS per organisation | N |
| Move-in | move-in | `movein.ts` | 3/5 | Rust axum+tokio endpoint, signed answer, kernel verify where it shows data, React-TS UI; SQL with RLS per organisation | O (Move-In) |
| Locale | settings | `locale.ts` | 4/4 | Rust axum+tokio endpoint, signed answer, kernel verify where it shows data, React-TS UI; SQL with RLS per organisation | B |
| Workspace | app.index | `workspace.ts` | 4/4 | Rust axum+tokio endpoint, signed answer, kernel verify where it shows data, React-TS UI; SQL with RLS per organisation | B / N |
| Account deletion | account | `account-deletion.ts` | 3/3 | Rust axum+tokio endpoint, signed answer, kernel verify where it shows data, React-TS UI; SQL with RLS per organisation | J / A2 |
| Glitch / issues | admin inbox | `glitch.ts` | 0/3 | Rust axum+tokio endpoint, signed answer, kernel verify where it shows data, React-TS UI; SQL with RLS per organisation | R (Admin) |
| Mail predict | mail | `mail-predict.ts` | 3/3 | Rust axum+tokio endpoint, signed answer, kernel verify where it shows data, React-TS UI; SQL with RLS per organisation | Q1 |
| People import | app.import.tsx | `people-import.ts` | 3/3 | Rust axum+tokio endpoint, signed answer, kernel verify where it shows data, React-TS UI; SQL with RLS per organisation | P |
| Support | admin | `support.ts` | 3/3 | Rust axum+tokio endpoint, signed answer, kernel verify where it shows data, React-TS UI; SQL with RLS per organisation | R (Admin) |
| Release | release | `release.ts` | 2/2 | Rust axum+tokio endpoint, signed answer, kernel verify where it shows data, React-TS UI; SQL with RLS per organisation | O / S |
| Analytics | app.analytics.* | `analytics.ts` | 1/1 | Rust axum+tokio endpoint, signed answer, kernel verify where it shows data, React-TS UI; SQL with RLS per organisation | R |
| Revenue | finance | `revenue.ts` | 1/1 | Rust axum+tokio endpoint, signed answer, kernel verify where it shows data, React-TS UI; SQL with RLS per organisation | O |

**Total: 169 of 475 awam endpoints have a Rust twin; 306 are Bun-only.**

## Founder Bun code (48 endpoints): when it moves
The founder PAGES are already new (Rust + React-TS + SQL). What is still Bun is the old founder endpoints behind the read-only decks (Mail, People, AI, Systems, Control, Finance, Release, Move-In). They move with their letter, and are REMOVED only at **T (cutover)**, after the Rust twin is GREEN and he says so.
| Bun file | Rust twins / total | Moves with letter |
|---|---|---|
| `movein.ts` | 2/11 | O (Move-In) |
| `release.ts` | 11/11 | O/S |
| `founder.ts` | 0/6 | N/P |
| `org.ts` | 0/4 | P |
| `analytics.ts` | 2/2 | R |
| `billing-support.ts` | 0/2 | O |
| `crm.ts` | 0/2 | P |
| `storage.ts` | 0/2 | R |
| `admin.ts` | 0/1 | R |
| `ai-credits.ts` | 0/1 | V |
| `glitch.ts` | 0/1 | R |
| `integrations.ts` | 1/1 | R |
| `perf.ts` | 0/1 | R |
| `revenue.ts` | 0/1 | O |
| `security.ts` | 1/1 | J (done in new stack) |
| `settings.ts` | 1/1 | B/H (done in new stack) |

**Founder total: 18 of 48 have a Rust twin; 30 are Bun-only.** Order: O, P, Q, R, S, then T removes the Bun twins. That is the answer to 'when does the founder Bun code go to the latest technology': letter by letter from O, and the Bun code is switched off at T.
