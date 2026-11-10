# FOUNDER UI "WOW" RULES + TECHNOLOGY (founder order 11 Nov 2026 02:34/02:36 PKT)
Order (verbatim gist): ring green/yellow = ghatiya colour combo, not wow; show a DEMO how to beat Apple; keep everything else intact; read UI frontend rules + backend rules + repo technology, put them at the TOP of the repo for Claude.

## 0. Read first (in this order)
1. docs/claude/FOUNDER-UI-DESIGN-28OCT.md (tokens, audit, Rule 61 stack) 2. docs/claude/FOUNDER-LOGIN-UI-LAW-10NOV.md 3. docs/claude/G-MIX-D3-PLAN-11NOV.md 4. this file.

## 1. Technology (do not mix layers)
Backend Rust `anexomail-founder` (axum 0.8, tokio, ring, WebTransport/QUIC target, SSE fallback; NO Bun/Node/WebSocket in any server runtime) on Supabase Postgres (RLS, append-only hash-chain ledgers). Browser: Rust WASM kernel (Rule 52) verifies Ed25519 envelopes + action hashes before any key touch. UI: React 19.2, Vite, TanStack Router (hash), Tailwind 4.2, shadcn, strict TypeScript, bun:test. One build for 390/820/1200+ (container queries, no JS size switch). Awam never inside the founder binary.

## 2. What "better than Apple" means HERE (research 11 Nov: Apple HIG Liquid Glass hierarchy/harmony/consistency; WCAG 2.2; our Rule 52)
Apple's own rules: material only where it serves content; depth guides attention; never colour alone; no decorative glass; design as a connected system. We copy the discipline, and go beyond with things Apple cannot show:
1. PROVENANCE: every number carries source + age + a verified tick from the WASM kernel (Apple shows no cryptographic proof).
2. TRUTH over comfort: Path card says HTTP/1.1 when it is HTTP/1.1; empty/unknown shown as "not answering", never a fake green.
3. ONE HUE FAMILY per object: a trust object uses one hue with luminance/depth; state is carried by WORD + SYMBOL + SHAPE (gap in an arc, hollow node), only one small warm accent for Needs attention/Alert. NO green+yellow+red traffic-light arcs (founder: ghatiya). Blue/orange, never red/green pairs.
4. ONE hero moment per screen (one orb/line), calm work screens (Rule 60); motion = slow breathe only, honours prefers-reduced-motion and forced-colors.
5. Tokens stay: type 12/13/14/16/22(+hero), radii 8/12/16, targets >=44, contrast >=4.5, tabular numerals.
## 3. Trust hero demo (design canvas, not code yet)
https://claude.ai/artifact/38Yjaabcn5smDSF3B1sCPw : A Aurora seal (luminous orb), B Quiet instrument (big word + one line of 4 nodes), C Four orbits (one thin ring per fact, gap = needs a look). Real data: Device key none, Path HTTP/1.1, Integrity good, Ledger good. Winner is implemented in Devices.tsx/devices.css only after his pick; rest of the page untouched. RULE 9: becomes awam "Your devices" look later (AP9).
