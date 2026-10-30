# WHAT IS ON THE SERVER vs ONLY IN THE REPO — read this after any compaction, do NOT rewrite installed code (30 Oct 2026, 23:05 PKT)
Source of truth for "is it installed": the founder's own pasted output + Chrome. Update this file every time he installs something.

## INSTALLED + seen in Chrome (green)
| Item | Evidence |
|---|---|
| Rust `anexomail-founder` through the 66-test build (auth sharing, immutable assets, early kernel) | installs 22:14, 22:24, 22:37 |
| SPA through commit 35867e0: Dashboard plane look, splash with real logo, HealthOrb (green 2/2), BridgeMap, real `LogoMark` in sidebar/splash/profile, Founder blue top bar + eyebrow, greeting v2 | Chrome 22:59 (logo on profile clear of the real long name; top bar text gradient) |
| SQL E100-E106, E108, **E109 founder_live** (CHECK_E109 9/9 OK, founder paste 22:44) | server |
| Awam web: probe-mode log version of the host guard (auth.ts, pulled earlier) | status shows mode probe |

## IN THE REPO ONLY (not installed yet; do not rewrite, just give the founder the pull)
| Item | Needs |
|---|---|
| SPA greeting v3 (pill centred under "Good night", date next to the clock) | founder-install |
| L5 v2: SQL E110 + CHECK_E110, Rust `hostproof.rs` (70 tests) + `/founder/v1/hostguard`, awam `auth.ts` DB record, `founder-hostguard.sh` DB status, Dashboard "Host separation" card | 4 pulls in order: sql-run (E110) -> awam pull.sh -> founder-install -> founder sign out/in -> status (see PULL-COMMANDS 22:58) |

## NOT STARTED (order unchanged)
Rust `/founder/v1/live` + SSE (uses E109 `founder_live_snapshot/tick/since`) -> Dashboard auto-update -> F2c Merkle (E107) -> S2 -> F2d passkey -> Finance -> People -> Mail Desk -> Systems -> Control -> F9 cutover. `pending_channels` hard-coded list in bridge.rs must move to the E109 registry.

## FOUNDER RULES THAT KEEP BEING BROKEN (check before every UI change)
1. Real logo only (`LogoMark` in Brand.tsx), never redraw. 2. No mock data. 3. Founder blue (#5ec8ff to #4aa3f0) on the title and pill. 4. Backend = Rust + tokio async 24 h + WASM kernel; 3D only draws kernel-verified values. 5. User side code is never edited (the one allowed touch: `server/routes/auth.ts` host guard).
