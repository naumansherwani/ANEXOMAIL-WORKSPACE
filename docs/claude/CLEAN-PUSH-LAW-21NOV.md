# CLEAN-PUSH LAW (his 21 Nov 2026 21:20 and 21:38: "yeh RULE hai, strict follow kero, sab repo mein likho")
Written 21 Nov 2026 21:39 PKT.
1. After EVERY push, `git status --short` must print NOTHING. A reply never ends with a dirty tree, and never with a second hook round ("still working" after a push = law broken).
2. Why it broke before: the post-commit hook (docs/cursor-work/server/hooks/post-commit) re-wrote the Admin Desk WORKING-NOW.md after each commit but did not add it. FIX (21 Nov 21:16): the hook now adds docs/claude/state/WORKING-NOW.md AND docs/claude/admin-desk/state/WORKING-NOW.md to its own "ledger line" commit; the root admin-desk/state/WORKING-NOW.md is no longer copied or tracked (desk-copy-sync.py SKIP_FILES, .gitignore).
3. Commit procedure (every time): python3 docs/cursor-work/server/desk-copy-sync.py sync; python3 lanes/lane-sync.py; git add -A; then rec.sh in a loop that stops as soon as `git diff --cached --quiet` is true; git push -q; then check `git status --short | wc -l` = 0 BEFORE replying.
4. Never mention checkpoint commits in chat (his 21 Nov 11:00).
