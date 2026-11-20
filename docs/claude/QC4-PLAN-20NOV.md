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

## STATUS 20 Nov 2026 09:10 PKT
QC4-2 DONE (20 Nov 2026 09:10 PKT): founder-web/src/reply_pure.ts + 13 golden tests (pure TypeScript, sandbox runner only): replyTargets (reply, reply all, me removed, dedupe, Reply-To), subjects (Re once, Fwd once), replyBody (selection replaces whole mail), forwardBody, splitQuote (Gmail, wrapped, Outlook, forwarded, trailing block; never loses a character), referencesFor (RFC 5322 3.6.4, max 20 keep root). tsc clean, all pure-TS tests pass, vite build OK. NEXT: QC4-3 Rust References from the stored parent, then QC4-4 UI (InlineReply, buttons, fold chip, selection reply, forward), QC4-5 tests, QC4-6 his one install, QC4-7 my live look.

## THE SPLIT, TWO SUBPHASES, ONE INSTALL (20 Nov 2026 09:30 PKT, his order 09:00: one phase QC4, at most 2 subphases)
QC4a = SERVER AND DATA (Rust + Tokio + axum, kernel API, pure TypeScript). Written and tested FIRST, no screen change.
- Feature 7, correct References: Rust Summary gets "references" (the opened mail's own References header, max 40) and "reply_to" (its Reply-To header); the open door already returns the summary, so the browser gets them with no new door. The reply sends references = referencesFor(parent references, parent Message-ID) (reply_pure.ts, DONE) and the send door re-validates every id (msgid_ok, max 20, already in fmail_mime.rs).
- Feature 3 data: Reply-To (needed for reply all and for lists) comes from the same summary.
- mail_api.ts: send carries references; types updated. All through the kernel RPC.
- Pure TS reply_pure.ts + 13 tests: DONE (reply, reply all, subjects, quote, selection, forward block, fold split, References chain).
QC4b = THE SCREEN (React 19 + TypeScript + Tailwind + Framer Motion), additive mounts only.
- Feature 1 inline reply panel under the opened mail (same editor, pre-send bar, schedule presets; pop-out to the full window).
- Feature 2 Reply / Reply all / Forward buttons (44 px, every size) and keys r, a, f.
- Feature 3 Reply all button using replyTargets, bar warns above 20 people.
- Feature 4 quoted text folded behind a "..." chip (splitQuote), full quote kept in the sent mail.
- Feature 5 reply to the selected part (read-only window.getSelection).
- Feature 6 forward inline block + "Fwd:" once.
Then ONE founder-install, then my live Chrome look (read-only: a reply is only SAVED as a draft or sent to nobody; I never send a real mail).
## CORRECTION OF MY EARLIER PLAN (honest)
I first wrote "the send door builds References from the stored parent". The code shows that cannot work for every mail: a mail with seal_mode recipient_pq is sealed FOR the browser kernel; the server cannot open it (fmail_ep.rs open_ep returns sealed_for_kernel). So the parent's References are read where the mail is opened (server for vault mail, summary_json; kernel for pq mail) and sent back with the reply; the send door re-validates them. For pq mail the kernel summary does not carry References/Reply-To until the kernel is rebuilt: the reply then uses [parent Message-ID] only (still threads correctly by In-Reply-To), logged as a gap for the kernel (web-wasm) update.
## STATE 20 Nov 2026 09:30 PKT
QC4a Rust edit (Summary.references + test) is on branch wip-qc4a ONLY (not main) because cargo has not run yet and his founder-install builds origin/main; it merges to main after the WHOLE cargo suite passes. Reply_to still to add in the same edit.

## STATUS 20 Nov 2026 09:55 PKT
QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcANl4MB). Rust edit was kept on branch wip-qc4a until cargo passed, then only the code files were brought to main. QC4a TECHNOLOGY, in plain words (written for the next Claude): RUST + TOKIO + AXUM: fmail_core.rs summarize() now reads the mail's References header (max 40 ids) and Reply-To header (addresses) with mail-parser 0.11.5; summary_json() hands both to the browser inside the existing open door (no new door, no new SQL), so a reply learns the thread chain where the mail is opened. The send door (fmail_mime.rs parse_compose, unchanged) RE-VALIDATES every id (msgid_ok, max 20) and writes In-Reply-To + References, so the browser is never trusted blindly. WASM KERNEL RPC: nothing new; mail_api.send already spreads the compose body, the send target hash does not include references so touch checks stay identical. REACT 19 + TYPESCRIPT: MailBox reply passes referencesFor(opened.sum.references, message_id) (reply_pure.ts, RFC 5322 3.6.4, max 20, thread root kept); MailCompose sends references. SQL: none. KNOWN GAP: recipient_pq mail is opened by the browser kernel (web-wasm), whose summary does not carry References/Reply-To until the kernel is rebuilt; such a reply sends [parent Message-ID] only and still threads by In-Reply-To. NEXT: his ONE founder-install for QC4a (Rust binary + bundle), then QC4b the screen (inline panel, Reply/Reply all/Forward buttons + keys r a f, fold chip, selection reply, forward block, reply all warn above 20), then my live look.


