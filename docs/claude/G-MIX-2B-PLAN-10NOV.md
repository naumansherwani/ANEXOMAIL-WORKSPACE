# G-MIX 2b PLAN: sign-in ceremony fully in Rust (written 10 Nov 2026 01:08 PKT, founder order 10 Nov 01:07)

Goal: password, passkey, recovery code, magic link and MFA all run in the founder binary (`anexomail-founder`), nothing in the old shared app. Founder only, fail closed, generic denial. Awam never enters this binary.

## What already exists (reuse, do not duplicate)
- `passkey.rs` (667 lines, J3): WebAuthn Level 3 parse + verify (ring, ES256/RS256/Ed25519), doors to SQL. E139 (819 lines), E117 (step-ups, recovery codes/requests), E118 (chairman protocol).
- `auth.rs` (2a): password login/refresh/logout against the identity service; today a verified second factor is refused (fail closed). 2b removes that refusal ONLY by replacing it with a real, proven second step.
- `login.rs` Limiter, `dbsc.rs` session binding (K7).

## Technology (latest, one layer each)
| Layer | Technology | Why |
| --- | --- | --- |
| Ceremony brain | SQL E151 (Postgres 16): sign-in ticket ledger, SHA-256 hash chain, append-only triggers, RLS, risk decision door, selftest, CHECK_E151, 900+ lines | the database keeps every rule, Rust only does bytes |
| Passkey sign-in | Rust, reuse passkey.rs verify, new scope signin, user verification required, BE/BS rules from E139 | no second WebAuthn implementation |
| MFA (TOTP) | identity-service factor challenge/verify called from Rust with the pending token | secret never leaves the identity service |
| Recovery code | Rust door to founder_recovery_* (E117), delay + cancel window kept | already advance-level |
| Magic link | identity-service one-time link, landing page verified by Rust, token_hash single use, never sufficient alone once a passkey is active | link = possession of mailbox only |
| Session issue | Rust, only after the ticket is complete; DBSC/device key binding (K7) applied at issue | one door out |
| UI | React 19 + TypeScript SignIn.tsx steps, WebAuthn browser API, 44px targets, one build for 390/820/1200 | Rule 34 |
| Kernel | Rule 52 WASM kernel verifies signed answers | unchanged |
| Transport | HTTPS + WebTransport/SSE, no WebSocket, no Bun/Node | banned |

## Design
1. POST /founder/v1/auth/login: password ok and founder => create a SIGN-IN TICKET (opaque 256-bit, 120 s, single use, bound to IP-hash + device-key hint) and return {step: needed factors}. No session token leaves yet.
2. Factors: POST .../auth/passkey/options|verify, .../auth/totp, .../auth/recovery, .../auth/magic/request|land. Each writes one ledger row (hash chained) and a failure counts on email AND ip AND ticket.
3. SQL door founder_signin_decide(ticket): complete only when the required factor set is met (rule: password + one of passkey | totp; recovery code = password + code + delay window E117; magic link = never alone when a passkey exists).
4. On complete: Rust releases the held session, DBSC/device key bound, ticket burned.
5. Anything else: same generic 401, held identity session ended, ledger keeps the reason (founder card shows it: this also closes the optional "refused proof reason" idea).

## Order of work (each GREEN only WIRED: YES / REAL: YES)
- S1 E151 SQL + CHECK_E151 (tested here on a local Postgres 16, then his sql-run.sh).
- S2 Rust ticket + passkey sign-in + tests; S3 TOTP; S4 recovery; S5 magic link; S6 SignIn.tsx steps; S7 live proof (his phone passkey, my Chrome read), mobile 390 / tablet 820 / laptop.
- Then legacy auth routes of the old app are dead code for the founder side for good: G-MIX complete.

## Honest limits
- Magic link and TOTP need the identity service endpoints on his server; each is probed live before it is called GREEN.
- Passkey sign-in REAL proof needs his hands (phone or key) once.
- Deadline: founder blueprint GREEN by 25 Nov; L starts 10 Nov (today) per his order.

## LAW added 10 Nov 2026 01:14 PKT (founder 10 Nov 01:13): OLD LOGIN PAGE STAYS THE SAME
The sign-in page look (SignIn.tsx, Cinematic) does NOT change. Only the security behind it goes to the next level. A second step (passkey / TOTP / recovery) appears as the SAME card style only when the account needs it; password-only founders see exactly today's page.

## S1 status (10 Nov 2026 01:14 PKT)
E151 written (797 lines): tables policy/tickets/factors/magic_links/events/nets/handoffs, doors open/factor/release(+v2)/deny/magic_issue/magic_land/locked/risk/report/verify/tick/net_label/nets_list, two selftests. Local Postgres 16: both selftests PASS, second run clean, CHECK_E151 6/6. Server run by him pending (sql-run.sh AUTO).


## REVISION 10 Nov 2026 18:29 PKT (founder 10 Nov 18:26: "mujhe apne liye 2fa nahi chaiye"): THE FOUNDER SIGN-IN IS ONE FACTOR
- Founder: NO 2FA, NO TOTP. S3 (TOTP) is DROPPED. A passkey he enrols is NOT a hidden second step: it is a first-step alternative ("Continue with a passkey" signs in alone; user verification = something you have + you are).
- E152 (written, tested locally, 6/6 CHECK) = policy word `founder_signin_policy.second_step` default 'off' ('required' stays possible only by a chained, audited change), method 'passkey', E151 selftests carried. Magic link: still NEVER alone (frozen): with the word off the link is refused outright, the button answers honestly.
- What guards a password-only founder instead: the login Limiter + E151 lockout (5 fails / 900 s per founder and per network), the new-device approval gate on the server (a new browser sees "This device needs approval" and only HIS server command can approve it), DBSC / device key binding (K7), AES-256 TLS 1.3 + X25519MLKEM768, hash-chained sign-in ledger with risk reading.
- Order now: S1 E151 (GREEN) -> S1b E152 (SQL, his run) -> S2 Rust signin.rs (password ticket + passkey sign-in, UI wiring of the passkey button in the SAME look) -> S4 recovery door (E117, delay kept) -> S5 magic link (stays refused while the word is off; honest message) -> S7 live proof (his phone passkey, my Chrome, 390/820/1280). S3 TOTP removed.
- AWAM (not founder): 2FA is REMOVED for users (not even optional), see docs/claude/AWAM-NO-2FA-10NOV.md (NO 2FA at all, his 10 Nov 19:16) (awam lane, after the founder lane).
