# 3D / Three.js plan — PARKED (founder 21 Oct 2026 00:14: 'chodo, repo main alag ker do')
FOUNDER 21 Oct 02:20: landing pages par 3D NAHI (mailbox hero hata). Baqi 3D workspace ke andar.
Order: Basic-green kaam pehle; 3D uske baad, ek ek (pehla = landing hero 3D mailbox). Faisla: TECH-MAP.md 0d.
Founder ki extras: mobile+tablet+laptop sab ko cinematic experience, ON/OFF toggle; Business Pro orb 'shahi/sab se mehnga'.

## 3D GRAPHICS — kahan ana hai (CEO faisla 20 Oct 2026; abhi bana NAHI, sirf naksha)
Halat: asli Three.js sirf AnexoChat `chat/cinema/Scene.tsx` mein hai. Baqi "cinematic" 2D canvas/CSS hai. Qaida: jahan 3D madad kare, jahan kaam ke raste mein aaye wahan NAHI (inbox/compose/settings = tez + saaf, 3D nahi).
| Jagah | 3D kya | Plan | Mobile |
|---|---|---|---|
| Landing hero | Dak ke packets ek 3D mailbox mein girte hain (ConvergenceCanvas ka 3D version) | sab | halka (kam particles) |
| Login / pehla workspace loader | BrandMark ka ghoomta 3D logo (WorkspaceLoader) | sab | halka |
| Dashboard hero (Greeting ke upar) | Plan ke rang ka chhota 3D badge/orb: Basic neela, Pro jamuni, Business sunehri | sab, 1 canvas | band (CSS gradient) |
| Empty states (khali inbox, khali calendar) | Chhoti 3D tasveer, sirf jab list khali ho | sab | band |
| Upgrade/plans page | Plan cards par halka 3D tilt | Basic ko dikhane ke liye | band |
| AnexoChat | Cinema scene (pehle se) | Pro+ | halka |
| **NAHI**: inbox list, thread, compose, settings, security, billing | — | — | — |
Har jagah: `prefers-reduced-motion` par band, lazy-load (pehle page chale, phir 3D), 1 page = 1 canvas. Founder ka hukm milne par ek ek karke banega; pehle landing hero.

## Pull / SQL status (founder ne chalana hai — aakhri maloom halat)

## Plan-orb rang (CEO faisla 21 Oct 2026, founder ne rang chunne ka ikhtiyar diya)
| Plan | Rang | Hex | Ehsaas |
|---|---|---|---|
| Basic | Neela | #3B82F6 | saaf, bharosemand |
| Pro | Jamuni | #8B5CF6 | creative, tez |
| Business | Sunehri | #D4A017 | daulat, kaarobar |
| Business Pro | **Imperial Ruby + Platinum kinara** | #9B1B30 + #E5E4E2 | shahi, sab se mehnga: gehra yaqooti laal, platinum chamak, dheemi "taaj" jaisi roshni. Sone se alag (Business sunehri hai), jamuni se alag (Pro) |
Qaida: Business Pro ka orb sab se zyada layers (inner glow + platinum ring + halka particle halo) — baqi plans se zyada "qeemti" lage.
## Basic se jude 3D kaam (founder: 'basic se related bhi likh lo')
- Khali inbox + khali calendar ki chhoti 3D tasveer (Basic ke pehle 10 minute ka hissa).
- Plans page: Basic card par halka tilt (Basic ko dikhane ke liye).
- Dashboard hero Basic neela orb.
- Sab jagah: mobile/tablet halka, laptop poora, ON/OFF toggle, reduced-motion band, lazy-load.

## 21 Oct 2026 03:00 — STATUS: BANA (v1) — ab PARKED nahi
Sab 5 jagah wire ho chuki hain (landing hero mailbox, loader logo, dashboard plan-orb, empty inbox/calendar, plans tilt). Mobile/tablet = "lite" (kam polygons/particles, dpr 1), laptop = "full" (pointer parallax). Toggle: Settings -> Appearance -> Graphics. Live test: 390/820/laptop pull ke baad.
