> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# "Bulletproof system" — founder ke 5 reliability/safety points (26 Oct 2026, docs-only)

Founder: "in 3 points par bhi aik nazar maar lijiyega taake aap ka system bilkul bulletproof ho jaye" (asal mein 5 points di hain). Koi code abhi nahi likha — status + implementation note, jab "ab likho" ho tab banega.

## 1. 8K video call freeze — Dynamic Adaptive Scaling
Founder: 95% computers 8K live video par crash ho jaate hain; internet bhi itna tez nahi hota. Dynamic scaling chahiye jo kamzor laptop/internet par khud-ba-khud 4K/1080p par aa jaye, screen freeze na ho.
- **Status check:** `src/lib/chat-video-quality.ts` mein **yeh already maujood hai** — ladder `8k -> 4k -> 1440p -> 1080p -> 720p -> 480p`, "adaptive controller" section hai jo sender ki quality rung set karta hai. Is liye yeh naya kaam nahi, **live verify karna hai** ke adaptive controller sach mein kamzor connection/laptop par neeche gir raha hai ya nahi (stress-test, M-series migration ke baad).

## 2. Bari files (8GB) par browser crash — WASM Chunk-based Streaming
Founder: Chrome/Edge 2GB se badi file ko memory mein nahi jhel sakte, tab crash ho jata hai. WASM chunk-based streaming chahiye, 8GB file ko 20MB-20MB tukron mein tor kar bhejna.
- **Status:** Naya kaam hai. General WASM kernel (PRICING-POSITIONING doc ka Rule 52 wala) ke andar ek module hoga: file ko client-side 20MB chunks mein tor kar, ek-ek chunk upload karna (resumable), kabhi poori file ek saath memory mein na ho. Attachment/storage upload flow ka hissa banega.

## 3. Pre-warmed QUIC path — background tab sleep
Founder: website par likha hai "Pre-warmed network path before you press call" — agar browser tab background mein so jaye (Chrome tab sleeping), QUIC connection freeze ho sakta hai. Background keep-alive ping chahiye.
- **Status:** Naya kaam — call-start se pehle jo QUIC warm-up connection hai, usay ek halka periodic ping/keep-alive dena hai jab tab background mein ho (Page Visibility API se tab state dekh kar), taake browser connection ko drop na kare.

## 4. Final-warning ladder — account block se pehle, email + push dono
Founder: yeh honesty ka sabse bada saboot hai ke hum direct block nahi karte. Notification email AUR push dono par honi chahiye, taake user na kahe "mujhe warning nahi mili."
- **Status check:** `src/lib/account-integrity.ts` + `IntegrityGate.tsx`/`AccountIntegrityPanel.tsx`/`IdentityVaultPanel.tsx` mein warning/appeal flow maujood hai. **Verify karna hai:** kya warning dono channel (email + push) par jaati hai, ya sirf ek par? Jahan sirf ek channel hai wahan doosra add karna hoga.

## 5. Device Safety Vault — biometrics nahi, lekin cookie-clear se identity loose na ho
Founder: "One person, one account — sealed device identity, no biometrics" achha hai privacy ke liye, lekin agar user browser clear kare ya cookies ura de, to device hardware identity UUID loose nahi honi chahiye. **Loophole hai, fix karna hai, repo mein phase se likhna hai.**
- **Status check (achi khabar — architecture pehle se sahi hai):** `src/lib/device-fingerprint.ts` (E70/E71) **cookie/localStorage ID store NAHI karta** — har baar browser se **hardware traits** (GPU, fonts, screen, timezone, etc — 5 groups) collect kar ke `groupHash` (SHA-256) banata hai. Yeh stateless hai: cookie/localStorage clear karne se iska result nahi badalta, kyunke yeh hardware se dobara compute hota hai, kahin store nahi hota client-side.
- **Lekin ek ALAG, kamzor id hai jo founder ke dare ko sach kar sakti hai:** `src/lib/handoff.ts` ka `deviceId()` — yeh `localStorage` mein ek random UUID banata/store karta hai (cross-device draft handoff ke liye), **yeh cookie-clear se zaroor loose hoti hai.** Yeh identity/fraud vault (E70/E71) se alag, kam-stakes cheez hai (sirf "yeh wahi laptop hai jahan draft chhora tha" janne ke liye), lekin agar founder isko bhi "device identity" maan rahe hain to confirm karna hoga ke dono mein farq samjha diya jaye.
- **Agla qadam:** (a) `basic-gate-probe.sh` jaisa ek live test banao jo cookies/localStorage clear kar ke dekhay ke E70/E71 ka device_hash wahi rehta hai ya nahi (chrome JS se simulate), (b) agar asli loophole mile (kisi edge-case mein hash badal jaye) to usay fix karo, (c) handoff ka localStorage id explicitly "best-effort convenience" ke taur par document karo, security-critical na banao.
