
# INSTALLER-AFTER-CUT LAW (10 Nov 2026 02:50 PKT, founder order after the 10 Nov incident)

**What happened.** G-MIX 2d cut the old awam app away from the founder host (`founder-legacy.sh MODE=off` removes `FOUNDER_LEGACY_UPSTREAM` from `/etc/anexomail/founder.env`, 10 Nov 01:02). `founder-install.sh` (line "K4.2") added the line back on every run (`grep -q ... || echo FOUNDER_LEGACY_UPSTREAM=127.0.0.1:443`). Since K4.5 `127.0.0.1:443` is the Rust SNI front itself, so the old-path proxy forwarded into itself in a loop: 500/502, resets, Chrome ERR_INVALID_RESPONSE on the founder site (his photos 02:33 and 02:38). My mistake: I did not re-check the installer after the cut.

**Fix.** Repo: `founder-install.sh` never adds the line and deletes a loop line (`127.0.0.1:443`). Server: his `founder-legacy.sh MODE=off` run (output 02:50: OK, healthz 200, /founderlogin /app /api = 404 on the Rust port, native sign-in 401). Live probe by me after it (02:50 PKT): / = 200 six times in a row, /healthz = 200, /api/x = 404, /app and /founderlogin = 302 to /, /founder/v1/me = 401.

**Law.** 1) After ANY cut, switch, rename or removed config line, grep every installer and script (`docs/cursor-work/server/*.sh`) for that line before the next command goes to him. 2) An installer never re-adds what a cut removed. 3) Every reply says whether a server command is needed and gives it as ONE line at the TOP. 4) A fix is "fixed" only after the live probe; until then the reply says "repo only, not on your server".

**Still open (not green).** The browser look (his eyes): login after sign-out, `/founderlogin#/dashboard` hash (router re-adds it), "Forgot your password?" answer.
