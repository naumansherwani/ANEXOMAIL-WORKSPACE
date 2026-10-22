# WORLD CLOCK — "Global Time-Chain" blueprint + CEO verdict. Founder hukm 22 Oct 2026 08:05 PKT (attachment 93134f3c)
> Founder: "futuristic World Clock ko subdomain jitne bhi hain aur core workspace dashboard features ke saath connect karna hai."
> Rules: privacy (metadata-only, location/flight tracking kabhi nahi) · "inbound mail HAMESHA accept" · Polar/billing NO TOUCH · universal UI Rule 37 + family Rule 40 (sab ko ek jaisa) · jo number hum naap nahi sakte woh likhte nahi · Bun fallback rehta hai.

## Verdict (sach pehle)
| # | Founder idea | Faisla | Asal design |
|---|---|---|---|
| 1 | 3D globe (Three.js + OffscreenCanvas), hover par rotate, day/night, weather | **HAAN, progressive** | Lazy-load Three.js; day/night terminator local math (sun position, koi API nahi); static SVG/2D fallback + `prefers-reduced-motion`; phone par halka. **Weather = baad mein** (bahar ki API chahiye, optional). WASM nahi (bundle bhari, faida nahi). INP<150 ms naap kar. |
| 2 | Overlap Matrix Optimizer (green/amber/red slider) | **HAAN — yehi asli feature (= calendar #4b)** | Ek timeline slider; har guest ke zone mein: 🟢 working hours (E58) 🟡 out-of-office ya kam-taadad kinara (ghante working window ke 1h andar) 🔴 raat (22:00–06:00 local ya working se door). Free/busy sirf (andar ka content nahi). Server par Rust `team.overlap` (calendar_busy + working hours), browser sirf draw. |
| 2b | "Human Fatigue Cost: sprint quality -30%" | **NAHI woh number** | Jhoota/anaap-sakne wala percent hum nahi likhenge. **Badal:** sach-ghantay: "Japan ke liye yeh 3h working se bahar, unka din 12h ho jaye ga" (working hours + us din ki meetings se compute). Saaf, ginti-wala, challenge ho sakta hai. |
| 3 | Flight-Time Slipstream (flight data/altitude, inbound hold) | **NAHI (privacy + mail wada)** | Kisi ki flight/coordinates track karna = surveillance; aur inbound mail rokna hamare wade ke khilaf. **Badal:** user khud "Travelling to <zone> from <date>" status set kare (opt-in); calendar us zone mein dikhaye; sirf *notifications* ka quiet-time shift (mail kabhi nahi rukti). |
| 4 | Speculative Latency Clock: NTP/atomic microsecond via SSE, har member ki QUIC latency "p95<42ms" | **ADHA** | Browser mein microsecond maane nahi rakhta (network jitter ms mein). **Karenge:** "device clock drift" badge (server time endpoint + round-trip se offset, ±ms) — meeting se pehle kaam ka. **Nahi karenge:** doosre member ki "latency" ya "route p95" — hamare paas aisa naap nahi, likhna jhoot hoga. SSE push pehle se hai (R5/B4); clock usi par. |
| 5 | Financial market + "bank clearing 4m12s" banner billing par | **NAHI** | Billing Polar (merchant of record) ka hai; "rollback" jaise daawe hum nahi kar sakte. **Optional baad:** pinned shehar ke saath "market open/closed" chip (sirf shaaye-shuda exchange hours), billing se door. |
| 6 | Zero-bundle l10n + Speculation Rules | **HAAN** | `locale.bundle` (28 zubanen) pehle se; shehar naam `Intl.DisplayNames`; hover par prefetch; LCP<1.8 s naap kar. |

## "Subdomain jitne bhi hain" — kahan kahan jodna
| Jagah | Kya |
|---|---|
| anexomail.com /app/calendar toolbar | **W0 BANA (code)**: Globe pins, 6 shehar, account mein save |
| New meeting / Find a time / Booking host sheet | W2: slider + har guest ke zone ka green/amber/red |
| Dashboard (workspace) | W1: chhota "Aaj team ka waqt" card (pins + kaun jaag raha hai) |
| People / CRM contact | W1: contact ka local waqt + working-hours chip (zone aaye to) |
| /book/<handle> (public) | visitor ka zone pehle se; host ka local waqt ek line |
| billingportal.anexomail.com | sirf waqt/zone formatting (invoice dates) — koi market banner nahi |
| Chat / calls (AnexoChat) | call se pehle "unka waqt abhi X" chip |
Sab jagah ek hi component/lib (`WorldClocks`, zone helpers), duplicate nahi.

## PHASES (har phase: sandbox proof + 390/820/1440 + founder server output -> GREEN)
- **W0** world-clock pins (calendar #4a) — CODE READY 22 Oct 08:20 (Rust locale clocks + web WorldClocks); server install + live check baaki.
- **W1 (CODE READY 22 Oct 08:55, server install pending)** `calendar.overlap` Rust (free/busy + working hours + OOO, sirf metadata) + overlap matrix UI + dashboard "team ka waqt" card (= calendar #4b).
- **W2** meeting slider in NewMeeting/Find-a-time + sach-ghantay fatigue line.
- **W3** 3D globe (lazy, fallback, reduced-motion, day/night math) — dashboard + clock popover.
- **W4** device-drift badge (server time endpoint) + opt-in "travelling" status.
- **W5** l10n shehar-naam + Speculation Rules + perf pass (LCP 1.8 s, INP 150 ms naapa hua).
FOUNDER FAISLA 22 Oct 08:15: 'sab banega, jo website ke liye better ho woh opt karo'. Mera chunav: (a) fatigue = sach-ghantay HAAN; (b) travelling status opt-in HAAN; (c) market chip HAAN lekin default OFF, sirf pinned shehar ke saath, sirf shaaye-shuda exchange hours, billing se door. Pehle wale sawal:
(a) fatigue ko sach-ghanton wali shakal (haan?) (b) travelling status opt-in (haan?) (c) market chip chahiye ya nahi.

## FOUNDER HUKM 22 Oct 08:20: "yeh banye ga kisi bhi keemat pe, lekin awam ko sach ke saath" — BUILD PLAN (har cheez ka sach-wala version)
Asool: screen par jo number/lafz aaye woh asli naap ya user ka diya hua data ho. Jo naap nahi sakte woh label ke saath "andaza" nahi, bilkul nahi dikhate.
| # | Banega (sach ke saath) | Data kahan se (asli) | Phase |
|---|---|---|---|
| F1 | **Fatigue**: "Is waqt par meeting rakhi to Japan ka din 14 ghante lamba ho jaye ga (working 09–17 se 5 ghante bahar)" | working hours (E58) + us din ki meetings (calendar) — ginti, koi % nahi | W2 |
| F2 | **Travelling / In Transit**: user khud route+departure+arrival waqt daale (ya event se) -> timeline par "In transit" badge, landing par apna naya zone | user ka diya hua data; hum flight/coordinates track NAHI karte | W4 |
| F2b | **Alerts hold**: transit ke dauran sirf push/notification chup (quiet), mail HAMESHA inbox mein aati hai | notification layer (B4) | W4 |
| F3 | **Latency clock**: har member ka "server tak" RTT, **us ke apne browser se naapa hua**, rolling p50/p95, sirf online + consent (opt-in); protocol asli (`nextHopProtocol` = h3/h2) | `/rpc/time.ping` (Rust) + browser Performance API; QUIC tab dikhe jab Caddy h3 de | W4 |
| F3b | **Time sync badge**: device clock server se kitna aage/peeche (±ms), NTP nahi (browser mein ms se zyada maane nahi rakhta) | Rust `time.now` + round-trip offset | W4 |
| F4 | **Billing deadline banner**: "Aap ka plan 23 Oct 14:00 (Karachi) ko renew/khatam" — asli Polar/subscription tareekh, user ke zone mein countdown | hamari subscription table (Polar webhook se bhari); koi bank-clearing / rollback daawa nahi | W5 (Polar ko haath nahi lagate, sirf padhna) |
| F4b | **Market open/closed chip** (opt-in, default OFF) | shaaye-shuda exchange hours (weekday); holiday data nahi to "holiday check nahi" likhte | W5 |
| F5 | **WASM** | Pehle naap: solar/terminator hisaab JS mein ~microseconds hai; WASM sirf tab jab benchmark JS ko haraye. Plan: globe worker mein JS pehle (OffscreenCanvas), WASM lazy `import()` sirf globe khulne par, size budget <= 30 KB gz, aur BENCH proof ke baghair nahi shaamil. | W3 (benchmark gate) |
Sab packages/family ko ek jaisa (Rule 37/40); sirf bhari server-side cheez (agar kabhi) plan-surface capability se.

## FOUNDER FAISLE 22 Oct 08:40 (Ultimate Combination Matrix) — meri kaarwai
1. **Fatigue -> "Focus Ring Overlay"** (working-hours ginti ki jagah) — MANZOOR. Ring avatar ke gird (SVG/CSS conic-gradient, Three.js nahi: INP/bundle). Rang = us din ki *booked meetings ka bojh* (calendar metadata, sirf jinka free/busy hum dekh sakte hain), Fresh blue -> Amber. Koi activity/keystroke telemetry nahi. Note: Overlap Matrix (W1) ke green/amber/red ko user ki **khud likhi hui** working hours (E58 setting) chahiye — woh tracking nahi, user ka apna setting hai; woh rehti hai.
2. **Travelling "Slipstream" opt-in** — MANZOOR, lekin **user-entered** (route + departure/arrival). "Device network change se location shift pakadna" NAHI (location inference = surveillance, hamari Privacy policy ke khilaf). Alerts quiet hote hain, mail kabhi nahi rukti.
3. **Market Pulse chip** ("NYSE: Open" / "LSE: Closed") — MANZOOR (opt-in, default OFF). Ek deterministic Rust function (exchange ka IANA zone + hours + weekday); "NTP ticker" ki zaroorat nahi, server time endpoint kaafi. "p95 < 60 ms" ka daawa nahi likhte jab tak naapa na ho. Holiday data na ho to chip "holiday check nahi" likhe.
Shehar naam: Zurich/Lahore. Lahore IANA zone nahi (Asia/Karachi ka waqt); label-alias baad mein (W5 l10n).
