# People (Admin Desk)
Organisations, users, devices and permissions: metadata only, never message content

- Phase: R5a
- Technology: Rust, Postgres RLS, signed read doors
- Moves from founder: People
- Rules: Desk isolation (own files, /desk/v1/*, fadm_* tables, Rule 52 kernel calls); real data only, no mock; seen live at 390/820/1200+ before GREEN.
- Status: planned. Replace `status` with `live` in meta.ts only when wired and proven.
