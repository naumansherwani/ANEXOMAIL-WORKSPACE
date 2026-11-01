# BRIDGE ENGINE — Email <-> Chat: functional workflow + relational design (design note, Rule 63; 1 Nov 2026)
Founder order (verbatim in docs/cursor-work/founder/founder-commands.md, 1 Nov 05:00): five features (unified ledger threading, promise and decision extraction, file evidence chain, direct broadcast to external email from chat, honest edit and revocation sync) + split-screen Bridge (left email, right chat, bottom/centre Bridge Engine). Deliverable now: workflow + database logic for the founder's product architecture manual. NO code was written for this note; every SQL block below is a design sketch, built later phase by phase (Rule 66).

## 0. Ground rules this design keeps
1. NO AI. Every decision is deterministic: the one WASM kernel (`intent@1`, Rule 52) parses promises and deadlines; Rust (tokio, async, 24 h) and SQL re-check the same result. Same input gives the same output, always.
2. REUSE, never duplicate. Existing and proven in this repo: `mail_threads`, `mail_messages`, `mail_attachments` (sha256, scan, org_id; E48), `mail_outbox`, `mail_domains`; `chat_conversations`, `chat_messages` (edited_at, deleted_at, seq), `chat_attachments`, `chat_edit_message`, `chat_delete_message` (1 h) and E7 (Business: delete for everyone within 48 h); `work_promises`, `work_tasks`, `calendar_events`; **`commitment_ledger` E97** (append-only, hash-chained, HMAC-sealed per org, actions recorded/linked/fulfilled/broken/snoozed/cancelled). The Bridge adds only the join layer, the timeline, the file state machine, outbound and tombstones.
3. The ledger holds HASHES and ids, never message text or file bytes. That is what makes "append-only forever" and "delete for everyone really deletes" compatible (section 8).
4. Honesty limits (written, not hidden): an email already delivered to an external mailbox cannot be unsent by anyone; delete-for-everyone covers the workspace (both sides of the Bridge, all members, all copies we hold) and clean-up of fragments. Delivery confirmation is "accepted by the receiving server" (SMTP status / DSN), not "read".
5. User side and founder side never mix. This is a USER-APP (workspace) feature in the awam stack. The founder's Bridge page may only show aggregate counts (links, open promises, stale files, outbound failures), never content (Rule 69, FC18).
6. One phase at a time, green on server + CHECK + live in Chrome before the next (Rule 66). SQL numbers proposed: E111 to E116 (E107 stays reserved for F2c Merkle, E109/E110 are founder live/host proof).

## 1. The idea in one picture
```
 LEFT: Email thread (mail_threads)      |  RIGHT: Chat room (chat_conversations)
 ----------------------------------------------------------------------------
 [msg][msg][msg]  ...                   |  [chat][chat][file][voice][decision]
 ----------------------------------------------------------------------------
 BRIDGE ENGINE (bottom anchor): bridge_events = ONE Outcome Timeline, hash-chained
   mail_in -> chat_msg -> promise -> file v2 -> decision -> mail_out -> delivered
   + dependency lines (promise -> task -> promise) + file state badges + stale warnings
```
One click on a thread creates (or opens) its room: `bridge_open(thread_id)`. One thread has at most one room (unique). Everything that happens on either side is appended, in order, to ONE timeline.

## 2. Core tables (the relational spine)
```sql
-- 2.1 the link: one mail thread <-> one chat room
create table bridge_links (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  thread_id uuid not null references mail_threads(id) on delete cascade,
  conversation_id uuid not null references chat_conversations(id) on delete cascade,
  created_by uuid not null, created_at timestamptz not null default now(),
  state text not null default 'open' check (state in ('open','closed')),
  unique (thread_id), unique (conversation_id)
);
-- 2.2 the Outcome Timeline: append-only, hash-chained per link, HMAC-sealed with the org key (same primitive as E97 commitment_*)
create table bridge_events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null, link_id uuid not null references bridge_links(id) on delete cascade,
  seq bigint not null,                                  -- per link, gapless
  kind text not null check (kind in ('mail_in','mail_out','chat_msg','chat_file','chat_voice','promise','decision',
                                     'file_state','stale','edit','revoke','delivery')),
  ref_table text not null, ref_id uuid not null,        -- points at the real row (mail_messages, chat_messages, work_promises ...)
  content_hash text not null check (content_hash ~ '^[0-9a-f]{64}$'),   -- SHA-256 of the canonical content, never the content
  actor uuid, payload jsonb not null default '{}'::jsonb,               -- ids, counts, states only (CHECK: no body, no email address)
  prev_seal text not null default '', seal text not null,
  created_at timestamptz not null default now(),
  unique (link_id, seq)
);
```
Triggers: UPDATE, DELETE, TRUNCATE are refused (same guard pattern as `founder_live_events`). The `seal` = HMAC(org_key, prev_seal || seq || kind || ref_id || content_hash || created_at). `bridge_verify(link_id)` recomputes the chain (the Rust core and the kernel can both do it; the UI shows a green "chain intact" or the first broken seq).

