# QC8a + QC8b PLAN (21 Nov 2026 03:50 PKT). His order 03:11: make QC8a and QC8b, do world-class web research, HIS EXISTING STAYS UNTOUCHED, the new work only CONNECTS to it and complements it. PLAN ONLY: NO CODE until his haan (his order 03:06).
Supersedes the single-phase draft docs/claude/QC8-PLAN-21NOV.md (kept for the plain-words answer at its top). QC8 is optional polish (plain answer there).

## The split (my proposal, he can change it)
- QC8a = KEYBOARD LAYER: what the keys do. Shortcut map, "?" help, switch-off / remap (WCAG 2.1.4), list navigation, Esc order.
- QC8b = ACCESSIBILITY LAYER: what a screen reader / low-vision / motor user gets. Semantics, focus return, spoken announcements, contrast and forced colours, reduced motion, target size.

## Law of this plan: EXISTING = NO TOUCH, NEW = CONNECT
- Existing code that stays byte for byte: MailBox.tsx, MailView.tsx, MailCompose.tsx, MailPresendBar.tsx, MailTimeline.tsx, InlineReply.tsx, Palette.tsx, the orb / BridgeMap, mail.css / mailbox.css, mail_keys.ts, mail_keys_pure.ts.
- New files only, attached by ONE mount line in the app root (a single `<A11yLayer/>`; nothing inside the mail components changes). The mount line is shown to him before it is written.
- ZERO-TOUCH techniques (all standard browser behaviour, no edit of existing handlers):
  1. Switch-off: a new capture-phase keydown listener on window runs BEFORE the existing bubble handler; when the founder turned single-letter shortcuts off it stops the event (stopImmediatePropagation) so the existing handler never fires. Nothing in MailBox.tsx changes.
  2. Announcements: a new observer watches the status text that the existing UI already shows (Undo bar, Presend bar, delivery line, errors) and speaks it; the existing components are not edited.
  3. Semantics and focus: a new "enhancer" adds only missing attributes (role, aria-label, aria-posinset/setsize, tabindex roving) on the existing elements at runtime, never removes or restyles anything.
- HONEST LIMIT: a runtime overlay reaches most gaps, not all (a control with no stable selector, or a list that needs real grid structure, may need a one-line edit in the component). Rule: every such edit is listed one by one, shown to him as the exact diff, and written only after his haan. Default = overlay only.

## Research (read 21 Nov 2026, sources at the bottom)
1. WCAG 2.1.4 Character Key Shortcuts is LEVEL A: any shortcut made only of printable characters (letters, "?" = Shift+/, and sequences like g then a) must be turnable OFF, or remappable with Ctrl/Alt, or active only while that component has focus. The founder mailbox has g-sequences and single letters: today it does not meet 2.1.4. Reason: speech-input and accidental keys.
2. ARIA Notify: element.ariaNotify(text, {priority}) is now Baseline (newly available, since Sept 2026): speech without a hidden live region, text independent of the DOM, "high" interrupts, "normal" queues; caveats: several calls in a row are not reliably all spoken (combine into one sentence), aria-live wins over it, a Permissions Policy can block it silently. Plan: use ariaNotify when present, fall back to ONE polite live region; one sentence per event; never the mail content.
3. WAI-ARIA APG listbox: arrows, Home/End, type-ahead, Shift/Ctrl multi-select, option names short, and "a listbox must not contain interactive elements". A mail row has star / select / unread controls, so the right pattern for the mail LIST is the APG GRID (rows + cells) or a listbox whose row actions are the existing keys (s, e, u). Decision for him in question 4.
4. From the standard WCAG 2.2 / platform references (known standards, not re-fetched today): 2.4.11 Focus Not Obscured (sticky bars must not hide the focused control), 2.5.8 Target Size minimum 24 x 24 CSS px (his own rule is 44 px), :focus-visible rings, prefers-reduced-motion, prefers-contrast, forced-colors (Windows high contrast must keep every control visible), native <dialog> returns focus to the opener on close.
5. Note on what is NOT needed: no new library is required for any of the above (browser APIs only); axe-core and Playwright are MY sandbox test tools, never shipped to his site.

## QC8a steps (keyboard layer)
a1 AUDIT of keys, read-only: table of every key in every context (list, reading, compose, dialogs, palette) and every conflict (browser, screen reader, speech input). Real Chrome keyboard-only walk.
a2 New key map in a NEW pure module (golden tests first): context table, Esc order (sheet, dialog, mail), Ctrl+Enter send, "?" opens help. The existing mail_keys.ts stays; the new layer only adds.
a3 Switch-off / remap setting (zero-touch capture listener, WCAG 2.1.4): Settings key "keyboard.single_keys" = on / off, stored through the existing settings door (key registry checked first; if a new registry row is needed it is a tiny SQL file, schema-first law, his haan first). Remap with Ctrl/Alt = second step.
a4 "?" HELP SHEET: a NEW visible panel: shown to him as a mock first (UI law); Radix dialog, lists only the keys of the current screen.
a5 List navigation: arrows, Home/End, type-ahead, Shift-range, on top of the existing j/k (unchanged).
a6 CHECK: bun tests, tsc, vite build, rules-gate, real-Chrome keyboard-only walk, then 390 / 820 / 1200+.

