# QC1e emoji picker: FOUNDER ledger (19 Nov 2026, PKT)
Founder side only (founder-web/src/*). Awam ledger is a separate file: QC1E-LEDGER-AWAM-19NOV.md.
Technology: shared pure module emoji_pure.ts (bun-tested) + React 19 / TypeScript picker, emojibase-data 17.0.0 (local lazy chunks, CSP self-only), Intl.Segmenter, Framer Motion, localStorage recents (fw.emoji.recent, fw.emoji.tone). Phase: QC1e (Compose Studio), D1..D4.
Times are the real git commit times. Earlier ledger lines of this day carried wrong future times and were re-timed to the commit times.

| Time | Change |
|---|---|
| 13:24 | Plan and sub-phases D1..D4 written (QC1E-EMOJI-RESEARCH-PLAN-19NOV.md) |
| 13:32 | D1 built: picker, native artwork, Unicode 17, new-emoji safety hint ("Use words") |
| 13:53 | Flaky snap_seal test fixed (his order) |
| 13:57 | Tab row no longer squashed (12 px) |
| 14:10 | +5 px spacing between search, tabs and skin tone |
| 14:12 | Single search result no longer stretched |
| 14:18 | Corner smiley idea tried (my misreading) |
| 14:27 | Button beside Send in the footer row, X close button (his word) |
| 14:44 | Picker no longer squeezed or clipped in the compose form (flex none, grid by dvh, keyboard scroll inside grid) |
| 14:50 | WhatsApp order: category icons on top, round search + X, section heading with skin tone, grid; opens on Recently used; history = last 32 (his 14:46/14:47). Sandbox: 384 bun tests pass, tsc clean, vite build OK, 32 cells at 1536 and 390 |
Open: live Chrome look after his pull, ":" shortcode, D3 search (English first, then Urdu/Roman Urdu), D4 company pack, sealed recents.

| 20 Nov 2026 01:15 PKT | LIVE CHROME LOOK after his pulls (founder tab, 1536x674): picker z-index 30 sat above the sticky Send row (z 2) and the card content (717 px) was taller than the card (619 px), so emoji cells showed over Send/Discard (same as his photo 01:04). His word 01:05: "awam side perfect, founder ka bhi yehi". FIX: founder compose now uses the SAME overlay as awam: textarea + EmojiDock inside `.emo-over` (MailCompose.tsx), CSS scoped to .mbx-compose (emoji.css: --emog grid height clamp 96..168px by viewport, wrapper keeps room, footer z-index 40). Proof so far: injected the same CSS live (constructable stylesheet): Send row clear, picker inside the card. Real bundle proof only after his founder-install. |

| 20 Nov 2026 01:22 PKT | His word 01:07 "position height ko founder ke account ke mutabiq kero": founder picker grid height now comes from the founder compose card itself (--emog = clamp(96px, 92dvh - 520px, 208px), 208 px = the founder's own original grid height on big screens), wrapper room = grid + 192 px, picker position = top of the message box inside the card. Layout only, no colour touched. |

| 20 Nov 2026 01:32 PKT | HIS founder-install pasted (OK, healthz 200, SPA 200). My LIVE CHROME look on the REAL founder bundle (founderworkspace.anexomail.com/#/mail, New mail, Smileys tab, 1536x674): live CSS = index-yUnuG76D.css = the repo build; picker opens over the message box INSIDE the card, tabs + round search + X + heading + tone + grid (2 rows at this small viewport, scrolls), Send / emoji button / date / Discard row fully clear, no cells over it. Colours unchanged. NOT GREEN YET: 390 / 820 live look + scrollbar-drag case still open. |

| 20 Nov 2026 01:35 PKT | **QC1e D1 (founder) = GREEN BY HIS WORD** (his 20 Nov 01:29: "ok perfect hai ... D1 green kero"). WIRED: YES (EmojiPicker + EmojiToggle + EmojiDock mounted in MailCompose, emojibase-data 17 bundled, recents in localStorage fw.emoji.recent) / REAL: YES (my Chrome look on the REAL founder bundle after his install 01:32: picker over the box inside the card, Send row clear, CSS hash = repo build). TECH-LAW CHECKED: React 19 + TypeScript + Framer Motion + shared pure module, no network, no vendor, CSP self-only, no Node/Bun/WebSocket added. Colours untouched. STILL OPEN (not hidden): 390 / 820 live look, scrollbar-drag case live, sealed recents (vault key), D2 ":" shortcode (DISCUSS FIRST, pure code written + tested 17/17 but PARKED in git stash "QC1e D2 shortcode pure code + tests", not committed), D3 Urdu/Roman Urdu search, D4 company pack. |

| 20 Nov 2026 01:40 PKT | **D2 ":" shortcode, FOUNDER gate BUILT (not green).** His word 01:37: plan at the top of the repo (docs/claude/QC1E-D2-PLAN-20NOV.md), min 2 letters ("best in the world" = Slack/Discord/GitHub), founder and awam both but gates never mixed, two pulls. Code (founder-web/src): EmojiShortcode.tsx (useShortcode + EmojiShortcodeList, WAI-ARIA 1.2 combobox, useDeferredValue, IME-safe, Escape closes only the list), emoji_pure.ts (shortcodeAt, shortcodeSearch, acceptShortcode, rankRecent), emoji.css (.emo-sc list, 44 px rows), MailCompose.tsx (hook on the textarea + list in the .emo-over wrapper). Proof so far: bun 387/387 (emoji_pure 18), tsc clean, real Chromium at 1536 / 820 / 390: no list for "12:30" or a link, 8 rows of 44 px, ArrowDown moves aria-activedescendant, Escape closes only the list, Enter and click insert, no page errors. Waits his founder-install, then my live Chrome look on the real bundle. |

| 20 Nov 2026 01:50 PKT | **D2 ":" shortcode, FOUNDER: motion added (his word 01:49: "duniya ka advance, motion hai toh kero").** EmojiShortcodeList now uses motion/react (the picker's engine): list fades + rises 6 px in 0.14 s, exit fade, and ONE shared-layout highlight pill (layoutId) springs from row to row; useReducedMotion = no movement at all. Colours untouched (same .emo-sc tokens). Proof: tsc clean, Chromium 1536/820/390 flows unchanged in both modes, motion sampled: no-preference opacity 0.73 -> 1.0 and the pill moves 100 -> 144 px over frames; reduce = opacity 1 at once, pill jumps. Waits his founder-install, then my live Chrome look. |
