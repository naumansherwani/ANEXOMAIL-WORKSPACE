# QC4 PLAN, inline reply and forward (20 Nov 2026 08:58 PKT). Phase table: FOUNDER-MAILBOX-PHASES-18NOV.md row 8. Contract: tech-contracts/CURRENT.md (top block).
## What exists today (read from the repo, not guessed)
- Reply opens the compose window (MailBox.tsx line 144) with "Re: subject", a "> " quoted body and in_reply_to + reply_to (draft link). Subject helper replySubject, quote helper quoteReply (mail_pure.ts).
- Rust Compose already has in_reply_to and a references list (fmail_mime.rs lines 20, 124-125); the UI never sends references, so the References chain is NOT built (a real gap against RFC 5322 3.6.4).
- NOT existing: Reply all, Forward, inline reply under the mail, quoted text folded, reply to the selected part.
## Best answers (single best, his 07:09 style)
1. Inline reply = a panel UNDER the opened mail (no popup), same editor + same pre-send bar + same schedule presets as Compose (reuse MailCompose body, do not copy it). Pop-out button turns it into the full Compose window.
2. Reply, Reply all, Forward are three buttons on the opened mail (44 px, every screen size). Keys: r reply (exists), a reply all, f forward.
3. Reply all = original From + To + Cc minus my own addresses, de-duplicated (case-insensitive), Reply-To header respected when present; the bar warns when more than 20 people (QC3 rule).
4. Quoted text folded: in the reading view and in the inline editor the quoted tail is collapsed behind a "..." chip (Gmail/Outlook way); one tap opens it. Sent mail keeps the full quote (standard).
5. Reply to the selected part: if text is selected in the opened mail, Reply quotes ONLY that selection (read-only window.getSelection; no HTML parse; Trusted Types safe).
6. Forward inline: "---------- Forwarded message ----------" block with From, Date, Subject, To, then the original text. Subject "Fwd: ..." once.
7. Forward as .eml = needs the attachment pipeline (Q3: Hetzner Storage Box + ClamAV). NOT in QC4; logged in CLOSE-THE-GAPS and planned inside Q3.
8. References / In-Reply-To correct: the SERVER builds References from the stored parent (parent's References + parent's Message-ID, newest last, trimmed to 20 as RFC 5322 advises) when the send door gets reply_to = parent id. The browser is never trusted for threading headers.
## Points
QC4-1 contract + plan (this file, CURRENT.md). QC4-2 pure TS reply_pure.ts + golden tests. QC4-3 Rust door change (References from the stored parent) + cargo (whole suite, never filtered). QC4-4 UI: InlineReply, buttons, fold chip, selection reply, forward; additive mounts only. QC4-5 tests (tsc, pure-TS tests, cargo, vite, real-CSP harness 390/820/1280). QC4-6 his ONE founder-install. QC4-7 my live Chrome look on his site (no real send: a reply to my own address only if he allows; otherwise bar and draft only).
## NOT in QC4
Forward as .eml (Q3), attachments (Q3), AI drafting (dropped to July 2027), per-recipient delivery rows (QC3 gap).
