# WORKING NOW (auto snapshot before a compaction, 20 Nov 2026 20:59 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: QSPEED, MEASURED (his pastes 20:58 PKT). FACTS: (a) journal: every database rpc is SLOW 306-546 ms (founder_live_tick every 5 s, outbox_claim, followup sweep/next196, dtls_due189, push_claim...). (b) db-latency-check: ping to the database edge 1-6 ms, tcp 4-11 ms, tls 20-35 ms, FIRST BYTE 318-375 ms even on ONE reused connection. So the cost is NOT network: it is the REST front + the database behind it (about 320 ms floor per call), 50 ms is impossible while every call goes through REST. (c) login finish = about 8 sequential calls = 2.5 s+, and any failure shows 'sign-in service not answering' (busy). DECISION PATH: A) cut the number of calls (login finish as ONE SQL door, parallel reads, writes after the answer, Rust cache) = about 0.35 s per login, code only; B) direct Postgres connection from Rust (tokio-postgres pooled): needs his read-only paste of db-direct-probe.sh to know the real distance; C) the 50 ms goal needs the database next to the server (Hetzner Postgres, allowed vendor): his word only. Do NOT name the CDN in front of the database to him.
NEXT STEP: 1) commit db-direct-probe.sh (read-only) and give him ONE line; 2) write login finish as ONE SQL door (new E197, read E167/E153/passkey schema first, schema-first law) + Rust finish_inner uses it; 3) audit/ledger writes after the answer; 4) network-only retry; 5) rec.sh; his two lines: sql-run then founder-install; 6) my live Chrome login timing before/after
HIS LAST WORD: SQL advance 400+ likho QC7
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
- 4501d30d 20 Nov 20:59 QSPEED measured: 320 ms per REST call; db-direct-probe.sh added
- b5f54935 20 Nov 20:56 ledger line 56c1a29a
- 56c1a29a 20 Nov 20:56 QSPEED: login busy cause recorded, waiting for his paste
- befd2f2e 20 Nov 20:52 ledger line 14983446
- 14983446 20 Nov 20:52 QSPEED started: login path read, plan recorded

## Uncommitted files (half-done work if any)
 M docs/claude/state/WORKING-NOW.md

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 docs/claude/state/WORKING-NOW.md | 18 ++----------------
 1 file changed, 2 insertions(+), 16 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (659f22dc5284b4f9fdfa61b999f6494cbcfb71cb)
