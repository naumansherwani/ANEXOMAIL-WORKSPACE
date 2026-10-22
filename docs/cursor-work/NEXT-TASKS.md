# NEXT TASKS — agla kaam, tarteeb ke saath (founder 22 Oct 2026 10:12 PKT, LOCKED)

> **22 Oct 2026 20:32 (founder, Rule 44):** SQL ab SERVER par `sql-run.sh` se chalti hai (editor nahi), aur woh PEHLE chalti hai. Command: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh)` (bina naam = sab nayi) ya naam aakhir mein bina .sql ke.
Compact / naya chat: pehle AGENTS.md (Rule 37/38/40/41/42), `DONE-DO-NOT-REPEAT.md`, phir YEH file. Jo GREEN hai dobara nahi banana. Har commit ke saath server commands (Rule 41); SQL server + Supabase editor dono (Rule 42, pehli line khali, lint).

## >>> RESUME HERE — compact ke baad SIRF YAHAN SE (22 Oct 2026 22:45 PKT, founder: "hamaray kaam ki tarteeb kharab ho gayi") <<<
**Qaida (founder):** koi NAYA phase/kaam founder se poochhe bina shuru nahi (identity vault maine bina poochhe shuru kiya tha — dobara nahi). Tarteeb neeche wali table hi hai. Har push: Rule 41 + **Rule 46** (1 SQL -> 2 Rust install -> 3 Rust restart+health -> 4 Brain installer agar Bun badla -> 5 Web pull; sirf badli hui technology ke steps, har ek alag poori command). Server par kuch bhi agent nahi chalata.

**Is session mein GREEN ho chuka (dobara mat banao):** #10 History search (live verified) · E65 RLS sweep · Rule 43/44/45/46 · identity vault SQL E66/E67/E68/E69 (server par SQL chal chuki, CHECK OK) · Bun mirror/outbox/guard + Web device-key/SignupReview/IdentityVaultPanel (code pushed) · Rust vault_core.rs (pure, parity) · refresh par double loading (founder: GREEN) · sign-in loading click par (deployed, recorder ne tasdeeq ki).

**Founder ke server par BAAQI (yeh agent nahi kar sakta):**
1. Brain installer: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/brain-identity-install.sh)` — yeh DEVICE_VAULT_KEY bhi banata hai (print nahi). Founder ne abhi tak chalaya nahi (22:41 par naam hi type kiya tha).
2. ~~Web pull 2b92ea4~~ DONE + GREEN (22:50 recorder se tasdeeq). (purani line:) phir founder sign-out/sign-in karega aur main Chrome tab (1609160381, MCP group) mein recorder (window.__navlog: history patch + MutationObserver + fetch status) lagake LIVE dekhunga ke `SIGNIN @/app` flash ab nahi. Agent production par password type NAHI karta (founder khud sign-in karta hai).
3. Privacy/footer naya paragraph — founder "haan" par (AUTH-MIGRATION-PLAN.md mein draft).

**E72 APPEAL 20,000 + EVIDENCE: CODE READY (23 Oct 03:00). Rule 46 order: 1 SQL (sql-run.sh auto: E72+CHECK_E72) -> 2 Rust installer (rust-engine-install.sh, module evidence) -> 3 `pm2 restart anexomail-rust --update-env && pm2 save && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health` -> 4 Brain installer (brain-identity-install.sh) -> 5 attach-gc/install.sh (evidence safai) -> 6 Web pull + Ctrl+Shift+R. Phir live test: blocked/test account se appeal + 1 PNG attach, reviewer panel mein download.**

