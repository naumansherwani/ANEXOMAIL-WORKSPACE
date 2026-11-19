# QC1e Emoji picker: research and plan (19 Nov 2026 13:35 PKT, his order 13:23)
His word: a basic feature of writing mail, later also AnexoChat. Same for basic, Pro, Business, Business Pro, Business Premium, Business MAX and the founder; awam side and founder side have separate gates and separate pull commands, the things themselves are the same. Every emoji WhatsApp has must be there. Anexomail must be different. NOTHING is built yet (stash@{0} = parked first draft, untouched until his haan).

## Facts from the web (checked 19 Nov 2026)
- Unicode 17.0 / Emoji 17.0, 9 Sep 2025: 7 new emoji (Distorted Face, Fight Cloud, Orca, Hairy Creature, Trombone, Landslide, Treasure Chest); about 3,953 emoji recommended for general interchange. (https://blog.emojipedia.org/whats-new-in-unicode-17-0/)
- CLDR 48 (names and search keywords in many languages) published 30 Oct 2025. (https://blog.unicode.org/2025/10/unicode-cldr-48-available.html)
- Artwork licences per Emojipedia: Google Noto = Apache 2.0, Microsoft Fluent = MIT, Twemoji = MIT; Apple, Meta and WhatsApp artwork has no reuse licence listed, so it is NOT ours to copy. (https://shop.emojipedia.org/pages/licenses). Verify each licence file before any bundling.
- "Every WhatsApp emoji" is a Unicode question, not an artwork question: WhatsApp sends the same code points. We cover the whole Unicode emoji list (singles, skin tones, ZWJ families, flags, keycaps); the receiver sees their own phone's artwork.

## Features (the standard to beat)
1. Whole Unicode 17 list in the CLDR categories, search, skin tone and gender memory, frequently used, keyboard-only use, ":" shortcode typeahead in the composer (WhatsApp, Slack, Discord style).
2. Grapheme-correct editing (Intl.Segmenter): backspace removes a whole family or flag, never half of it.
3. Screen-reader names from CLDR in the user's language.

## What only Anexomail will have
A. NEW-EMOJI SAFETY: each emoji carries the Unicode version it appeared in (emoji-test.txt "E17.0"). Before Send, an emoji newer than the common phone baseline gets a quiet hint "may show as a box on older phones" and one tap swaps it for its name in words. Gmail and WhatsApp never warn.
B. SEARCH IN URDU AND ROMAN URDU: emojibase-data 17 ships NO Urdu locale (checked), so BOTH the Urdu-script and the Roman-Urdu keyword lists are our own curated map (hexcode to keywords) (dil, khush, mubarak, shukriya, dua...). Nobody searches emoji in Roman Urdu.
C. SEALED RECENTS: "frequently used" is stored sealed (vault key, like the rest of the mailbox), follows the person across devices, no telemetry, no third-party fetch (CSP self-only; no emoji image is ever loaded from another site).
D. ONE PURE MODULE, TWO GLUES: data + search + skin tone + version check live in one pure module (tested); founder glue and awam glue are separate files and separate pull commands (AWAM-INHERITS and SEPARATION laws). AnexoChat reuses the same module later.
E. PLAN TIERS: the picker is the same on every plan. Only the OPTIONAL company emoji pack (Business tiers, a logo as an inline image with a text fallback for other mail programs) differs by plan; numbers are his decision and it is a LATER step, not QC1e core.

## Decisions I need from him
D1 Look: native phone/computer artwork only (zero download, nothing third-party), or also our own bundled set (Noto Apache 2.0, self-hosted, so every screen looks the same)? My advice: native first.
D2 Place of the button: inside the message box (bottom-right corner, WhatsApp style) or next to Send in the footer (what the parked draft does)? My advice: inside the box plus ":" typeahead.
D3 Roman-Urdu search: yes or no?
D4 Company emoji pack for Business tiers: later (my advice), or in QC1e?

## Technology (founder side)
React 19 + TypeScript pure module (build-time CLDR data, lazy chunk), native popover (HTML popover API), Intl.Segmenter, Rust vault sealing for recents (existing seal module), PostgreSQL RLS table for the sealed recents, no Node/Bun on the server, no outside fetch.

## SUB-PHASES (his order 19 Nov 13:29: D1 first, D4 last)
- D1 (BUILT 19 Nov 13:40, awaits founder-install + his look): all Unicode 17 emoji from bundled emojibase-data 17.0.0, native artwork, picker (search, groups, skin tone, recents) inside the compose footer, NEW-EMOJI SAFETY line under the message box (finds emoji newer than Unicode 15.1, "Use words" swaps them for their names). Tech: React 19 + TypeScript pure module emoji_pure.ts (bun tests), HTML popover, Intl.Segmenter, lazy Vite chunks, no network, CSP self-only.
- D2: button inside the message box bottom-right + ":" shortcode typeahead.
- D3: Urdu + Roman Urdu keyword map merged into search.
- D4 (LAST): company emoji pack for Business tiers (SQL + Rust + storage).
- Later: sealed recents (vault key, RLS table), awam glue with its own pull command.
