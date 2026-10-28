# FOUNDER UI — design system + audit (28 Oct 2026, 12:40 PKT)
Founder 12:21–12:31: UI "world-class (Vercel level)" nahi tha; 100 variants banao, mobile/tablet khas dekho, jab Vercel se aage ho tab batao; frontend technology rules (backend ke saath) ke mutabiq dekho.

## 1. Audit of the old UI (measured, not opinion)
- 13 font sizes (8–60px), 6 radii, 14 text colours, no tokens. "not connected" at 48px was the loudest text on the page.
- 30 nav items in two lists, bottom item clipped; on a phone the menu took ~450px before any content.
- Same rounded card + ALL-CAPS label everywhere; cinematic effects on every element (nav stagger, card lift, gradient headings, flip clock).
- No URLs per page (no back button / deep link); Google Fonts at runtime.

## 2. Method: 100 variants (lab/gen.js, score.js — kept in the session scratchpad, not shipped)
10 palettes x 3 navigation models x 4 radii x 2 densities x 3 KPI styles x 2 ledger styles x 4 headline styles, 100 seeded combinations, each rendered at desktop 1440, tablet 820, phone 390.
Automated checks (all must pass): no horizontal scroll at any size; secondary-text contrast >= 4.5; phone tap targets >= 44px; tablet >= 40px; <= 8 distinct font sizes; greeting + first number inside the first phone screen above the bottom bar; attention ledger within 1.5 screens. 64/100 passed all.
Visual review of the 64: floating bottom bar + row ledger (phone), icon rail (tablet), sidebar (desktop) won; tables are cramped on phones so rows there. HONEST VERDICT: variants alone reach Vercel PARITY (clean hierarchy), not "ahead".

## 3. Where we go beyond (real, not decoration)
1. **Trust indicator** (topbar): one place that states what can be trusted right now — device approved, writes signed, responses verified in this browser (amber until F2b). Dashboards like Vercel have no cryptographic provenance.
2. **Provenance on every number** (next): source + age under each figure; after F2b a verified tick from the browser WASM kernel (Ed25519).
3. **Adaptive city**: greeting by sunset in the home city; planned: theme follows the sunset (needs one new E108 key).
4. Cinematic layer RESTORED at the founder's order (12:49): aurora, glass sidebar, nav spotlight + stagger, gradient greeting with the name accent, flip clock, card lift (src/cinema.css). Page change = one 160ms fade-in (CSS; View Transitions were dropped — they waited on the compositor). Reduced-motion respected. LESSON: never remove a look the founder praised without asking.
5. Keyboard first: Ctrl/Cmd+K, `g` then b/f/p/m/s/a.

## 4. Tokens (src/ui.css — single source)
Type 12/13/14/16/22/32 (Inter, self-hosted woff2, tabular numerals) · radii 8/12/16 · surfaces --bg/--s1/--s2/--line · one accent --ac · states ok/warn/bad · gutter 32 (24 tablet, 16 phone).
Layout: >=1024 sidebar 236px; 700–1023 icon rail 64px; <=700 no sidebar + floating bottom bar (Bridge, Finance, People, Mail, More -> search).

## 5. Rule 61 UI stack vs what is built
| Rule 61 | Built | Gap |
|---|---|---|
| React 19.2 | yes | — |
| Vite 8.2 | yes | — |
| TanStack Router (static SPA) | hash routes written by hand; TanStack Router install in progress | switch (small) |
| Tailwind 4.2 + shadcn | no — plain CSS on tokens | decision: new components may adopt Tailwind v4 mapped to the same tokens (@theme); old CSS not rewritten wholesale |
| Three.js WebGPU lazy | three is a dependency; the 3D scene was removed from the Bridge (founder: no 3D clutter) | only when a screen needs it |
| Motion/GSAP | CSS animations only (cinema.css) | GSAP when a 3D/scroll scene needs it |
| TypeScript | no — plain JS (.jsx) | gap: convert, or founder approves JS |
| WASM kernel verifies audit chain/responses in the browser | NOT yet | F2b (step 4 of FOUNDER-MASTER-ORDER) |
| Backend Rust axum + tokio, WebTransport/QUIC | HTTP/3 fetch today; WebTransport live stream not yet | Decide + Live Pulse step |
Founder-side rules honoured in this UI: Rule 69 (no mock data: every number is a real response or an honest "Not connected"), Rule 64 (done = green in his Chrome), Rule 67 (English UI).
