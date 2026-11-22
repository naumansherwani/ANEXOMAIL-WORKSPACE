# RESTORE the desk lane from 20261122-0808-6dd5a41b-d10-colours-liked (only when the Chairman says so)
1. Verify: `python3 docs/cursor-work/server/code-backup.py verify`
2. Restore (writes over the desk lane paths only, nothing else): `tar -xzf backups/desk/20261122-0808-6dd5a41b-d10-colours-liked/code.tar.gz -C .`
3. `python3 docs/cursor-work/server/desk-copy-sync.py sync` (desk lane), build, run the tests, then commit and push as usual.
Paths in this backup: docs/claude/admin-desk, admin-desk, founder-web/src/desk, founder-web/dist-desk, founder-web/vite.desk.config.ts, founder-web/desk.html.
