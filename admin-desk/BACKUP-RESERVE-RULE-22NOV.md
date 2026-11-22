# BACKUP RESERVE RULE (his word 22 Nov 2026 11:39 PKT)
Backups in backups/desk stay RESERVED. They are used only when he says so. When code from a backup is needed, ONE command restores ONLY the files asked for (not everything); the live (newer) code of every other file is untouched, because the website changes all the time.
List backups: 
Look at specific files (live code untouched, extracted to /tmp): 
Write them into the repo (those files only, backup version replaces the new one): same line with RESTORE_APPLY=1 in front of bash. Then desk-copy-sync, build, tests, commit.
Every UI change still needs a fresh backup first (backups/desk + MANIFEST) and his haan. Written 22 Nov 2026 11:40 PKT.
