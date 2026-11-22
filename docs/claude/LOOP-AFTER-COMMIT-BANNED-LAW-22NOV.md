# LOOP-AFTER-COMMIT IS BANNED (his 22 Nov 2026 21:40 PKT, in anger)
Once a step is committed and pushed, nothing may keep running that dirties the repo again (the 2-minute checkpoint loop rewriting WORKING-NOW made "uncommitted changes, commit again" repeat forever).
1. docs/cursor-work/server/ckpt-loop.sh snapshots only while real work is uncommitted; clean tree = it writes nothing.
2. After my commit + push, `git status --short` must be empty and STAYS empty until the next real edit.
3. No scheduled message, background loop or hook may create a new commit or a new change by itself on a clean tree.
Note: the earlier written text of this rule was not found in the repo on 22 Nov 21:4x; this file is now its home.
