# ADMIN DESK (admindesk.anexomail.com): everything for the Desk lives here
His order 21 Nov 2026 08:19 PKT: the Desk has its OWN folder, installer, SQL series and blueprint, separate from founder and awam, directly connected to Claude.
- server/  Rust binary anexomail-desk (loopback 4400)       - scripts/  installer + read-only checks (desk-install.sh, desk-host-check.sh)
- sql/     Desk SQL series AD1, AD2, ... (never the E series)  - gates/   ADVANCED-TECHNOLOGY gate (DESK-FEATURES.json + desk_tech_gate.py), shouts, blocks commit
- BLUEPRINT-ADMIN-DESK.md  live phases with FEATURE / CODE / TECHNOLOGY / HAAN   - docs/  copy of the main blueprint (read-only context)   - state/  RESUME.md
- Desk web code stays in founder-web/src/desk (+ desk.html, vite.desk.config.ts) because it builds with the one Vite toolchain; the isolation gate (lanes/lane-sync.py) guards it. Moving it under admin-desk/web is an OPEN item (needs its own package + the shared kernel imports allowed by the gate).
Install on his server: git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:admin-desk/scripts/desk-install.sh) 2>&1 | tail -15

> 24 Nov 2026 06:4x PKT RULE: edit Desk scripts ONLY in docs/claude/admin-desk/ (source). The root admin-desk/ folder is a mirror: desk-copy-sync deletes anything written only there.