**E70+E71 IDENTITY HARDENING: CODE READY + local-verified (23 Oct 01:30; E70 ab 5 fingerprint groups hw/gpu/font/gfx/env + 'hidden fingerprint' rule fp_evasion allow/review/hold with founder panel switch; machine groups survive browser switch). Server par baaqi (Rule 46, alag alag): (1) SQL sql-run.sh (auto E70+E71+CHECKs+E65 sweep) (2) Rust installer rust-engine-install.sh (E71: probation guard export_glue/cal_glue) + (3) Rust restart+health ALAG command (Rule 46, founder 23 Oct: install ke baad HAMESHA: pm2 restart anexomail-rust --update-env && pm2 save && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health) (4) Brain installer (5) Web pull + Ctrl+Shift+R (E70 ke liye). E71 = probation limits (Brain mail send/schedule/outbox + bulk import; Rust invites/booking page/people.import/calendar guests), DB session backstop (hold account ka session banta hi nahi), approve par khud email (recovery email, 60s worker). Phir founder live test: panel mein gate 'Approve everyone' -> test signup -> 'waiting for a quick review' -> approve -> sign-in -> gate wapis 'Hold matches'. Uske baad AGLA KAAM: #4c ICS subscribe.**
**FOUNDER HUKM 22 Oct 23:01 — IDENTITY HARDENING (ban wapis nahi aana chahiye, "fingerprint lo"): H1 = asli browser fingerprint (canvas/WebGL/audio/fonts/hw/screen/tz/lang -> client par HMAC-ready stable hash, server par HMAC kind 'fingerprint'; raw kabhi store nahi). Policy: fingerprint match = HOLD (pending, founder decide), fingerprint + koi aur signal = DENY; fingerprint akela kabhi seedha ban nahi (collision/false-positive). H2 = probation (naya account limited), H3 = disposable-email block, H4 = approval-gate switch (panel se on/off, har signup pending). Privacy/footer line sirf founder 'haan' par. Rule 46 order. Founder se pooochna: H1-H4 #4c se PEHLE ya baad.**
**#2 W2 Focus Ring: CODE READY (22 Oct) — server par Rust install -> Rust restart+health -> Web pull baqi; phir Chrome live check (Find a time list mein ring). AGLA KAAM: #4c ICS subscribe.** Uske baad #4c ICS subscribe -> #5 event files -> W3/W4/W5 -> #6 CalDAV -> #7 Google -> #8 Rooms -> M-series -> G16. AUTH Phase A (sign-in Rust par + vault_glue.rs + local mirror) W2 ke BAAD, tab bhi pehle founder se poochho.
Dates: E55 grants-heal 30 Oct se pehle; Caddy cert 12 Nov se pehle. Phone 390/820 checks baaki.

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
| 10 | **G16 billing portal P2+** (naya kaam) | docs/claude/BILLING-PORTAL-BLUEPRINT.md, 4 founder faislay baaki (tab poochho). **LAZMI: BLUEPRINT ke aakhir mein 'GRACE PERIOD + WORKSPACE PAUSE' spec (3 grace din purple/yellow/red -> pause -> Resume/Upgrade/Downgrade; Basic ko Downgrade nahi) — isi mein banana** | |

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
- 22 Oct 20:55: #10 CODE READY: E64 SQL + Rust cal `calendar.history` + Web (/app/search 'Meetings & history', calendar deep link ?date=&event=). Baaki: server install (3 commands) + Chrome live check -> GREEN, phir #2 W2 Focus Ring.
- 22 Oct 21:10: #10 REWORK (founder law 20:02, 100 saal): E64 ab keyset cursor (p_after_ts/p_after_id) + p_facets by_year + hybrid raasta (2000+ matches => seedha date-index filter; aam lafz par relevance => recent). Proof 42/42, CHECK 11/11, bench 120k meetings 1926 se: rare 35 ms, aam 60-70 ms, gehra page 61 ms, by_year 470 ms. Rust: after_ts/after_id/facets + cal_core::history_cursor (42 tests). Web: cursor 'Show more', Years chips, import-wali line hata di. UI ab koi hadd nahi batata.
- 22 Oct 20:30: E65 RLS+advisor sweep READY (Rule 43). Sandbox: 2 baar chala, CHECK 6/6, proof OK. Server: sql-run E65_rls_and_advisor_sweep CHECK_E65. #10 server install ke saath chalana.
- 22 Oct 21:05: #10 GREEN (live Chrome verified). AGLA: #2 W2 Focus Ring. E65 (RLS sweep) server par chalana baqi.
- 22 Oct 21:15: server SQL+Rust+Web sab green, Chrome smoke OK. AGLA: #2 W2 Focus Ring.
- 22 Oct 21:55: FOUNDER HUKM (Rule 45): sign-in Rust par migrate (Phase A–D), Bun hamesha fallback, vault qaide. Plan `docs/cursor-work/AUTH-MIGRATION-PLAN.md`. Order: pehle #2 W2 Focus Ring, phir AUTH Phase A (founder ka 'haan' D se pehle). Privacy audit ke gaps plan mein.
- 22 Oct 21:25: E66+E67 (identity/passkey vault) SQL READY. Server: bare sql-run.sh. Agla: #2 W2 Focus Ring, phir Auth Phase A (Rust vault_core + device-key).
- 22 Oct 21:45: identity vault ADMIN complete (E68 + Bun + Web + Rust procs). Server: SQL(bare) -> Rust(MODULES=all/main) -> Web. Phir wapas #2 W2 Focus Ring.
- 22 Oct 22:20 CONTEXT (compact ke baad yahan se): identity vault phase POORA (E66/E67/E68/E69 + Bun + Web + Rust procs + vault_core.rs). Founder ne sab "tarteeb se, 100% green" kaha. Baqi sirf: (1) server par SQL(bare)->Rust->Web run + Chrome verify (founder), (2) pepper: DEVICE_VAULT_KEY env set karna behtar (warna service-key-tail fallback; service key rotate ho to hashes badal jayenge) — founder ko batana, (3) privacy/footer paragraph founder "haan" par (AUTH-MIGRATION-PLAN.md), (4) Auth Phase A mein vault_glue.rs (feed poll + outbox + LISTEN) + sign-in Rust par + passkey encrypt. PHIR #2 W2 Focus Ring (agla kaam) -> #4c -> #5 -> W3-W5 -> #6 -> #7 -> #8 -> M-series -> G16.
- 22 Oct 22:40: Founder ko dena: Brain installer (brain-identity-install.sh) — E69 SQL + web pull + Rust install ho chuke (sab green). Uske baad Chrome verify (panel Identity vault hissa) aur W2 Focus Ring.
- 22 Oct 22:50: sign-in fix #2 pushed — founder Web pull + Ctrl+Shift+R + sign-in test; bounce phir aaye to recorder trace (founder khud sign-in karega, main Chrome tab mein recorder laga ke padhunga). Brain installer (identity) founder ne abhi nahi chalaya.
