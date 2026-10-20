# 3D / Three.js plan — PARKED (founder 21 Oct 2026 00:14: 'chodo, repo main alag ker do')
Abhi koi 3D kaam nahi. Jab founder kahe tab hi; pehla = landing hero 3D mailbox. Faisla: TECH-MAP.md 0d.
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
