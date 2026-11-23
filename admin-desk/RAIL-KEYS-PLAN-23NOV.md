# RAIL KEYS PLAN (tag SHORTCUTS-ALL-FOLDERS), written 23 Nov 2026 07:5x PKT, his 07:36 word. STATUS: PLAN ONLY, NO CODE until his haan on the final map.
His words: mix Ctrl / Alt / Shift as the best systems do (Ctrl+K search is the model), research on the web, make it perfect, for ALL rail folders; the rail scroll bar must stop at the folder whose key was pressed; the rail itself stays untouched; NEVER "g then letter" style in anything new.

## ADVANCE-RESEARCH [1m-keys] (web research 23 Nov 2026)
- Primer (GitHub) keyboard-shortcuts pattern: prefer modifier shortcuts, single characters are an accessibility failure (WCAG 2.1.4 needs off / remap / focus-only), a shortcut is never the only way (WCAG 2.1.1), avoid Ctrl+W/T/N/F/L, list shortcuts in a help dialog and expose them with aria-keyshortcuts. https://primer.style/accessibility/patterns/keyboard-shortcuts
- TanStack Hotkeys sensible defaults: Ctrl/Cmd+T/N/W and Alt+Tab never reach the page; Mod+K style chords are safe and fire in text fields; Ctrl+Alt+letter clashes with AltGr on Windows (Urdu and other layouts); single keys need ignoreInputs. https://tanstack.com/hotkeys/latest/docs/guides/sensible-defaults.md
- W3C WCAG 2.1.4 Character Key Shortcuts: https://www.w3.org/WAI/WCAG21/Understanding/character-key-shortcuts ; WAI-ARIA APG keyboard interface: https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface
- Zendesk Agent Workspace and Slack/Linear style apps: one palette key (Ctrl/Cmd+K) reaches everything, a small set of global keys, a "?" or Ctrl+/ help sheet.

## DESIGN (final, mixed on purpose, each family has one job)
| Family | Keys | Job |
|---|---|---|
| Ctrl+K | opens the Desk command bar (the search that already exists) focused; type a folder name, Enter | reaches ALL 27 folders and cards, nothing to memorise |
| Ctrl+D | Dashboard (GREEN already) | home |
| Ctrl+/ | opens a "Keys" help sheet listing every key (also aria-keyshortcuts on each rail button, and the rail title shows the key) | discoverable |
| Alt+Shift+letter | direct folder keys (existing 14 card keys keep their letters; 11 new letters) | one key per folder, e.code based so Urdu layout works |
| Alt+Shift+digit 1..8 | the 8 folders left after the letters | one key per folder |
| Alt+Shift+Up / Down | previous / next folder in rail order | walk the rail |
No Ctrl+Alt (AltGr clash). No Ctrl+Shift+letter (Chrome owns many). No "g then" chord anywhere new; the OLD "g then letter" chord is removed only on his word (asked).
Typing guard: nothing fires while he types in a field (Ctrl+K still opens the bar from a field, like every Ctrl chord); key repeat ignored.
Every key ends with the rail scrolling the active item into view (the scroll-follow effect that is already GREEN), so the scroll bar stops at the folder of the key pressed.

## KEY MAP (27 rail items)
Dashboard Ctrl+D. Card letters (unchanged, Alt+Shift): Alerts A, Service health S, Systems Y, SLA clocks L, Plans P, Runbooks B, Escalations X, Queue Q, Security E, Staff T, Deliverability V, Move-In M, Reports R, Ledger U.
New letters: Inboxes I, Cases C, Macros O, Routing G, Automations N, People H, CRM J, Knowledge K, View as W, Data requests Z, Abuse F.
Digits: Incidents 1, Quality 2, Team 3, Shifts 4, Analytics 5, Bridge 6, Policy 7, Audit 8.
(Rail items that equal a card use the card key; the code reads the key from ONE table so a key can never be listed twice: a unit test fails on any duplicate.)

## CODE PLAN (after his haan, own CURRENT.md block first, then code, one commit)
desk_cards.ts: one KEYMAP table (id, key) + pure functions comboTarget (Alt+Shift letter/digit), railStep (Alt+Shift Up/Down), paletteKey (Ctrl+K), helpKey (Ctrl+/); DeskPages.tsx handler; DeskShell.tsx titles + aria-keyshortcuts + Keys sheet; tests: no duplicate key, every rail item has a key, every key goes to its route, no key fires while typing. Then his desk-install + my Chrome look (press each family, rail stops at the folder).
