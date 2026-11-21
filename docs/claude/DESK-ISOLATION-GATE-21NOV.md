# DESK ISOLATION GATE (his 21 Nov 2026 07:29 PKT: "gate ko samjha do, yeh naya tareeka samjhay, yeh founder ki technology sab kuch samjhao, mix nahi karna founder ke saath")
The commit gate (rules-gate.py, which runs lanes/lane-sync.py --check, shown as "[73 lanes]") now knows the Admin Desk. The Desk is its own security domain; the gate FAILS the commit if the two are mixed.
## What the gate now forbids (function desk_isolation in lanes/lane-sync.py)
1. DESK files (founder-web/src/desk/**, desk.html, vite.desk.config.ts, and later server/desk/**) may import ONLY: the shared sign-in pieces (signin_pure, signin_passkey, signin/*), kernel, tls_line, the shared css files, and their own folder. A Desk file that imports a founder screen or module (App, api, Mail*, Settings, Scene3D ...) FAILS.
2. DESK files may NOT name a founder door (/founder/v1/), the founder session key (anexo.session.token), FOUNDER_ settings or founder tables (fmail_*, founder_*). The Desk uses /desk/v1/*, key anexo.desk.session, tables fadm_* only.
3. FOUNDER code (founder-web/src, server/founder/src, outside the Desk) may NOT import desk/ or name /desk/v1/, anexo.desk.session or fadm_*.
Proof (21 Nov 07:5x): clean repo = 0 problems; a deliberate "import ../App" in a Desk file FAILED; a deliberate "/desk/v1/" in a founder file FAILED; both reverted.
## What stays shared on purpose
The Rust WASM kernel (Rule 52, one kernel), the sign-in look pieces (BrandMark, AuthCinema, shadcn ui), css, and pre-session helper postJson. Everything else is separate: token audience "desk", key anexo.desk.session, own DB role desk_app, own tables fadm_*, own host admindesk.anexomail.com, own bundle dist-desk, own passkey rp_id.
## Existing gates that still apply to the Desk
Rule 52 raw-fetch ratchet (it caught my first Desk login: now the shared postJson is used), tech-contract in CURRENT.md, GREEN wording (WIRED/REAL/TECH-LAW CHECKED), manifest, lanes, vendor ban. Future (when the code exists): Rust desk crate may not use founder tables; SQL for the Desk may not GRANT on founder tables to desk_app (add to this gate in R3a2).
