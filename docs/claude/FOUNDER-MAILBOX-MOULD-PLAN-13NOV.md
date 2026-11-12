<!--TECHLAW-->
# FOUNDER MAILBOX + CALENDAR: THE MOULD PLAN (awam code -> founder, advanced technology) — 13 Nov 2026 00:50 PKT
His words (13 Nov 00:16, 19:21, 18:53): mailbox starts now (the L series is complete except LA-7b live proof, which waits for real data). Show the research of MY repo. The founder mailbox = the awam mailbox 2 for 2, built on advanced technology, UI/UX on advanced technology, the awam code MOULDED for the founder. Attachments = Tokio + Rust + WebTransport. Security top notch. Admin > Mail Desk (R3) is separate.
This file = the per-file mould (what is copied, what is changed, what is new). The overview, technology table and security list stay in FOUNDER-MAILBOX-PLAN-12NOV.md. ORDER CHANGE (his word): Q (mailbox + calendar) comes BEFORE S5/M/N/O/P; those follow right after Q. TECH-LAW-GATE dates moved to match (see section 8).

## 1. What I read in the repo (13 Nov, nothing guessed)
| Awam piece | Size | What it does |
|---|---|---|
| server/rust/mail_core.rs | 745 | pure: address checks, header encoding, MIME build, attachment wrap, SMTP send, dot-stuffing, date parse |
| server/rust/mailx_core.rs + mailx_glue.rs | 379 + 680 | folder/status checks, labels, templates + variables, snippets, drafts, snooze/remind, send-confidence (forgotten attachment, empty subject...), pro-only gate |
| server/rust/mail_glue.rs | 958 | IO: send over SMTP, attachments dir on the Storage Box, plan limits |
| server/rust/attach_core.rs + attach_glue.rs + inbound_attach.rs | 367 + 460 + 425 | name cleaning, bidi tricks, dangerous extensions, magic bytes, org-only dedupe, clamd INSTREAM parser, inbound files |
| server/rust/cal_core.rs + cal_glue.rs | 2605 + 2242 | RFC 5545 ICS build, invites/RSVP tokens, free slots, conflicts, overload, meeting cost, availability, goals, history cursor |
| calexp / calfile (core+glue) | 173+66, 72+112 | .ics export, calendar files |
| src/routes/app.mail.* | 394 + 344 + 137 + 28 | folder list + search, thread reader, outbox ("queued on this device, sent only when proven"), folder 404 |
| src/components/app/compose/ComposeStudio.tsx | — | compose (Leo assist, send confidence, templates, snippets, signatures, schedule send, follow-ups) |
| src/lib/mail.ts 438, compose.ts 387, mail-predict.ts 231, mail-attachments*.ts 118+142, mail-identity.ts | — | hooks: threads, thread, labels, accounts, identities, folder counts, send, thread actions, live (WebTransport, poll fallback), snooze presets, drafts + versions, templates, snippets, signatures, send confidence, schedule/cancel send, follow-ups, insights, writing prediction, attachments (limits, upload, remove, download) |
| src/routes/app.calendar.tsx 965 + src/lib/calendar.ts 711, calendar-invites/-files/-subs/-jump, caldav.ts | — | month/week/day, create/update meeting, guests, resend invites, find time, free slots, team load, focus windows, tasks, promises, follow-through, notes, outcome, RSVP lookup/respond, export, CalDAV |
| Mail server | Postfix + Dovecot + OpenDKIM on mail.anexomail.com | stays the MTA; mailbox naumansherwani.founder already listed |
Awam inbound runs through a Bun script (deliver-to-supabase.ts): NOT allowed for the founder (Bun/Node banned), so the founder inbound is Rust.

