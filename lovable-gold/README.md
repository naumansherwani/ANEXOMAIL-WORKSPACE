# lovable-gold: the Lovable-era website, frozen, split into AWAM and FOUNDER (Rule 73)

Founder 3 Nov 2026 08:40 PKT: the Lovable (Bun) code is gold. It is preserved here, whole, split by who it is for, so it is in front of our eyes whenever we
polish it and migrate it to the latest technology (Rust). The live files stay where the site and server build from them; this folder is an exact COPY.

* `awam/` (755 files): the user-side website. `src/` (React site), the Bun server (`server/routes`, `server/gates`, `server/lib`, `server/mail`, `server/accounts`, ...),
  `sql/` phase files, `anexochat/`. Mirrors the repo paths. `awam/ENDPOINTS-awam.csv` = every endpoint that belongs to the awam (gates and endpoints for the awam go to the awam)
  with its Rust status (RUST-FIRST = a Rust twin exists, BUN-ONLY = still only Bun).
* `founder/` (47 files): the Lovable-era founder pages (`src/routes/app.founder*`, `founder*.tsx`, `FounderBar`, `src/lib/founder*`) and the Bun founder endpoints
  (`server/routes/founder.ts`, `server/lib/founder-*`). `founder/ENDPOINTS-founder.csv` = the `/api/founder/*` endpoints (some live in route files shared with the awam,
  e.g. admin.ts, analytics.ts: those files sit in `awam/`, the founder rows are in this CSV). They migrate into the Rust founder crate (`server/founder`) on the latest technology.
* `MANIFEST.sha256` = sha256 of every file here. READ-ONLY: the rules-gate fails if this folder differs from the live files or from the manifest.
* Refresh only through `python3 lanes/lane-sync.py`, after a live file was changed on purpose. Cutover T may delete a LIVE file only on the founder's word; the copy here stays.
* The migration plan and counts: `docs/claude/LOVABLE-BUN-MIGRATION-PLAN-03NOV.md`. Lane lists: `lanes/{founder,awam,shared,docs}.txt` (every tracked file in exactly one), `lanes/lovable-awam.txt`, `lanes/lovable-founder.txt`.
Counts at generation: {'founder': 318, 'awam': 1344, 'shared': 70, 'docs': 316}.
