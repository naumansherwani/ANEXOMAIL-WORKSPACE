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
| SPA greeting REVERTED to v2 (1 Nov): v3 centring was rejected by the founder; server already has v2, nothing to pull for the greeting | none |
| L5 v2: SQL E110 + CHECK_E110, Rust `hostproof.rs` (70 tests) + `/founder/v1/hostguard`, awam `auth.ts` DB record, `founder-hostguard.sh` DB status, Dashboard "Host separation" card | 4 pulls in order: sql-run (E110) -> awam pull.sh -> founder-install -> founder sign out/in -> status (see PULL-COMMANDS 22:58) |

## NOT STARTED (order unchanged)
Rust `/founder/v1/live` + SSE (uses E109 `founder_live_snapshot/tick/since`) -> Dashboard auto-update -> F2c Merkle (E107) -> S2 -> F2d passkey -> Finance -> People -> Mail Desk -> Systems -> Control -> F9 cutover. `pending_channels` hard-coded list in bridge.rs must move to the E109 registry.

## FOUNDER RULES THAT KEEP BEING BROKEN (check before every UI change)
1. Real logo only (`LogoMark` in Brand.tsx), never redraw. 2. No mock data. 3. Founder blue (#5ec8ff to #4aa3f0) on the title and pill. 4. Backend = Rust + tokio async 24 h + WASM kernel; 3D only draws kernel-verified values. 5. User side code is never edited (the one allowed touch: `server/routes/auth.ts` host guard).

## UPDATE 1 Nov 05:10 PKT
- Greeting v3 (centred eyebrow/heading, date under clock) was REJECTED by the founder ("woh pehle wala sahi tha"). Bridge.tsx and dx.css are back to v2 (same as 35867e0). The server already runs v2. Never centre anything in the greeting again without his exact sentence.
- New design note (docs only, no code): docs/claude/BRIDGE-EMAIL-CHAT-ENGINE-DESIGN-01NOV.md (Email <-> Chat Bridge, phases B1-B7, SQL E111-E116 proposed). Awam-stack feature; nothing installed.

## UPDATE 1 Nov 05:25 PKT (founder paste)
- INSTALLED and verified by founder: E110 (CHECK_E110 7/7 OK), Rust 70 tests + hostproof + /founder/v1/hostguard (founder-install OK, service alive). hostguard status: ready_to_enforce True, rust:exchange 5, web_guard_last_seen None => awam `pull.sh` (step 2 of L5 v2) NOT done yet; mode still probe. Next for founder: awam pull.sh, then `founder-hostguard.sh enforce`.
- REPO ONLY (needs founder-install): top bar title removed + date under the clock (this commit). Everything else in SPA = what the server has.
- Bridge (Mail<->Chat) = master order 12b, after steps 11 and 12.
- 1 Nov 05:30 PKT: g-clip fix in repo; pending founder-install together with 05:25 UI (top bar title removed, date under clock).

## UPDATE 1 Nov 05:35 PKT - founder-install (44e1661) DONE by founder (70 tests, SPA 200, healthz 200). Chrome live: g of "morning" now complete, top-bar title gone, eyebrow stays. Date under the clock is on the page (clock column).
### NEXT, in master-order terms (FOUNDER-MASTER-ORDER-28OCT.md)
| # | What | Owner | Rule |
|---|---|---|---|
| N1 | Finish step 3 / L5: awam `pull.sh` (web_guard_last_seen is None), then `founder-hostguard.sh status` -> `enforce` | founder (2 commands) | green = status shows web_guard_last_seen set + enforce on |
| N2 | Founder order 22:17 "live data, auto updates": Rust `/founder/v1/live` + SSE over E109 (`founder_live_snapshot/tick/since`), then Dashboard auto-update (React-TS, kernel-verified frames). Replace hard-coded `pending_channels` with registry here too | Claude | CHECK + Chrome (watch a number change without reload) |
| N3 | Step 5 F2c audit v1 + Merkle (E107), design note first (Rule 63), kernel `merkle` | Claude | then 5a I1 Ledger Integrity Gauge |
| N4 | Step 6 S2 Settings (Time machine, Drift) -> step 7 F2d passkey + S3 -> step 8 Decide/Live Pulse/S4 -> 8a I3 | Claude | in this order |
| N5 | 9 Finance, 10 People (+10a I2, 10b K4), 11 Mail Desk (+11a K1), 12 Systems/AI (+12a K2), **12b Mail<->Chat Bridge**, 13 Control (+13a K3), 14 F9 cutover, 15 Founder desk | Claude | one phase at a time |
Not asked and NOT next: Mail<->Chat Bridge build (12b). Leftover checks: orb amber/red under a real warning; F5 refresh 50-100 ms target; awam-side kernel 0.5.0 / E90 release publish.
