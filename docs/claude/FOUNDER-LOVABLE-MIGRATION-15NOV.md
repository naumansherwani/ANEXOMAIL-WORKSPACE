# FOUNDER: LOVABLE CODES MIGRATION PHASE (his order 15 Nov 2026 19:19 PKT, written so Claude never has to wonder)

HIS WORD: the Lovable codes (Bun, old technology) are written; they are PRESERVED as written in `lovable-gold/founder/` (frozen, read-only, SHA-256 manifest, gate-protected). The ONLY job is: take each code as it is written, move it to the ADVANCE TECHNOLOGY, FIX ITS LOOPHOLES on the way, POLISH it more, and hand it to the founder. Nothing is invented from scratch and nothing is thrown away. Awam does the same in its own blueprint (`docs/claude/AWAM-LOVABLE-MIGRATION-15NOV.md`), never mixed.

## THE RULE FOR EVERY LOVABLE FILE (the migration recipe, same for all)
1. READ the frozen Lovable file and its endpoint row (`ENDPOINTS-founder.csv`); write down what it does (the business behaviour is the spec).
2. TECH CONTRACT first (`tech-contracts/CURRENT.md`), then code: Rust axum + Tokio handler in `server/founder/src`, calls through the kernel `rpc@1` over WebTransport (HTTP/3 only), data in PostgreSQL with RLS, React 19 + TS page on TanStack, Tailwind 4, shadcn, Framer/GSAP. No Bun, no Node, no WebSocket, no SSE.
3. LOOPHOLE PASS (written as a list in the phase, each item fixed, never skipped): device token + passkey step-up where it changes money or access; no cookie-only trust; RLS on every table; input validation; rate limit; every change writes the audit ledger; no secret in the browser; CSP self-only; no raw fetch.
4. POLISH: the Lovable look is kept where he loved it, cinematic UI law applies (never flatten), 390 / 820 / 1200+, 44 px touch targets, plain-English wording, no empty screens.
5. PROOF: parity tests (Rust answer equals the Bun answer on the same input), his server paste, my live Chrome look, live bundle = repo. Only then GREEN (WIRED: YES / REAL: YES / TECH-LAW CHECKED).
6. The Bun route is removed ONLY at phase T and only on his word. The Lovable copy in `lovable-gold/` stays forever.

## STATUS TODAY (counts from the 3 Nov map, not re-mapped; re-map is step 1 of each phase)
Founder Bun endpoints: 48. Rust twin existed for 18 on 3 Nov, 30 Bun-only. The founder Rust crate was since rebuilt on the E-series (A to L are GREEN), so the real per-endpoint status is re-checked at the start of each phase.

