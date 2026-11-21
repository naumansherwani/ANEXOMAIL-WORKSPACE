# Managed Move-In (Admin Desk)
Customer onboarding cockpit: slots, cut-overs, mailbox and DNS checks

- Phase: R4-11
- Technology: Rust, DNS probes, Postgres, kernel
- Moves from founder: Managed Move-In
- Rules: Desk isolation (own files, /desk/v1/*, fadm_* tables, Rule 52 kernel calls); real data only, no mock; seen live at 390/820/1200+ before GREEN.
- Status: planned. Replace `status` with `live` in meta.ts only when wired and proven.