## HIS APPROVED FEATURE LIST, VERBATIM (his paste 20 Nov 2026 09:12 PKT, added to the repo at his order)
QC4a (server aur data)	Feature 7 (sahi References): Rust mail ke References aur Reply-To header padhega. Feature 3 ka data (Reply-To). mail_api.ts mein send ke saath references. Pure TS reply_pure.ts + 13 tests bane hue hain. QC4 ka poora plan
Technology (har hissa kis cheez par):
* Pure TypeScript (reply_pure.ts): reply aur reply all ke recipients, subject, quote, fold aur References ka hisaab. Yeh bana hua hai.
* Rust + Tokio + axum: send door parent mail se References khud banayega. Browser par threading headers ka bharosa nahi karenge.
* Kernel RPC: mail_api.ts ke zariye, koi raw fetch nahi.
* React 19 + TypeScript + Tailwind + Framer Motion: inline panel aur buttons.
* PostgreSQL: naya SQL nahi chahiye, kyunke door ke paas parent mail pehle se readable hai.
Features ki list (QC4 mein kya banega):
1. Inline reply: mail ke neeche panel, popup nahi. Editor, pre-send bar aur schedule presets Compose wale hi hain, aur ek pop-out button hai.
2. Reply, Reply all, Forward: teen buttons, har screen size par 44 px. Keys: r, a, f.
3. Reply all: aap khud nikal diye jate hain, duplicate hat jate hain, Reply-To ka lihaaz hota hai. 20 se zyada log hon to bar warn karegi.
4. Quoted text fold: purana quote "..." ke peeche band, ek tap se khulta hai. Bheji gayi mail mein poora quote rehta hai.
5. Selected hisse ka reply: mail mein kuch select karke Reply dabayein to sirf wohi quote hota hai.
6. Forward (inline): "Forwarded message" ka block (From, Date, Subject, To) aur "Fwd:" sirf ek baar.
7. Sahi References: ab UI sirf In-Reply-To bhejti, aage server poori chain banayega (max 20, thread ki jad rakhi jayegi).

NOTE (my 09:30 correction, shipped in QC4a 09:55): the Rust bullet and feature 7 wording above are SUPERSEDED in HOW, not in WHAT: the References chain is read where the mail is opened (summarize/summary_json: References + Reply-To), the reply sends it, and the send door re-validates every id; the server cannot open recipient_pq mail. All 7 features stay as he wrote them.

## THE 7 FEATURES vs THE REPO CODE, MATCHED (20 Nov 2026 10:05 PKT, his order 09:10: put the full plan in the repo and match it to the codes)
His list (my first QC4 plan text, now in the repo) compared line by line with what the code really contains. Checked by grep of the source, not from memory.
| # | Feature | Pure logic (reply_pure.ts, 13+1 tests) | Rust / data | Screen (React) | Status |
|---|---|---|---|---|---|
| 1 | Inline reply panel under the mail, same editor + bar + presets, pop-out | n/a | n/a | InlineReply: NOT IN CODE | QC4b |
| 2 | Reply, Reply all, Forward buttons (44 px) + keys r, a, f | n/a | n/a | Reply button + key r exist (opens the Compose window, MailBox.tsx reply()); Reply all, Forward, keys a and f NOT IN CODE | QC4b |
| 3 | Reply all (me removed, dupes removed, Reply-To honoured, warn above 20) | replyTargets, hasOthers: IN CODE, tested | Reply-To read in summarize() + open door: IN CODE (cargo 559/0) | button + 20-person warn NOT IN CODE (bar rule exists in QC3) | data DONE, screen QC4b |
| 4 | Quoted text folded behind "..." | splitQuote: IN CODE, tested (never loses a character) | n/a | fold chip NOT IN CODE | QC4b |
| 5 | Reply to the selected part | replyBody(selection): IN CODE, tested | n/a | window.getSelection read NOT IN CODE | QC4b |
| 6 | Forward inline block, "Fwd:" once | forwardBody, forwardSubject: IN CODE, tested | n/a | Forward UI NOT IN CODE | QC4b |
| 7 | Correct References / In-Reply-To | referencesFor: IN CODE, tested | summarize() reads References (max 40), send door re-validates (max 20, fmail_mime.rs): IN CODE | MailBox reply passes references, MailCompose sends them: IN CODE (source test) | DONE, not installed |
## Two lines of the pasted plan are SUPERSEDED (do not follow them)
- "send door builds References from the parent itself": WRONG for recipient_pq mail (the server cannot open it). Real design: References + Reply-To are read where the mail is opened (summary), the reply sends them, the send door re-validates. Section "CORRECTION" above.
- "PostgreSQL: no new SQL because the door can read the parent": true that no SQL is needed, but for a different reason (nothing is looked up server-side).
- "UI only sends In-Reply-To": that was the OLD state; since QC4a (c2ff627c) the reply also sends references.
## One-line truth
Code today: feature 7 DONE end to end (not installed); feature 3 data DONE; features 1, 2 (reply all, forward, keys a/f), 3 (button), 4, 5, 6 screens = QC4b, not written. Pure logic for all of them is written and tested.