### Endpoints, by Lovable file -> phase
| Lovable file (frozen in lovable-gold/founder/server/routes) | Endpoints | Of them Rust twin on 3 Nov | Goes to phase | Target (advance technology) |
|---|---|---|---|---|
| `admin.ts` | 1 | 0 | R (R3 Mail Desk / admin) | Rust axum handler in `server/founder/src`, kernel `rpc@1` over WebTransport, SQL RLS, React-TS page |
| `ai-credits.ts` | 1 | 0 | V (Founder AI) | Rust axum handler in `server/founder/src`, kernel `rpc@1` over WebTransport, SQL RLS, React-TS page |
| `analytics.ts` | 2 | 2 | R (analytics) + O (billing/revenue) | Rust axum handler in `server/founder/src`, kernel `rpc@1` over WebTransport, SQL RLS, React-TS page |
| `billing-support.ts` | 2 | 0 | R (support)  | Rust axum handler in `server/founder/src`, kernel `rpc@1` over WebTransport, SQL RLS, React-TS page |
| `crm.ts` | 2 | 0 | P (CRM) | Rust axum handler in `server/founder/src`, kernel `rpc@1` over WebTransport, SQL RLS, React-TS page |
| `founder.ts` | 6 | 0 | P (mailboxes, AI mail: with Q mail) | Rust axum handler in `server/founder/src`, kernel `rpc@1` over WebTransport, SQL RLS, React-TS page |
| `glitch.ts` | 1 | 0 | R (health) | Rust axum handler in `server/founder/src`, kernel `rpc@1` over WebTransport, SQL RLS, React-TS page |
| `integrations.ts` | 1 | 1 | R (integrations) | Rust axum handler in `server/founder/src`, kernel `rpc@1` over WebTransport, SQL RLS, React-TS page |
| `movein.ts` | 11 | 2 | O (Release / Move-In), to confirm with him | Rust axum handler in `server/founder/src`, kernel `rpc@1` over WebTransport, SQL RLS, React-TS page |
| `org.ts` | 4 | 0 | P (Org) + S (kill switch, impersonate) | Rust axum handler in `server/founder/src`, kernel `rpc@1` over WebTransport, SQL RLS, React-TS page |
| `perf.ts` | 1 | 0 | R (speed) | Rust axum handler in `server/founder/src`, kernel `rpc@1` over WebTransport, SQL RLS, React-TS page |
| `release.ts` | 11 | 11 | O (Release) | Rust axum handler in `server/founder/src`, kernel `rpc@1` over WebTransport, SQL RLS, React-TS page |
| `revenue.ts` | 1 | 0 | O (Finance) | Rust axum handler in `server/founder/src`, kernel `rpc@1` over WebTransport, SQL RLS, React-TS page |
| `security.ts` | 1 | 1 | R (safety) + S | Rust axum handler in `server/founder/src`, kernel `rpc@1` over WebTransport, SQL RLS, React-TS page |
| `settings.ts` | 1 | 1 | B S1 (REBUILT, GREEN) | Rust axum handler in `server/founder/src`, kernel `rpc@1` over WebTransport, SQL RLS, React-TS page |
| `storage.ts` | 2 | 0 | R (systems) | Rust axum handler in `server/founder/src`, kernel `rpc@1` over WebTransport, SQL RLS, React-TS page |

### Pages and libs, by phase
| Lovable page / lib (frozen in lovable-gold/founder/src) | Goes to phase | State |
|---|---|---|
| `founder.tsx`, `founderlogin.tsx`, `founder_.$.tsx`, `founder.preview.tsx`, `founder-gate*.ts`, `founder-host-guard*.ts` | A, K4, G-MIX (login, gate, host separation) | REBUILT in Rust + React-TS, GREEN. Bun copy stays until T. |
| `app.founder.tsx`, `FounderBar.tsx` | B, D (Dashboard, Bridge, sidebar) | REBUILT, GREEN |
| `app.founder_.settings.tsx` | B S1, H, I | REBUILT, GREEN |
| `app.founder_.billing.tsx`, `revenue*.tsx`, `launch.*.tsx` (checklist, deployments, lock, qa, roadmap) | O | NOT started |
| `app.founder_.org.tsx`, `crm.tsx`, `movein.tsx` | P (movein: O or P, to confirm) | NOT started |
| `app.founder_.admin.tsx`, `analytics.tsx`, `perf.tsx`, `integrations.tsx`, `safety.tsx`, `calls.tsx` | R | NOT started |
| `app.founder_.security.tsx` | R + S | NOT started |
| `app.founder_.ai.*.tsx` (9 pages) | V | NOT started |
| `app.founder_.motion.tsx` | L (look, polish) | check against the new L before moving |

## WHEN IT STARTS (honest, in his order of 15 Nov 19:19)
1. NOW: Q series (mail + calendar) until it is complete. The Lovable migration does not start before Q is GREEN.
2. THEN S5 (TanStack Start SPA mode), his word: S5 starts AFTER the Q series is complete.
3. THEN M, N in letter order (new features), and the Lovable migration phases in letter order: O (Finance, Release, Move-In), P (People), R (Systems, 6 pages), S (Control), V (Founder AI), then T (cutover: remove the old Bun founder routes, only after Rust == Bun parity proof and his word), U (Docs + Sheets).
4. Dates: 25 Nov 2026 is the LAST day for the whole founder blueprint (his 9 Nov order); the day plan is `FOUNDER-DEADLINE-25NOV-PLAN.md`. Seminar London January: finishing phases is the priority. If a phase fails its proof it is fixed the same day and the list shifts honestly.
5. Each phase starts with the re-map of its Lovable files and ends with the loophole list closed.
