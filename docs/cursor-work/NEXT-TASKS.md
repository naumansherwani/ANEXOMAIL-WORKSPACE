# NEXT TASKS — agla kaam, tarteeb ke saath (founder 22 Oct 2026 10:12 PKT, LOCKED)
Compact / naya chat: pehle AGENTS.md (Rule 37/38/40/41/42), `DONE-DO-NOT-REPEAT.md`, phir YEH file. Jo GREEN hai dobara nahi banana. Har commit ke saath server commands (Rule 41); SQL server + Supabase editor dono (Rule 42, pehli line khali, lint).

## Tarteeb (upar se neeche, ek ke baad ek)
| # | Kaam | Design / file | Server order |
|---|---|---|---|
| 1 | **#10 History search** (Cmd+K, saalon purani meetings/notes/tasks/mail, FTS + trigram, org wall) | docs/claude/CALENDAR-BLUEPRINT.md §5. SQL E64 (Rule 38+42), Rust proc, Web (Cmd+K ka "history" filter: tareekh range, banda, domain) | SQL -> Rust -> Web |
| 2 | **W2 Focus Ring** (booked-meeting load ka SVG/CSS ring, sach-ghantay fatigue lines meeting slider mein) | docs/claude/WORLD-CLOCK-BLUEPRINT.md (founder decisions 08:40: Focus Ring, no Three.js) | Web (+Rust agar load endpoint chahiye) |
| 3 | **#4c ICS subscribe** (external calendar read-only) | CALENDAR-ROADMAP #4c | SQL -> Rust -> Web |
| 4 | **#5 Event par files** (mail attach pipeline reuse) | CALENDAR-ROADMAP #5 | SQL -> Rust -> Web |
| 5 | **W3 globe** (benchmark-gated WASM) · **W4** latency/time-sync/travelling (opt-in, user-entered) · **W5** billing deadline banner, market chip (default OFF), Lahore alias | WORLD-CLOCK-BLUEPRINT W3–W5 | as needed |
| 6 | **#6 CalDAV (B7d)** | CALENDAR-ROADMAP #6 (app password 27 Oct se passkey, Caddy .well-known surgical) | |
| 7 | **#7 Google sync** | founder ko pehle Google Cloud verification shuru karni hai | |
| 8 | **#8 Rooms / resources** | CALENDAR-ROADMAP #8 | |
| 9 | **M-series M1–M7** (Outlook-style mail features) | 3 founder faislay baaki (tab poochho) | |
| 10 | **G16 billing portal P2+** (naya kaam) | docs/claude/BILLING-PORTAL-BLUEPRINT.md, 4 founder faislay baaki (tab poochho) | |

## Pehle se GREEN (dobara mat banao)
Calendar #0–#4b, #9; World clock W0/W1; landing/plans calendar copy; E58–E63. Detail: DONE-DO-NOT-REPEAT.md.

## Founder ke faislay jo yaad rakhne hain
- Calendar abhi sab package ko UNLIMITED (limits baad mein Claude ke mashware se) — CALENDAR-BLUEPRINT §1b. Family/lifetime/Business Pro = unlimited (Rule 40).
- Honest only: koi invented number/score nahi; "Basic ko itna do ke deewana ho jaye".
- Bun fallback na hatao; Sign-in A locked (Rule 39); prices/cards LOCKED.
- Dates: E55 grants-heal 30 Oct se pehle; Caddy cert renewal 12 Nov se pehle; mail reminders ko server timer; test page `pro-buyer` ON.

## >>> ABHI CHAL RAHA HAI (compact ke baad yahin se shuru) <<<
**22 Oct 2026, 19:40 PKT — #10 History search SHURU kar diya.** Plan: SQL E64 (meetings/notes FTS + trigram, org wall) -> Rust proc `calendar.history` -> Web `/app/search` "Meetings & history" (tareekh range, banda). Pehle se mojood: `/app/search` + `useUniversalSearch` (people/companies/threads/attachments). Status neeche log mein update hota rahega.

- 22 Oct 20:30: #10 SQL E64_history_search + CHECK_E64 + proofs/E64_proof (32/32) bana, lint OK, 2 baar chala, 'pehla char gum' sim OK. Perf (60k meetings, sandbox): rare word 9-21 ms; sab-matching shabd ('meeting') 1.4 s (statement_timeout 8s ke andar; baad mein hybrid optimisation). Agla: Rust `calendar.history` (cal_glue) -> Web /app/search 'Meetings & history'.
