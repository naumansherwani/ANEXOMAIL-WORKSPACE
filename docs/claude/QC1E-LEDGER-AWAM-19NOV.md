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
