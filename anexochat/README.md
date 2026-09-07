# ANEXOChat — apna alag folder (ANEXOMAIL se juda)

ANEXOChat ka har repo asset yahan rehta hai. ANEXOMAIL Workspace ke `sql/` aur `docs/`
mein ANEXOChat ka kuch nahi rakha jata.

```
anexochat/
  sql/    — har ANEXOChat phase ka SQL (Supabase #4 mein copy-paste)
  docs/   — blueprint, file engine, gateway (Caddy), TURN/relay
```

## SQL (Supabase #4 -> SQL Editor)

| File | Phase | Kya banata hai |
| ---- | ----- | -------------- |
| `sql/anexochat_phase01_foundation.sql` | 1–5 | workspaces, members, conversations, messages, receipts, presence, files, `chat_access()` |
| `sql/anexochat_phase03_message_engine.sql` | 3–6 | reactions, edit history, tombstone, work items, conversation state, audit |
| `sql/anexochat_phase07_cinema_video.sql` | 7–10 | reply/pin, mute/archive, hidden messages, WebRTC signals, `chat_video_allowed()` |
| `sql/anexochat_phase10a_call_engine.sql` | 10A | call sessions/stats, ICE + relay truth |
| `sql/anexochat_phase10b_8k_video.sql` | 10B | measured resolution truth (8K sirf jab asal mein chale) |
| `sql/anexochat_phase11_attachments.sql` | 11 | `chat-media` bucket, attachments, avatars |
| `sql/anexochat_phase11b_attachment_flag.sql` | 11B | attachment flag fix |
| `sql/anexochat_phase12_continuity.sql` | 12 | devices, drafts (rev), positions, deep trigram search |
| `sql/phase13_15_file_engine.sql` | 13/14/15 | transfer vs storage split, chunk sha256, resumable 5 GB |
| `sql/phase16_18_file_truth_safety.sql` | 16/17/18 | evidence chain, type policy, local-only scanning |
| `sql/phase19_22_device_safety_work.sql` | 19/20/21/22 | device vault, trust revoke, safety queue, work chain |
| `sql/phase23_promise_engine.sql` | 23 | promise recovery (human-only), device ban appeals |
| `sql/phase24_decision_ledger.sql` | 24 | decision ledger + impact map (versioned, never overwritten) |
| `sql/phase24a_account_integrity.sql` | 24A | one person, one account ladder — flag -> written warning -> human block, device-hash-only bans, 72h export before purge |

Tafseel: `sql/README.md` (isi folder mein).

## Docs

- `docs/anexochat-blueprint.md` — Phases 1–57 ka asli spec (build isi se).
- `docs/anexochat-file-engine.md` — file/transfer engine ops.
- `docs/caddy-anexochat.md` — gateway: `/rpc/*` · `/file/*` · `/wt/*` -> Rust :3200, Bun :3300 fallback.
- `docs/anexovideochat-turn.md` — coturn/relay host setup.

## Code kahan hai (yeh folder sirf SQL + docs ka hai)

Rust PRIMARY engine `server/rust/main.rs`, Bun fallback `server/routes/chat.ts`,
frontend `src/routes/app.chat*`, `src/components/app/chat/*`, `src/lib/chat-*.ts`.
