# AUDIT BEFORE INSTALL LAW (his word, 23 Nov 2026 01:23 PKT)
"Jab sara phase ke codes likh ke test ker ke audit kerne ka rule dai raha hoon takay perfect ke kareeb rahay, aur phir install ki command lun ga."

ORDER, every phase, no exception:
1. Write ALL the phase's code (SQL, Rust, UI, installer) and its point list.
2. TEST it: scratch PostgreSQL (fresh, new, upgrade), cargo tests, the REAL compiled binary end to end where it has a command, unit file through `systemd-analyze verify`, shell through `bash -n`.
3. AUDIT it on purpose, as a hostile reader, and FIX what the audit finds BEFORE he is asked to do anything. The audit looks at: quiet-day gaps (does anything only run when someone clicks?), old binary or old row on his server, own process mistaken for a stranger (ss cuts names to 15 letters), what a rerun does, what happens when a mount or service is absent, who can call a door, what is written to a log, every file the installer touches.
4. COMMIT with a TESTED: line, push, clean tree.
5. ONLY THEN the install command(s) for his server, each ONE line. Never an install command while code is half written or untested.
Found by this audit on 23 Nov (D5a-4): (a) the timer needed a heartbeat door (fadm_lookup_tick) or the last links of a quiet day would never be sealed; (b) an old binary given an unknown subcommand starts the whole server, so the installer probes with `timeout 5`; (c) the Control Plane installer refused its own process because ss prints "anexomail-contr".
