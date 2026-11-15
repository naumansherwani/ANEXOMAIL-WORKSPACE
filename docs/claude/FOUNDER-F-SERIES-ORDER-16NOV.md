# F-SERIES = THE "OLD APP" CARDS WAITING FOR THEIR RUST DOORS (his question 16 Nov 04:40: "yeh F Series kya hai, tarteeb kab aye gi")

**What it is.** In founder-web/src/catalog.ts every Systems/People/Finance/Release/Control card has a phase code F3..F8 (an early 30 Oct naming). 21 of those cards still read the OLD app's /api/founder/* and answer 404 on the founder host: they have no Rust door yet. That is real open work, not a bug.

| Old code | Deck | Lettered blueprint phase (the real order) | Cards open |
|---|---|---|---|
| F3 | Finance, Release, Move-In | O Finance deck (Polar webhook ledger, revenue, billing, release) | Finance 5, Release 5 |
| F4 | People | P People (Org, CRM, Team, Account 360, Insider Guard) | 3 |
| F6 | Systems, AI | R Systems (health, analytics, speed, admin, safety, chat) + V Founder AI | Systems 5, AI 1 |
| F8 | Control | S Control (kill switch, flags, executor, poison pill) | 2 |
| F5 | Mail | Q (running now, Q1d) + R3 Mail Desk | none |

**Every card needs:** a Rust door under /founder/v1/... (axum, signed answer, kernel RPC), an E-series SQL step (RLS, append-only, selftest, CHECK), the card switched from `legacy` to the new endpoint in catalog.ts, then my live Chrome look. NO mock data. Each is GREEN only when WIRED: YES / REAL: YES.

**ORDER (planned 16 Nov, everything founder is due 30 NOV 2026; he can reorder):**
1. 16-17 Nov: Q1d-1a (keys DONE 04:45, policy switches, DNS TXT, Check DNS), Q1d-2a, Q1d-2b first real mail, Q1d-1b Gmail proof.
2. 18 Nov: AUDIT-Q1d + auto fix, Q1b4.
3. 19-20 Nov: Q3 attachments (Tokio + Rust + WebTransport, ClamAV, Hetzner Storage Box; gate date 26 Nov).
4. 21-22 Nov: O (F3): Finance 5 + Release 5 + Move-In.
5. 23 Nov: P (F4): People 3.
6. 24-25 Nov: R (F6): Systems 5 + R3 Mail Desk, V AI 1.
7. 26 Nov: S (F8): Control 2 + executor.
8. 27 Nov: N (Decide + Live Pulse + push), T cutover (remove old Lovable/Bun founder routes: only after every card above is on its Rust door), U Docs/Sheets.
9. 28-30 Nov: X extras, M MoQ (gate 30 Nov), Q-pqmail 29 Nov, final AUDIT, whole blueprint check.
Until a card has its door, it says "Not connected yet. This one waits for its own Rust door (Fx)".
S5 (TanStack Start in SPA mode) is closed: Router-only decided 16 Nov.
