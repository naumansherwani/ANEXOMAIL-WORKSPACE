# COMPOSE RESEARCH (17 Nov 2026 06:4x PKT, his order 06:29: "web research kero, repo mein likho kya research kiya, phir codes plan, phir advance codes")
Scope: founder side only. Three decisions: the editor (QC2), the phone compose layout (QC0b / QC8), the undo window and "send now" (QC3). AI drafting is DROPPED until the AI product (his word 06:29, July 2027).

## 1. Editor (decides QC2)
Sources read: PkgPulse "Tiptap vs Quill vs Lexical vs Slate 2026" (npm weekly distributions 23 to 29 Oct 2026: @tiptap/core 33.0 M, lexical 8.4 M, quill 8.1 M, slate 4.1 M; versions Tiptap 3.32.2, Lexical 0.53.0, Slate 0.147.4); its notes: Tiptap = "first-class" HTML output, default choice for new React product editors; Lexical = HTML needs serializers, explicit control, own infrastructure; Slate = you own serialization; Quill = last release 2.0.3 on 30 Nov 2024 (not moving). Search results also listed Tiny, Velt, Guideflow, Eddyter roundups (no facts used beyond the above).
MEASURED HERE (my sandbox 17 Nov, esbuild --minify, React 19, a minimal rich editor with bold, italic, lists, quote, link, history, HTML export): Lexical 0.53.0 = 631,999 B raw / 203,503 B gzip; Tiptap 3.34.0 (StarterKit, ProseMirror) = 636,224 B raw / 199,150 B gzip; React alone = 222,729 B raw / 68,852 B gzip. So the editor costs about 135 KB gzip (Lexical) vs 130 KB gzip (Tiptap): NO size advantage for Lexical, my earlier assumption was wrong. Both MIT.
Why it matters for MAIL: the HTML we send must be clean and safe. ProseMirror (under Tiptap) has a strict SCHEMA: a document can only hold the node and mark types we allow (paragraph, hard break, bold, italic, underline, link, bullet and ordered list, blockquote, code), so a pasted Word or web page cannot smuggle other tags into the model; generateHTML is first-class; second wall = Rust `ammonia` allow-list on the server; third = a plain-text part always sent.
DECISION (changes my 17 Nov 01:55 proposal, honest): TIPTAP 3 (ProseMirror) with a restricted schema + custom paste rules; collaboration extensions NOT used (no licensing question). Lexical stays the fallback if a proof in QC2 fails (Android IME, paste, undo). Final proof is the QC2 contract.

## 2. Phone compose layout (decides QC0b, QC8)
Sources read: screensdesign.com "bottom sheet vs full screen mobile UX": a sheet fits a brief decision about an object already on screen; a FULL SCREEN fits sustained attention, several related inputs and a stable place to return to; "a software keyboard can consume much of a short sheet"; long text input = a dedicated screen; define a draft and say whether leaving keeps it. Search results on Gmail for Android and the Superhuman mobile redesign (blog) show full-screen compose with the send action in a fixed place; Fastmail multi-window compose.
DECISION: FULL-SCREEN on the phone (not a half sheet), with: a draft that is ALWAYS kept (leaving, swipe-down or Back minimizes to Drafts, never discards; Discard is a separate explicit button with a confirm), Send and the formatting row pinned ABOVE the keyboard (visualViewport + dvh, 44 px targets), safe-area insets, no nested sheets (schedule menu = a small popover, not a second sheet). Tablet 820: floating sheet. Laptop: docked window bottom right with minimize / full screen and several drafts as tabs.

## 3. Undo send and "send now" (decides QC3)
Sources read: Superhuman blog "how to unsend an email": undo send = the mail is HELD 5 to 30 s before it leaves; Gmail desktop up to 30 s, Gmail mobile 5 s; Outlook web up to 10 s, no undo on Outlook mobile; Superhuman undoes with Ctrl/Cmd+Z; the article names NO way to skip the wait. 
DECISION (his word 06:29): keep 30 s. NEW: on the undo bar the X ("Send now") releases the mail at once instead of waiting 30 s; the other button stays "Undo". Needs a server door: SQL E185 `fmail_outbox_release_now` (only a row in state `queued`, never a `scheduled` or cancelled one: sets not_before = now(), ledger line `send_release`), Rust door POST /founder/v1/mail/release (signed, passkey policy as normal send), UI. Settable 5 to 120 s stays a later option, not first.

## 4. Dropped
AI drafting / grammar help: dropped until the AI product (July 2027). Read receipts and tracking pixels: refused (spying). Recall of delivered mail: impossible outside one tenant; said honestly in the UI.

