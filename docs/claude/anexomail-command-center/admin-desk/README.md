# ADMIN DESK = a module of the ANEXOMAIL COMMAND CENTER OS (his 24 Nov 2026 08:50 order: folder Claude -> ANEXOMAIL COMMAND CENTER OS -> ADMIN DESK)
Written 24 Nov 2026 08:5x PKT. Home page of the Desk inside the OS folder. The OS docs are in the folder above this one; the Desk's own working files stay in docs/claude/admin-desk/ (the commit gate, desk-copy-sync, the install scripts and the unit tests read that exact path, so a physical move is its own gate-surgery step: see "Physical move" below).

## Where everything is
- OS plan: ../COMMAND-CENTER-OS-PHASES-24NOV.md, ../COMMAND-CENTER-OS-SECURITY-PROTOCOL-24NOV.md, ../COMMAND-CENTER-BRAIN-LAW-24NOV.md, ../DECISION-BRIDGE-FINAL-24NOV.md
- Desk status now: ../../admin-desk/state/WORKING-NOW.md, ../../admin-desk/NOW-LIST-23NOV.md, ../../admin-desk/DESK-D-SERIES-BLUEPRINT-22NOV.md, ../../admin-desk/COMPACT-RESUME-24NOV.md
- Desk SQL (ONE series AD): ../../admin-desk/sql/ (checks in sql/checks/); Desk Rust doors: ../../admin-desk/server/src/; Desk UI code: founder-web/src/desk/; install: ../../admin-desk/scripts/desk-install.sh
- Contract: ../../tech-contracts/CURRENT.md (newest block first)

## Physical move (not done, why)
Moving docs/claude/admin-desk/ under this folder changes the path that rules-gate.py, ckpt.sh, desk-copy-sync.py, desk-phase-start.py, code-backup.py, TECH-LAW-GATE.json and the Rust/TS comments read. Done blind it makes every commit fail. It is written as a gate-surgery phase: change the path in those files in one commit, git mv, run the gate, run every test. Needs his "haan".
