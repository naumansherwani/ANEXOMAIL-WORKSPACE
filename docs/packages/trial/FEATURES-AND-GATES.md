> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# Trial — kya milta hai, gate kya (CEO faisla)
Plan id `trial` (resolve_plan, ek hi code path; server gate asli, UI aaina — Rule 57). Sab server-side.

| Cheez | Trial mein | Gate / hadd |
|---|---|---|
| Address | 1 asli `handle@anexomail.com` (claim mojooda) | 1 per insaan, reserved list, 30 din reserve baad mein |
| Mail | asli send/receive, folders, search, snooze/schedule (Pro jhalak) | bahar bhejna rozana hadd (CEO: 25/din), attachment 10MB |
| Calendar + booking | **calendar ke SAB features** (founder 03:30), asli; booking link 1 | koi calendar feature band nahi (rooms/team-wide jaisi Business cheezein ko chhor kar: wahan "Business" chip) |
| People/Companies | asli (khud ke contacts) | koi sample contacts nahi |
| CRM jhalak | accounts/leads/pipeline ka **khali asli board** | max 25 records (Pro ka jhalak, full nahi) |
| **ANEXOChat (basic)** | **1:1 + chhote groups (max 5 log), text, photo/doc (10MB), reply/forward/star, message->Task/Promise** | **Voice/video calls, relay calls, voice notes, pop-out, group calls = BAND** (Business+ ki cheez, "Upgrade" nishan) |
| Storage | 1 GB | hard cap, trial org ke andar hi |
| AI | **ZERO** (mojooda lock) | — |
| Custom domain, integrations, SSO | nahi | Pro+ |
| Security | passkey/devices dekhna, ek insaan = ek trial (device vault) | signup holds (trialx LIVE) |

## ANEXOChat trial mein kyun (CEO)
ANEXOChat hamara farq hai (email + chat + kaam ek jagah: message -> Task/Promise). Chat ke bina trial user sirf "ek aur email" dekhta hai. Isliye basic chat **(calls ke bina)**: seedha, sasta (storage/bandwidth chhota), aur abuse kam (calls SFU/TURN kharcha bhi nahi). Calls trial ko "Upgrade" ka wazeh sabab bante hain.
**Chat kis se:** trial workspace ke andar. User 2 guests tak invite kar sakta hai (woh bhi 48h trial pate hain — viral loop); trial chat kabhi real company ke chat se mix nahi.
**SQL zaroori:** `chat_ensure_workspace` ab plan trial par `chat_not_entitled` nahi dega, lekin `chat_caps` mein calls=false (SQL, BUILD-PLAN step 2).
## Pro-only jhalak ka nishan
Har Pro/Business feature par chhota "Pro" ya "Business" chip + "See plans" — fakta nishan, kuch fake nahi dikhana.
