# CALENDAR BLUEPRINT — user ko kya, kaise, kis package par (founder 22 Oct 2026 09:21 PKT)
Compact ke baad: pehle AGENTS.md Rule 37/38/40, phir `docs/cursor-work/CALENDAR-ROADMAP.md` (status), phir yeh file (design + copy). Qeematein/cards `plans.ts` LOCKED — yahan sirf feature lines ka draft.

## 1. Access model (Rule 37 + Rule 40 — sach)
- **Features sab paid packages par EK jaise** (Rule 37: package ke hisab se alag code nahi). Calendar mein tier-literal NAHI; `TeamTime`/`OverlapMatrix`/booking/working hours sab par koi `billed ===` nahi.
- **Farq sirf miqdar (limit) ka**, aur woh bhi capability (`plan-surface.ts`) se, component sirf capability dekhe. Abhi KOI calendar limit capability bani nahi; jo hard-cap Rust mein hain woh sab ke liye barabar hain: calendars 1–20, world-clock pins ≤6, matrix ≤12 log / ≤7 din, `extra` ≤15 KB.
- **Family / lifetime (Rule 40): sab kuch UNLIMITED**, asli khareedar jaise poora account/profile, koi Upgrade nazar nahi aata. **Business Pro: unlimited** (limits ki upar wali had nahi lagti). Yaani aage jab limits capability banengi: family = unlimited, Business Pro = unlimited, baqi packages ke apne number.
- Founder faisla BAAKI (numbers): Basic/Pro/Business ke liye calendars, pins, history-search ki gehrai (saal), matrix ke log. Jab tak founder number na de, **koi limit lagayi nahi jati** (sab ko poora milta hai) aur landing page par koi number likha nahi jata.

## 1b. Founder faisla 22 Oct 09:24 PKT (LOCKED, verbatim)
"calender basic walon ko itna daina ke woh attarct ho jaye aur woh mere product ke deewwane ho jaye abhi hum unlimted pe bana rahay hain baad main tumharay mashwaray se kis package ko kitna calndar daina hai yeh decide karay gay"
- **Abhi har calendar feature UNLIMITED banta hai, sab paid packages ko** (koi limit capability/gate nahi lagani, koi number landing par nahi). Limits baad mein, Claude ke mashware se, founder tay karega.
- **Basic ko itna do ke woh deewana ho jaye**: Basic = poora calendar experience (invites+RSVP, booking, working hours/OOO, calendars, pins, matrix, history search ka bada hissa). Upgrade ki wajah "calendar kam hai" nahi, "team/governance/volume" ho.
- Mera mashwara jab limits tay hon (abhi sirf rai, lagayi nahi): Basic ke liye limit sirf un cheezon par jahan lagat asli ho (history ki gehrai, bohat bade attendee matrix), baqi feature kabhi gate nahi; Business Pro/Family unlimited. Numbers founder ke "haan" ke baad.

## 2. Calendar kya hai — sirf GREEN (landing par likhne ke qabil)
| Feature | Haal | Landing par? |
|---|---|---|
| Invites + RSVP reply seedha calendar mein (iMIP, SPF/DKIM verified sender) | GREEN | haan |
| Booking page (log khud waqt chunein, mail + .ics, cancel/reschedule, double-booking lock) | GREEN | haan |
| Working hours, out-of-office, alag rang ke calendars, reminders, 12h/24h | GREEN | haan |
| World-clock pins (kai shehar, account-synced) | GREEN (desktop) | haan |
| Team availability matrix (sab ke zones mein behtareen waqt, asli minutes) | CODE+SQL/Rust/Web live, live check baaki | **GREEN ke baad** |
| Outcome colours (#9), History search (#10) | design | nahi, bane nahi |
| ICS subscribe (#4c) | CODE READY 23 Oct (E73, Rust ics, Web) | nahi |
| CalDAV, Google sync, event files, rooms | TODO | nahi |

## 3. Landing / plans copy (draft; lagane se pehle founder "haan")
- Landing card (index.tsx, "Calendar"): "Meetings jo thread ke saath rehti hain. Invite bhejein, Accept/Decline seedha calendar mein aaye, aur booking page se log khud waqt chunein."
- Plans ki line "Contacts & calendar" ko badal kar: "Calendar: invites with replies, booking page, working hours, out-of-office, reminders" (Basic se; Rule 37 — sab par ek).
- "World-clock pins" Basic se; "Team availability matrix" tab jab #4b GREEN.
- Business Pro / Family: "Unlimited" sirf tab likhna jab limits capability ban jaye, warna jhoota claim.

## 4. #9 Outcome colours (red → yellow → green) — design
- Red now-line hamesha red (pehchan). Rang EVENT/TASK block par.
- Red = waqt guzar gaya, outcome khula. Yellow = shuru ho chuki ya deadline 24h mein, khula. Green = user ne khud "Achieved" tap kiya. "Missed" alag neutral/dark nishan.
- "Outcome" optional ek line (user likhe), meeting ke baad ek tap. Koi score/percentage nahi.
- Zaroorat: event par `outcome` (text) + `outcome_state` (open/achieved/missed) — SQL E63 (Rule 38) + Rust clean + UI. Task-linked events Tasks ki asli state se rang lein.

## 5. #10 History search (saalon purani) — design
- Ek box (Cmd+K): events, attendees, notes, tasks, mail threads. Filter: tareekh range, banda, domain.
- Postgres FTS (`tsvector` generated column + GIN) + `pg_trgm` (typo/naam); org-scoped RLS-jaisi deewar (E62 jaisa: active member, sirf apni/shared cheezein, doosre ke private notes kabhi nahi).
- Itihaas: events table baray ho to year ke hisaab se partition; EXPLAIN se 100 ms ka daawa naapna PEHLE, phir likhna.
- FOUNDER LAW (22 Oct 20:02): history 100 SAAL ke liye design hoti hai — user ko koi "hadd" nahi dikhai jati. SQL: keyset cursor (starts_at,id) => gehra page bhi tez; by_year naksha; aam lafz par hybrid raasta; 1900/2126 ki tareekh bhi chalti hai. UI mein "import ke baad" jaisi line nahi.
- Kyun khichega: "us client ne kya kaha tha" ek search mein; switching cost asli value se.