## 2. The mould rules (what always changes when awam code becomes founder code)
1. **Never import awam files** (FC18/FC22, Rule 73 lanes). Pure cores are shared through `#[path]` include (one code, no copy: mail_core, attach_core, cal_core). Glue and UI are founder files.
2. **No plan limits.** Every `plan_allows_pro`, `pro_only_proc`, `cost_allowed`, invite quota: replaced by the founder gates (DBSC-bound session + passkey touch for the dangerous ones).
3. **Own tables** `fmail_*` / `fcal_*`, RLS on, never the awam tables; SQL from E167.
4. **Transport:** every call over kernel rpc@1 (WebTransport, HTTP/3). The awam hooks use fetch/Supabase: not copied. Live push = the existing WebTransport live feed (SSE fallback).
5. **Crypto at rest:** message bodies AES-256-GCM per message key; attachments end-to-end sealed chunks (stream@1); keys from the vault master.
6. **Every send / delete / export / key event** = hash-chained ledger row + Merkle anchor (the existing founder audit chain).
7. **UI built in founder-web** (React 19, TS, TanStack, Radix/shadcn, Framer Motion, GSAP, Tailwind 4): same features and same flow as awam, cinematic founder look, 390 / 820 / 1200+ in one build.

## 3. Feature by feature (awam -> founder)
| Awam feature | Founder version | Advanced technology |
|---|---|---|
| Folders (inbox, sent, drafts, trash, spam, archive) + counts | same, counts from `fmail_folder_counts()` | SQL STABLE function, RLS, live count push over WebTransport |
| Thread list + search | same, virtualised list (10k rows smooth), full-text search | Postgres tsvector + GIN, keyset pagination (no offset), kernel RPC |
| Thread reader | same, plus sender-check badges (SPF / DKIM / DMARC / ARC), look-alike warning | Rust verification at inbound (mail-auth crate after Q0 audit), HTML sanitised in the kernel, sandboxed iframe, remote images off |
| Labels, snooze, remind, templates + variables, snippets, signatures, drafts + versions | same logic (mailx_core reused) | pure core shared, founder tables, versioned drafts append-only |
| Send confidence | same (forgotten attachment, empty subject, wrong recipient) | shared pure core, + look-alike recipient check |
| Compose (Leo assist, prediction) | same screen; AI assist runs only through the founder AI gateway (Rust), nothing leaves in clear to a third party without his switch | Rust proxy with redaction, per-call ledger |
| Send / outbox / undo / schedule send | same; undo window and schedule are server-side, outbox shows "queued, sent only when proven" | Rust Tokio queue, DKIM Ed25519 + RSA signing, MTA-STS, DANE, TLS 1.3 with the PQ hybrid where the peer offers it, TLS-RPT; passkey touch to send as the company |
| Attachments | same limits and names rules (attach_core) | **Tokio + Rust + WebTransport**: 1 MiB chunks, up to 8 parallel bidirectional streams, resumable, each chunk AES-256-GCM sealed in the browser (kernel stream@1, AAD = file id + index + total), Hetzner Storage Box holds ciphertext only, ClamAV clamd on every inbound and outbound file, hybrid ML-KEM-768 + X25519 wrapped file key; fallback = HTTP/3 range PUT/GET |
| Inbound mail | founder address list (naumansherwani.founder@..., company boxes he names) | Postfix -> Rust LMTP handler (Tokio), MIME parse, spam score, ClamAV, sealed insert |
| Follow-ups, insights | same | Rust, ledger |
| PQ mail content | NEW for founder (awam does not have it) | OpenPGP RFC 9980 (ML-KEM-768+X25519, ML-DSA-65+Ed25519) in the one WASM kernel (pqmail@1) |
| Calendar views, meetings, guests, RSVP, resend invites, find time, free slots, conflicts, team load, focus windows, tasks, promises, notes, outcome, export, CalDAV | same, founder tables `fcal_*`, RSVP tokens signed with Ed25519 | cal_core.rs shared (ICS RFC 5545, iTIP), CalDAV over HTTP/3, invites go through the same Rust outbound as mail |
| Meeting cost | founder keeps it (private rates only he sees) | passkey gate for rates |

