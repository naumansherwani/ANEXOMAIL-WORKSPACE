# NO TEST, NO COMMIT, NO PULL (his law, 23 Nov 2026 00:46 PKT, in anger)
His words: "ajj ke baad test ke bina main nahi lun ga pull; test live kiye bina commit nahi send kerna; repo, ledger, gates ko bata do."
1. Code, SQL or installer scripts are committed (and so can be pulled by him) ONLY after they were RUN: cargo tests, the SQL on a scratch PostgreSQL (CHECK all true, also the UPGRADE path from the version already on his server), the real round trip (HTTP/3, Chrome look) wherever it can be done without his password.
2. Every ledger line of such a commit carries `TESTED: <what ran and its result>`. rules-gate.py rule "NO TEST NO COMMIT" refuses the commit otherwise.
3. Never write "done" for a row whose test does not exist; a row with code but no test says so (see DBSC-PHASE-LIST truth table).
4. Before giving him a server command, run its script's logic on the scratch database; his server is not the test bench.
5. After his install, his paste is the proof; read EVERY line of it, say what is true, fix what is not.
