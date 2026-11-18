<!--TECHLAW-->
# QLIVE: LIVE MAIL, NO REFRESH (his word 18 Nov 2026 05:16 + 05:24). PHASE NOW, before Q-contacts-kernel.
STATE: IN PROGRESS (plan written 18 Nov 05:4x PKT, code follows). Gate check `Q-live` (founder-web/src/mail_change.ts must contain `mail_live_push`) is open until this is GREEN.
HIS WORDS: "gmail mein mail aati hai to refresh nahi hota, new mail samne aa jati hai; yeh puri website ke liye basic feature hai (awam ke liye bhi); hum ne is ko duniya ki advance technology par karna hai; pehle web research, plan points repo mein, phir SQL 500 lines super advance". Packages (basic, PRO, business, Business PRO are built first; Business Premium and Business MAX are built later, their codes are preserved: every limit lives in one table `tier_limits` below, never hard-coded).

## 1. WEB RESEARCH (standing rule 0, read 18 Nov 2026) and what it forced
| Finding (source) | Decision |
|---|---|
| Today the mail screen does NOT push: `mail_api.ts live()` reads counts + lanes every 5 s (MAIL_POLL_MS), its own comment says "Phase Q3 replaces this with a pushed WebTransport stream". The dashboard already has a pushed WebTransport live stream (E109, wt.rs, h3.rs, livefeed.ts), frames signed and verified by the kernel. | NO new transport: mail rides the SAME verified stream as a new event `mail`. The 5 s poll stays ONLY as the honest fallback when the stream is not live. |
| JMAP (RFC 8620 section 7): push sends a tiny StateChange ("something changed, state = X"), never the data; the client then asks "changes since state X". Stalwart docs: notifications are throttled, merged and can be dropped, so a push is a PROMPT to check, never the record. | Frame = tiny hint (seq, kind, folder id, message id). The truth is always `changes since cursor`. A lost frame costs nothing. |
| IMAP NOTIFY (RFC 5465) + IDLE: server pushes per mailbox events (MessageNew, MessageExpunge, FlagChange). | Our `kind` set mirrors it: arrive, expunge, flags, move, label, draft, outbox, scan, verdict. |
| Postgres LISTEN/NOTIFY: payload cap 7999 bytes, NO delivery if the listener is down, lost on reconnect, breaks behind a transaction-mode pooler (dev.to article, Postgres docs). The proven cure: an outbox TABLE with a monotone id + a cursor; NOTIFY is only the wake-up. | E187 = a per-mailbox append-only change LOG with a gapless sequence (row-locked head, so commit order = sequence order, no hole like a plain SEQUENCE gives) + `pg_notify` of ids only (wake-up for any direct listener). Delivery = at-least-once through the cursor. |
| Our Rust server talks to Postgres over PostgREST (`Sb.rpc`), so it cannot hold a LISTEN connection. | Rust wakes up by an IN-PROCESS poke (intake, send, mail actions all run inside this same binary: zero latency) plus a SAFETY head-check every 2 s while at least one stream is open (one tiny call; a write made by anything else still shows within 2 s; idle server = zero cost). |
| Privacy: a push channel is a metadata channel. | The log holds ids and a closed kind only. No subject, no address, no body, no blind index. Content is always fetched through the sealed doors. |

## 2. THE ADVANCED DESIGN (hybrid, all ours, no vendor)
1. SQL E187 (500+ lines): `fmail_change_head187` (per mailbox: head seq, head hash, floor seq, floor hash), `fmail_change_log187` (append-only, hash-chained: row_hash = SHA-256(prev_hash, mailbox, seq, kind, folder, message, thread, at)). AFTER triggers on fmail_messages, fmail_outbox, fmail_message_labels write the log through ONE internal door that row-locks the head. Doors: since (cursor read, with `gap` when the cursor fell below the floor), head, heads (all mailboxes, for the watcher), verify (recomputes the chain), prune (keeps 14 days / 20000 rows, moves the floor, keeps the floor hash so the chain still verifies), posture, selftest (rolls back).
2. Rust `fmail_live.rs`: process-wide watcher (poke + 2 s safety), `broadcast` hub, new event `mail` on the existing live stream (signed envelope, same Ed25519), signed door `GET /founder/v1/mail/changes?box=&after=&limit=`.
3. Kernel/browser: `mail_change.ts` (pure, tested): cursor, gap rule, coalescing of a burst into ONE refresh (150 ms), what a kind means for the screen. `livefeed.ts` gets `onMail`. `mail_api.live()` becomes push-first: a frame or a cursor catch-up triggers counts + lanes at once; poll only when the stream is not live (then 5 s) and a 30 s safety check when it is live.
4. Screen: new mail slides into the list by itself (Framer Motion, reduced-motion respected), unread badge and the tab title update, no refresh, no flicker, works at 390 / 820 / 1200+.
5. HYBRID layers (listed honestly): WebTransport/QUIC push when the tab is open (this phase); the existing J6 Web Push when the tab is closed (J6 is already GREEN, wiring `arrive` into it = sub-step QLIVE-b, after this phase is GREEN); ML-DSA hybrid signature on frames = already carried by the existing signed envelope, no new work.
6. AWAM: awam inherits the PURE modules (`mail_change.ts` logic, the SQL pattern) later through its own blueprint, its own SQL numbers, its own gate and its OWN pull command (separate from the founder one). Founder and awam are never mixed; awam files stay frozen now.

7. FINDING while coding (18 Nov 06:1x): the shared Rule 52 kernel (web-wasm flive.rs) passes only the live events snapshot / tick / events. A new event name would be dropped, and forking the shared kernel would touch the frozen awam pin. So the push is a normal signed `tick` that carries an extra `mail: {box, head}` object (frame_json in fmail_live.rs, mailPart in mail_change.ts): the kernel verifies it exactly like every tick, no kernel change, no awam change. Q-contacts-kernel (later) will face the same shared-kernel rule.

## 3. tier_limits (codes preserved, enforced later per package)
| Package | Live streams per account | Change log kept | Build status |
|---|---|---|---|
| Basic | 1 | 3 days | later |
| PRO | 2 | 7 days | later |
| Business | 5 | 14 days | later |
| Business PRO | 10 | 14 days | later |
| Business Premium | 25 | 30 days | LATER (code preserved, not built now) |
| Business MAX | 100 | 30 days | LATER (code preserved, not built now) |
Founder lane: 20 streams (live.rs MAX_STREAMS), 14 days.

## 4. SUB-STEPS (each closes with proof)
a) plan + contract + gate check (this file) b) SQL E187 + CHECK_E187 (sandbox selftest) c) Rust watcher + frame + door + tests d) browser pure module + livefeed + mail_api.live + tests e) build, rules-gate, his two install lines f) my live Chrome: send a mail to himself, watch it appear with NO refresh, 390 / 820 / 1200+, then GREEN (WIRED: YES / REAL: YES / TECH-LAW CHECKED).
