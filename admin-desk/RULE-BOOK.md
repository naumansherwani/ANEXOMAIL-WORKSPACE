# ADMIN DESK RULE BOOK (a copy kept inside the Desk folder, his word 22 Nov 2026 07:20 PKT; written 07:28 PKT)
Source of truth for the phase rules = the top of DESK-PHASES-22NOV.md (copied below, rules 1..10). Master laws that apply to the Desk, with their files (read them, never re-argue them):
- DESK HTTP/3 LAW (21 Nov 09:23): HTTP/1 and HTTP/2 banned for the Desk, HTTP/3 only; docs/claude/tech-contracts/CURRENT.md
- DESK ISOLATION LAW (21 Nov 07:29): own security domain, never mixed with founder code, doors, keys or tables; docs/claude/DESK-ISOLATION-GATE-21NOV.md
- AUTOFIX LAW (21 Nov 04:33): a loophole or gap is fixed by Claude himself until it is seen working live in Chrome; docs/claude/AUTOFIX-LAW-21NOV.md
- NO UNFINISHED WORK (7 Nov): GREEN only WIRED: YES / REAL: YES; docs/claude/CLOSE-THE-GAPS-07NOV.md
- Rule 52: Desk-signed, kernel-verified answers and frames, HKDF/HMAC request MAC, replay nonce
- Rule 70: every reply ends with the technology table and "Abhi code mein NAHI"
- Vendor ban: only Caddy, Namecheap (his hands), Hetzner, his own Rust; docs/claude/FOUNDER-VENDOR-BAN-13NOV.md
- Address him only as Aap, Roman Urdu, short; Pakistani time only, never UTC
- Phase order and technology per phase: DESK-PHASES-22NOV.md; dashboard cards: DASHBOARD-CARDS-CLICK-PLAN-22NOV.md; his feature list: DASHBOARD-LIVE-COMMAND-22NOV.md

## STRICT RULES (copy of DESK-PHASES-22NOV.md, top; rebuilt by ckpt.sh)
1. BEFORE EVERY PHASE: run `python3 docs/cursor-work/server/rules-read.py` then `python3 docs/cursor-work/server/desk-phase-start.py <phase>` and READ both outputs, plus docs/claude/admin-desk/state/WORKING-NOW.md and docs/claude/state/WORKING-NOW.md. The scripts print this page, the phase row and the ledger tail; receipts last 2 hours.
2. ADVANCE TECHNOLOGY ONLY, AND IT MUST BECOME CODE: the technology written next to a phase is his word, not a wish. A listed technology missing from code = OPEN GAP, the phase is never GREEN. Contract first (docs/claude/tech-contracts/CURRENT.md), code second.
3. HTTP/1 AND HTTP/2 ARE BANNED FOR THE DESK, everywhere (code, tests, comments, strings). HTTP/3 + WebTransport (QUIC) only. HTTP fallback is banned until HE approves it.
4. RULE 52: every Desk call and every stream frame is Desk-signed (Ed25519) and verified by the Desk's own Rust WASM kernel; requests carry the HKDF/HMAC MAC + replay nonce.
5. GREEN only with "WIRED: YES / REAL: YES / TECH-LAW CHECKED" AND my live Chrome look (live bundle = repo, 390 / 820 / 1200+). Installed or written is not green.
6. ISOLATION: the Desk is its OWN security domain (own binary, keys, tables, cookie, role). Never mix with founder or awam code. Vendor ban stays (Caddy, Namecheap by his hands, Hetzner, his own Rust only).
7. Never remove or restyle a feature he did not name. Login look and Bridge look are his approved ones.
8. After EVERY message: repo + ledger + blueprint + COMPACT-SAVE updated with real date and time (rec.sh, desk-copy-sync, lane-sync, manifest-sync, rules-gate 0 fail). EVERY phase is named by ALPHABET in build order (A, B, C ... Q), never S-numbers; the old ids stay in brackets.
9. Address him only as Aap, Roman Urdu, short; end every reply with the Rule-70 table and "Abhi code mein NAHI"; server commands = ONE line.
10. WEB RESEARCH GOES INTO THE REPO IN ORDER (his 22 Nov 2026 07:15 PKT): every web search's points and features are written, in order, into the blueprint (section 'WEB RESEARCH LOG' in DASHBOARD-CARDS-CLICK-PLAN-22NOV.md plus the phase row they belong to) in the same step; each point gets a phase letter and is built in that phase, never left in chat.
11. FOLDER-WISE GREEN, DASHBOARD FIRST (his 22 Nov 2026 07:26 PKT, REPEATED 20:15 PKT in anger; step order = DASHBOARD-FOLDER-ORDER-22NOV.md): the Desk is made green folder by folder in rail order and the DASHBOARD folder (D, D1..D6) goes green completely before any other folder starts. Order: 1 Dashboard, 2 Mailboxes (was Inboxes), 3 Cases, 4 Replies, 5 Routing, 6 SLA clocks, 7 Automations, 8 Admin Desk group (Managed Move-In .. Quality), 9 Company group (Team .. Audit). A folder is green only by rule 5.
12. FOUR-DAY TARGET (his 22 Nov 2026 07:26 PKT): the WHOLE Admin Desk is complete, wired and green in 4 days: by 26 Nov 2026 07:26 PKT. Day plan: docs/claude/admin-desk/FOUR-DAY-PLAN-22NOV.md. Every message re-checks the day plan against the clock.
13. NO READ, NO COMMIT (his 22 Nov 2026 07:26 PKT): the commit gate 'DESK PHASE START' fails a Desk code commit unless the receipt shows the strict rules, this blueprint, the rule book and both WORKING-NOW files were read (desk-phase-start.py prints and records them), the receipt is under 2 hours old, and the strict rules have not changed since the read.
14. NO PHASE NAME, NO "P1" ANYWHERE AN EMPLOYEE CAN SEE ON THE ADMIN DESK (his 22 Nov 2026 09:03 PKT, CHAIRMAN, said three times, "baaned hai"): not in cards, pages, tooltips, alert text, notes, test rows or database rows that Claude writes. Phase names live only in docs and code comments. Words to use: Urgent, Not connected yet. The gate DESK WIRING fails phase names in Desk text and in the test alert script. Before writing ANY visible text, check it for D2, R3b, phase K, P1.