## 4. UI/UX advance spec (founder mailbox and calendar screens)
- Three-pane on laptop (folders / list / reader), two-pane tablet, one-pane phone with the same components (ONE BUILD law, no size switch in JS): CSS container queries + fluid grids.
- Keyboard first: command palette (his existing Ctrl K), j/k, e, #, r, a, f, c, "/" search; every action has a visible control too (44 px touch targets).
- Framer Motion layout animations (list reorder, undo toast), GSAP only for the attachment ring and send flight; prefers-reduced-motion honoured; forced-colors honoured.
- Attachment progress: per-chunk ring with parallel streams visible, pause / resume, "scanned clean" seal, "sealed end to end" badge.
- Security chips on every thread: sender verdict, "no remote content", "scanned".
- Calendar: day/week/month with the awam logic, drag to move (optimistic, ledger-confirmed), find-time sheet, RSVP chips.
- Look: the cinematic founder look; nothing of the existing screens is restyled (UI LAW); the mail and calendar are NEW screens added to the existing sidebar entries (Mail is already listed).

## 5. SQL plan (advance level, from E167; each file = blank first line, CHECK file, selftest, RLS)
E167 fmail_core (accounts, folders, threads, messages) + keyset indexes + tsvector | E168 labels, drafts (versions append-only), templates, snippets, signatures | E169 outbox + schedule + undo + send ledger (hash chain, append-only trigger) | E170 attachments (chunk map, quarantine, scan verdict, key wrap) | E171 inbound verdicts (SPF/DKIM/DMARC/ARC, spam) + deliverability | E172 fcal_core (calendars, events, attendees, RSVP tokens) | E173 fcal tasks, promises, notes, focus windows | E174 posture views + CHECK for all. About 900 lines of SQL over these files; run only by sql-run.sh in number order.

## 6. Order inside Q (contract in CURRENT.md first for each step, TECH-LAW rows, code, GREEN with live proof)
Q0 research note (crate choices after licence + audit read: MIME parse, DKIM, mail-auth, OpenPGP PQC; dedupe vs end-to-end decision) -> Q1a SQL E167-E171 -> Q1b Rust inbound + Postfix hook -> Q1c read side + list/reader UI -> Q1d compose / send / outbox / drafts / templates -> Q2 shared attachment code -> Q3 chunked WebTransport attachments + ClamAV + Storage Box -> Q1e calendar (E172-E173) + UI -> Q4 PQ mail -> Q5 PQ network -> Q6 sealed agreements. Each step seen live at 390 / 820 / 1200+ before GREEN; the awam blueprint line is updated each time (Rule 9).

## 7. What I need from him (only these, one by one, none blocks Q0)
1. Which company mailboxes the founder mailbox must show besides naumansherwani.founder@anexomail.com (list in "anexomail inboxes to build").  2. Should AI assist (Leo) be ON in the founder compose? Default OFF until he says.  3. Hetzner Storage Box path stays /mnt/anexomail-box (already given).

## 8. Gate dates (my bookkeeping, tech law NOT weakened)
Because Q now runs first, TECH-LAW-GATE fail dates move: A-tanstack-start 14 Nov -> 18 Nov, M-moq 16 Nov -> 20 Nov; clamav + storagebox (20 Nov) are closed by Q3, kept at 20 Nov. Deadline for the whole founder blueprint stays 25 Nov.

Abhi code mein NAHI: all of the above (plan only). Q0 starts next.

## 9. PRESERVATION + AWAM MIGRATION LAW (his word 13 Nov 2026 00:26; written so a compacted Claude cannot lose it)
His words: the awam pro package is 100% done on the latest technology; the founder codes must be written so that LATER the awam site migrates from Bun/Node to advanced technology; the awam codes are PRESERVED; the founder codes preserve the awam codes and put GATES and ENDPOINTS around them. Earlier K-series mistakes cost him one week of redone work: NO mistakes here.
1. **Awam files are FROZEN.** `docs/claude/CORE-FREEZE.json` holds the SHA-256 of 43 awam files (mail, mailx, attach, cal, calexp, calfile cores + glue, inbound_attach, src/lib mail/compose/calendar/caldav, src/routes/app.mail.* + app.calendar, ComposeStudio, deploy-mail.sh, mount-box.sh). `core-freeze.py` checks them; rules-gate FAILS ("CORE FREEZE") when one changes. Changing one on purpose needs HIS written word, then a line in `docs/claude/CORE-UNFREEZE-OK.txt`, then `core-freeze.py --refreeze`.
2. **The founder build INCLUDES the pure cores with `#[path]`** (mail_core, mailx_core, attach_core, cal_core, calexp_core, calfile_core) and wraps them in founder glue `fmail_*.rs` / `fcal_*.rs`. Wrapper = gate (DBSC session, passkey step-up where listed) + endpoint (`/founder/v1/mail/*`, `/founder/v1/cal/*`) + founder tables. The cores never learn about the founder.
3. **Golden tests:** the awam core unit tests (cargo test of those files) run unchanged inside the founder build; if the founder wrapper breaks a core test, the install stops. A founder test per wrapper proves the gate (refused without session, refused without touch).
4. **Migration-ready by design:** the cores are pure (no IO, no Bun/Node, no Supabase), so the later awam migration can call the SAME cores from the new Rust awam service. Nothing in the founder glue is copied into the awam files and nothing in the awam files points at founder code (separation law, Rule 73 lanes).
5. **Every Q step starts with:** `python3 docs/cursor-work/server/core-freeze.py` = 0 changed, and ends with the same, in the commit.
6. **Resume for a compacted Claude:** rules-read.py -> RESUME-POINT.md line 2 -> this file (sections 3, 6, 9, 10) -> `CURRENT.md` row "PHASE Q" -> the first unchecked Q step.

