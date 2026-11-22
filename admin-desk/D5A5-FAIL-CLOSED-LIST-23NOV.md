# D5a-5 (phase 1i) FAIL-CLOSED PROOF: the point list (written FIRST, his order 23 Nov 2026 02:07 PKT)
His word: "Control Plane band ho to Desk 'Data unavailable' dikhaye, purana jawab kabhi na dikhaye." Order LOCKED: 1i now, then 1j, 1k, 1l, 1m, 1n, 1o. Rule 52 stays: the browser side lives in the Rust WASM kernel. Schema-first read: lookup.rs (accept, Plane, run), AD4/AD4b (fadm_lookup_finish outcomes), kernel wire.rs.

## Web research (23 Nov 2026), point taken from each
| Source idea | Point taken |
|---|---|
| "Signed is not fresh" (authority needs signature AND freshness) | F2/F3: an old but genuine Control Plane answer is refused |
| Fail-closed guides (deny on error, never degrade to old data, no stale-while-error) | F1, F4, F5, F8 |
| Replay mitigations (nonce + short expiry, bind answer to request) | F3 (answer bound to request id, company, not older than the request), F9 kernel nonce |
| HTTP Message Signatures: created/expires/nonce | F2 short window (15 s) instead of 60 s |
| Circuit breaker (fast failure during an outage, bounded wait) | F1 deadline 6 s total, F7 breaker |

## Points (status honest; "planned" until its test line says passed)
| # | Point | Advance technology | Where |
|---|---|---|---|
| F1 | ONE total deadline (6 s) around the whole Control Plane call (connect + request + answer); slow or hanging = unavailable, audit line closed as unavailable. Was up to 18 s. | Tokio timeout over quinn + h3 | lookup.rs |
| F2 | Freshness: a verified answer must be at most 15 s old and never older than the request it answers (was 60 s window). | Ed25519-signed answered_at, monotonic check | lookup.rs accept |
| F3 | Answer bound to THIS request: request_id + company + not older than request; an old genuine answer, another company's answer, a future-dated one = unavailable. | signed binding fields | lookup.rs accept |
| F4 | No cache, no stale-while-error: every lookup response carries cache-control no-store; no code path returns a remembered answer. | headers + test | lookup.rs out() |
| F5 | One honest shape for every failure: 503 {"error":"data_unavailable", request_id, freshness:null}, no fields, no reason why (server log has the cause). Oversize (>64 KB), non-200, garbage, slow-drip all land here. | closed response set | lookup.rs |
| F7 | Circuit breaker: 3 failures in 30 s opens it for 15 s; while open the Desk answers unavailable at once (still audit-first: begin + finish unavailable). Half-open probe after 15 s. | lock-free atomics, no new crate | lookup.rs |
| F8 | D20 database down: begin cannot run = same unavailable shape (no fields); database lost between begin and finish = the answer is NOT shown (audit line could not be closed), row stays requested and the AD4b sweep makes it abandoned. | PostgreSQL + test that kills the backend mid-lookup | lookup.rs + test |
| F9 | Kernel (Rule 52, Rust WASM): lookup answer is shown only if signature + path + method + nonce (bound to THIS call, so a recorded answer cannot be replayed) + clock pass AND answered_at is at most 15 s older than the Desk's own signed envelope time (a wrong laptop clock cannot hide stale data) AND request_id and company equal what the page sent AND HTTP status is 200; else the kernel returns state "unavailable". Pure function `lookup_view(status, body)` maps every non-OK, stale, replayed or malformed thing to unavailable, so the 1j screen cannot show old data. | Rust WASM kernel | kernel/src/wire.rs + lib.rs |
| F10 | Tests: plane double variants (down, hang, slow, garbage, oversize, old answer, replayed answer, other company, future, wrong key, wrong status), real HTTP/3 loopback with a Control Plane that never answers, D20 both modes, breaker open/half-open/close, kernel stale + replay + wrong request. | cargo test, scratch PostgreSQL | tests |
| F11 | Live proof: real binary against the scratch PostgreSQL with the Control Plane port closed = unavailable and audit rows closed; then his install + my Chrome look (door answers sealed). | e2e script | scripts |

## Honest limits
1. The text "Data unavailable" on the screen is phase 1j (the screen); 1i proves the data layer and the kernel can never hand old data to a screen.
2. The Control Plane has its own refusal log; unavailable here does not mean the Control Plane did nothing.
3. Breaker state is per Desk process (restart resets it).

## STATUS 23 Nov 2026 02:5x PKT (honest)
F1, F2, F3, F4, F5, F7, F8, F9, F10 are WRITTEN and PASSED:
- server cargo test: 62 passed (new: freshness 15 s + not older than the request, breaker state machine, no-store on every response, Control Plane that never answers is cut at the deadline (real HTTP/3 loopback), and in the real-PostgreSQL test: old genuine answer, future answer, other-company answer = unavailable with audit line closed; breaker open = unavailable at once; D20 database down BEFORE the audit line = unavailable, no row; D20 database KILLED between audit line and closing = nothing shown, row stays requested).
- kernel cargo test: 9 passed (new: lookup_view fresh / stale / other request / other company / 503 / future / no fields / garbage / unsigned / wrong key / replay for another call / other door / tampered / signed refusal / clock 100 s off still good).
- the real compiled WASM was run in Node with an INDEPENDENT Ed25519 signer: fresh = data; 16 s old, 503, other request, garbage = unavailable.
- TypeScript: tsc clean, bun test 45 pass (4 new for the state mapping), desk bundle built.
Hostile self-audit (what I tried to break): clock drift (fixed: freshness vs the Desk's signed time), stuck half-open breaker (self-heals after 15 s), refusal counted as failure (no: a signed refusal means the plane is alive), 429/403 mapped to unavailable by the kernel (decision for the 1j screen: it will use deskCall error codes for those two), connection cached after DB loss (test kills it), hang without a timer (deadline on session check and on the call).
NOT yet: F11 (his install + my Chrome look; the new SPA bundle and Rust binary reach his server only through desk-install).
