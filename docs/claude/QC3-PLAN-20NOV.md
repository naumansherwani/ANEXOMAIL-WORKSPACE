# QC3 (FOUNDER): PRE-SEND CALM BAR + SCHEDULE PRESETS + DELIVERY TIMELINE. PLAN, 20 Nov 2026 07:15 PKT. His order 07:09: "in sab ek hi jawab hai jo duniya ka best ho", web research, plan in repo, advanced code, start. ONE phase (QC3-A server, QC3-B browser = two steps of the SAME phase; GREEN only when both are WIRED: YES / REAL: YES / TECH-LAW CHECKED).
AFTER A COMPACTION: read this file, then tech-contracts/CURRENT.md top block "QC3", then `python3 docs/cursor-work/server/rules-read.py`. QC3a (Send now) is already GREEN. Next free SQL = E195.

## RESEARCH (opened and read 20 Nov 2026)
- Gmail Reply-All BCC banner (Jul 2026): a WARNING with a suggestion, never a block.
- Gmail attachment reminder: fires only on Send, when the text mentions an attachment and none is attached (waits for Q3 here).
- Undo send: 5 s default, up to 30 s (we keep 30 s + Send now).
- Delivery stages are queued, deferred (4xx), bounced (5xx), delivered; retries start about 1, 5, 15 min and grow; give-up about 5 days; RFC suggests at least 30 min between retries; status must come from delivery events, not the first accept.
- A bounce goes to the envelope return path, never the From header (backscatter).

## HIS 4 QUESTIONS, ONE BEST ANSWER EACH (his word 07:09: decide the best, no more asking)
1. Bar = WARNING ONLY, never blocks, one calm inline line (no popup), one press "Send anyway". Reason: Gmail and Superhuman do the same; a blocking check trains people to click through. Each warning has a plain reason and, where possible, a one-press fix.
2. Presets (PKT, server keeps UTC): Later today (+3 h), Tonight 20:00 (hidden after 20:00), Tomorrow 09:00, Monday 09:00 (next Monday), Custom. A preset is never inside the 30 s undo window (E170 refuses that).
3. Timeline = Sent mail detail only. The Undo bar stays as it is (his UI law: no touching what he likes).
4. Recipient limit = 20 across To+Cc, warn "Bcc kar len?" with a one-press move of Cc to Bcc. Bcc itself is never warned.

## WHAT THE DATA ALREADY HAS (checked)
fmail_outbox: state queued|scheduled|sending|sent|failed|cancelled|undone, attempts, last_error, smtp_reply, rcpt_count, tls_out, dkim_signed, undo_until, not_before, next_attempt, released_at, created_at, finished_at. Ledger: send_queue, send_schedule, send_release, send_undo, send_start, send_ok, send_fail, send_cancel. Existing list door fmail_outbox_list170 only shows 1 day and misses created_at, next_attempt, smtp_reply, released_at.
HONEST LIMIT: the ledger knows the hand-off to the recipient's server (SMTP accept), not the inbox. The timeline says "Accepted by the recipient's server", never "read" or "in inbox". Per-recipient rows are not stored today (rcpt_count only), so the timeline is per mail.

## POINTS (build and prove in this order)
QC3-1 contract in CURRENT.md (technology first).
QC3-2 SQL E195 (+CHECK_E195, selftest, pglite PG17 proof): `fmail_outbox_timeline195(p_mailbox, p_message)` read-only, security definer, service_role only, no content (no sealed columns): the outbox row facts + that message's ledger events in order (action, time, no payload). Forced ownership by mailbox.
QC3-3 Rust door GET /founder/v1/mail/timeline?box=&message= (signed, own_box check, same shape rules as outbox_ep) + pure `fmail_timeline` step builder with cargo tests (queued, undo, released, scheduled, sending, deferred with attempts + next retry + reason, sent, failed, cancelled, undone).
QC3-4 Browser pure module `presend_pure.ts` (checks: empty subject, >20 rcpt, unfilled placeholders, no-mail domain from QC1c facts; `presets(now, tz)` PKT; `timelineSteps(row)` labels) + bun tests with golden cases (DST-free PKT, Monday edge, 20:00 edge, 21:00+ edge).
QC3-5 UI: MailPresendBar (inline, role=status, aria-live polite, 44 px buttons, Send anyway), schedule preset menu replacing the raw datetime-local as the first choice (Custom keeps it), MailTimeline in Sent detail. Additive mounts only; the QC2 placeholder warn-once is folded INTO the bar (same behaviour, one place).
QC3-6 tests: tsc, bun, vite build, sandbox under his REAL CSP at 390/820/1280 (Playwright harness in scratchpad rt/), rules-gate.
QC3-7 his ONE sql-run (E195) + ONE founder-install, then my live Chrome look (never send a mail, never write his sealed data). Phone 390 / tablet 820 by his screenshots.

## NOT IN QC3
Attachment-word check (Q3), per-recipient delivery rows (needs a recipients table: logged as OPEN GAP), SPA update after install (QC8 or earlier), AI drafting (dropped to Jul 2027).

## STATUS 20 Nov 2026 07:30 PKT
QC3-1 contract DONE. QC3-2 E195 DONE AND RUN ON HIS SERVER (his sql-run 07:26: 70 passed, 0 failed, CHECK_E195 7/7 OK). QC3-3..7 OPEN.
QC3 TECHNOLOGY PER STEP (my explanation to him 20 Nov 07:23, his order 07:26 to write it word for word everywhere): PostgreSQL (SQL): DONE. E195 written, sandbox 70/0, and RUN ON HIS SERVER 20 Nov 07:26 PKT: his sql-run paste shows e195_selftest_passed 70 / failed 0, CHECK_E195 all 7 OK, CHECK_E65 all OK (SQL part only, the phase is NOT green). Rust + Tokio + axum (async): NEXT STEP, QC3-3. Signed door /founder/v1/mail/timeline is an async axum handler and runs on the Tokio runtime, like the other mail doors. Not written yet, so not in code yet. WASM kernel: QC3-5, when the screen's API call is written. The timeline call goes from mail_api.ts through the kernel RPC (WebTransport/HTTP/3), never raw fetch; rules-gate refuses a commit when the fetch count rises. New WASM code in the kernel: NOT in this phase. The kernel is already live (K8d) and is reused. Pre-send checks and presets are computed in the TypeScript pure module presend_pure.ts, like mail_pure.ts. If he wants those checks inside the Rust WASM kernel instead, he says so; that changes the QC3-4 design, so his word is needed before QC3-4 starts.
