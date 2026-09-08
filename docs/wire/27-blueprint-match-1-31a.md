# 27 — Blueprint match · Phase 1 → 31A (static repo read, 8 Sep 2026)

Status: READY (har row repo mein maujood; DONE sirf `docs/wire/26` ke live proof ke baad)

Source: `anexochat/docs/anexochat-blueprint.md` vs `src/routes/app.chat.tsx` (ek surface — `anexochat.tsx` / `anexovideocall.tsx` / `chat.tsx` sirf redirect → `/app/chat`) · `anexochat/sql/*.sql` · `server/rust/main.rs` dispatch · Bun mirror `server/routes/chat.ts`, `server/routes/files.ts`.

| Phase | Naam | SQL | Rust `/rpc/*` (main.rs line) | Repo |
|---|---|---|---|---|
| 1 | Foundation | `anexochat_phase01_foundation.sql` | `chat.bootstrap` 306 | READY |
| 2 | Dual realtime transport | (schema nahi, by design) | `src/lib/chat-transport.ts` Rust→REST chain | READY |
| 3 | Message engine | `anexochat_phase03_message_engine.sql` | `chat.send` 363 · `chat.messages` 344 · `chat.receipts` 395 | READY |
| 4–5 | Data foundation + RLS | phase01/03 (RLS, `chat_access()`) | DB layer | READY |
| 6 | Mail integration (unread) | phase03 `chat_unread_total` | `chat.unread` 582 | READY |
| 7–8 | Core UI + messenger parity | `anexochat_phase07_cinema_video.sql` | `chat.conversations` 323 · `chat.react` 470 · `chat.message.pin` 640 · `chat.search` 674 | READY |
| 9 | Message states | phase01 receipts | `chat.typing` 416 · `chat.presence` 445/434 | READY |
| 10 | Edit/delete | phase07 | `chat.message.edit` 485 · `.delete` 500 | READY |
| 10A | Call engine | `anexochat_phase10a_call_engine.sql` | `chat.signal.send` 858 · `.poll` 880 · `chat.turn.credentials` 892 · `chat.call.start` 907 · `.end` 945 | READY |
| 10B | Adaptive 8K | `anexochat_phase10b_8k_video.sql` | `chat.call.stat` 927 | READY |
| 11 | Attachments/drafts | `anexochat_phase11_attachments.sql` | `chat.attachment.commit` 589 · `.attach` 605 · **ticket/list/avatar Bun-only** (`server/routes/chat.ts:585,664,695,708` — blueprint line 222 ke mutabiq, S3 signing Bun par) | READY (documented split) |
| 11B | Attachment flag | `anexochat_phase11b_attachment_flag.sql` | via `chat.messages` | READY |
| 12 | Continuity | `anexochat_phase12_continuity.sql` | `chat.device.seen` 688 · `chat.continuity` 709 · `chat.draft.save` 719 · `chat.position.save` 753 · `chat.search.deep` 775 | READY |
| 13–15 | File engine / 5 GB resumable | `phase13_15_file_engine.sql` | `file.state` 972 · `file.begin` 980 · `file.transfer.state` 999 · `.mark` 1007 · `file.commit` 1021 · `file.versions` 1033 · `POST /file/chunk` 2687 | READY |
| 16–17 | File truth + safety | `phase16_18_file_truth_safety.sql` | `file.truth` 1044 · `file.evidence` 1053 · `file.safety.state` 1068 · `file.download.ack` 1073 | READY |
| 18 | Content safety | same | `chat.safety.report` 1125 · `.queue` 1143 · `.advance` 1152 · `.reveal` 1172 · `.standing` 1186 | READY |
| 19–20 | Device vault + trust | `phase19_22_device_safety_work.sql` | `chat.device.vault` 1089 · `.trust.list` 1106 · `.trust.set` 1110 | READY |
| 21 | Safety reporting | same | (Phase 18 arms) | READY |
| 22 | Message → work | same | `chat.work.create` 512 · `.list` 535 · `.state` 546 · `.suggest` 1194 · `.from_message` 1203 · `.depend` 1222 · `.complete` 1236 · `.chain` 1252 · `.board` 1261 | READY |
| 23 | Promise engine | `phase23_promise_engine.sql` | `chat.promise.board` 1266 · `.recover` 1268 · `.keep` 1288 · `.history` 1304 | READY |
| 24 | Decision ledger | `phase24_decision_ledger.sql` | `chat.decision.mark` 1318 … `.unlink` 1407 | READY |
| 24A | Account integrity | `phase24a_account_integrity.sql` | `chat.device.appeal` 2292 · `.queue` 2306 · `.decide` 2317 | READY |
| 25–27 | Timeline · health · provenance · collision | `phase25_27_timeline_health_provenance.sql` | `chat.timeline.get` 1428 · `chat.health.*` 1462/1471 · `chat.provenance.*` 1475/1484 · `chat.collision.*` 1497/1508 | READY |
| 28 | Receipts + handover | `phase28_receipts.sql` | `chat.receipt.*` 1532–1600 · `chat.handover.*` 1623–1670 | READY |
| 29 | Email → chat | `phase29_email_to_chat.sql` | `chat.bridge.*` 1687–1773 | READY |
| 30 | Chat → email | `phase30_chat_to_email.sql` | `chat.email.*` 1797–1876 | READY |
| 31 | File context | `phase31_file_context.sql` | `file.context.card` 1889 · `.diff` 1898 · `.duplicates` 1913 · `.stale` 1922 · `.link` 1931 · `.unlink` 1952 · `.graph` 1968 · `chat.message.attach` 1609 | READY |
| 31 (video) | Call business record | `videocall_phase31_call_record.sql` | `call.record` 1981 · `.board` 1990 · `.event` 2003 · `.transport` 2022 · `.file.share` 2041 · `.work.link` 2056 | READY |
| 31A (video) | Light-speed call path | `videocall_phase31a_lightspeed.sql` | `call.ring.start` 2079 · `.settle` 2099 · `.state` 2114 · `call.connect.*` 2123–2151 · `call.sfu.*` 2162–2206 · `call.survival` 2215 | READY |

## Frontend ↔ Rust name audit

105 unique rpc names frontend (`src/lib/chat*.ts`, `app.chat.tsx`) se nikaale; sab Rust dispatch mein hain siwaye 4 Bun-only (Phase 11 ticket/list/avatar — intentionally, fallback path `src/lib/chat-transport.ts:29`). **Koi orphan call nahi.**

## Note

- Blueprint prose mein "Phase 31A" heading nahi — sirf SQL file `videocall_phase31a_lightspeed.sql`. Founder chahe to blueprint mein heading add karein.
- Yeh static read hai. Har row READY → DONE sirf `docs/wire/26-live-login-chat-call.md` ke browser + SQL proof se.
