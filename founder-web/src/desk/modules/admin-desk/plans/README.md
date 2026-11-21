# Plans (Admin Desk)
Which plan a company is on and what it entitles (support lane, response hours, priority)

- Phase: R3p
- Technology: Signed Polar webhook receiver (HMAC), Postgres fadm_plans
- Moves from founder: no, new in the Desk
- Rules: Desk isolation (own files, /desk/v1/*, fadm_* tables, Rule 52 kernel calls); real data only, no mock; seen live at 390/820/1200+ before GREEN.
- Status: planned. Replace `status` with `live` in meta.ts only when wired and proven.