## 10. Q0 RESEARCH NOTE (13 Nov 2026 01:30 PKT; sources read today, nothing chosen from memory)
| Need | Choice | Evidence (read 13 Nov) | Status |
|---|---|---|---|
| MIME / RFC 5322 parse | `mail-parser` 1.0.0 (24 Oct 2026), Apache-2.0 OR MIT, Stalwart Labs, 41 charsets, every function fuzzed + Miri | docs.rs mail-parser | chosen for Q1b, pin exact version, `cargo deny` licence check |
| SPF / DKIM verify, DKIM sign, DMARC, ARC | `mail-auth` 0.14.1 (26 Oct 2026), Apache-2.0 OR MIT, Stalwart Labs; DKIM Ed25519-SHA256 + RSA-SHA256 (+ DKIM2), SPF, DMARC; ARC is historic and opt-in feature; crypto backend aws-lc-rs (default) or ring or pure rust-crypto | docs.rs mail-auth | chosen for Q1b (verify) and Q1d (sign); ARC off by default (shown only when the feature is on) |
| OpenPGP post-quantum | `pgp` (rPGP) 0.21.1: PQC section cites RFC 9980, ML-KEM-768+X25519, ML-DSA-65+Ed25519 (also ML-KEM-1024+X448, ML-DSA-87+Ed448, SLH-DSA) implemented | docs.rs pgp IMPL_STATUS | candidate for the kernel `pqmail@1` (must compile to WASM: to be proven in Q4a; licence line to be read in the crate manifest before use) ; Sequoia also has PQC (blog 15 Nov 2025) as the second option |
| Virus scan | ClamAV clamd INSTREAM (parser already in attach_core.rs) | repo | reuse, no new crate |
| LMTP inbound | own small Tokio LMTP server (RFC 2033) in `fmail_in.rs`, Postfix `virtual_transport = lmtp:inet:127.0.0.1:<free port>`; port chosen ONLY after the fresh `ss` list (PORT RED LINE) | repo + Postfix config | design; no crate needed |
| Outbound SMTP | own Tokio SMTP submission client with `mail-auth` DKIM signing; TLS 1.3 via rustls with X25519MLKEM768 where the peer offers it; MTA-STS + DANE lookups | repo (smtp_send exists in mail_core, blocking: the async client is new) | Q1d |
| Whole-MTA alternative (Stalwart mail-server) | NOT chosen: it would replace Postfix/Dovecot that already serve awam and the company boxes; we reuse its libraries only | decision | recorded |
| Attachment dedupe vs end-to-end | founder default: dedupe OFF for sealed files (a hash of plaintext would leak equality) | PQN0 note | recorded |
Rules for every crate: exact version pinned, `cargo deny` (licence allow list Apache-2.0 / MIT / BSD / ISC / Unicode), `cargo audit` clean before the install, listed in CURRENT.md row PHASE Q, registered in TECH-LAW-GATE.json.
Open: rPGP WASM build + licence line (Q4a); aws-lc-rs vs ring choice must match the rustls provider already in the founder binary (read Cargo.lock in Q1b, never two crypto stacks).