---
## 17 Nov 2026 07:20 PKT - HIS ORDER (07:05): Gmail-level compose, window states, rim to the top, send shimmer in logo colours
Method note (honest): the web searches of 17 Nov 07:1x returned result lists (titles of Gmail help pages, Superhuman reviews, CSS animated-border guides); I did not open every page, so the feature table below is the well-known public feature set of those products, and each row says which technology Anexomail uses. Anything marked LATER is already a sub-phase in FOUNDER-COMPOSE-PLAN-17NOV.md.

### A. Window states (Gmail: minimize, pop-out / full screen, close) -> QC0d, BUILT 17 Nov
- normal (centred, as he sees today) / large (expand button, up to 1100 x 92% height) / minimized bar (bottom-right, restores with one click; on a phone it sits above the tab bar).
- The component stays mounted, so text, recipients and the sealed draft are never lost while minimized. Technology: React 19 state + CSS data-mode attributes, visualViewport on phone; no new network door.

### B. The feature set of the best compose boxes, with the technology each needs (all in the plan, in this order)
| Feature (who has it) | Anexomail technology | Phase |
|---|---|---|
| Undo send, schedule send, send later presets (Gmail, Superhuman) | Rust Tokio outbox + SQL E170/E182/E185, 30 s hold; X on undo bar = send now | QC0c, QC3, QC3a |
| Address chips, autocomplete, drag between To/Cc/Bcc (Gmail, Superhuman) | PostgreSQL RLS People + kernel-verified door, React chips | QC1 |
| TLS lock on each recipient chip (nobody has it) | our own outgoing TLS facts (Qtls) | QC1 / Qtls |
| Emoji picker, every emoji (Gmail) | native popover + Unicode CLDR data | QC1e |
| Rich text + plain-text mode, signatures, snippets with variables (Gmail, Superhuman) | Tiptap 3 / ProseMirror restricted schema, Rust ammonia sanitiser, text/plain part | QC2 |
| Pre-send checks: empty subject, "attached" word with no file, big Cc, reply-all (Gmail) | pure TS checks, unit tested | QC3 |
| Inline reply, quoted text folded, forward as .eml (Gmail, Outlook) | Rust mail-parser + mail-builder | QC4 |
| Attachments drag-drop / paste, progress ring, size limit (all) | WebTransport chunked upload, Hetzner Storage Box, ClamAV | Q3 |
| Follow-up reminder if no reply (Superhuman) | Rust Tokio timer + ledger | QC7 |
| Confidential / expiring mail (Gmail) | sealed envelope + kernel key release | LATER, own phase |
| End-to-end encrypt toggle with key on the chip | kernel OpenPGP RFC 9980 (ML-KEM-768 + X25519, ML-DSA-65 + Ed25519) | Q4 |
| AI drafting / Smart Compose | DROPPED until the AI product (July 2027), his word | - |

### C. The rim and the send shimmer (his images 3 and 4) -> QC0d + QC0e, BUILT 17 Nov
- Name of the effect: Animated Gradient Border (conic-gradient on a registered @property angle) with a Shimmer / sweeping glow pass.
- Technology: CSS @property --mbx-a (angle) + conic-gradient + mask on a pseudo-element overlay; it animates a custom property, not layout, so it is cheap; it is switched off under prefers-reduced-motion. No JavaScript.
- Fix for image 3: the blue rim was a layer behind the header, so the header background covered its top part. It is now an overlay above everything (z-index 6), so the line runs to the very top and all round.
- On SEND: the box plays ONE sweep in the original Anexomail logo palette, then closes after 0.95 s (instantly under reduced motion). Logo palette read from public/favicon.svg: steel navy #1E3557 and #2C4C79 with platinum #F5F8FB, #E6EBF1, #C3CCD8 (a silver light sweeping over steel blue). The idle rim keeps the mailbox blue.

---
## 17 Nov 2026 07:55 PKT - CORRECTION BY HIS WORD (QC0g): phone compose = a BOX (bottom sheet), NOT full screen
His phone screenshot 07:47 and word: "full screen ka idea mobile pe bad hai, mere mobile pe compose box nahi ata". The 06:4x research line that preferred a full screen on phones is overruled by the founder. Phone now: bottom-sheet card, page dimmed behind, grab handle, rounded top corners, logo-blue rim, follows the keyboard (visualViewport), Send pinned, minimize bar above the tab bar. The Android autofill pill on the To field is neutralised (-webkit-autofill). Seen in the sandbox with the REAL MailCompose at 390; his phone screenshot after install is the proof.