How events get written (no polling guesswork): triggers on `mail_messages` insert and `chat_messages` insert call `bridge_append(link_id, kind, ref, hash)` only when that thread/conversation has a link. They add a few microseconds and never fail the original insert (exception swallowed into a `bridge_dead_letters` row, counted on the dashboard).

## 3. Feature 1: Unified Ledger Threading (Deterministic Context Map)
Workflow:
1. User clicks "Open room" under a thread. `bridge_open(thread_id)` creates the chat conversation (type `thread_room`, members = thread participants who are workspace members; external people are NOT members, they stay email-only) and the `bridge_links` row, and appends event 0.
2. From then on every mail message and every chat message/file/voice note lands in `bridge_events` in true order. The timeline ordering key is `(created_at, source seq)`; ties resolved by `chat_messages.seq` / mail `received_at` so the order is deterministic and reproducible.
3. The "context map" is a read model: `v_bridge_timeline` joins events to their rows (only for members who may see the thread). It shows mail and chat in ONE list with a marker for which side each came from, so "what was said on email" and "what was decided on chat" read as one story.
Access rule: the room's RLS = the thread's RLS (a user sees a room only if they can see the thread). No new permission model.

## 4. Feature 2: Immutable Promise and Decision extraction (no AI)
Pipeline (deterministic, three checks):
1. Compose time, in the browser: WASM `intent@1` reads the line ("I will deliver the sales report by Friday") and returns a typed result: `{ kind: 'promise', verb, object, due: <resolved date by the user's timezone rules>, confidence: 'rule-matched' }`. Resolution of "Friday" uses the org timezone and the message timestamp, so it is reproducible. If no rule matches, nothing is extracted (no guess).
2. Send time, in Rust: the server runs the same parser (same crate, compiled natively) on the stored text and REFUSES to register if its result differs from what the client sent (parity check, as E97 `attention_cost` already does).
3. Register: `bridge_record_promise(link_id, source_event_id, parsed)` inserts into `work_promises` (+ `work_tasks`, + optional calendar hold, all existing, atomic) and appends `commitment_ledger` action `recorded` and a `bridge_events` row kind `promise`. The promise row carries `source_hash` = hash of the original chat line. The line itself stays where it is; nobody can later claim a different sentence was the promise.
Decisions: a decision is a promise-like record with `kind='decision'` created by an explicit rule phrase or an explicit "Mark as decision" click by a member with the right (never inferred). It is appended to the same ledger.
Downstream impact (the "warning sign that cannot be erased"):
```sql
create table bridge_dependencies (
  org_id uuid not null, from_promise uuid not null references work_promises(id),
  to_ref_table text not null check (to_ref_table in ('work_promises','work_tasks','calendar_events')), to_ref_id uuid not null,
  declared_by uuid not null, created_at timestamptz not null default now(),
  primary key (from_promise, to_ref_table, to_ref_id)
);
```
- A cycle check (recursive CTE) rejects any dependency that would close a loop.
- `bridge_impact(promise_id)` is a recursive CTE returning every downstream item and its owner. Pure SQL, no model.
- A tokio job (Rust, every minute) finds promises past due and not fulfilled and appends `commitment_ledger` action `broken` (once) with `bridge_events` kind `promise`. The dashboard warning for downstream items is computed from `bridge_impact`, shown while the promise stays broken. It can only change by appending a new row (`fulfilled` late, `snoozed` with a reason by the owner's manager); the original `broken` row stays in the chain. That is what "cannot be erased" means technically.

## 5. Feature 3: File Evidence Chain ("Selected -> Verified -> Available") and stale-file warning
```sql
create table bridge_file_refs (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null, link_id uuid not null references bridge_links(id) on delete cascade,
  origin text not null check (origin in ('chat','mail')),
  chat_attachment_id uuid references chat_attachments(id), mail_attachment_id uuid references mail_attachments(id),
  name_key text not null,                     -- normalised family name (lower-case, extension kept, version suffixes stripped by fixed rules)
  sha256 text not null check (sha256 ~ '^[0-9a-f]{64}$'), size_bytes bigint not null,
  version_no int not null,                    -- 1,2,3 within (link_id, name_key) by arrival order
  supersedes uuid references bridge_file_refs(id),
  state text not null default 'selected' check (state in ('selected','verified','available','blocked')),
  created_at timestamptz not null default now(),
  unique (link_id, name_key, version_no)
);
```
State machine (a transition function `bridge_file_advance(id)`, never a direct UPDATE of `state`):
- `selected`: the file was picked in chat or attached to mail; hash computed.
- `verified`: the existing attachment scan (E48 `mail_attachments.scan`) is clean AND the sha256 matches the stored object. A failed scan sets `blocked` (never `available`).
- `available`: stored, verified, and linked into the thread's attachment pipeline (same sha256 means ONE stored object, two references, so chat and mail show the same file and storage is not doubled).
Stale warning, deterministic:
- When a newer version of the same `name_key` arrives (either side), the older one is marked `superseded` in the read model and a `bridge_events` kind `stale` row is appended.
- When a mail decision event (kind `decision`) is newer than the file a chat member is looking at, the chat screen shows the warning with a LIVE diff: for text-like files a line diff; for others the hash, size and version difference plus the decision text link. The diff is computed by a fixed algorithm (Myers line diff in Rust), same result every time. We do not claim semantic understanding of binary files.

## 6. Feature 4: Direct reply to an external client from the chat panel
Workflow:
1. A client writes from Gmail or Outlook; the message arrives as `mail_in` in the linked thread.
2. In the chat panel the member types a reply and presses "Send as email". `bridge_send_external(link_id, chat_message_id, to, subject?)` builds a `mail_outbox` row with correct `In-Reply-To` and `References` from the thread (so the client's mail app threads it) and the org domain identity (`mail_domains`).
3. The existing Rust mail core signs it with the domain's DKIM key and sends. DMARC alignment is checked BEFORE enqueue: `From` domain must equal the signing domain (aligned); if the domain has no verified DKIM or an enforced DMARC policy fails the check, the send is refused with a plain reason shown in chat (no silent fallback).
4. `bridge_outbound` tracks it:
```sql
create table bridge_outbound (
  id uuid primary key default gen_random_uuid(), org_id uuid not null, link_id uuid not null references bridge_links(id),
  chat_message_id uuid not null references chat_messages(id), mail_outbox_id uuid not null,
  from_domain_id uuid not null references mail_domains(id), dkim_signed boolean not null default false, dmarc_aligned boolean not null,
  rfc_message_id text, provenance_hash text not null,   -- SHA-256 over (org, link, sender user, device, chat_message hash, final RFC822 hash)
  state text not null default 'queued' check (state in ('queued','sent','deferred','delivered','bounced','refused')),
  last_status text, updated_at timestamptz not null default now(), unique (chat_message_id)
);
```
5. Provenance (origination verification) = the sealed timeline event of kind `mail_out` carrying `provenance_hash`: it proves which member, from which approved device, wrote which chat line, and which exact bytes were sent. Delivery confirmation updates `state` from SMTP results and DSNs and appends a `delivery` event; the chat shows "Delivered to the receiving server at 14:02" or the bounce reason. We never show a fake "read" tick.

## 7. Feature 5: Honest Edit marker
- Chat edit already exists (`chat_edit_message`, `edited_at`). The Bridge adds `bridge_edits(event_id, version_no, content_hash_before, content_hash_after, edited_by, edited_at)` and an `edit` event. The UI shows "Edited" with the time on that message in the timeline and on the linked promise/decision if the edited line was its source (the promise keeps `source_hash` of the ORIGINAL line, so a quietly changed promise is visible as a mismatch).
- Email already sent cannot be edited. A correction is a NEW message: `Correction to <message>` appended with a link to the original (`supersedes` in payload). The marker is honest: "original sent 10:02, correction sent 10:20".

## 8. Feature 5b: Delete for Everyone (including after 48 h) and fragment clean-up
- Window: Business plan keeps E7 (48 h). The founder's wording "48 ghante baad bhi kaam karega" matches the card promise "still works after 48 hours" for Business; other plans keep the 1 h rule. Policy is a column on the plan, not hard-coded.
- `bridge_revoke(event_id, reason)` (member who sent it, or an org admin with the right):
  1. appends a `revoke` event (tombstone): `ref_table`, `ref_id`, `content_hash` of what was removed, who, when, reason code. This is the only thing that remains, and it holds no content.
  2. `bridge_scrub(target)` removes the body from `chat_messages`/`mail_messages`, deletes attachment objects and `bridge_file_refs` rows that are not referenced elsewhere, and deletes fragments: search index rows, `mail_thread_insights` snippets, previews, notification text, outbox bodies not yet sent. Each cleaner returns a count; the counts are written into the tombstone payload (`fragments_cleaned`). `bridge_verify_scrub(target)` re-scans every known fragment table for the hash/id and must return zero.
  3. A promise whose source line was revoked stays in the ledger as `source_revoked: true` (the commitment existed; its wording is gone), so accountability is not lost by deleting text.
- Limits: external recipients keep what they received. The UI says so before confirming.

## 9. Split-screen UI (React-TS, Cinematic, kernel-verified)
- Left panel: mail thread; right panel: chat room; bottom anchor: the Bridge Engine strip (timeline with hash seals, dependency lines, file badges `Selected -> Verified -> Available`, stale warnings, "chain intact" badge from `bridge_verify`).
- Live updates: Rust tokio streams (SSE first, WebTransport later, same plan as the founder Live Pulse); each frame is verified in the browser by the WASM kernel; unverified frames are not drawn.
- Real data only. A thread without a room shows "Open room", never an invented example. Empty timeline says "No events yet".
- Mobile: panels stack; the Bridge strip becomes a tab.

## 10. Where each technology lives (Rule 70)
| Part | Technology |
|---|---|
| Tables, triggers, state machine, impact CTE, tombstones, verify functions | SQL (Postgres, RLS on, append-only guards, selftests, CHECK files) |
| Event writers, due-promise job, outbound queue and DKIM/DMARC pre-check, delivery status ingest, scrub orchestration, SSE stream | Rust (tokio, async, 24 h) in the existing mail/chat cores (awam stack, not the founder binary) |
| Promise parsing, hash, seal verification in the browser, line diff preview | the ONE WASM kernel (`intent@1`, `merkle`, `verify`) |
| Split-screen, timeline, badges, composer "Send as email" | React-TS + Tailwind, Cinematic CSS |
| Founder-side visibility (counts only) | founder Bridge page: Rust `/founder/v1/...` aggregate RPC over E109-style fingerprints, never content |

## 11. Phases (each one green before the next)
| Phase | Content | SQL |
|---|---|---|
| B1 | links + Outcome Timeline + verify + room open | E111 |
| B2 | promise/decision from chat via kernel parity, dependencies, impact, broken job | E112 |
| B3 | file refs state machine, stale warning, diff | E113 |
| B4 | external send from chat, DKIM/DMARC pre-check, provenance, delivery | E114 |
| B5 | edit markers + corrections | E115 |
| B6 | revoke + scrub + verify_scrub | E116 |
| B7 | split-screen UI + live stream + founder aggregate card | — |
Order rationale: B1 is the spine every other feature appends to; B6 comes after B1-B5 because it must know every fragment table the earlier phases create.

## 12. Open questions for the founder (only the ones that change the build)
1. Room membership: workspace members of the thread only (recommended), or also invited guests with limited rights?
2. Delete-for-everyone window for non-Business plans: keep 1 h (as the plan cards say today)?
3. `Send as email` for a domain without verified DKIM: refuse (recommended, honest) or send unsigned with a warning?
