# DESK BRIDGE LIVE TRANSPORT: HIS DECISION + WHEN RULE 52 AND MoQ ARRIVE (22 Nov 2026 04:15 PKT, his 04:15)
HIS DECISION: option 3, WebTransport (QUIC), is the live transport of the Desk Bridge ("yahi Supabase + Rust architecture par 100% fit"). His questions: when does Rule 52 come in the Admin Desk, when does MoQ come, all detail.
## 1. DECISIONS (ledger lines)
| # | Decision | Detail |
|---|---|---|
| D1 | WebTransport over HTTP/3 is the Bridge's live transport | Rust (quinn + h3 + an h3 WebTransport layer) on the Desk's OWN QUIC listener. PORT: UDP 4400, not 443: his ss/ufw facts (PORTS-LIVE.md): UDP 4400 reserved + ufw allow for the Desk; UDP 443 belongs to the founder. A port change only after his fresh ss paste (red line). |
| D2 | The signed poll doors stay as the FALLBACK | His tech law: WebTransport with seamless fallback. The five doors (/desk/v1/bridge/summary, /alerts, /alerts/act, /services, /incidents) are needed anyway for actions (ack, assign, resolve) and for a browser without WebTransport. Nothing is wasted. SSE is optional later. |
| D3 | Rule 52 on the stream: every message is a signed envelope | Same Desk Ed25519 key (kid e92a4cb169d466a2), same wire format v1 + a stream sequence number: {seq, track, ts, body, sig}. The Desk kernel in the browser verifies EACH message, refuses a gap or a replay of seq, and shows STALE if no signed message arrives for 12 s. The stream is opened with the same session token + request MAC as a normal call. |
| D4 | MoQ: after WebTransport works, tracks named now | MoQ (IETF moq-transport draft, see docs/claude/admin-desk/WORLD-ADVANCE-DESK-22NOV.md W4) fits the Bridge exactly: publisher = Desk Rust, one track per feed (bridge/alerts, bridge/services, bridge/summary), groups = one snapshot + deltas, subscribers = staff screens. We name our WebTransport tracks the MoQ way TODAY so the move is a swap of framing, not a redesign. NOT promised inside the 4 days: it is a draft standard and the Rust/browser pieces must be proven first. |
## 2. WHEN (order, nothing breaks)
| When | Step | Gate |
|---|---|---|
| Now (Sun 22) | 0. PROVE real HTTP/3 to a browser on the Desk (UDP 4400 listener, Alt-Svc, nextHopProtocol h3). Today the browser still shows h2 (his curl: HTTP/2 200) so HTTP/3 is NOT proven: WebTransport cannot start before this. His command: desk-h3-check. | his paste |
| Sun 22 | 1. Signed poll doors (the five above) + Rule 52 (already live since R3d, 22 Nov 01:55) | cargo tests + Chrome |
| Sun 22-Mon 23 | 2. Desk WebTransport server (Rust) + Desk kernel stream client (WASM) with per-message verify, seq, 12 s stale | sandbox + Chrome |
| Mon 23 | 3. Bridge screens read the stream, poll fallback if WebTransport is absent | 390 / 820 / 1200+ |
| Tue-Wed | 4. Fan-out per team (W4) | |
| After 4 days or if time | 5. MoQ track framing + its relay test | draft status checked first |
## 3. HONEST RISKS (no guess)
(a) the h3 crate set the Desk uses is h3 0.0.8: its WebTransport layer must be checked in the sandbox before code, not assumed. (b) Safari / mobile WebTransport support must be tested per browser: the fallback poll covers it. (c) Caddy fronts the site over HTTP/2 today; WebTransport must reach the Desk listener on UDP 4400 DIRECTLY (Alt-Svc h3=":4400"), not through Caddy's TCP proxy. (d) Rule 52 itself is NOT new: the Desk already signs and verifies every sealed door; only the stream framing is new.
## WHERE RULE 52 IS TODAY IN THE DESK: LIVE (R3d, his rerun 22 Nov 01:55: key + signed refusal OK). Dashboard loads /desk/v1/auth/me through deskCall (signed). Every Bridge door will be inside the sealed router (signed.rs guard): no raw fetch.
