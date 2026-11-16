# Q1b4 step d: TRUST RING + DELETE CONFIRM + SENT TIME (UI plan + codes plan) - 17 Nov 2026 02:5x PKT
His orders (17 Nov 02:10 + 02:54): Q1b4 research-based advance UI; "trash par click karo to poochta bhi nahi: do you want to delete? yes/no, advance technology ke saath fix karo". UI LAW: additive only, MailBox.tsx gets ONE-LINE mounts, orb untouched.

## Research (what the world does)
- Gmail shows SPF/DKIM/DMARC only in "Show original"; Proton/Fastmail show one lock or badge; nobody shows a per-mail ring WITH the evidence and a reason list. WCAG 2.2: never colour alone (text label + shape), 24 px minimum target (we use 44), focus visible, reduced motion respected.
- Destructive actions: NN/g + Apple HIG: confirm only what is hard to undo, say exactly what happens, make the safe button the default focus, never "OK/Cancel" but verbs ("Move to Trash" / "Keep"). Native `<dialog>` + `showModal()` gives a real focus trap, Esc, inert background and top-layer with no library.

## Technology
React 19 + TypeScript strict, Framer Motion (ring sweep 160-220 ms, off for reduced motion), native `<dialog>` modal, CSS `@property` angle, Tailwind-free plain CSS files (same as mailbox.css), pure functions in `*_pure.ts` with bun tests, data from the signed Rust doors (`/founder/v1/mail/auth`, kernel-verified GET). No new dependency.

## Codes (new files only; MailBox.tsx = one-line mounts)
1. `founder-web/src/trust_pure.ts` (+ `trust_pure.test.ts`): `ringSegments(facts)` -> 8 segments (SPF, DKIM, DMARC, ARC, TLS, Scan, Sender, Look-alike) each {key,label,tone ok|warn|bad|off,text}; `gradeTone(grade)`; `reasonsText(reasons)`; `outFacts(f)` -> the sentence for outgoing mail ("Signed by anexomail.com (Ed25519 + RSA), delivered over TLS 1.3 post-quantum, accepted by the receiver at HH:MM:SS (250)"); `sentTime(row)` uses `sent_ms` (the 250), never the compose time.
2. `founder-web/src/TrustRing.tsx` + `trust.css`: small ring (score number + grade letter + 8 arcs) on the mail header; click opens "Why this ring?" sheet (reasons list, raw evidence from `/mail/auth`, chain hash head). Outgoing mail: no ring, the facts line instead. "not checked" is honest grey when the server gave no verdict.
3. `founder-web/src/confirm_pure.ts` (+ test) + `ConfirmSheet.tsx` + `confirm.css`: `deleteQuestion(folder, direction)` -> exact words and verbs per case (inbox/archive/spam -> "Move to Trash? You can restore it from Trash"; unsent outbox mail -> "Discard this unsent mail? It will not be sent"; trash -> "This mail is already in Trash"). Native dialog, default focus on the safe button, Esc = keep, Enter on the red button only when focused.
4. `mail_api.ts`: `authFacts(box, message)` (GET /founder/v1/mail/auth, kernel-verified).
5. `mail_pure.ts`: Row gets optional `score`, `grade`, `sent_ms` (additive).
6. `MailBox.tsx`: both trash buttons call `ask()` which opens ConfirmSheet; mount `<TrustRing .../>` inside `.mbx-chips` and the outgoing facts line; Sent time uses `sent_ms`.
## Proof
tsc clean, bun tests green, vite build, then my live Chrome at 390 / 820 / 1200 after his founder-install (SPA is installed by the same command).
