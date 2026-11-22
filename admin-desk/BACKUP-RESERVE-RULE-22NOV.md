# BACKUP RESERVE RULE (his word 22 Nov 2026 11:39 PKT)
Backups in backups/desk stay RESERVED. They are used only when he says so. When code from a backup is needed, ONE command restores ONLY the files asked for (not everything); the live (newer) code of every other file is untouched, because the website changes all the time.
1. List the backups:
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:admin-desk/scripts/desk-restore.sh) 2>&1 | tail -8
2. Look at specific files (live code untouched, they are extracted to /tmp): the same line with the backup name fragment and the file name fragment after the closing bracket, for example: ... desk-restore.sh) perfect-login DeskShell.tsx 2>&1 | tail -8
3. Write them into the repo (only those files, the backup version replaces the new one): the same line with RESTORE_APPLY=1 in front of bash. Then desk-copy-sync, build, tests, commit.
Every UI change still needs a fresh backup first (backups/desk + MANIFEST) and his haan. Written 22 Nov 2026 11:40 PKT.
