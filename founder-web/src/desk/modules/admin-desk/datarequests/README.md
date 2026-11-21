# Data requests (Admin Desk)
Export and delete requests with deadline clock and proof of completion

- Phase: R5d
- Technology: Rust jobs, Postgres, ledger
- Moves from founder: no, new in the Desk
- Rules: Desk isolation (own files, /desk/v1/*, fadm_* tables, Rule 52 kernel calls); real data only, no mock; seen live at 390/820/1200+ before GREEN.
- Status: planned. Replace `status` with `live` in meta.ts only when wired and proven.
