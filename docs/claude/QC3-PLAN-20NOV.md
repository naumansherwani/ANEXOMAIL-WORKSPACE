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

## STATUS 20 Nov 2026 07:42 PKT
QC3-3 (Rust + Tokio + axum timeline doors, commit 86b37e9d, cargo 558/0) = HIS founder-install RUN at 07:40 (his word); his output paste NOT seen yet, so no saboot line (healthz, SPA, Ed25519) is recorded and QC3 is NOT green. QC3-4 (presend_pure.ts, 50 bun tests, bun 454/0) pushed ced1f86d. NOW QC3-5 UI. TECHNOLOGY OF QC3-5 (written BEFORE code): React 19 + TypeScript + Tailwind 4 + Framer Motion (reduced motion respected) for MailPresendBar, schedule preset menu and MailTimeline in Sent detail; every API call goes through the Rust WASM kernel RPC (WebTransport/HTTP/3) from mail_api.ts, never raw fetch; Trusted Types safe (no innerHTML); same code at 390/820/1200+, 44 px targets; existing cinematic UI untouched, additive mounts only.

## STATUS 20 Nov 2026 07:48 PKT
QC3 PROGRESS TABLE (his order 07:46, write it everywhere): QC3-1 contract = DONE. QC3-2 SQL E195 = DONE and RUN ON HIS SERVER (70/0, CHECK 7/7). QC3-3 Rust + Tokio + axum doors (fmail_timeline.rs) = WRITTEN, cargo 558/0, commit 86b37e9d, his install RUNNING now, paste not seen. QC3-4 presend_pure.ts + 51 bun tests = DONE (pure-TS tests 455/0 (sandbox test runner, not a runtime)). QC3-5 UI (MailPresendBar, SchedulePresets, MailTimeline, mail_api via kernel RPC, mounts in MailCompose + MailBox) = WRITTEN, commit 7b5a6021, his install RUNNING now (he says both pull commands are being installed), paste not seen. QC3-6 tests = DONE in sandbox (tsc clean, pure-TS tests 455/0 (sandbox test runner, not a runtime), cargo 558/0, vite build, real-CSP harness 390/820/1280 no errors). QC3-7 = OPEN: his install paste (healthz, SPA, Ed25519) + my live Chrome look (clear anexo-assets-v1 cache first, never send a mail) + 390/820 live; QC3 is NOT green until then and his word. STILL OPEN after QC3: Sent-list badges not on screen yet (API ready), per-recipient delivery rows, SPA update after install, attachment-word check (Q3).

## STATUS 20 Nov 2026 08:12 PKT
QC3 SABOOT (his founder-install paste, 2 runs, 20 Nov 2026 08:12 PKT): SPA index=200, exchange bina token=401, Ed25519 signing ON kid s1 write-request signature ENFORCED, public key endpoint=200, healthz=200, me bina token=401, bridge bina token=401, OK founder service zinda. => QC3-3 Rust doors + QC3-5 bundle INSTALLED on his server. QC3-7 now = my live Chrome look (started 20 Nov 2026 08:12 PKT). PHASE ORDER: QC3 (now, QC3-1..6 done, QC3-7 live look running) -> QC4 -> QC5 -> QC7 -> QC8 -> Q3. QC1c green by his word; QC0 green; QC3a done earlier. QC3 NOT green until live look + his word. Test runner wording: pure-TS tests 455/0 are a sandbox runner, NOT a runtime.

## STATUS 20 Nov 2026 08:25 PKT
QC3-7 LIVE LOOK (20 Nov 2026 08:25 PKT, my Chrome, his founderworkspace.anexomail.com, 1536 wide): live bundle index-DhaYIeTm.js contains the QC3 code (mail/timeline, presets). SENT timeline PROVEN LIVE on real mail 'QC3a send now proof': Queued 11:30:16, Send now pressed 11:30:22, Handed over (1 try) 11:30:25, Accepted by the recipient's server 11:30:25, line '1 recipient. Accepted means the recipient's server took it. Whether it reached the inbox is not something any server tells us.', Refresh + Show tries (1). COMPOSE PRESETS PROVEN LIVE: Later today 11:15, Tonight 20:00, Tomorrow 09:00, Monday Mon 23 Nov 09:00, Custom date box; no console errors. NOT PROVEN: calm pre-send bar firing (needs a recipient, I never risk a real send), 390/820 live (window resize did not change the viewport, innerWidth stayed 1536), Sent-list badges (not mounted). I sent no mail and wrote nothing.
