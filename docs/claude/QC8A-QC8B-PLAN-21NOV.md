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
