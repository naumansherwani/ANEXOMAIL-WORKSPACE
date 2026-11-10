> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# Founder channels — CEO soch (1 Nov 07:15 PKT) — SIRF LIST, koi code nahi (founder: "CEO ki tarah socho, user ke mindset se")
Founder ka sawal: Glitch / Support / Company Mail se founder ko KYA chahiye? Rule: har cheez asli source se; "Not connected" tab tak jab tak source nahi.
## User ki nazar se (3 haalat)
1. "Kuch toot gaya" -> Glitch: ek click "Report a problem" (page, kya hua, screenshot optional). Jawab chahiye: "mil gaya, fix ho raha".
2. "Mujhe madad chahiye" -> Support: sawal likho, jawab email/in-app mile, ticket ka status dikhe.
3. "Company se mail" -> Company Mail: billing, security, welcome — founder ka official awaaz.
## Founder ko in se kya chahiye (zaruri, tarteeb se)
A. **Inbox ek jagah**: teeno channel ek list: kaun, kab, kitna purana, status (new/open/waiting/solved). "Aaj kitne naye, kitne 24h se purane" ek nazar mein.
B. **Severity**: glitch ko khud-ba-khud darja (checkout/login toot = critical). Critical par Dashboard orb laal + push.
C. **SLA ghari**: har ticket par "jawab dene mein 4h baaki". Late = Dashboard "needs a look".
D. **Jawab yahin se**: reply founder UI se (Mail Desk step 11), sent history audit chain mein.
E. **Duplicate group**: 40 users ek hi glitch bataen = 1 issue "40 affected" (founder ko shor nahi, asar dikhe).
F. **Customer context**: report ke saath user ka plan/MRR (Polar) — paying customer ka glitch upar.
G. **Trend**: pichhle 7 din glitch/support ginti, sab se zyada kharab page, resolve time.
H. **Privacy**: message body sirf founder ko; list mein mail/IP nahi; delete/retention rule.
## Source (asli) har channel ka
- Glitch: awam site ka report form + client error beacon -> nayi table `user_reports` (Bun/Rust intake). Bina is intake ke wiring ka source EXIST NAHI.
- Support: wahi intake (kind=support) + support@ mailbox (Mail Desk).
- Company Mail: Postfix/Dovecot mailboxes via Mail Desk (step 11).
## Phase (ek waqt ek, har phase SQL >=800 lines)
P1 intake SQL+Rust (user_reports, events hash-chain, severity, dedup, SLA) -> channels `connected` apni E111 state machine se, evidence live_source.
P2 founder Inbox UI (list, filter, detail, status badlo) + Dashboard cards live.
P3 Reply + Mail Desk (step 11) -> Support/Company Mail connected.
P4 awam site par "Report a problem"/"Help" button (user side, awam migration ke saath; interim awam file touch founder ki haan par).
Nuqta: jab tak P1 server par nahi, "Not connected" SACH hai; P1 ke baad pehli report aate hi live.
