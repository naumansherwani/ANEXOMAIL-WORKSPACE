# EVENING PLAN, 24 Nov 2026 (written 14:4x PKT for the founder; Claude resumes HERE tonight)
Read order tonight: rules-read.py, WORKING-NOW.md, this file, docs/claude/admin-desk/ALL-PHASES-IN-ORDER-24NOV.md (top state block).

## A. LIVE LOOK RESULT (my Chrome, 14:4x PKT, anexomail.com)
- /auth = LIVE AND NEW: no loading hang, all 11 lines + 8-tagline dots, sub line "Your enterprise. Your network. Access Your Global Workspace.", HTTP Message Signatures (RFC 9421) wording found in the page text. Screenshot 1536 wide looked right. 390 and 820 on the live site NOT yet looked at (use resize_window).
- / (landing) footer = STILL OLD ON THE LIVE SITE: it shows "Live WebTransport over UDP / QUIC Native Pipeline / ... Seamless Cross-Protocol HTTP Fallback" (5 rows). That text exists NOWHERE in the repo (grep whole repo = 0), so the live landing is served from an older snapshot or cache, not from src/components/site/SiteFooter.tsx (repo has 11 rows with the login words). Same with ?nocache=. FIRST TASK TONIGHT: find what serves "/" (prerender / static file / Caddy / service worker / old build dir on the server) with ONE read-only command for him; no guessing (law: 0.1% doubt = read-only command + his paste).
- GREEN for sign-in text only after 390 + 820 look; GREEN for landing footer only after the footer shows on live.

## B. WAITING HIS WORD (do not act before)
1. Desk login text demo (DeskSignIn.tsx patch, "THE GLOBAL GRID WORKPLACE"): his "haan", then real code, his plain desk-install, my live look. Dashboard tagline parked.
2. Parked awam card logo-colour gradient (demo/awam-signin-24nov/real-wip): his word.

## C. TONIGHT'S ORDER (blueprint order, one phase at a time)
1. Landing footer finding above (read-only command, his paste, fix, my live look at 390/820/1200+).
2. B13 T4 (manual exception by authorised staff with a SECOND reviewer: screen + granting case.assign). Start with the RESEARCH-IN-BLUEPRINT step: web research, point list in the blueprint + NOW-LIST + CURRENT.md contract (RULE 52 COMBO: S= M= L=) BEFORE any SQL (next free Desk SQL number after AD33 = AD34; read AD30/AD31/AD32/AD33 first, SCHEMA-FIRST), then Rust, then screen, scratch tests, gate.
3. Then T5 (dual-approved correction of a wrong binding), T6 (consent bound to same case + tenant on both DBs + cross-tenant isolation tests), Z4b-3, Z4c (needs his haan; ONE new awam route file), then B11, B12, B6c, B9c Y4/Y6, 1n, 1o.
4. After every step: repo + WORKING-NOW (ckpt.sh) + ledger (rec.sh) + blueprint + NOW-LIST, gate 0 fail, push, git status empty.

## D. HIS COMMANDS (plain, one line, no label before them)
- Awam: git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -15
- Desk (separate): git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:admin-desk/scripts/desk-install.sh)
- Lesson 24 Nov 14:17: never put a label like "Awam (aapki sign-in):" in front of a command; bash reads it as part of the command.

## E. STILL NOT IN CODE (only written on pages = OPEN promises P8-P17)
HTTP Message Signatures RFC 9421 + WIMSE, Media over QUIC for ANEXOCHAT, ML-DSA hybrid, OpenPGP PQC, MTA-STS, DANE, DBSC on awam, HTTP/3 + AES-256 on awam (K5b).
