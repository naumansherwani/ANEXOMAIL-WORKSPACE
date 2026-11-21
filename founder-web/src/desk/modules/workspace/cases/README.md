# Cases (Anexomail Workspace)
Every user problem as a case: owner, status, priority, history, one-click assign, close with root cause

- Phase: R3b
- Technology: Rust, Postgres RLS + relation tuples (AD2), kernel signed calls
- Moves from founder: no, new in the Desk
- Rules: Desk isolation (own files, /desk/v1/*, fadm_* tables, Rule 52 kernel calls); real data only, no mock; seen live at 390/820/1200+ before GREEN.
- Status: planned. Replace `status` with `live` in meta.ts only when wired and proven.
