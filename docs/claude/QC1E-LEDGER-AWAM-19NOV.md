# QC1e emoji picker: AWAM ledger (19 Nov 2026, PKT)
Awam side only (src/components/app/compose/emoji/*, ComposeStudio.tsx, ComposeOverlay.tsx). Founder ledger is a separate file: QC1E-LEDGER-FOUNDER-19NOV.md. Own gate, own pull (pull.sh).
Technology: same shared module copy + React 19 / TypeScript, emojibase-data ^17.0.0 in package.json, CORE-UNFREEZE-OK entry for ComposeStudio.tsx (his 13:34).
Times are the real git commit times.

| Time | Change |
|---|---|
| 13:39 | Awam glue added (own folder, own gate) |
| 13:53 | Awam pull fix: emoji files + package.json in DEPLOY-MANIFEST, bun install step in pull.sh; awam blueprint row |
| 14:15 | Awam look recorded (his 14:16 order) |
| 14:18 | List of other awam message boxes that will get the emoji box |
| 14:22 | Compose cut at the bottom fixed: Send bar always sticky, panel raised |
| 14:27 | Emoji button beside Send like the founder, X close |
| 14:35 | Picker opens over the message box (emo-over), scrollbar click no longer closes it |
| 14:40 | Overlay collapse fixed, scrolls into view; sandbox at 4 sizes |
| 14:50 | WhatsApp order and last-32 history, same as founder; sandbox 15 emoji tests pass, tsc clean, vite build OK |
Open: awam pull + live Chrome look, ":" shortcode, D3, D4, emoji box in chat / notes / events, bun.lock update.

| 20 Nov 2026 01:12 PKT | LIVE CHROME LOOK after his pull (business.test, anexomail.com/app/mail/inbox, 1536x674): GOOD. Picker = tabs, round search + X, "Recently Used" (dolphin remembered), grid, panel not cut, button beside Send. His word 01:05: "awam side ka perfect hai". Founder is now made to match it. emoji.css copy carries the founder-scoped rules (.mbx-compose only), awam unchanged in behaviour; 390/820 live look still open. |

| 20 Nov 2026 01:35 PKT | **QC1e D1 (awam) = GREEN BY HIS WORD** (his 20 Nov 01:05 "awam side ka perfect hai", 01:29 "D1 green kero"). WIRED: YES (ComposeStudio .emo-over + EmojiDock + EmojiToggle beside Send) / REAL: YES (his pull output 01:00 + my Chrome look on business.test anexomail.com/app/mail/inbox: tabs, search + X, Recently Used remembers, panel not cut). TECH-LAW CHECKED: same shared module, no network/vendor. STILL OPEN: 390 / 820 live look, emoji box for chat / notes / events (one by one, own pulls), awam bun.lock, D2 ":" shortcode (discuss first, awam gate separate), D3, D4. |

| 20 Nov 2026 01:43 PKT | **D2 ":" shortcode, AWAM gate BUILT (not green).** Own gate, own commit, own pull (pull.sh), after the founder gate (543a4247). Plan docs/claude/QC1E-D2-PLAN-20NOV.md (min 2 letters, 8 rows of 44 px, ARIA 1.2 combobox, IME-safe, recent-first, skin tone applied). Code (src/components/app/compose/emoji/): EmojiShortcode.tsx + emoji_pure.ts (+ test 18/18) + emoji.css copies, NEW shortcodeNative.ts (the awam message box is GhostTextArea = CORE-FREEZE with no extra props, so the hook attaches native listeners to the real textarea; keydown in the CAPTURE phase), ComposeStudio.tsx = additive mount only (useShortcode + useShortcodeNative + EmojiShortcodeList inside .emo-over; unfreeze entry 19 Nov stays). GhostTextArea is NOT touched. Proof so far: tsc clean, bun test 18/18, bun run build:bun OK, real Chromium 1536 + 390: no list for "12:30", Escape closes only the list (host Escape untouched when the list is closed), list open = Tab picks the emoji and the ghost-text Tab does not fire, list closed = Tab goes to ghost text as before, no page errors. Waits his pull.sh, then my live Chrome look on business.test Compose. |

| 20 Nov 2026 01:51 PKT | His word 01:50: motion for the ":" shortcode list is RESERVED for AnexoChat (docs/claude/anexochat-reserved/SHORTCODE-MOTION-RESERVED-20NOV.md, written in the awam blueprint). Awam mail compose list stays instant: NO awam code change in this step, awam gate stays commit 2e4bd81b (waits his pull.sh). |
