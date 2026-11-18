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

## 8. AUDIT 18 Nov 2026 06:2x (his order: full audit, fix every loophole) and LIVE FINDINGS
| # | Finding | Fix | State |
|---|---|---|---|
| 1 | LIVE: `/mail/changes` answered HTTP 400 (the old `parse_box` refuses every parameter but `box`), so the second tab never updated | `parse_query` reads box, after, limit in one strict pass; unit test uses the exact query the browser sends | fixed, needs his founder-install |
| 2 | A mail ping went to EVERY open stream (tiny metadata leak: "this mailbox is active") | `fmail_live::Owned`: a stream only hears about mailboxes its signed-in user owns | fixed |
| 3 | The change log was never pruned (unbounded growth) | prune every 6 h by the watcher (14 days / 20000 rows, chain verifies from the floor hash) | fixed |
| 4 | The 5 s read stays only as fallback; hidden tabs make no calls (by design) | none needed | ok |
| 5 | Selftest uses `alter table ... disable trigger` inside a rolled-back transaction (short lock on the log table) | accepted: runs on his command only | noted |
| 6 | His dashboard alert "6 requests blocked in the last 24 h": all 6 = ONE session LbDzb2Iz, `why: no_cookie`, in 3 pairs 2 s apart (03:56, 04:53, 05:22); `reject_replay` = 12, `refreshed` = 114 in the same 24 h. Each pair = the kernel exchange attempt + its fetch fallback, both without a valid bound cookie, right when a DBSC refresh was rejected as a replay. Not an attacker, but real denials. | cause is read from CHECK_BLOCKED_TIMELINE (his paste), not guessed; then a fix in dbsc.rs / api.ts with tests | FIX WRITTEN 18 Nov 06:3x: dbsc.rs 10 s duplicate-refresh window (same session + same challenge), cargo 447/447; needs his founder-install, then watch blocked_24h stop rising |
Order after QLIVE is GREEN: Q-contacts-kernel (his 05:00 order, shared Rule 52 kernel rule applies: no fork of the awam pin), then QC1c, the rest of the Q series, QSPEED.

## 9. FEATURE LIST vs REPO vs LIVE CHROME (his 18 Nov 06:38 order, checked 06:5x PKT)
| Feature he listed | Repo | Live (my Chrome) |
|---|---|---|
| Push, not poll (signed tick mail{box,head}) | fmail_live.rs, livefeed.ts mailPart | PROVEN: tab A title (2)->(3) in about 2 s, both directions, Live pill on |
| Counts + tab title "(3) Mail" | MailBox.tsx titleWith | PROVEN |
| 14 change kinds | E187 check + KINDS (same list), 33/33 selftest | read/unread proven live; other kinds by SQL selftest |
| Gap = full refresh, burst = 1 refresh (150 ms), reconnect catch-up, 5 s fallback / 30 s safety | mail_change.ts + 9 bun tests, mail_api.live | by unit tests only, NOT forced live |
| New mail slides into the list | MailBox.tsx arrival pill + list reload | NOT seen live (needs a real incoming mail) |
| Privacy (ids + kind only) | E187 columns, CHECK_E187 9/9 | by SQL, door answers 401 without the signed token |
| Rollback FOUNDER_MAIL_LIVE=off | fmail_live::start | not toggled |
| Live bundle = repo | live index-BKWy-ioS = repo dist at 8cb9c7df; newer dist (DInNMywS, 47ee79d5) differs ONLY by system_brain.json text, no code | blocked_24h still 6 after the dup-refresh install (not rising) |

## 10. LINE-BY-LINE MATCH, 18 Nov 06:5x (his order: every listed feature, in repo or not)
All 10 features and all 5 code rows exist in the repo (file + line checked): push tick (fmail_live frame_json, livefeed mailPart), cursor door (changes_ep), 14 kinds (E187 triggers: arrive/sent/draft on insert, move, read/unread, star/unstar, scan, verdict, expunge, outbox, label/unlabel), gap rule + 150 ms coalesce + reconnect catch-up + visibility poke + 5 s/30 s (mail_change.ts, mail_api.live), idle = zero DB calls (receiver_count()==0 -> continue), privacy (ids + kind columns only), rollback FOUNDER_MAIL_LIVE=off, slide-in list rows (MailBox motion.li, reduced-motion respected).
NOT in code / not complete (honest list): (a) tier stream limits: table fmail_tier_limits187 + door fmail_tier_limit187 exist, but the Rust stream cap is still the flat live.rs MAX_STREAMS 20 (per-package enforcement = later, with the packages; Premium/MAX codes preserved); (b) 'draft' is logged on insert only, an in-place draft edit made on another device is not announced (a draft discard or move is); (c) not seen live: the slide-in of a real incoming mail, gap, burst, reconnect, FOUNDER_MAIL_LIVE=off. No code changed in this pass, so no new install is needed.

## 11. FIXES FOR THE HONEST OPEN LIST (his 18 Nov 06:44 order: "loophole fix kero, phir pull command")
| Gap from section 10 | Fix | Proof |
|---|---|---|
| (a) per-package stream limits not enforced | `stream_tier.rs`: per-account admission with the 7 packages, numbers PARSED from E187 in a test (no drift), refusal = 503 `stream_limit` + Retry-After 5, browser keeps its 5 s read; Premium/MAX preserved with built = false; awam side written in AWAM-QLIVE-TIERS-18NOV.md | cargo tests |
| (b) a draft edit on another device was not announced | SQL E188 (QC1c now takes E189): triggers on fmail_draft_versions (new version) and fmail_drafts.discarded_at write a `draft` line through the E187 door | sandbox PG16 chain E167..E189: selftest 7/7, CHECK_E189 5/5, CHECK_E187 9/9 still ok |
| (c) slide / gap / burst / reconnect / rollback never forced | `founder-web/sim/mail_live.sim.test.ts` drives the REAL mail_api.live() against a fake E187 server and a fake stream (9 scenarios). Run: `bun test ./sim` (kept out of the normal run because bun's mock.module is process-wide). It FOUND TWO REAL BUGS, both fixed: (1) a network error inside the cursor door was an unhandled rejection and the screen never said "reconnecting"; (2) after the stream dropped the 30 s safety timer kept waiting instead of dropping to the 5 s fallback | bun 355/355 normal run + 9/9 sim, tsc clean |
