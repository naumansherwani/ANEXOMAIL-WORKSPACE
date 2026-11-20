# WORKING NOW (manual checkpoint, 20 Nov 2026 19:38 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: DK-b (DK3+DK4) WRITTEN + tested + pushed; waits his install; then DK5: his key PRF touch, real pq mail to himself, my Chrome 390/820/1280
NEXT STEP: give him the install line; after paste my live check of kernel 0.20.0 + MailDeviceKey panel; then DK5
HIS LAST WORD: gandu context bhul gaye? -> answered: DK-b
RULE: finish THIS step first (uncommitted files below are the half-done code), then commit with rec.sh. ONE phase, ONE command at a time.

## LIVE PORTS OF HIS SERVER (docs/claude/state/PORTS-LIVE.md, his fresh ss paste; update it whenever he pastes a new one)
Source = HIS fresh paste: `ss -tulnp | head -40` and `ss -tlnp | grep anexomail-rust`, **20 Nov 2026 03:30 PKT** (real clock). Printed by ckpt.sh (into WORKING-NOW.md) and by rules-read.py, so a fresh Claude after compaction sees it first.
UPDATE RULE: every time he pastes a new `ss`, replace the table below + the date in the same step (rec.sh), and append one line to docs/claude/SERVER-PORTS-RED-LINE-08NOV.md. Never guess a port: no fresh paste = ask for a read-only command.
|---|---|---|
| TCP | 0.0.0.0:3200 | HTTP/RPC `/rpc/*` (behind Caddy) |
| TCP | 127.0.0.1:3500 / 3600 / 3601 | internal (local only) |
| UDP | *:3443 | WebTransport |
| UDP | 0.0.0.0:3501 | awam Rust UDP (internal channel) |

## FOUNDER + other processes in the same list (never touch)
| Proto | Port | Process |
|---|---|---|

## Last 5 commits
- 66e0f507 20 Nov 19:27 ledger line a9dc80e1
- a9dc80e1 20 Nov 19:27 DK3 keygen
- 4fefe297 20 Nov 19:22 ledger line 3db4ad62
- 3db4ad62 20 Nov 19:22 DK-a live Chrome look recorded (19:35 PKT)
- 481ce7fd 20 Nov 19:22 ledger line ea896d7b

## Uncommitted files (half-done work if any)
M  CLAUDE.md
M  docs/claude/DONE-DO-NOT-REPEAT.md
M  docs/claude/RESUME-POINT.md
M  docs/claude/founder/PULL-COMMANDS.md
M  docs/claude/state/HEARTBEAT.json
MM docs/claude/state/WORKING-NOW.md
M  docs/claude/tech-contracts/CURRENT.md
M  docs/cursor-work/CLAUDE-CHAT-CONTEXT-WITH-FOUNDER-NAUMAN-SHERWANI.md
M  docs/cursor-work/DONE-DO-NOT-REPEAT.md
M  docs/cursor-work/founder/founder-commands.md
M  docs/cursor-work/server/DEPLOY-MANIFEST.txt
M  docs/cursor-work/server/PULL-COMMANDS.md
D  founder-web/dist/assets/index-BHXpBeGf.js
A  founder-web/dist/assets/index-BRkP6ODP.js
R  founder-web/dist/assets/kernel.worker-CIfmRW-j.js -> founder-web/dist/assets/kernel.worker-CaGbLt0X.js
M  founder-web/dist/index.html
R  founder-web/dist/kernel/anexo-kernel-0.19.0.wasm -> founder-web/dist/kernel/anexo-kernel-0.20.0.wasm
R  founder-web/public/kernel/anexo-kernel-0.19.0.wasm -> founder-web/public/kernel/anexo-kernel-0.20.0.wasm
M  founder-web/src/Keys.tsx
M  founder-web/src/MailBox.tsx
A  founder-web/src/MailDeviceKey.tsx
M  founder-web/src/MailView.tsx
M  founder-web/src/kernel.pin.ts
M  founder-web/src/kernel.test.ts
M  founder-web/src/kernel.ts
M  founder-web/src/kernel.worker.ts
M  founder-web/src/mail_api.ts
A  founder-web/src/mail_keys.ts
A  founder-web/src/mail_keys_pure.test.ts
A  founder-web/src/mail_keys_pure.ts
A  founder-web/src/mail_pq.ts
A  founder-web/src/mail_pq_pure.test.ts
A  founder-web/src/mail_pq_pure.ts
M  founder-web/src/system_brain.json
M  lanes/ALL-FILES.csv
M  lanes/founder.txt
M  lanes/shared.txt
M  lovable-gold/README.md
M  server/founder/src/fmail_ep.rs
M  server/founder/src/fmail_kem.rs

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 server/founder/src/fmail_ep.rs                     |  29 +++
 server/founder/src/fmail_kem.rs                    |  22 +++
 server/founder/src/main.rs                         |   2 +
 web-wasm/Cargo.lock                                |   2 +-
 web-wasm/Cargo.toml                                |   2 +-
 web-wasm/tests/kem_keygen_vector.json              |   6 +
 web-wasm/tests/kem_vector_dk3.json                 |  14 ++
 45 files changed, 733 insertions(+), 285 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (7195832d12128864ea947d4d18b8092a68b06b29)