## QC8b steps (accessibility layer)
b1 AUDIT, read-only: every control: name, role, state, focus ring, contrast, target size; axe-core 0 serious / critical goal; forced-colors screenshot; reduced-motion check.
b2 Semantics enhancer (runtime, additive attributes only), grid or listbox decision applied.
b3 Focus: return to the opener after Compose / dialog / sheet; opened mail takes focus; focus never hidden behind sticky bars (2.4.11).
b4 Announcements: ariaNotify + one polite live region fallback; events: sent, undo available, scheduled, moved, error, new mail; plain English.
b5 Visual: forced-colors and prefers-contrast rules as NEW css that only applies in those modes (normal look pixel-identical, proven by screenshot diff); target size check.
b6 CHECK: same as a6 plus a screen-reader pass (NVDA/VoiceOver notes, my sandbox cannot run a real screen reader: stated plainly, he or a tester confirms).

## Technology contract (his law, nothing older): React 19 + TypeScript + Tailwind 4 + Radix, pure TypeScript key map with golden tests, browser platform APIs (ariaNotify, ARIA, :focus-visible, forced-colors), Framer Motion respects reduced motion. NO server, NO SQL (except the possible one registry row), NO listener, NO vendor. Rust WASM kernel untouched.

## Questions for him (haan / na)
1. Split into QC8a (keys) and QC8b (accessibility) as above?
2. Zero-touch overlay first (existing files byte for byte), one-line edits only after he sees each diff: yes?
3. Switch-off of single-letter keys (WCAG 2.1.4, level A): yes? (his own keys keep working when it is ON)
4. Mail list: APG grid (correct for rows with star / select) or keep a simple list with the existing keys?
5. Skip QC8 altogether and do the dated tech-law items first (26-30 Nov)? His call.

## Sources (read 21 Nov 2026)
- MDN Element.ariaNotify(): https://developer.mozilla.org/docs/Web/API/Element/ariaNotify
- W3C Understanding SC 2.1.4 Character Key Shortcuts: https://www.w3.org/WAI/WCAG21/Understanding/character-key-shortcuts
- W3C WAI-ARIA APG Listbox pattern: https://www.w3.org/WAI/ARIA/apg/patterns/listbox
- W3C WAI-ARIA APG Grid pattern: https://www.w3.org/WAI/ARIA/apg/patterns/grid

## HIS 5 ANSWERS (21 Nov 2026 03:22 PKT, written line by line as he wrote them; Claude wrote the 4 answers' reasons in his words)
1. QC8a (Keys) aur QC8b (Accessibility) alag: HAAN, 100% theek. Reason: keyboard shortcuts (j/k/c/e) aur accessibility (screen readers, focus rings, contrast) alag layers hain.
2. Zero-Mutation Shadow Overlay: HAAN. Pehle overlay real UI ko chhue baghair test hoga; us ke baad jab woh aankh se approve karay, tab line-by-line code change.
3. Single-letter shortcuts ka switch (WCAG 2.1.4 Level A): HAAN, lazmi. Settings mein ON/OFF toggle; ON = us ki fast keys chalti hain, OFF = single-letter keys band.
4. Mail list: simple list rahay jaisi hai (grid pattern NAHI). j/k ya Up/Down arrows se mails ke beech move.
5. QC8 skip kero?: NA. Pehle QC8a aur QC8b khatam (30 Nov tak 9 din; navigation / accessibility ki buniyaad).
His order 03:22: read the repo before any code ("yeh read kiye bina codes nahi likhna"). His word "shuru kero QC8a" = the haan for QC8a. Existing files stay byte for byte unchanged; new files only; mount line and the "?" sheet mock are shown to him BEFORE they are written.

