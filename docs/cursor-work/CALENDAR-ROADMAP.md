# CALENDAR ROADMAP (G26/G27) — EK jagah, sach tarteeb. Founder spec 22 Oct 2026. Update: 22 Oct 07:20 PKT
Rule: "GREEN" = founder ka server output + live check. Is file ko har calendar step ke baad update karo (founder-commands/ledger se yahan ka hawala).

| # | Kaam | Haal |
|---|---|---|
| 0 | Layout v2 (Classic+Expanded, shehar-naam clock, 12h/24h/Auto, account sync E57) | GREEN |
| 1 | Working hours, out-of-office, alag calendars + rang, reminders (E58 SQL+Rust+web) | GREEN. Baaki polish: mail reminders ko server timer chahiye |
| 2 | Booking page B7c (E59 lock, rate limit, mails + .ics, cancel/reschedule) | GREEN (live verify 22 Oct) |
| 3 | iMIP reply G26 (E60 SQL, imip_core.rs, deliver hook, rsvp_via label) | **GREEN 22 Oct 07:47** — founder output imip-reply-proof.sh: A auth nahi=reject, B jhoota From=reject, C sahi=applied (accepted via=calendar_app), D duplicate=ignore. Guest-list bug (created_at) fixed+live. Gmail ka RSVP-bar Gmail ka masla (shart nahi) |
| 4 | **4a+4b GREEN (founder 22 Oct 09:32: dashboard card ke liye members banana practical nahi — GREEN)**. Timezone world-clock pins (kai zones), team overlay (sirf free/busy), ICS subscribe (external) | 4a world-clock pins: CODE READY 22 Oct 08:20 (Rust locale_core::clocks_ok 7 tests + locale_glue `clocks` key, web WorldClocks.tsx in Classic+Expanded toolbars, account-synced, sab packages). Server install + live check BAAKI. 4b team overlay, 4c ICS subscribe: shuru nahi |
| 5 | Event par files (mail attach pipeline reuse, naya storage nahi) | Shuru nahi |
| 6 | CalDAV (B7d) — PROPFIND/REPORT, ctag/etag, tz, recurring exceptions, app password (27 Oct se passkey), Caddy .well-known surgical | Shuru nahi |
| 7 | Google Calendar sync (OAuth, watch+sync token, loop-guard) | Shuru nahi. FOUNDER: Google Cloud verification application abhi shuru kare |
| 9 | Outcome colours (event par red→yellow→green, user ka khud ka Achieved tap; line hamesha red) | **GREEN 22 Oct 10:15 (Chrome live: Aim save, Achieved + hara dot, reload ke baad bacha, Reopen, Aim removed — guests ko mail nahi gayi)**. Pehle CODE READY 10:30: SQL E63_event_goal (+CHECK_E63, proofs/E63_proof.sql 14/14 sandbox) · Rust cal_core clean_goal/goal_state_ok/goal_tone (41 tests) + cal_glue meta.set `goal`,`goal_state` · Web lib/goal.ts (+test), EventDetail OutcomeEditor, dot on TimeGrid + month list. Server install + live check baaki. Design: CALENDAR-BLUEPRINT §4 |
| 10 | History search (Cmd+K, saalon purani, FTS+trigram, org wall) | **CODE READY 22 Oct 20:55**: SQL E64 (+CHECK_E64, proofs 32/32; 60k meetings mein rare shabd 9-21 ms, sab-matching shabd 1.4 s) · Rust cal `calendar.history` (42 core tests) · Web lib/history.ts + HistoryResults (/app/search) + calendar deep link ?date=&event=. Server install + live check baaki |
| 8 | Rooms / resources (pseudo-attendee, wohi conflict engine) | Shuru nahi |

## Spec ke faislay (founder ko jawab, line by line)
- Google sync/CalDAV: practical. Webhook sirf "kuch badla" bolta hai, data sync token se; watch channel renew; do-taraf loop guard; "instant" = kuch seconds. Google verification asli rukawat (bina uske warning + 100 users). Android mein CalDAV built-in nahi (DAVx5). "Zero-copy", "Tokio main thread" = dawa nahi.
- Booking: practical. DB lock, rate limit, mail+.ics+link. WASM nahi (LCP kharab); LCP target 1.8 s naap kar.
- iMIP: sender == attendee + SPF/DKIM zaroori. Collision warning RSVP ke waqt (BAAKI). "Ledger prompt" = seedha conflict chip.
- Event elements: files practical (attach pipeline); alag calendars+rang practical; team overlay sirf free/busy; external = ICS subscribe (bina ijazat nahi); "hardware-accelerated" = smooth CSS, INP 150 ms naap kar; world-clock pins chhota kaam; rooms akhir mein.

## World Clock blueprint (founder 22 Oct 08:05)
Detail + CEO verdict + phases W0–W5: docs/claude/WORLD-CLOCK-BLUEPRINT.md. #4a=W0 (code ready), #4b team overlay = W1.

