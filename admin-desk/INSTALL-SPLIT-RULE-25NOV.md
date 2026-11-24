# INSTALL RULE: SQL COMMAND AND WEB COMMAND ARE SEPARATE (his 25 Nov 2026 02:40, 02:56, 03:02 and FINAL 03:21 PKT, STRICT, STANDING for the Admin Desk)
His words 03:21: "sql ki command alag web ki command alag". Claude's 03:09 idea (one web command that also runs SQL) is WITHDRAWN: it broke his order. Never again.
1. SQL command = admin-desk/scripts/desk-sql-install.sh (word SQL in the name): runs the Desk-database AD files not yet in the database, nothing else.
   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:admin-desk/scripts/desk-sql-install.sh) 2>&1 | tail -25
2. WEB command = admin-desk/scripts/desk-install.sh: Rust, page, kernel and every advance technology (Rule 52: all the advance technology in the ONE web install, seen live in Chrome). It NEVER runs the Desk-database SQL. (Awam-database files AD21..AD31 run inside cp-install.sh, part of the Control Plane install, as they always did.)
   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:admin-desk/scripts/desk-install.sh) 2>&1 | tail -45
3. A reply gives the SQL line and the WEB line as two separate, numbered, labelled-in-the-sentence lines ONLY for what the phase changed: new Desk-database SQL = SQL line first; code = web line second. If the phase changed only one of them, only that line. Never one command that does both.
ONE web install carries ALL the advance technology.

## 25 Nov 2026 03:54 PKT (his order, STRICT, learned from founder-install.sh + sql-run.sh): THE WEB INSTALL CARRIES NO SQL
- desk-install.sh and cp-install.sh run NO SQL file and print NO SQL proof. The awam-database SQL (AD21..AD26, AD31 + CHECKs, cp_lookup password, the AD22/24/31/23 PROOF lines) moved to admin-desk/scripts/awam-sql.sh, called ONLY by desk-sql-install.sh (after ad-auto.sh). SQL first, web second. cp-install reads /etc/anexomail-controlplane/db.url (made by the SQL command) and says "run the SQL command first" if missing.
- Gate ids INSTALL-WEB-NO-SQL, INSTALL-SQL-HAS-AWAM, INSTALL-AWAM-SQL-FILE. Build speed: thin LTO + codegen-units 16 + incremental in both Cargo.toml (measured CP 1m09 warm, Desk 1m51 warm).
