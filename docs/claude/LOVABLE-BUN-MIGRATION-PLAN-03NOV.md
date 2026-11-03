# Lovable (Bun) code: preserved, split awam / founder, migrated to the latest technology (founder 3 Nov 2026 08:40 PKT)

His words: the Lovable Bun code is migrated by him; the founder code (Rust, React-TS, SQL E-series) is NOT part of it. The whole website's Lovable code is kept in `lovable-gold/`, awam side and founder side apart, in front of our eyes, so we polish it first and then pull it into the new stack. Endpoints and gates that go to the awam belong to the awam.

## Where everything is
| What | Where |
|---|---|
| Lovable awam site + Bun server + sql + anexochat (frozen copy) | `lovable-gold/awam/` (list: `lanes/lovable-awam.txt`) |
| Lovable founder pages + Bun founder endpoints (frozen copy) | `lovable-gold/founder/` (list: `lanes/lovable-founder.txt`) |
| Endpoint split, with Rust status | `lovable-gold/awam/ENDPOINTS-awam.csv` (475), `lovable-gold/founder/ENDPOINTS-founder.csv` (48) |
| New founder stack (built after, NOT Lovable) | `founder-web/`, `server/founder/`, founder E-series SQL (`lanes/founder.txt`) |
| New awam Rust services (built after, NOT Lovable) | `server/rust/*_core.rs / *_glue.rs` |

## Migration status by endpoint (from the 24 Oct map, 523 endpoints)
| Side | Endpoints | RUST-FIRST (Rust twin exists, Bun fallback) | BUN-ONLY (still only Bun) | Target |
|---|---|---|---|---|
| awam | 475 | 169 | 306 (chat.ts 141, auth.ts 23, ai.ts 21, org.ts 20, ai-automation.ts 14, files.ts 11, admin.ts 10, ai-credits.ts 10, ...) | awam Rust crate `server/rust` (axum), awam gates |
| founder | 48 | 18 | 30 (movein.ts 9, founder.ts 6, org.ts 4, ...) | founder crate `server/founder` (axum 0.8 + tokio), founder gate (device token, Ed25519) |

## Rules for the migration (Rule 73)
1. `lovable-gold/` is read-only reference. Polish a live file first, then run `python3 lanes/lane-sync.py` only when the change is intended.
2. Awam endpoints and gates go only to the awam crate; founder endpoints only to the founder crate. Shared identity stays `founder_accounts` (read by awam auth) until the founder says otherwise.
3. A Bun endpoint is removed only after its Rust twin is GREEN (his paste + Chrome) and the founder says so (cutover T). The Lovable copy stays.
4. Order: founder letters first (Finance O last), awam parked until the founder account is 100% ready (AWAM-PARKED-ORDER-02NOV.md), then Basic, Business, Business Pro, Business Premium last.
5. No code is moved or deleted by this plan. It is a map.
