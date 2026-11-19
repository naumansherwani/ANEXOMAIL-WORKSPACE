# QC1e D2: ":" SHORTCODE TYPEAHEAD (his word 20 Nov 2026 01:37 PKT: write the plan at the top of the repo, read it to him, then code for founder AND awam on advanced technology, gates never mixed, two pulls)

Founder gate = founder-web/src/* (pull: founder-install). Awam gate = src/components/app/compose/emoji/* + one additive mount in ComposeStudio.tsx (pull: pull.sh). One shared PURE module (emoji_pure.ts), two copies, two glues, two ledgers, two blueprint lines.

## What it does
1. Trigger: ":" + at least 2 name characters (letters, digits, _ - +). His "best in the world" rule = what Slack, Discord and GitHub do (2 characters); 1 character is NOT used, it would fire on emoticons like ":D" and ":)".
2. The ":" must be at the start of the text or after a space / newline / opening bracket. "12:30", "https://x" and "a:b" never open it.
3. A list of at most 8 emoji opens over the message box (inside the same .emo-over wrapper as the picker). Each row = the emoji + its name, 44 px high (touch).
4. Keys: ArrowDown / ArrowUp move (wrap), Enter or Tab put the emoji in place of the typed ":name", Escape closes the list only (never the compose window), mouse or tap picks. List closed = Enter, Tab and Ctrl+Enter work exactly as before. While an IME is composing (Urdu / Chinese keyboards) the list stays out of the way.
5. Names: English now (":thumbs_up", "_" and "-" = space). Urdu / Roman Urdu names = D3.
6. Ranking: emoji the writer used recently (the same 32-history, key fw.emoji.recent) come first, then label match, then tag match. The saved skin tone is applied. Using a shortcode also counts as "used" (history updates).

## Advanced technology (nothing older than this)
- React 19 + TypeScript strict; search runs on useDeferredValue so typing never waits for the list.
- Data = the same bundled emojibase-data 17 chunks, lazy, loaded on the first ":xx", no network, no vendor, CSP self-only.
- Accessibility = WAI-ARIA 1.2 combobox pattern: the textarea gets aria-autocomplete="list", aria-expanded, aria-controls and aria-activedescendant; the list is role="listbox" with role="option" rows and aria-selected; a polite live line says "N emoji suggestions". Reduced-motion respected (no animation when set).
- Pure logic (shortcodeAt, shortcodeSearch, acceptShortcode, rank) is DOM-free and bun-tested; UI is proven by a real-Chromium Playwright run (1536 / 820 / 390) before any pull.
- Layout = same flexible layout on laptop, tablet, phone (one build). Colours = the host's own tokens: founder keeps its colours, awam keeps its look.

## Order and proof
Founder first (commit + dist + ledger + blueprint, one pull: founder-install), then awam (commit + manifest + ledger + blueprint, one pull: pull.sh). Each closes only with my live Chrome look on its own site after his pull; GREEN needs WIRED: YES / REAL: YES / TECH-LAW CHECKED.
