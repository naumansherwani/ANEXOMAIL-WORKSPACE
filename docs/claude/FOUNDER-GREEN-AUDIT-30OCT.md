# FOUNDER GREEN AUDIT — what is really green (30 Oct 2026, 22:00 PKT)
Rule: GREEN = running on the server + CHECK passed + seen live in the founder's Chrome. "Code done" is NOT green. Evidence column = where it was seen.

## GREEN (server + Chrome live)
| Item | Technology | Evidence |
|---|---|---|
| T1 stack: TypeScript strict, TanStack Router (hash), Tailwind 4.2, shadcn | UI | Chrome 30 Oct 19:16 |
| L1 actions cache, L2 Bridge 863 ms, L3 awam links off the founder host, L9 Dashboard/Bridge split, L10 top bar | RUST + UI | Chrome 19:56 |
| L11 refresh: boot logo, gzip, immutable assets (FCP 571 ms) | RUST + UI | Chrome 19:56 |
| F2b: kernel verifies every answer in the browser ("Trusted") | KERNEL + UI | Chrome 20:20 |
| Settings write + reload persist (Personal, Appearance) | RUST + SQL E108 + UI | Chrome 20:35 |
| Dashboard front page, company watch, tiles, 7 of 7 endpoints verified, gates from registry (1/5/6, 0 enabled), audit chain intact #14 | UI + RUST + KERNEL | Chrome 21:06 |
| Sidebar "Dashboard", "User dashboard" in the user-app group, top bar "Founder Command Center", Bridge icon, bridge/settings fetched once, kernel worker starts at 459 ms (was 1946) | UI + KERNEL loader | Chrome 21:46 and 22:00 (JS read of sidebar + resource timings) |

## CODE DONE, NOT GREEN (needs founder-install, then Chrome proof)
| Item | Technology | What must be seen |
|---|---|---|
| L19 refresh round 3: `early.js` starts the kernel at page parse; instant verified snapshot after F5; 66 Rust tests incl. auth sharing (one DB answer for 9 parallel calls, 5 s, a "no" never kept, writes always fresh); kernel .wasm immutable cache | KERNEL loader + UI + RUST | F5 timing: data should arrive about 1 s sooner; snapshot paints before the live answer |
| Dashboard copy pass (plain words) | UI | read the page |

## OPEN (not green)
| Item | Blocker |
|---|---|
| L5 host guard | founder: sign out, sign in at /founderlogin once; then `status` must show a `[founder.host]` line (awam web already pulled, probe logs every login) |
| L7 bun.lock | repo only, proven in sandbox; no server step needed |
| Polar API metrics (billing row says webhook live, API not connected) | Polar reader token, step F3 |
| Executor (0 actions enabled) | F8 |
| Sidebar group "Workspace (user app)" still lists old links "Founder" and "Admin" that open the old Lovable pages | removed at F9 cutover (they are user-app routes; founder never edits user files) |
| Everything from F2c onward | not started (design note first, Rule 63) |
