# ANEXOChat — SQL blocks (Supabase #4)

Yeh folder ANEXOMAIL ke `sql/` se ALAG hai — ANEXOChat ka apna ghar.
Run: Supabase #4 -> SQL Editor mein poori file copy-paste -> Run. Har file idempotent + self-healing,
grants pehle phir RLS. Blueprint: `anexochat/docs/anexochat-blueprint.md`. Gateway: `anexochat/docs/caddy-anexochat.md`.

## anexochat_phase01_foundation.sql — ANEXOChat Phase 1 slice (Phases 1-5)

Kahan chalti hai: **Supabase #4 -> SQL Editor**.

- Tables: `chat_workspaces` · `chat_members` · `chat_conversations` · `chat_participants` ·
  `chat_messages` (unique `client_msg_id` = idempotent send, per-conversation `seq` = ordering) ·
  `chat_message_receipts` (append-only delivered/read) · `chat_presence` · `chat_typing` ·
  `chat_files` + `chat_file_chunks` (sha256 + resume truth) · `chat_atmosphere_prefs`
- GRANTs + RLS: har object workspace membership ke peeche; `chat_access()` gate =
  founder_accounts YA entitlement `business | business_pro | ai_*`. Basic/Pro = zero access
- Functions: `chat_ensure_workspace` · `chat_direct_conversation` · `chat_send` (idempotent) ·
  `chat_mark` · `chat_conversation_list` (truthful health + reason) · `chat_messages_page` ·
  `chat_presence_ping` · `chat_typing_ping`
- ATMOSPHERE LOCK: Dawn/Day/Dusk/Night device clock se; Rain/Storm/Snow/Sunny sirf manual.
  Koi weather API, koi temperature — kahin store bhi nahi hota
- End par 2 VERIFY queries (chat tables + chat functions count)

## anexochat_phase03_message_engine.sql — ANEXOChat Phases 3-6

Kahan chalti hai: **Supabase #4 -> SQL Editor** (pehle `anexochat_phase01_foundation.sql`).

- **Phase 3 (message engine):** `chat_reactions` · `chat_message_edits` (append-only history,
  purana body kabhi gum nahi) · soft delete tombstone · `chat_work_items` (task/promise/decision)
  · `chat_conversation_state` (active/waiting/blocked/closed) · `chat_audit`
- **Phase 4 (SB4):** har naye object par `workspace_id` — workspace isolation mandatory
- **Phase 5 (RLS):** har table par RLS + participant/membership policy; security DB boundary par
- **Phase 6 (ANEXOMAIL integration):** `chat_unread_total(_user)` = sidebar badge ka asli sach
- Functions: `chat_log` · `chat_react` · `chat_edit_message` · `chat_delete_message` ·
  `chat_work_create` · `chat_work_list` · `chat_work_set_state` ·
  `chat_conversation_set_state` · `chat_unread_total`
- VERIFY: chat tables **16**, chat functions **19**

## ANEXOChat Phase 7–10 — Cinema + ANEXOVideoChat
- `anexochat/sql/anexochat_phase07_cinema_video.sql` — reply_to + pinned_at on `chat_messages`,
  mute/archive on `chat_participants`, `chat_message_hidden` (delete for me),
  `chat_signals` (WebRTC signalling, 2-min TTL), `chat_video_allowed()`
  (founder + business_pro only), 5-minute edit window, 1-hour delete-for-everyone
  window, `chat_messages_page` with reactions + reply quote, `chat_search_messages`.
- Verify: `select count(*) from information_schema.tables where table_schema='public' and table_name like 'chat\_%';` → 18
- Verify: `select count(*) from information_schema.routines where routine_schema='public' and routine_name like 'chat\_%';` → 27

## anexochat_phase10b_8k_video.sql — ANEXOChat Phase 10B (adaptive 8K truth)

Kahan chalti hai: **Supabase #4 -> SQL Editor** (Phase 10A ke BAAD).

- `chat_call_sessions` + columns: `capture_width/height` · `capture_native_8k` ·
  `max_encoded_*` · `max_decoded_*` · `top_rung` · `hw_accelerated` · `downgrades` · `upgrades`
- `chat_call_stats` + columns: capture/encoded/decoded size · `rung` ·
  `quality_limitation` · `available_out_kbps` · `frames_dropped` · `power_efficient`
- `chat_call_stat()` update: wahi ownership check (`not_your_call`) + naye fields
- View `chat_call_resolution_truth` — 8K asal mein kitni baar chala (measured, not marketed)
- Verify: `select * from public.chat_call_resolution_truth limit 5;`

## anexochat_phase11_attachments.sql — ANEXOChat Phase 11 (attachments + avatars)

Kahan chalti hai: **Supabase #4 -> SQL Editor**.

