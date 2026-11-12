<!--TECHLAW-->
# FOUNDER MAILBOX + CALENDAR PLAN (phase Q) — founder order 12 Nov 2026 18:53 and 19:21 PKT. PLAN ONLY, nothing built yet.

## His words (kept)
- 18:53: the founder mailbox is the awam mailbox that already exists, copied the same way, but the code is moulded for the founder and built on advanced technology. The Hetzner (Storage Box) confirmations open since 7 Nov are GIVEN.
- 19:21: after the phase series in order (L-A, S5, M, N, O, P) comes **mailbox + calendar**. The calendar already exists for awam on Rust. The founder mailbox is a separate one. Where the awam problems are heard is the ADMIN (Admin > Mail Desk = R3, separate, own folder, listed below). Then **back to D3**, and the order continues from there. STRICT: the founder mailbox plan = advanced technology, **file attachment transfer = Tokio + Rust + WebTransport together**, security top notch.

## 1. What already exists in the repo (read 12 Nov 19:30, nothing guessed)
| Thing | Where | Size | Use for the founder |
|---|---|---|---|
| Mail pure core (MIME build, address checks, SMTP send, dot-stuffing, headers) | server/rust/mail_core.rs | 745 lines | reuse via `#[path]` include (logic stays the same) |
| Mail extras (folders, status, labels, templates, snippets, drafts, snooze/remind, send-confidence, pro-only procs) | server/rust/mailx_core.rs + mailx_glue.rs | 379 + 680 | port the logic, founder gates instead of plan limits |
| Mail glue (IO: attachments dir `/mnt/anexomail-box/attachments`, SMTP) | server/rust/mail_glue.rs | 958 | founder version talks to the founder tables, never the awam ones |
| Attachment brain (name cleaning, bidi/control tricks, dangerous extensions, magic-bytes exe check, org-only dedupe path, clamd INSTREAM reply parser) | server/rust/attach_core.rs, attach_glue.rs, inbound_attach.rs | — | ONE shared code (Q2), no second copy |
| Calendar (RFC 5545 ICS build, invites/RSVP, free-slot finder, conflicts, meeting cost, CalDAV) | server/rust/cal_core.rs (2605), cal_glue.rs (2242), docs/claude/CALENDAR-BLUEPRINT.md, CALDAV-BLUEPRINT.md | — | pure core reused, founder tables and `/founder/v1/cal/*` |
| Awam UI | src/routes/app.mail.*, app.calendar.tsx; src/lib/mail*.ts, calendar*.ts, caldav.ts | — | same features and look; founder UI is built in founder-web (Radix/shadcn, cinematic), never imports the awam files (FC18/FC22) |
| Mail server | server/mail/deploy-mail.sh = Postfix + Dovecot + OpenDKIM on mail.anexomail.com; mailboxes in the list (hello, moveyourbusiness, resolved, billing, leo, naumansherwani.founder, ...) | — | stays the MTA; founder inbound goes to Rust (below) |
| Storage Box | server/storage/mount-box.sh (u659696, `/mnt/anexomail-box`) | — | attachments for the founder mailbox |
| Founder Admin Inbox (issues: glitch/support) | server/founder/src/inbox.rs, founder-web (Inbox) | — | NOT the founder mailbox; it is the first piece of the Admin side (R3) |
| Planned PQ mail content | docs/claude/ONE-ORDER-27OCT.md PQM0-PQM5, PQN0-PQN5 | — | Q4/Q5 below |

Awam mail inbound today runs through a Bun script (deliver-to-supabase.ts). The founder inbound is **Rust only** (Bun/Node are banned for the founder).

## 2. Technology (founder law, in capitals in CLAUDE.md line 18). One row = one listed technology = where it lives
| Layer | Technology | Where in code |
|---|---|---|
| Backend | Rust, Tokio, Axum; new modules `fmail*.rs` in `server/founder/src` | mail routes `/founder/v1/mail/*`, calendar `/founder/v1/cal/*` |
| Browser to server | every call over the kernel's WebTransport RPC (rpc@1, HTTP/3); fetch only where K8d allows | founder-web/src/mail/, kernel |
| Live new mail / typing-free push | WebTransport server push (live feed already exists), SSE fallback | wt.rs, livefeed.ts |
| **Attachment transfer (his strict word)** | **Tokio + Rust + WebTransport**: one bidirectional stream per chunk, up to 8 parallel streams, resumable (chunk index map held server side), fallback = HTTP/3 range PUT/GET. Chunk = 1 MiB, each chunk AES-256-GCM sealed in the browser by the kernel (`stream@1`), nonce = counter, chunk order authenticated (AAD = file id + index + total), a tampered or reordered chunk is refused | server/founder/src/fmail_att.rs, kernel stream@1, wt.rs |
| Storage | Hetzner Storage Box (mount exists) holds only ciphertext chunks; file key wrapped with X25519MLKEM768-style hybrid (ML-KEM-768 + X25519) | fmail_att.rs, Storage Box |
| Virus scan | ClamAV clamd INSTREAM on the server for every INBOUND attachment, before it is shown or opened; outbound scanned before send. For end-to-end sealed uploads the scan runs on the plain file in the browser-to-server stream window before sealing is finalised (design decision recorded in PQN0: "dedupe vs encryption") | attach_core.rs (parser exists), fmail_att.rs |
| Database | PostgreSQL, RLS ON, own tables `fmail_*`, append-only hash-chained ledger for every send/delete/key event, selftests and CHECK files, number from E166 | docs/cursor-work/sql |
| Inbound | Postfix to a Rust LMTP/pipe handler (`anexomail-founder --deliver`, Tokio), MIME parse, SPF/DKIM/DMARC result stored, spam score, ClamAV, then insert. Message body stored AES-256-GCM encrypted at rest with a per-message key | fmail_in.rs |
| Outbound | Rust SMTP submission with DKIM (Ed25519 + RSA), MTA-STS, DANE where the peer has it, TLS 1.3 with the PQ hybrid when the peer offers it, TLS-RPT; undo-send window; signed sent-log | fmail_out.rs |
| Post-quantum content | OpenPGP RFC 9980 (ML-KEM-768+X25519, ML-DSA-65+Ed25519) in the one WASM kernel (`pqmail@1`); private keys never leave the device | Q4 |
| HTML mail safety | sanitised in the kernel, shown in a sandboxed iframe, remote images blocked by default, link rewriting with a warning on look-alike domains, no scripts, ever | founder-web/src/mail/ |
| Access gates | DBSC-bound session (enforce is ON), passkey touch (step-up) to send as the company, to delete for good, to export; G tiers as in the rest of the founder app | gate.rs, policy_step.rs |
| UI | React 19, TypeScript, TanStack Router, Tailwind 4, Radix/shadcn, Framer Motion, GSAP; **same features and the same look as the awam mail and calendar**, different data. One build, 390 / 820 / 1200+ together | founder-web/src/mail/, cal/ |

