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
