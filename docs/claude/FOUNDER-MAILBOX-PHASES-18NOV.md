# FOUNDER MAILBOX: PHASE ORDER + STATUS (updated 19 Nov 2026 11:1x PKT; first written 18 Nov 10:5x, his word: "mujhe updated blueprint send kero")
Rule: one phase at a time; GREEN only WIRED: YES / REAL: YES / TECH-LAW CHECKED with proof, seen on 390 / 820 / 1200+. Technology law: Rust + Tokio + axum, WASM kernel, HTTP/3 + WebTransport, X25519MLKEM768, AES-256-GCM, React 19, forced-RLS Postgres.

| # | Phase | What | Status 18 Nov 10:5x |
|---|---|---|---|
| 1 | QC0 | Compose polish | GREEN (his word 02:11) |
| 2 | QC1c | TLS lock on each recipient chip (probe, retry, proven line, MTA-STS, DANE) | GREEN BY HIS WORD 19 Nov 11:05. Proven: pq (Gmail), nomail, unreachable + retry 1/5 min, real send proven line, E190 6/6, MTA-STS + DANE wired (cargo 481/481, installed). 19 Nov 12:25 PKT: F8-3 TLS-RPT sender + F8-4 strict ratchet = E191 CHECK 9/9 (selftest 28/28) on his server + founder-install live (cargo 489/489), GREEN BY HIS WORD; the first real report day (20 Nov) and the loosen UI (F8-5, needs his haan) stay open. Open list (not hidden, in CLOSE-THE-GAPS-07NOV.md): none/refused live, retry 30 min step, DANE on a real signed domain, received hint, phone 390/820 | F8-5 (per-domain signed loosen) GREEN BY HIS WORD 19 Nov 13:20: E192 CHECK all OK, selftest 14/14 on his server, founder-install 4/4, my Chrome look (card under the untouched Sending switch, Strict, ledger verified). TECHNOLOGY USED (founder side): Rust + tokio + axum (tls_step.rs, per-domain sender, TLS-RPT worker), WebAuthn passkey assertion signing the exact change (E118 T2), Rust WASM kernel actionCheck before the key is touched, React 19 + TypeScript card (TlsLoosen.tsx), PostgreSQL 16 forced RLS + SECURITY DEFINER doors + hash-chained ledger (E191/E192), rustls TLS 1.3 X25519MLKEM768 + MTA-STS + DANE, HTTP/3 signed API.
| 3 | QC3a | Undo bar X = send now (E185 release door, signed Rust door, kernel RPC) | GREEN BY HIS WORD 20 Nov 05:20 PKT (he said: the rest is green; only QC2, QC3, QC4, QC5, QC7, QC8 remain) |
| 4 | QC1 | Recipient chips, People autocomplete (lock part = QC1c) | GREEN BY HIS WORD 20 Nov 05:20 PKT (laptop look 19 Nov) |
| 5 | QC1e | Emoji picker (all emoji) | **D1 = GREEN BY HIS WORD 20 Nov 01:29 (founder + awam, WIRED: YES / REAL: YES, TECH-LAW CHECKED, ledgers QC1E-LEDGER-FOUNDER/AWAM-19NOV.md); NOW = D2 ":" shortcode: plan docs/claude/QC1E-D2-PLAN-20NOV.md, FOUNDER gate = GREEN BY HIS WORD 20 Nov 02:06 PKT (WIRED: YES / REAL: YES: his founder-install 01:59 + my live Chrome look 02:08; TECH-LAW CHECKED), no hint on founder (awam only); shortcode MOTION reserved for AnexoChat (awam side, not founder) by his words 20 Nov 01:50 + 01:52; everything else in D1 + D2 stays intact (docs/claude/anexochat-reserved/), mail list is instant** | D1 BUILT 19 Nov 13:40 (native art, Unicode 17 picker + new-emoji safety; order D1 > D2 button in box + ':' typeahead > D3 Urdu/Roman Urdu search (FOUNDER = GREEN BY HIS WORD 20 Nov 2026 02:55 PKT, eb55a6bc: WIRED: YES / REAL: YES: his founder-install + my live Chrome look 02:50, TECH-LAW CHECKED; 574 emoji words, English name in the row; 390/820 open) > D4 company pack LAST); not green until his install + look. AWAM has its own row in AWAM-BLUEPRINT-CLEAN-17NOV.md (same D1-D4, built together with the founder, separate gates). Plan: research + plan docs/claude/QC1E-EMOJI-RESEARCH-PLAN-19NOV.md (Unicode 17, new-emoji safety, Urdu + Roman Urdu search, sealed recents, one pure module for founder + awam + AnexoChat). Waits his answers D1-D4. Technology: React 19 TS pure module, HTML popover, Intl.Segmenter, Rust vault seal, PostgreSQL RLS | [20 Nov 05:20: GREEN BY HIS WORD for the founder side]
| 6 | QC2 | Rich text editor (Tiptap 3), signatures, snippets | GREEN BY HIS WORD 20 Nov 06:44 PKT (WIRED: YES / REAL: YES / TECH-LAW CHECKED by his word; his sql-run E194 33/0 + CHECK OK, his founder-install 4/4 saboot; commit 328e2aa8). OPEN inside it: my live Chrome 390/820/1200 look, rich-mode shortcodes + emoji safety line (CLOSE-THE-GAPS). |
| 7 | QC3 | Pre-send checks, schedule presets, delivery timeline | GREEN FINAL BY THE CHAIRMAN'S WORD 20 Nov 09:03 PKT (WIRED: YES / REAL: YES / TECH-LAW CHECKED; Outbox badge, timeline, presets, delivery board live; follow-ups in CLOSE-THE-GAPS-07NOV.md) |
| 8 | QC4 | Inline reply and forward | NOW (20 Nov 08:50): QC2 + QC3 are green, QC4 is next; tech contract in CURRENT.md first (Rust mail-parser + mail-builder, kernel RPC, React 19 TS) |
| 9 | QC5 | Delete forever | OPEN, REMAINING (his word 20 Nov 05:20) |
| 10 | QC7 | Follow-up reminder, draft sealed in browser too | OPEN, REMAINING (his word 20 Nov 05:20) |
| 11 | QC8 | Shortcuts and accessibility final pass | OPEN, REMAINING (his word 20 Nov 05:20) |
| 12 | Q3 | Attachments (WebTransport, Hetzner Storage Box, ClamAV) | Queued |
| 13 | Qtls | Outbound policy: MTA-STS + DANE, TLS-RPT (fmail_qtls.rs written, not called from sender), E191 "send only if TLS" | Code exists, wiring open |
| 14 | U1U2 | Mailbox unified views | Queued |
| 15 | Q4 | OpenPGP PQC (RFC 9980) | Queued |
| 16 | U5 | Queued | Queued |
| 17 | Q1e | Calendar | Queued |
Dropped: AI drafting until July 2027. DKIM2 needs no work. SQL: E190 done (rerun with loophole fix, CHECK 6/6), next free E191.

