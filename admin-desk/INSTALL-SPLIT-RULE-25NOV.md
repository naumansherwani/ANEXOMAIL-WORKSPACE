# INSTALL RULE: ONE COMMAND PER REPLY (his 25 Nov 2026 02:40, 02:56, 03:02, 03:09 PKT, STRICT, STANDING for the Admin Desk)
His anger was about TWO commands in one reply (a web install that also ran the SQL, then a second SQL command that ran it again). The fix he left to Claude (03:09): ONE COMMAND PER REPLY, always.
1. WEB command = admin-desk/scripts/desk-install.sh. It does EVERYTHING of the phase: Rust binary, page, WASM kernel, every advance technology (Rule 52: ONE install carries ALL the advance technology, seen live in Chrome at 390 / 820 / 1200+) AND the Desk SQL once inside it (step 8b; files already in the database are skipped). Used for every phase that changes Rust, page or kernel, with or without SQL.
   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:admin-desk/scripts/desk-install.sh) 2>&1 | tail -45
2. SQL command = admin-desk/scripts/desk-sql-install.sh (the word SQL is in the name). SQL ONLY, used ONLY when a phase changed SQL and nothing else (no Rust, page or kernel).
   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:admin-desk/scripts/desk-sql-install.sh) 2>&1 | tail -25
3. A reply NEVER carries both. If the phase has code: the web command only. If it is SQL only: the SQL command only. The reply names the command (SQL or WEB) in the sentence beside the line; the line itself has no label.
ONE COMMAND PER REPLY: ONE web install carries ALL the advance technology.
