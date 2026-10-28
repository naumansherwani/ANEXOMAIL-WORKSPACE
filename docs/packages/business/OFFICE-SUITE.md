> **28 Oct 2026 05:13 PKT — SUPERSEDED (Docs+Sheets):** founder hukm: Docs + Sheets editor SAB packages mein, open-source engine (Collabora/OnlyOffice) + WOPI. Slides (Show) ka faisla baqi. Dekho docs/claude/OFFICE-HR-ACCOUNTING-MIGRATION-28OCT.md.

# OFFICE SUITE — Writer / Sheet / Show = BUSINESS package ka hissa (founder hukm 26 Oct 2026 22:35)

**Rule 58:** Office suite (Writer = documents, Sheet = spreadsheets, Show = presentations) **Business package** ka feature hai (starts_at = business; Business Pro aur Enterprise ko bhi milta hai). **Basic aur Pro mein NAHI**, CRM P3-P6 ka hissa NAHI. Feature ID: N-DOC-01 (docs/packages/features.tsv, FEATURE-CATALOG.md). Halat: PROPOSED, abhi bana nahi.

| Hissa | Package | Technology (Rule 52 + 56: sirf Rust + WebTransport/WASM kernel, Bun nahi) |
|---|---|---|
| Writer (collaborative documents) | Business+ | Rust CRDT engine (doc_core std-only tests + doc_glue), WASM kernel mein browser-side merge, live cursors WebTransport stream par |
| Sheet (formulas, tables) | Business+ | Rust formula engine (core, tests) + CRDT cells, kernel mein recalculation |
| Show (slides) | Business+ | Rust slide model + CRDT, kernel renderer |
| Storage / sharing | Business+ | Supabase Postgres (cemented data layer) + files |
| Gate | Server par `resolve_plan` (Basic/Pro 403), UI sirf mirror (Rule 57) |

Order: MASTER-GREEN-PLAN step 9 (Business + ANEXOChat K3) ke baad; K3 (ONE QUIC) pehle kyunke live editing usi stream par chalegi.
Naya Rust crate (CRDT) judne se pehle founder ki ijazat (Cargo naya crate = G30 jaisa rule).
Is feature ko Pro CRM tracker ya Pro marketing mein na daalna; Pro card par "Writer/Sheet/Show" likha na ho.
