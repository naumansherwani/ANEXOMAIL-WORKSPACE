# MAIL <-> CHAT BRIDGE (founder order 28 Oct 2026, 13:10 PKT) — duplicate scan, technology first, order
Verbatim order: docs/cursor-work/founder/orders/2026-10-28-1310-mail-chat-bridge-VERBATIM.md. Named "Mail<->Chat Bridge" so it is never confused with the founder's "Bridge" home page. Docs only (Rule 63/64); mock never (Rule 69).

## 0. Technology (Rule 61/62; reuse rule FC18/FC20/FC22: user-side features come to the founder in latest tech, own folders/tables/endpoints, user files untouched)
Postgres (RLS, append-only + immutable triggers) -> Rust `anexomail-founder` (axum 0.8 + tokio; sha2, ring Ed25519) -> existing Rust mail procs for send (Postfix/opendkim signing stays where it is) -> WebTransport/HTTP3 -> WASM kernel verifies hash chains in the browser (F2b) -> React 19.2 split-screen view. Deterministic text rules only, no AI.

## 1. DUPLICATE SCAN — most of this ALREADY EXISTS on the user side (ANEXOChat phases, repo `anexochat/sql/`, E-series)
| Founder item | Exists today (user side) | What is genuinely NEW |
|---|---|---|
| F1 Thread -> secure chat room, one click | Phase 29 `email_discuss_in_chat`, `chat_email_links`, `chat_email_quotes` (email = formal record, chat = instant layer) | one `Thread_ID` master record binding Message-ID headers + chat room; founder-side (cross-tenant, Mail Desk) port |
| F2 Deterministic Promise/Decision -> Work Object, append-only | Phase 23 promise engine (`promise_recovery_log`, `promise_board`, downstream impact), Phase 24 decision ledger (immutable versions, `chat_decision_impact_log`) | extraction from EMAIL text too (today chat), company-wide ledger feeding Dashboard D2 |
| F3 File evidence chain Selected->Verified->Available + stale warning | Phase 28 receipts (Uploaded/Scanned/Verified/Available), Phase 16-18 file truth, Phase 31 `file_context_card`, `file_version_diff` | live "Stale-File" badge on BOTH panes when a later email decision supersedes the file |
| F4 Reply from chat panel as DKIM-signed email + live delivery/provenance | Phase 30 chat->email formal draft (citations, consent, escalations, append-only); provenance Phase 27 | one-step reply from the chat panel (still an explicit Send — Phase 30's "no accidental replacement" rule stays), delivery state shown in chat |
| F5 Honest Edit marker + Delete for Everyone 48 h | E7 delete-for-everyone 48 h (Business), E100 chat edit; Phase 27 provenance | one marker shown on the email<->chat pair; cleanup of fragments (see limits) |
| W1-W5 workflow items | the same phases (29, 30, 23/24, 31, 25 timeline) | Global Outcome Timeline merging email + chat in one view (Phase 25 timeline is chat-only) |
| D1 Unified Thread Identity | `chat_email_links` (pair table) | a single master `bridge_threads` record + chained events |
| D2 Append-only relations with `previous_hash` | Phase 27 `chat_message_provenance` (sealed chain), Phase 24 versions, E102 founder audit chain | one chain across email + chat events (`bridge_events`) |
| D3 Work object cannot be "Complete" without evidence hash | Phase 23 keeps/breaks promises by human decision | DB constraint: completion needs a verified evidence-file hash FK |
| D4 `File_Master` SHA-256, zero duplicate storage | Phase 13-15 `chat_files`, Phase 31 dedupe | one `file_master` shared by email attachments and chat |
| D5 Provenance (UTC, device token, session hash) per row | Phase 27 provenance, Phase 28 receipt devices | bind founder device token + session hash on every `bridge_events` row |
Founder-side rule: ports are NEW tables/endpoints under `/founder/v1/bridge/*`; the existing ANEXOChat tables are read through existing procs only, never edited.

## 2. New founder-side schema (planned names; E-numbers assigned when built)
`bridge_threads(thread_id, org_id, email_message_id_root, chat_room_id, opened_by, created_at)` · `bridge_events(id, thread_id, kind[email|chat|file|promise|decision|edit|revoke], payload_hash, prev_hash, utc, device_token, session_hash)` insert-only + deny update/delete triggers · `work_objects(id, thread_id, text_hash, owner, due, status, evidence_file_hash FK)` with CHECK/trigger: status=done requires verified `file_master.sha256` · `file_master(sha256 PK, size, first_seen)` · every table RLS on, founder-only access through RPCs.

## 3. Honest limits
- "Delete for Everyone after 48 h" works for recipients INSIDE Anexomail. A copy already delivered to Gmail/Outlook cannot be pulled back by anyone; we mark it revoked in our ledger and remove our fragments.
- Append-only and "delete" are reconciled as: content is crypto-shredded (key destroyed), the hash + tombstone stay in the chain, so tampering is still provable.
- A sent email cannot be edited at the recipient; an "Honest Edit" marker applies to chat messages and drafts, and a correction email is linked to the original.
- "Strict text patterns, no AI": commitments phrased unusually are missed; every extraction shows the matched phrase and a human can add one by hand.

## 4. Look (Mail Desk deck, later also the Business dashboard under FC22)
Split view: left = email thread, right = live chat stream, bottom anchor = Bridge Engine strip (hash chain status, work dependencies, file tracking, linear). One Outcome Timeline merges both. Cinematic look kept; 12-hour times; 390/820/1440 all supported.

## 5. Order (FOUNDER-MASTER-ORDER)
After 11 (Mail Desk) and 12 (Systems + AI + ANEXOChat): **12b-1** Thread-to-Room + `bridge_threads/events` + hash chain · **12b-2** deterministic extraction -> work objects (+ D3 constraint) · **12b-3** file evidence chain + stale badge (`file_master`) · **12b-4** reply from chat as DKIM-signed email (explicit Send) · **12b-5** honest edit / revocation sync · **12b-6** Global Outcome Timeline + split view. Feeds Dashboard D2 (Work Chain) and Bridge B1 (Needs you).

## 6. COMMON FEATURES — user ko bhi, founder ko bhi (founder order 28 Oct 13:16 PKT)
Ye 6 features ANEXOChat ke USERS ko pehle se milte hain aur FOUNDER ko bhi milenge (latest-tech port, founder ke apne tables/endpoints, user files untouched — FC18/FC20/FC22). Dobara design nahi hota; ek hi behaviour dono taraf.
| # | Common feature | User side (hai) | Founder side (aayega) |
|---|---|---|---|
| C1 | Mail se chat room | ANEXOChat phase 29 | step 12b-1 |
| C2 | Promise aur Decision nikalna | phase 23 + 24 | step 12b-2 |
| C3 | File evidence + stale-file warning | phase 28 + 31 | step 12b-3 |
| C4 | Chat se email jawab (explicit Send) | phase 30 | step 12b-4 |
| C5 | Delete for Everyone 48 ghante | E7 | step 12b-5 |
| C6 | Provenance hash chain | phase 27 | step 12b-1 (chain) |
Rule: user side mein koi behaviour badlega to founder wali copy ke saath compare hoga (parity), kyunke dono ek hi promise hain.
