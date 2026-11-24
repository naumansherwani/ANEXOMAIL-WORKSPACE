# INSTALL SPLIT RULE (his 25 Nov 2026 02:40, 02:56 and 03:02 PKT, STRICT, STANDING for the Admin Desk)
1. SQL INSTALL = admin-desk/scripts/desk-sql-install.sh (the word SQL is IN the command name). SQL only: every Desk AD file not yet in the database, CHECK first. It never builds Rust, the page or the kernel.
   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:admin-desk/scripts/desk-sql-install.sh) 2>&1 | tail -25
2. WEB INSTALL = admin-desk/scripts/desk-install.sh: Rust binary, page, WASM kernel and every other advance technology of the phase. WEB ONLY: it NEVER runs the Desk SQL any more (step 8b removed 25 Nov 03:0x). RULE 52: ONE web install carries ALL the advance technology of a phase; after it the technology is seen working LIVE in Chrome (390 / 820 / 1200+).
   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:admin-desk/scripts/desk-install.sh) 2>&1 | tail -45
3. NO DOUBLE RUN: a reply gives ONLY the install the phase needs, never both unless the phase has both SQL and web changes; then two numbered lines, SQL first, web second, each one plain line. (Incident 25 Nov 02:56: desk-install also ran the SQL, then ad-auto ran it again: his anger; fixed.)
4. Both commands are ONE plain line, no label inside it. The reply writes the word SQL or WEB in the sentence next to the line.
ONE web install carries ALL the advance technology (gate phrase).
