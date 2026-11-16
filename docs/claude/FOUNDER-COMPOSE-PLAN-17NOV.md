# FOUNDER COMPOSE (new message box) - advance plan, 17 Nov 2026 01:55 PKT

His order (17 Nov 01:45, photo of the Gmail compose box): "yeh compose mail ka box gmail ka hai mujhe bhi bana ke do, duniya ka advance level research ker ke features, technology advance level, kaun se features kaun se phase main, steps ke saath, kaun si technology, UI UX kya hoga".

STATUS: PROPOSAL ONLY. UI LAW (12 Nov): the current founder UI is never touched without his haan. Nothing below is built. Step C0 = a demo (artifact) first, his pick, then code.

## What already exists (do not rewrite): founder-web/src/MailCompose.tsx (113 lines, Q1d)
To, Cc/Bcc, Subject, plain textarea, sealed draft autosave with stale-save detection, schedule time, Send, Ctrl+Enter, UndoBar (30 s hold, E177 per-send touch OFF), Discard (E180). Backend: fmail_out.rs doors, fmail_outbox state machine, DKIM dual signature, TLS 1.3 + X25519MLKEM768 out.
Known small defect to fix inside C3: the hint under Send still says "Sending asks for your key touch" although per-send touch is OFF since E177.

## Research summary (17 Nov 2026)
- Undo send in the market: Outlook Mac up to 120 s, Gmail and Apple Mail 30 s, Proton 20 s, Superhuman and new Outlook 10 s. Real recall only inside one Microsoft 365 tenant. Ours is 30 s today: make it settable 5 to 120 s.
- AI drafting in others (Superhuman, Outlook Copilot, Gmail): drafts wait for the user, nothing sends alone. Our law: NO third-party vendor, so no outside AI API. AI in compose = his decision later (own on-server model in Rust or none). Not in the first phases.
- Editors 2026: Lexical (Meta, MIT, JSON state, HTML needs serializers, @lexical/yjs) and Tiptap (ProseMirror, MIT core, HTML export first-class, collab extensions have licensing). For a mail composer the HTML we SEND must be clean and safe: choose by sanitizing, not by features. Proposal: Lexical (small, accessible, React 19) + HTML made by our own serializer + Rust `ammonia` allow-list sanitizer on the server + a text/plain part always sent.
- Sources: aiemaily.com undo-send comparison, pkgpulse editor comparison (2026), zapier/toolradar/guideflow email client roundups.

## Features, each with phase and technology (order = build order)
C0 DEMO + CONTRACT (first, no live UI change): a clickable demo artifact of the new compose at 390 / 820 / 1200, his pick; contract in tech-contracts/CURRENT.md. Tech: React 19 TS, Framer Motion (motion/react).
C1 RECIPIENTS: address chips (Enter, comma, paste many), autocomplete from his own People/contacts (PostgreSQL RLS), drag chip between To/Cc/Bcc, bad address shown at once, "Reply all" safety (count of people). UNIQUE: each chip carries a SECURITY LOCK read from our own checks: "this server takes mail over TLS 1.3 with post-quantum" / "classic TLS" / "no TLS = we will not send" (needs Qtls MTA-STS/DANE results; before Qtls it shows only what Postfix/our SMTP proved on the last send). Tech: Rust door (contacts + domain TLS facts), kernel RPC, PostgreSQL, React.
C2 WRITING: rich text (bold, italic, lists, quote, link, code), plain-text mode toggle, paste-clean (no Word junk), emoji, inline spell check (browser native), saved SIGNATURES (several, per From), SNIPPETS / templates with a slash menu ("/thanks"), variables ({name}). Output: clean HTML + text/plain part. Tech: Lexical, Rust ammonia sanitizer, kernel, PostgreSQL (templates exist in E170 plan), React.
C3 SEND SAFETY + TIME: pre-send check (empty subject, "attached" word but no file, external domain not seen before, big Cc list, reply-all) as a calm bar, never a blocking dialog; undo hold settable 5-120 s; schedule presets (tomorrow 9:00, Monday 9:00, custom, his timezone shown); the Outbox timeline in the bar: queued, signed DKIM, TLS PQ, accepted by receiver (250) from our real ledger (Gmail does not show this); fix the stale key-touch hint. Tech: Rust Tokio exact-time sender (exists), E182 switch, hash-chained ledger, React.
C4 REPLY / FORWARD: inline reply under the mail, quoted text folded, "reply to the selected part", forward as attachment (.eml) or inline, correct References/In-Reply-To (exists). Tech: Rust mail-parser/mail-builder, React.
C5 ATTACHMENTS = the Q3 phase (already ordered): drag and drop, paste image, chunked upload over WebTransport to Tokio, ClamAV scan, sealed on Hetzner Storage Box, progress ring, size limit shown before sending. Tech: Rust Tokio WebTransport, ClamAV, Hetzner Storage Box, WASM kernel for chunk hashing.
C6 ENCRYPT = the Q4 phase: "Encrypt end to end" toggle per mail with OpenPGP PQC (RFC 9980), key shown on the chip; sign with his key. Tech: Rust (rpgp or sequoia, to be proven), kernel.
C7 FOLLOW-UP + DRAFTS EVERYWHERE: "remind me if no reply in N days" (Tokio timer + ledger, stops on reply); drafts sealed in the browser too (AES-256-GCM, IndexedDB via kernel) so nothing is lost offline. Tech: Rust Tokio, WASM kernel, PostgreSQL.
C8 THE SAME BOX ON ALL SCREENS + KEYBOARD + ACCESSIBILITY: ONE build: desktop = docked window bottom right (minimize, full screen, several drafts as tabs), tablet = floating sheet, phone 390 = full-screen bottom sheet with 44 px targets. Shortcuts: Ctrl+Enter send, Ctrl+K command palette, Ctrl+Shift+C cc, Ctrl+Shift+B bcc, Esc keeps the draft. role=dialog, focus trap, aria-live for the saved/undo text, prefers-reduced-motion. Tech: React 19, Tailwind 4, Radix Dialog, Framer Motion.

## NOT built on purpose (his laws)
- Read receipts and tracking pixels: they spy on the other person. Refused.
- Any outside AI / grammar vendor API (vendor ban). AI drafting waits for his decision on an own on-server model.
- "Recall of delivered mail": no mail system can really do it outside one tenant; we say so honestly.

## UI / UX of the box (one look, three layouts)
Cinematic glass card like the rest of the founder site (not a copy of Gmail's grey box): title bar with minimize / full screen / close, From (his address, the DKIM lock beside it), To with chips and a lock on each chip, Cc/Bcc revealed by one link, Subject, the editor with a slim toolbar that appears on focus, a quiet line "Draft saved, sealed AES-256" at the bottom left, Send (primary) + Schedule arrow, then after sending the bar: "Sent. Undo within 27 s" with the 4-step timeline. Colors and ring from FOUNDER-UI-WOW-RULES-11NOV.md (ring one hue). Motion short (150-220 ms), nothing flashes.

## Steps
1 his haan on this plan + his pick: editor Lexical or Tiptap (default Lexical).
2 C0 demo artifact (his look), his changes.
3 Write the technology contract in CURRENT.md, register any missing technology in TECH-LAW-GATE.json.
4 After Q1b4 (the current phase): C1, C2, C3, C4 one at a time, each: SQL (if any) -> Rust door -> kernel -> UI -> tests -> his ONE command -> my live Chrome look at 390/820/1200 -> GREEN with "WIRED: YES / REAL: YES / TECH-LAW CHECKED".
5 C5 with Q3, C6 with Q4, C7 and C8 after, then the audit.
