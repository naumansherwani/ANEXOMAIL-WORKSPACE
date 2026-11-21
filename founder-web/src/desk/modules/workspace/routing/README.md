# Routing (Anexomail Workspace)
Rules that put a case in the right queue by plan, language, topic and skill; load balancing

- Phase: R3b
- Technology: Rust rules engine, Postgres policy tables
- Moves from founder: no, new in the Desk
- Rules: Desk isolation (own files, /desk/v1/*, fadm_* tables, Rule 52 kernel calls); real data only, no mock; seen live at 390/820/1200+ before GREEN.
- Status: planned. Replace `status` with `live` in meta.ts only when wired and proven.