## 3. Security list (top notch, each with its proof)
1. End-to-end sealed attachments (AES-256-GCM chunks, hybrid-wrapped key); tamper test = a flipped bit in one chunk is refused (cargo test + kernel test).
2. Magic-bytes and extension policy (attach_core); zip bombs capped (size/ratio/depth); ClamAV on every inbound file; quarantine folder, never auto-open.
3. Sender checks shown on every mail: SPF / DKIM / DMARC / ARC verdict, look-alike warning.
4. Replay/forgery: every write carries the existing Ed25519 request signature; every send goes into the hash-chained ledger and is anchored with the existing Merkle anchors.
5. Rate limits and size caps in Rust, not only in the UI; all inputs checked against fixed lists before SQL (same style as inbox.rs).
6. Data at rest: bodies AES-256-GCM, keys from the vault master (exists), Storage Box ciphertext only; RLS on every table.
7. No remote content, no tracking pixels, no scripts; "unsafe link" interstitial.
8. Panic lock (J8d) also locks the mailbox; export and delete need a fresh passkey touch.

## 4. Order of work inside Q (each step: contract in CURRENT.md first, TECH-LAW rows, then code, then GREEN with saboot)
- **Q0** research note: crate choice for MIME parse, DKIM, OpenPGP PQC, after a licence + audit read (nothing chosen from memory). Records the "dedupe vs end-to-end" decision for the founder (default: dedupe OFF for sealed files).
- **Q1a** SQL `fmail_*` (messages, threads, labels, folders, drafts, outbox, ledger, att chunks) + CHECK + selftest (E166+).
- **Q1b** Rust inbound (LMTP, parse, ClamAV, store) + Postfix hook for naumansherwani.founder@anexomail.com and @nexatect.com (address list from "anexomail inboxes to build").
- **Q1c** Rust read side (folders, threads, search) over kernel RPC; UI list + reader.
- **Q1d** compose/send/outbox/undo/drafts/templates/snooze (port of mailx_core), DKIM outbound, passkey step-up.
- **Q2** shared attachment code (attach_core.rs reused, dedupe rules, signed links).
- **Q3** parallel resumable chunks over WebTransport (Tokio), `stream@1` in the kernel, ClamAV, Storage Box.
- **Q1e** Calendar: `cal_core.rs` reused, founder tables, ICS invites/RSVP, CalDAV, free slots; UI like the awam one.
- **Q4** PQM post-quantum mail content (RFC 9980, `pqmail@1`).
- **Q5** PQN post-quantum network and live-data protection (PQN0-PQN5).
- **Q6** Sealed Agreements.
- Each step is seen live at 390 / 820 / 1200+ before GREEN, and the awam blueprint line is updated (Rule 9).

## 5. Admin > Mail Desk (R3) is SEPARATE
Where the awam problems are heard: sidebar Admin > Mail Desk > Mail, own folder `founder-web/src/admin/maildesk/`, routes `/founder/v1/admin/maildesk/*`, tables `fadm_mail_*`, company mailboxes (support/hello, billing, abuse, glitch, appeals, moveyourbusiness), 24 h SLA, assign/escalate/resolve, deliverability. It shares only the common cores (attach_core, `stream@1`, PQM). Plan: FOUNDER-ADMIN-MAIL-DESK-03NOV.md. Letter order: R3 after Q.

## 6. Where it sits in the order
L-A (now: LA-3, LA-4, LA-2, LA-6; LA-7 needs a separate haan) -> S5 (TanStack Start decision, gate 14 Nov) -> M MoQ (gate 16 Nov) -> N -> O -> P -> **Q (this plan: mailbox + calendar)** -> then **back to D3** and the order continues (D-series, then R/R3, S..V, X). ClamAV and Hetzner Storage Box gates (20 Nov) are closed by Q3. Founder deadline 25 Nov stays the target.

Abhi code mein NAHI: everything above (plan only).