## QC8a a1 AUDIT (read-only, 21 Nov 2026, from the code)
Handlers on the page, by file (none edited):
- MailBox.tsx:163-181 (MOUNTED screen; window keydown): / search, r reply, a reply-all, f forward, then keyCmd (mail_pure.ts:117): c compose, j next, k prev, Enter open, e archive, # trash, s star, u unread, g then i/s/d/a/q/v/t/p folder (1.2 s), Esc close. Guards: compose open, dialog, INPUT/TEXTAREA/contentEditable.
- MailView.tsx:154-161: second copy of the same handler (NOT imported by App.tsx; App mounts MailBox only): not live, left alone.
- App.tsx:127-136 (window keydown): Ctrl/Cmd+K palette; g then d/b/f/p/m/s/a = go to a page. CONFLICT: on the mail screen "g" arms BOTH handlers (g s = Sent folder in mail AND Settings page in App; g a = Archive AND Audit; g d = Drafts AND Dashboard; g p = Spam AND People). Existing behaviour, reported to him, not changed without his word.
- MoreSheet.tsx:8 Esc; Palette.tsx:13-16 Esc, Up, Down, Enter (dialog); Profile.tsx:52 and Trust.tsx:12 Esc (document); Decks.tsx:29 and ConfirmSheet.tsx:15 Esc; EmojiPicker, EmojiShortcode, RecipientField, RichEditor, AmbientStudio, BridgeLanes, OrbWhy, TlsLock: widget keys inside their own element.
- No "?" help, no Home/End, no type-ahead, no Shift-range in the mail list; list rows: Up/Down arrows missing (only j/k).
- Single-letter keys today: always on, no switch (fails WCAG 2.1.4 level A). Settings registry: no keyboard key yet (sql folder has no registry row; a new row = tiny SQL file, schema-first, waits his haan before it is written).
Next: a2 = NEW pure module mail_keymap.ts + golden tests (no existing file touched).

## QC8a a6 LIVE (his Chrome, 21 Nov 2026 04:20-04:35 PKT, live bundle index-B_rALZuO = da98f43e)
Proven live: "?" sheet (14 rows), the switch writes anx.keys.single, "/" is ignored when OFF. NOT yet live-proven: Up/Down, Home/End, Shift-range, e # s u batch, type-ahead (they open or change his real mails; sandbox Chromium proof exists), 390/820. His word 04:08: search placeholder "Search" -> "Search mail" (one string, MailBox.tsx:259), live after his next install.

## QC8b b1 AUDIT (read-only, live DOM of his mail page, 21 Nov 04:35 PKT)
Facts: 51 visible controls; 0 without an accessible name; 0 under 24x24 px (WCAG 2.5.8); 0 images without alt; 0 duplicate ids; lang=en; 1 main, 3 nav, 4 live regions; prefers-contrast / forced-colors / reduced-motion not active on his machine (rules still need a forced-colors screenshot).
Gaps found (to fix by additive runtime attributes, no edit of existing files): (1) page has no h1 (heading level start); (2) .mbx-list carries aria-label on a plain div (ignored by screen readers: needs a role); (3) mail rows are a plain list: the open mail has no aria-current, unread dot is an <i> with aria-label (not announced reliably); (4) focus after Compose / dialog close not proven; (5) forced-colors and prefers-contrast CSS not written; (6) announcements for sent / moved / error not wired (only the key layer speaks). Real screen reader pass cannot be run in my sandbox: stated plainly.
Next: b2 semantics enhancer (new file, additive), b3 focus return, b4 announcements, b5 forced-colors css.

## QC8a a6 LIVE #2 (his Chrome, 21 Nov 2026 05:15 PKT, live bundle index-BCK9wT3H after his install #2)
Proven live: placeholder = "Search mail" (his word 04:09); KeyLayer dialog present; the switch default ON; "?" sheet opens and closes (earlier 14 rows, switch writes anx.keys.single). Sandbox Chromium with the real css: sheet at 390 / 820 / 1280 has no sideways scroll (scrollWidth = viewport), stacks to one column at 390, scrolls inside its own box, Close button 44 px; the Radix switch is 26 px high like every other founder Settings switch. My Chrome window cannot be resized to 390 / 820 on his machine (viewport stayed 1536), so the phone / tablet look on his real device is OPEN: he looks on his phone or I use the sandbox proof only.
STILL OPEN before GREEN: live Down / Home / End / Shift-range / batch / type-ahead on his real mails (they open mails: needs his ok), his phone look.

## QC8b TIME BOX (his 04:42 PKT, 21 Nov 2026): b2..b6 in 45 min, deadline 05:27 PKT. b2 04:42-04:53 | b3 -05:02 | b4 -05:12 | b5 -05:18 | b6 -05:27

## QC8b b2 DETAIL (for his discuss, 21 Nov 04:45 his clock)
New file only: founder-web/src/a11y_sem.ts (+ test) and one mount line in KeyLayer.tsx (or App.tsx). Runtime attributes via MutationObserver, no existing file edited: (1) one visually-hidden h1 "Mail" on the mail scene (heading start); (2) .mbx-list gets role=list (rows stay buttons inside listitem wrappers is NOT done, rows get role=listitem would break button role, so list uses role=group + aria-label kept); (3) open mail row gets aria-current=true, removed when closed; (4) unread dot <i aria-label> gets role=img so the label is announced, or row aria-description "Unread". Pixel look unchanged (attributes only). Test: bun test + live DOM read in his Chrome (axe-like counts).
