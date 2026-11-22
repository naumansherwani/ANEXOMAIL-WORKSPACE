# CODE BACKUP LAW (the Chairman, 22 Nov 2026 06:02 PKT, STANDING RULE)

His words: "perfect hogaya hai, codes preserve kero, backup folder admin desk ka banao us mein dalo, lekin pull tab hoga jab hum ko zarurat hogi, yeh humara backup hai, is pe security lagao, rule bana lo; baad mein awam ke liye bhi repo mein backup codes rakhenge, jab zaroorat hogi backup wala pull lenge, sab wapis aa jayega."

1. **Where:** `backups/<lane>/<YYYYMMDD-HHMM>-<commit>-<label>/` with `code.tar.gz`, `SHA256SUMS`, `MANIFEST.txt` (SHA-256 of every file), `RESTORE.md`. Lane `desk` now; lane `awam` later (same tool, separate lane, never mixed with desk or founder).
2. **Made by:** `python3 docs/cursor-work/server/code-backup.py desk <label>`. Verified by `code-backup.py verify`. Restore text: `code-backup.py restore desk <dir>` (prints, never runs).
3. **Pulled only when he asks.** No installer, deploy script or build reads `backups/`. A restore overwrites the lane paths only.
4. **Security:** (a) APPEND-ONLY, the commit gate "CODE BACKUP" fails any staged modify/delete under `backups/`; (b) SHA-256 of the archive and of the manifest is re-checked at every commit; (c) secrets are never included (`*.env *.seed *.pem *.key` are refused, no keys in the archive); (d) deterministic archive (fixed mtime, owner 0), so the same code gives the same hash.
5. **When:** when he says a screen is perfect, before any risky step, and at the end of every green phase (same as FOUNDER-BACKUP-LAW-10NOV.md for founder/awam archives).
6. **Open (his decision):** the repo is public, so a backup folder is public too (it holds only code that is already public). Once the repo is private, the backups can also be encrypted with a key HE keeps.

## Backups taken
- **desk / 20261122-0603-50eec49a-perfect-login**: the Admin Desk at his "perfect" login (single light below the card, eye + Save password, scale-to-fit), live-proven in my Chrome 22 Nov 06:02 PKT (bundle desk-YbabI512.js, no scrollbar, 1536x730). 300 files, sha256 30e6766e....
