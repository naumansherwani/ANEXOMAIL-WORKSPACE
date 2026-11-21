# Deliverability (Admin Desk)
Bounces, complaints, DKIM/SPF/DMARC, MTA-STS and DANE health per company

- Phase: R4-10
- Technology: Rust, DNS, Postgres
- Moves from founder: Mail Desk
- Rules: Desk isolation (own files, /desk/v1/*, fadm_* tables, Rule 52 kernel calls); real data only, no mock; seen live at 390/820/1200+ before GREEN.
- Status: planned. Replace `status` with `live` in meta.ts only when wired and proven.