- 22 Oct 08:40: #4a world-clock pins GREEN (desktop 1440 live: Zurich pin, reload par bacha). E61 SQL chala. 390/820 screenshot browser se nahi le saka (window resize viewport nahi badalti) — touch-up baqi. Aglu: W1 = #4b team overlay.

- 22 Oct 08:55 **#4b team overlay (= World Clock W1) CODE READY, server install + live check pending.** SQL E62_team_overlap (+CHECK_E62, proofs/E62_proof.sql 15/15 sandbox) · Rust `overlap` module (overlap_core 15 tests + overlap_glue 5 tests, proc `calendar.overlap`) · Web: `src/lib/overlap.ts`, `OverlapMatrix.tsx` (inside New meeting > Find a time), dashboard card `TeamTime.tsx`. Server order: SQL -> Rust (`MODULES="overlap"`) -> Web. Sandbox visual (mock engine) 390/820/1440 OK, no horizontal page scroll.
- 22 Oct 09:30: #4b W1: SQL E62 live OK, matrix live dekhi (guest+member+unknown zone). Fix: best times >=3h door, unknown-zone wording. Rust+Web install pending, phir GREEN (dashboard card + 390/820 live baqi).

- 22 Oct 09:40: Web pull OK (server==repo 513). Landing/plans calendar copy + access model (features sab ko, limits capability, family/Business Pro unlimited) likha: docs/claude/CALENDAR-BLUEPRINT.md. Founder 'haan' par copy plans.ts/index.tsx mein lagegi. Aglu: W1 live check (matrix 3h+dashboard card+390/820) -> #4b GREEN.

## TARTEEB (founder 22 Oct 09:26 PKT, LOCKED): pehle Calendar + World Clock POORA -> phir M-series (Outlook-style mail) -> phir G16 billing portal (naya kaam). Limits ke numbers, Google verification, M/G16 ke faislay isi tarteeb se baad mein. Calendar+WorldClock ka andar ki tarteeb: W1 live GREEN -> landing copy (founder "haan" par) -> #9 outcome colours -> #10 history search -> W2 Focus Ring -> #4c ICS -> #5 files -> W3/W4/W5 -> #6 CalDAV -> #7 Google -> #8 rooms.
- 22 Oct 09:45: W1 live (desktop, Chrome): 3 best-time chips 3h door OK, unknown-zone wording OK. Bug: "time zone not known" do baar (assessLine) -> fixed in overlap.ts, Web pull baaki. Dashboard card (>=2 members) + 390/820 phone abhi baaki -> phir #4b GREEN.
- 22 Oct 09:50: #4b GREEN (founder faisla). Web pull OK (fix live). Landing+plans calendar copy LAGI (index.tsx Calendar card, plans.ts 'Contacts & full calendar — invites with replies, booking page, world clocks'); qeematein/cards untouched, koi 'unlimited' number nahi. Phone 390/820 touch-up pending (founder ka phone). SHAAM ka kaam: #9 outcome colours (E63 SQL).
- 22 Oct 09:55: Chrome /plans dekha (Pro card 'Everything in Basic' => calendar line Basic se inherit; purani copy live kyunke web pull baaki). personal-tiers.ts calendar line bhi same copy (Rule 37). Web pull shaam ko.
- 22 Oct 10:30: #9 CODE READY (column naam `goal`/`goal_state`/`goal_state_at` — purana `outcome` jsonb alag hai, chhua nahi). Sach ke qaide: sirf organiser tap; repeating series par nahi (ek row = kai din); Achieved/Missed meeting shuru hone ke baad; koi score nahi. Server order SQL -> Rust(MODULES="cal") -> Web.
- 22 Oct 10:50: founder: Aim ko lamba karo ("50,000 ya jo better ho, decent+professional"). Faisla: Aim = headline + detail, 2000 harf, multi-line (SQL/Rust/Web teeno 2000). 50,000 nahi: mahine ki list har meeting ke saath goal bhejti hai (500 x 50k = 25 MB), aur itna lamba matn Agenda/Notes ka kaam hai. Ek constant (GOAL_MAX_CHARS + SQL function) badal kar baad mein barha sakte hain. E63 abhi server par nahi chala tha, isliye usi file mein badla.
- 22 Oct 10:15: GREEN — #9 outcome colours (live Chrome), landing/plans calendar copy (Basic card 'Contacts & full calendar...' live), E63 SQL+Rust cal+Web server par chale. Pichli lines: #0-#3 GREEN, #4a/#4b GREEN. Ab calendar mein baaki: #10 history search -> W2 Focus Ring -> #4c ICS -> #5 files -> W3/W4/W5 -> #6 CalDAV -> #7 Google -> #8 rooms.
- 22 Oct 10:12: tarteeb ek jagah likhi: docs/cursor-work/NEXT-TASKS.md (founder-locked).
- 22 Oct 20:55: #10 CODE READY (SQL+Rust+Web). Server order SQL -> Rust(MODULES="cal") -> Web. (22 Oct 21:xx founder law: 100 saal ki history ke liye design — keyset cursor + by_year + hybrid; UI mein koi hadd-wali line nahi.)