- Bucket `chat-media` (private, 25MB cap, sirf png/jpeg/webp/avif)
- Table `chat_attachments` (pending -> ready) + RLS: sirf conversation ke participants
- `chat_members` + `avatar_path` / `avatar_updated_at`
- Functions: `chat_attachment_new` · `chat_attachment_commit` · `chat_attachment_attach` · `chat_avatar_set`
- Backend routes: `POST /api/chat/attachments/ticket|commit|attach` ·
  `GET /api/chat/attachments/:messageId` · `POST /api/chat/profile/avatar/ticket|commit`
- Verify: `select state, count(*) from public.chat_attachments group by 1;`

- `anexochat_phase12_continuity.sql` — PHASE 12 cross-device continuity: `chat_devices`, `chat_drafts` (rev-based), `chat_positions` (anchor seq), `chat_continuity()`, `chat_search_deep()` (trigram full history). Rust PRIMARY arms: chat.device.seen · chat.continuity · chat.draft.save · chat.position.save · chat.search.deep; Bun `/api/chat/*` fallback.
- `phase13_15_file_engine.sql` — ANEXOChat Phase 13/14/15 file engine: file+version+chunk+transfer tables, pool/transfer separation, integrity ack, resume identity, commit + retention.
- `phase16_18_file_truth_safety.sql` — file evidence chain, type policy, local scan jobs, safety events, enforcement, download proof.
- `phase19_22_device_safety_work.sql` — device safety vault (signal minimization + retention purge), device trust + revoke events, safety reports/queue/reveal log/enforcement, work execution chain (provenance, dependency, evidence), message star + forward, `chat_phase_entitlements`.
- `phase23_promise_engine.sql` — promise recovery engine (promise columns on `chat_work_items`, append-only `promise_recovery_log`, `promise_board/recover/keep/history`), plus device ban appeals (`device_ban_appeals`, `device_appeal_open/queue/decide`) — device-only bans, never network.
- `phase24a_account_integrity.sql` — **PHASE 24A** (Phase 24 ke saath chalne wala account integrity layer): one person, one account ladder — `account_integrity` state, append-only `account_integrity_log`, published `account_integrity_policy` (3 accounts/device · 3 signups/24h · 72h export), `account_integrity_evaluate` (deterministic, sirf flag — engine kabhi block nahi karti), human-only `warn`/`block` (block sirf likhi hui final warning ke baad) with device-hash-only bans (IP/network kabhi nahi), `export_ready`, `release`, aur `purge_due` jo sirf 72 ghante ka export window guzarne ke baad delete karti hai.
- `phase24_decision_ledger.sql` — ANEXOChat PHASE 24 (tumhari asli tarteeb): decision ledger + decision impact map. `chat_decisions` (provenance: message_id + maker + UTC decided_at + source + SHA256 `body_hash`), append-only `chat_decision_versions` (immutability trigger — history kabhi overwrite nahi), `chat_decision_links` (sirf insaani link, 8+ char reason, remove = soft + logged), append-only `chat_decision_impact_log`, aur functions `decision_mark` / `decision_board` / `decision_state` / `decision_impact` (affects + `derived_from: same_conversation` sirf ishaara) / `decision_amend` (12+ char reason, version+1) / `decision_link` / `decision_unlink`.
- `phase25_27_timeline_health_provenance.sql` — ANEXOChat PHASE 25/26/27: conversation → outcome timeline (`conversation_timeline`, communication aur outcome do alag lane, har event apne asli record + evidence ke saath), `chat_message_important` (mark/unmark dono record), matter-level health (`conversation_health` / `conversation_health_board` — healthy · waiting · blocked · completed + owner + due + `reasons[]` with evidence), commitment collision prevention (`commitment_collisions` + append-only `commitment_collision_events`, `commitment_collision_scan` sirf insaani `depends_on` par — engine dependency kabhi invent nahi karti, `commitment_collision_act` 8+ char wajah ke saath, deadline/owner tabdeeli Phase 23 ke `promise_recover` se), aur message provenance seal chain (`chat_message_provenance` append-only + insert trigger + `chat_provenance_backfill`, `message_provenance` = sender · workspace · millisecond UTC · receipts · Integrity Verified, `conversation_chain_verify` tamper-evident chain audit). Helper `chat_feature_ok()`. Rust PRIMARY arms: chat.timeline.get · chat.timeline.important · chat.health.conversation · chat.health.board · chat.provenance.message · chat.provenance.chain · chat.collision.scan · chat.collision.act; Bun `/api/chat/timeline|health|provenance|collisions/*` fallback.

- `phase31c_file_download_manifest.sql` — PHASE 31C file download truth: `file_download_manifest(_user,_version)` (service_role only) — sirf ready + clean + available version, caller participant/owner, har chunk ka DB sha256 tarteeb se. Engine `GET /file/download?version=` (Rust :3200 primary) / `GET /api/chat/file/download` (Bun fallback) chunks stream karte waqt har sha256 match karta hai; mismatch = stream band. Pehli baar "Downloaded" step asli download par likha ja sakta hai (`file_download_ack` client se poore stream ke baad).
