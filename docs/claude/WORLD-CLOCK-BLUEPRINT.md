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
- **W1** `team.overlap` Rust (free/busy + working hours + OOO, sirf metadata) + overlap matrix UI + dashboard "team ka waqt" card (= calendar #4b).
- **W2** meeting slider in NewMeeting/Find-a-time + sach-ghantay fatigue line.
- **W3** 3D globe (lazy, fallback, reduced-motion, day/night math) — dashboard + clock popover.
- **W4** device-drift badge (server time endpoint) + opt-in "travelling" status.
- **W5** l10n shehar-naam + Speculation Rules + perf pass (LCP 1.8 s, INP 150 ms naapa hua).
Founder faisle: (a) fatigue ko sach-ghanton wali shakal (haan?) (b) travelling status opt-in (haan?) (c) market chip chahiye ya nahi.