## DATE PLAN v2 (his 19 Nov 11:23: the Q series is finished FIRST, then R3 Admin > Mail Desk) - written 19 Nov 2026 11:4x PKT
Last day for the whole founder lane stays 25 Nov; each date is the LATEST day, target is earlier. A phase that fails its proof is fixed the same day, the next one does not start. His 30 Nov - 30 Dec window is the AWAM lane (docs/claude/AWAM-LAUNCH-PLAN-19NOV.md).
| Date (Nov 2026) | Phase | What he gets |
|---|---|---|
| Thu 19 | QC3a Undo X = send now | X on the undo bar sends at once (E185, signed Rust door, kernel RPC) |
| Fri 20 | QC1 address book + autocomplete (E186), QC1e emoji picker | typing finds contacts, emoji |
| Sat 21 | QC2 rich text (Tiptap 3), signatures, snippets; QC3 pre-send checks, schedule presets, delivery timeline | writing and sending tools |
| Sun 22 | QC4 inline reply and forward; QC5 Delete forever; QC7 follow-up reminder + sealed draft in browser; QC8 shortcuts and accessibility pass | the daily mail loop |
| Mon 23 | Q3 attachments (WebTransport, Hetzner Storage Box, ClamAV). Needs his Hetzner written confirmation (his hands) | files in mail |
| Tue 24 | U1U2, Q4 OpenPGP (RFC 9980) | unified views, PGP |
| Wed 25 | **R3 Admin > Mail Desk** (FOUNDER-ADMIN-MAIL-DESK-03NOV.md): R3a company mailboxes (support, billing, abuse), awam problem inbox; R3b assign / reply / status / SLA; R3c look at 390 / 820 / 1200+ | the desk where awam problems are heard |
| Thu 26 - Sun 29 | U5, Q1e calendar, the QC1c open list, spill-over of anything that failed its proof | buffer, nothing new starts before the awam window |
His hands, one step at a time when each comes: phone 390 / tablet 820 screenshots, Hetzner confirmation, hardware keys.

- QC1e ledger (founder): docs/claude/QC1E-LEDGER-FOUNDER-19NOV.md

## TARGET FRIDAY 20 NOV 2026 (his order 02:48: how many phases must be complete today; set 20 Nov 03:0x PKT). Date plan v2 row Fri 20 = QC1 address book + QC1e emoji. STATE NOW: QC1 = GREEN on laptop (19 Nov 11:4x, live Chrome; phone 390 / tablet 820 look owed, after the Q series by his word 02:48); QC1e D1 + D2 + D3 = GREEN BY HIS WORD (20 Nov 01:29 / 02:06 / 02:55); QC1e D4 = discussion + plan written (docs/claude/QC1E-D4-PLAN-20NOV.md), waits his 4 answers. TODAY'S TARGET: 2 phases closed = QC1 (done) + QC1e (D4a library + admin + picker + ':' with text fallback; D4b inline embedding after Q3). Ahead of the plan: QC2 may start today (plan day 21 Nov) only after D4a is green. Ledger date for this target: 20.11.26.

- QC1e D4 (20 Nov 2026 03:15 PKT) = AWAM-SIDE phase, no founder code. Advance technology: Rust image-webp re-encode, forced-RLS + hash-chain SQL (E193 proven on his server), D4B CID inline images + derived PNG + ClamAV + Hetzner Storage Box. Detail: awam blueprint + docs/claude/QC1E-D4-PLAN-20NOV.md.



## STATE 20 NOV 2026 05:20 PKT (his word): founder compose chain QC0, QC1c, QC3a, QC1, QC1e = GREEN BY HIS WORD. REMAINING = QC2 (Tiptap 3 rich text, signatures, snippets), QC3 (pre-send checks, schedule presets, delivery timeline), QC4 (inline reply and forward), QC5 (Delete forever), QC7 (follow-up reminder, sealed draft in browser), QC8 (shortcuts, accessibility final pass). Q3, Qtls, U1U2, Q4, U5, Q1e calendar, R3 unchanged (not said green).
- REMINDER R3 Admin > Mail Desk (his 05:20): domain connect DNS verification of awam companies + every awam problem is dealt with in the Mail Desk (R3a/R3b); write it into R3 when it starts. Awam PRO Devices '4 trusted devices' limit = NOT CHECKED, check in the awam turn.
