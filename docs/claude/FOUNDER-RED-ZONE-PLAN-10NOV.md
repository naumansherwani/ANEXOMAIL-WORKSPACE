
# FOUNDER RED-ZONE PLAN: DATE-WISE (his order 10 Nov 2026 19:16; written 10 Nov 2026 19:17 PKT)
Rule: every phase below has ONE date = the day it must be GREEN (WIRED: YES / REAL: YES with proof, 390 / 820 / 1200+). A phase not green on its date turns RED: it moves to the next day AND the next day's own phases still stay due, so a red day is paid back the next day. HARD STOP 25 NOV 2026. Seminar launch 16 JAN 2027. Today = 10 Nov 2026.
**TARGET: 33 phase lines GREEN, 15 days, finish 23 Nov; 24 + 25 Nov are the buffer / red zone only.**

| Date | Phases that must be GREEN that day | Count | Needs his hands |
|---|---|---|---|
| Tue 10 Nov (today) | S2 live: GREEN 19:25 (his sign-in + peek paste) | 1 | done |
| Tue 10 Nov (MOVED TO TODAY by his order 19:42) | S6 passkey button (same look), S4 recovery, S5 magic = honest refusal, S7 live proof with his phone (G-MIX 2b closes) | 4 | his phone passkey once |
| Thu 12 Nov | L (Cinematic: Framer Motion + GSAP, Three.js WebGPU lazy) | 1 | |
| Fri 13 Nov | M (MoQ relay, Rust on wtransport + kernel) | 1 | |
| Sat 14 Nov | N, N1 (Decide, Live Pulse, Device Trust Map) | 2 | |
| Sun 15 Nov | O (Finance, Polar) | 1 | |
| Mon 16 Nov | P, P1, P2 (People, org, CRM, insider guard) | 3 | |
| Tue 17 Nov | Q1, Q2, Q3 (mail + calendar, attachments) | 3 | Hetzner written confirmations by 16 Nov |
| Wed 18 Nov | Q4, Q5, Q6 (PQM OpenPGP, sealed agreements) | 3 | |
| Thu 19 Nov | R, R1, R2, R3 (systems, analytics, mesh, Mail Desk) | 4 | |
| Fri 20 Nov | S, S1 (kill switch, flags, poison pill, T3 two-key) | 2 | his 2 hardware keys ready by 19 Nov |
| Sat 21 Nov | T (cutover) + U (Docs / Sheets, WOPI) | 2 | licence read for Sheets |
| Sun 22 Nov | V (Founder AI), X1, X2, X3, X4 | 5 | |
| Mon 23 Nov | FINAL: every line re-checked live | 1 | his tablet look 820 |
| Tue 24 / Wed 25 Nov | RED ZONE / buffer: only slipped phases | 0 | |
Total: 1+4+1+1+2+1+3+3+3+4+2+2+5+1 = 33.
Then (not part of the 33): awam lane 26 Nov - 16 Dec (NO 2FA, docs/claude/AWAM-NO-2FA-10NOV.md; K5b, migration, AnexoChat, full tests); 17 Dec - 15 Jan test / polish / rehearsal; 16 Jan 2027 seminar launch.
Honest limits, said once: phases marked "needs his hands" turn RED if his step is late; I never write a green that is not proven.

- 10 Nov 2026 20:06 PKT: founder-install OK; live bundle index-P9z4PDu = repo build (probed). S6/S5/S4 installed, NOT GREEN until S7 phone passkey. Next: S7 then founder-signin-peek.sh.

- 10 Nov 2026 20:18 PKT: passkey tap on phone showed 'not answering' (busy). Cause unknown until ledger/journal. Added journald stage lines (founder-signin stage=...) in signin.rs; cargo signin 15 pass. Devices & Sessions plan: docs/claude/FOUNDER-DEVICES-SESSIONS-PLAN-10NOV.md. NOT installed yet. Next: his peek paste, then founder-install of the logging build.

- 10 Nov 2026 20:31 PKT: logging build INSTALLED on his server (founder-install OK 4/4). Passkey tap on phone still shows busy (screenshot 20:30). Read-only log command: journalctl -u anexomail-founder -n 300 --no-pager | grep founder-signin | tail -15 . If no stage lines: failure is before finish (begin 403/503 or phone browser error). Next: fix from the log, then S7.

- 10 Nov 2026 20:37 PKT: ROOT CAUSE of the phone passkey 503 FOUND from his journal (stage=passkey_rows detail=founder_passkeys read failed, finish http=503): Rust read founder_passkeys.passkey directly, but E117 gives service_role NO select on that column (key body only via SQL doors); the stand-in test had hidden it. FIX = E154 SQL door founder_passkey_by_credential(text) (service_role only, null for unknown/revoked) + signin.rs uses it. Local: E154 twice clean, CHECK 3/3, door returns key for active and null after revoke; cargo 278 pass. Order for him: (1) SQL line (sql-run.sh bare), (2) founder-install, (3) phone passkey again (S7). Awam pull: NOT needed. NOT GREEN until live. LESSON: stand-in tests must model real column grants; check grants before any direct table read.

- 10 Nov 2026 20:44 PKT: E154 GREEN on his server (SQL layer: WIRED: YES / REAL: YES for the door; CHECK 4/4, selftest PASS, sha caa9de051d3e4517). Passkey sign-in as a whole NOT green: next ONE step = founder-install (Rust that calls the door), then phone passkey (S7). SQL last E154, next E155.

- 10 Nov 2026 21:08 PKT: S7 = GREEN (passkey path): his peek paste 21:07: ledger rows opened -> factor_ok -> completed -> released with method passkey at 20:53:20-20:53:55 (two sign-ins, hand-offs passkey, new_network risk 35 then 0), chain verifies true, his phone worked ('ok now working' 20:54). WIRED: YES / REAL: YES for passkey sign-in. Look: his phone screenshots (390) + sandbox 390/820/1280 earlier. Speed build installed? founder-install pasted 21:0x = OK (speed build). Awam: docs/claude/AWAM-PASSKEY-ONLY-PLAN-10NOV.md (AP1-AP8, password retired March 2027) + reference copies docs/claude/awam-passkey-reference/ (txt, not built). NEXT: measure speed, then D1-D4.
