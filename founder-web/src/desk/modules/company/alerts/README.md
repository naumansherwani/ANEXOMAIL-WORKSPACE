# Alerts (Company)
Circuit-breaker freezes, SLA breaches, key events (Desk's own bridge, never the Founder Bridge)

- Phase: ON11
- Technology: Postgres fadm_alert, Rust
- Moves from founder: no, new in the Desk
- Rules: Desk isolation (own files, /desk/v1/*, fadm_* tables, Rule 52 kernel calls); real data only, no mock; seen live at 390/820/1200+ before GREEN.
- Status: planned. Replace `status` with `live` in meta.ts only when wired and proven.
